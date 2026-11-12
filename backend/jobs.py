"""Durable background jobs with leases, retry backoff and a dead-letter state.

The queue is deliberately small: SQLite is the source of truth, a job is claimed
under BEGIN IMMEDIATE, and the model call happens after the claim transaction
has been released. An interrupted worker is retried after its lease expires; it
must never duplicate a business side effect because writes are guarded by the
lease token and by the workflows' own version checks.
"""
import json
import secrets
import time

from .db import dumps

LEASE_SECONDS = 30
MAX_ATTEMPTS = 3
STATES = ('queued', 'running', 'done', 'failed', 'dead', 'cancelled')


def new_id():
    return 'JOB-' + secrets.token_hex(8)


def enqueue(c, kind, key, payload=None, priority=0, run_at=None, max_attempts=MAX_ATTEMPTS):
    """Insert one active job per (kind, key); repeated triggers are idempotent."""
    now = time.time()
    run_at = now if run_at is None else run_at
    c.execute("""INSERT OR IGNORE INTO jobs(id,kind,job_key,payload,state,priority,run_at,attempts,
                 max_attempts,lease_until,last_error,result,created,updated)
                 VALUES(?,?,?,?,'queued',?,?,0,?,0,'','{}',?,?)""",
              (new_id(), kind, key, dumps(payload or {}), int(priority), run_at, int(max_attempts), now, now))
    row = c.execute("""SELECT * FROM jobs WHERE kind=? AND job_key=? AND state IN ('queued','running')""",
                    (kind, key)).fetchone()
    return public(row) if row else None


def public(row):
    if row is None:
        return None
    item = dict(row)
    item['key'] = item.pop('job_key')
    return item


def claim(c, kind, limit=1):
    """Lease due jobs. Exhausted rows are moved to the dead-letter state."""
    now = time.time()
    rows = c.execute("""SELECT * FROM jobs WHERE kind=? AND
        ((state='queued' AND run_at<=?) OR (state='running' AND lease_until<?))
        ORDER BY priority DESC, run_at, rowid LIMIT ?""",
                     (kind, now, now, int(limit))).fetchall()
    claimed = []
    for row in rows:
        attempts = row['attempts']
        if attempts >= row['max_attempts']:
            c.execute("""UPDATE jobs SET state='dead',lease_until=0,updated=?,
                         last_error=CASE WHEN last_error='' THEN '重试次数已达上限' ELSE last_error END
                         WHERE id=?""", (now, row['id']))
            item = public(row)
            item.update(state='dead', exhausted=True)
            item['payload'] = json.loads(row['payload'])
            claimed.append(item)
            continue
        lease = now + LEASE_SECONDS
        c.execute("UPDATE jobs SET state='running',attempts=attempts+1,lease_until=?,updated=? WHERE id=?",
                  (lease, now, row['id']))
        item = public(row)
        item.update(state='running', attempts=attempts + 1, lease_until=lease, exhausted=False)
        item['payload'] = json.loads(row['payload'])
        claimed.append(item)
    return claimed


def lease_ok(c, job_id, lease):
    row = c.execute('SELECT state,lease_until FROM jobs WHERE id=?', (job_id,)).fetchone()
    return bool(row and row['state'] == 'running' and row['lease_until'] == lease)


def succeed(c, job_id, lease, result=None):
    now = time.time()
    cur = c.execute("""UPDATE jobs SET state='done',lease_until=0,result=?,last_error='',updated=?
                       WHERE id=? AND state='running' AND lease_until=?""",
                    (dumps(result or {}), now, job_id, lease))
    return cur.rowcount == 1


def fail(c, job_id, lease, error=''):
    now = time.time()
    row = c.execute('SELECT * FROM jobs WHERE id=?', (job_id,)).fetchone()
    if not row or row['state'] != 'running' or row['lease_until'] != lease:
        return None
    message = (error or '')[:500]
    if row['attempts'] >= row['max_attempts']:
        c.execute("""UPDATE jobs SET state='dead',lease_until=0,last_error=?,updated=? WHERE id=?""",
                  (message or '重试次数已达上限', now, job_id))
        return 'dead'
    delay = min(5 * (2 ** max(0, row['attempts'] - 1)), 300)
    c.execute("""UPDATE jobs SET state='queued',lease_until=0,run_at=?,last_error=?,updated=?
                 WHERE id=?""", (now + delay, message, now, job_id))
    return 'queued'


def cancel(c, job_id):
    now = time.time()
    row = c.execute('SELECT state FROM jobs WHERE id=?', (job_id,)).fetchone()
    if not row or row['state'] not in ('queued', 'running'):
        return None
    c.execute("UPDATE jobs SET state='cancelled',lease_until=0,updated=?,last_error='任务已取消' WHERE id=?",
              (now, job_id))
    return 'cancelled'


def retry(c, job_id):
    now = time.time()
    row = c.execute('SELECT state FROM jobs WHERE id=?', (job_id,)).fetchone()
    if not row or row['state'] not in ('failed', 'dead', 'cancelled'):
        return None
    c.execute("""UPDATE jobs SET state='queued',attempts=0,lease_until=0,run_at=?,last_error='',
                 updated=?,result='{}' WHERE id=?""", (now, now, job_id))
    return 'queued'


def recover_expired(c):
    """Requeue interrupted leases; exhausted ones become dead letters."""
    now = time.time()
    dead = [r[0] for r in c.execute("""SELECT id FROM jobs WHERE state='running' AND lease_until<?
                                       AND attempts>=max_attempts""", (now,))]
    c.execute("""UPDATE jobs SET state='dead',lease_until=0,updated=?,last_error='重试次数已达上限'
                 WHERE state='running' AND lease_until<? AND attempts>=max_attempts""", (now, now))
    c.execute("""UPDATE jobs SET state='queued',run_at=?,lease_until=0,updated=?
                 WHERE state='running' AND lease_until<?""", (now, now, now))
    return dead


def stats(c):
    now = time.time()
    counts = {state: 0 for state in STATES}
    for row in c.execute('SELECT state,count(*) AS n FROM jobs GROUP BY state'):
        counts[row['state']] = row['n']
    oldest = c.execute("SELECT min(created) FROM jobs WHERE state='queued'").fetchone()[0]
    return {**counts, 'total': sum(counts.values()),
            'oldest_queued_seconds': max(0.0, now - oldest) if oldest else 0.0}


def list_jobs(c, state='all', limit=50):
    limit = max(1, min(int(limit), 200))
    if state and state != 'all':
        rows = c.execute("""SELECT * FROM jobs WHERE state=? ORDER BY created DESC LIMIT ?""",
                         (state, limit)).fetchall()
    else:
        rows = c.execute('SELECT * FROM jobs ORDER BY created DESC LIMIT ?', (limit,)).fetchall()
    items = []
    for row in rows:
        item = {k: v for k, v in public(row).items() if k not in ('payload', 'result')}
        items.append(item)
    return items


def count_active(c, kind=None):
    if kind:
        return c.execute("SELECT count(*) FROM jobs WHERE kind=? AND state IN ('queued','running')",
                         (kind,)).fetchone()[0]
    return c.execute("SELECT count(*) FROM jobs WHERE state IN ('queued','running')").fetchone()[0]
