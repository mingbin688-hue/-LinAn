"""Durable local orchestration. Rules/dispatch never wait for model generation."""
import hashlib
import json
import time

from fastapi import HTTPException

from . import jobs as queue
from .agents import result, specialist
from .context_pack import ContextBuilder
from .db import audit, dumps
from .workflow_store import enqueue, finish, node, run_detail


def _put(c, run_id, key, name, agent, status, input_data, output, mode='rules', error=None, attempts=0):
    """Write a node only when its rendered content changes, to keep the monitor quiet."""
    row = c.execute('SELECT status,input,output FROM workflow_nodes WHERE run_id=? AND node_key=?',
                    (run_id, key)).fetchone()
    if row and row['status'] == status and row['input'] == dumps(input_data) and row['output'] == dumps(output):
        return False
    node(c, run_id, key, name, agent, status, input_data, output, mode, error, attempts=attempts)
    return True


class Workflows:
    def __init__(self, db, engine, provider):
        self.db, self.engine, self.provider = db, engine, provider
        self.context = ContextBuilder(engine)

    def settings(self, c):
        return {'auto_dispatch': c.execute("SELECT value FROM settings WHERE key='auto_dispatch'").fetchone()[0] == 'true'}

    def _fingerprint(self, c):
        tasks = [dict(r) for r in c.execute("SELECT * FROM tasks WHERE state='pending' ORDER BY id")]
        workers = self.engine.worker_list(c)
        exclusions = [r[0] for r in c.execute('SELECT task_id FROM workflow_exclusions ORDER BY task_id')]
        data = [dict(r) for r in c.execute("SELECT id,elder_id,updated FROM incidents WHERE status='open' AND category='data' ORDER BY id")]
        # Refresh before the engine's five-minute recommendation expiry.
        return hashlib.sha256(dumps([tasks, workers, exclusions, data, self.settings(c), int(time.time() // 240)]).encode()).hexdigest()

    @staticmethod
    def _workflow_user(kind):
        return {'role': 'admin', 'username': 'workflow:' + kind, 'name': '流程编排',
                'elder_id': None, 'staff_id': None}

    def process(self):
        """Synchronous deterministic phase, called after commit and by the monitor."""
        with self.db.transaction(True) as c:
            now = time.time()
            queue.recover_expired(c)
            # Older application databases acquire an outbox for still-active tasks too.
            for t in c.execute("SELECT * FROM tasks WHERE state!='closed' AND NOT EXISTS (SELECT 1 FROM workflow_runs w WHERE w.task_id=tasks.id AND w.kind='risk')").fetchall():
                enqueue(c, 'risk', t['id'], 'rehydrate:' + t['id'])
            fingerprint = self._fingerprint(c)
            policy = self.settings(c)
            old = c.execute("SELECT value FROM settings WHERE key='dispatch_fingerprint'").fetchone()
            recs = {}
            if not old or old[0] != fingerprint:
                pending = c.execute("SELECT count(*) FROM tasks WHERE state='pending'").fetchone()[0]
                if pending:
                    matches = self.engine.recommendations(c, 'workflow:dispatch')['recommendations']
                    recs = {m['task_id']: m for m in matches}
                    if policy['auto_dispatch']:
                        for m in matches:
                            t = c.execute('SELECT * FROM tasks WHERE id=?', (m['task_id'],)).fetchone()
                            i = c.execute('SELECT * FROM incidents WHERE id=?', (t['incident_id'],)).fetchone()
                            blocked = c.execute('SELECT 1 FROM workflow_exclusions WHERE task_id=?', (t['id'],)).fetchone()
                            unknown = c.execute("SELECT 1 FROM incidents WHERE elder_id=? AND category='data' AND status='open'", (t['elder_id'],)).fetchone()
                            state = json.loads(c.execute('SELECT state FROM elders WHERE id=?', (t['elder_id'],)).fetchone()[0])
                            data_fresh = state.get('online') and now - state.get('last_seen', 0) <= 1800
                            if t['level'] == 1 and t['required_skill'] == 'phone' and i['category'] == 'safety' and not blocked and not unknown and data_fresh:
                                try:
                                    self.engine.confirm(c, 'workflow:auto_dispatch', m['id'])
                                    audit(c, 'workflow:auto_dispatch', 'auto_dispatch', t['id'], {'recommendation_id': m['id'], 'policy': 'level1-phone-v1'})
                                except HTTPException as exc:
                                    # A failed validation leaves the task pending; never bypass it.
                                    if exc.status_code not in (409, 422):
                                        raise
                c.execute("INSERT INTO settings VALUES('dispatch_fingerprint',?) ON CONFLICT(key) DO UPDATE SET value=excluded.value", (self._fingerprint(c),))
            # Read valid latest recommendation snapshots when scheduling did not change.
            for row in c.execute("""SELECT r.* FROM recommendations r JOIN tasks t ON t.id=r.task_id
                    JOIN staff s ON s.id=r.staff_id WHERE t.state='pending' AND t.version=r.task_version
                    AND s.version=r.staff_version AND r.created>? ORDER BY r.created DESC""", (now - 300,)):
                if row['task_id'] not in recs:
                    t = c.execute('SELECT * FROM tasks WHERE id=?', (row['task_id'],)).fetchone()
                    w = c.execute('SELECT * FROM staff WHERE id=?', (row['staff_id'],)).fetchone()
                    if t and w and t['version'] == row['task_version'] and w['version'] == row['staff_version'] and now - row['created'] <= 300:
                        recs[row['task_id']] = dict(id=row['id'], staff_id=row['staff_id'], eta=row['eta'], staff_name=w['name'])
            runs = c.execute("SELECT * FROM workflow_runs WHERE kind IN ('risk','review') AND status IN ('queued','running','waiting_human') ORDER BY created").fetchall()
            for run in runs:
                snapshot = json.loads(run['snapshot'])
                t = c.execute('SELECT * FROM tasks WHERE id=?', (run['task_id'],)).fetchone()
                if not t:
                    continue
                t = dict(t)
                fresh = run['status'] == 'queued'
                agent = 'risk' if run['kind'] == 'risk' else 'review'
                base = specialist(snapshot, run['kind'])[1]
                if fresh:
                    pack = self.context.build(c, self._workflow_user(run['kind']), question='',
                                              elder_id=run['elder_id'], task_id=t['id'])
                    summary = pack['summary']
                    _put(c, run['id'], 'context', '上下文整理', 'context', 'completed',
                         {'elder_id': run['elder_id'], 'source': snapshot['elder']['profile'].get('origin'),
                          'digest': summary['fingerprint']},
                         {'context': pack['model_context'], 'chars': summary['chars'], 'budget': summary['budget'],
                          'truncated': summary['truncated'], 'sections': summary['sections'],
                          'redactions': summary['redactions'], 'gaps': summary['gaps']})
                    _put(c, run['id'], 'assessment', '风险依据' if run['kind'] == 'risk' else '处置反馈复核',
                         agent, 'completed', {'task_id': t['id'], 'version': snapshot['task']['version'],
                                              'digest': summary['fingerprint']}, base)
                    c.execute('UPDATE workflow_runs SET context_digest=?,updated=? WHERE id=?',
                              (summary['fingerprint'], now, run['id']))
                if run['kind'] == 'risk':
                    m = recs.get(t['id'])
                    blocked = c.execute('SELECT 1 FROM workflow_exclusions WHERE task_id=?', (t['id'],)).fetchone()
                    unknown = c.execute("SELECT 1 FROM incidents WHERE elder_id=? AND category='data' AND status='open'", (t['elder_id'],)).fetchone()
                    if t['state'] != 'pending':
                        auto = c.execute("SELECT 1 FROM audit WHERE action='auto_dispatch' AND entity_id=?", (t['id'],)).fetchone()
                        reason = '符合关注级电话核实规则，已自动派单' if auto else '任务已由现有业务流程推进'
                    elif blocked:
                        reason = '拒单或人工继续跟进后的任务，保留人工派单'
                    elif unknown or t['level'] != 1 or t['required_skill'] != 'phone':
                        reason = '数据未知、优先或紧急任务，需要管理员人工确认'
                    elif not policy['auto_dispatch']:
                        reason = '自动派单未开启，等待管理员确认'
                    elif not m:
                        reason = '暂无符合技能、在岗、空闲及优先级约束的可用人员，等待人工处理'
                    else:
                        reason = '当前数据或推荐已变化，等待重新核实与人工确认'
                    match_summary = f"建议由{m['staff_name']}处理，仿真到达 {m['eta']:.0f} 分钟" if m else '无当前可用推荐；保留待处理任务'
                    _put(c, run['id'], 'schedule', '全量任务调度', 'dispatch', 'completed',
                         {'task_id': t['id'], 'priority': '紧急程度、等待时间优先；技能与单任务容量硬约束'},
                         result(match_summary, base['evidence']))
                    waiting = t['state'] == 'pending'
                    _put(c, run['id'], 'confirmation', '派单确认', 'dispatch',
                         'waiting_human' if waiting else 'completed',
                         {'auto_dispatch': policy['auto_dispatch'], 'task_state': t['state']},
                         result(reason, base['evidence'], [reason]))
                else:
                    waiting = t['state'] == 'review'
                    reason = '等待管理员复核；未解决结果必须继续跟进' if waiting else '管理员已关闭或继续跟进该任务'
                    _put(c, run['id'], 'confirmation', '人工复核', 'review',
                         'waiting_human' if waiting else 'completed',
                         {'task_state': t['state']}, result(reason, base['evidence'], [reason]))
                if fresh:
                    if self.provider.enabled:
                        job = queue.enqueue(c, 'explanation', run['id'], {'run_id': run['id']}, priority=100)
                        node(c, run['id'], 'explanation', '生成解释', agent, 'queued',
                             {'snapshot_version': snapshot['task']['version']}, base,
                             attempts=job['attempts'] if job else 0)
                    else:
                        node(c, run['id'], 'explanation', '生成解释', agent, 'completed',
                             {'snapshot_version': snapshot['task']['version']}, base,
                             error=self.provider.configuration_reason)
                    c.execute('UPDATE workflow_runs SET summary=? WHERE id=?', (base['summary'], run['id']))
                settled = 'waiting_human' if waiting else 'completed'
                if run['status'] != settled:
                    finish(c, run['id'], settled)

    def drain(self, limit=4):
        """Lease one job at a time; an interrupted worker becomes retryable after its lease."""
        for _ in range(limit):
            with self.db.transaction(True) as c:
                claimed = queue.claim(c, 'explanation', 1)
                if not claimed:
                    return
                job = claimed[0]
                run = c.execute('SELECT * FROM workflow_runs WHERE id=?', (job['key'],)).fetchone()
                if not run:
                    queue.cancel(c, job['id'])
                    continue
                snapshot = json.loads(run['snapshot'])
                agent = 'risk' if run['kind'] == 'risk' else 'review'
                if job['exhausted']:
                    fallback = result('解释生成多次中断，保留已有规则结果', mode='fallback',
                                      fallback_reason='生成重试已达上限')
                    node(c, run['id'], 'explanation', '生成解释', agent, 'failed',
                         {'snapshot_version': snapshot['task']['version'], 'historical': False},
                         fallback, 'fallback', fallback['fallback_reason'],
                         attempts=job['attempts'])
                    c.execute("UPDATE workflow_runs SET status='failed',mode='fallback',updated=? WHERE id=?",
                              (time.time(), run['id']))
                    continue
                base = specialist(snapshot, run['kind'])[1]
                node(c, run['id'], 'explanation', '生成解释', agent, 'running',
                     {'snapshot_version': snapshot['task']['version'], 'attempt': job['attempts']},
                     base, attempts=job['attempts'], started=time.time())
                lease = job['lease_until']
            started = time.perf_counter()
            try:
                answer = self.provider.generate(base, snapshot)
            except Exception as exc:  # expected provider problems fall back inside generate
                message = '解释生成异常：' + type(exc).__name__
                with self.db.transaction(True) as c:
                    if queue.lease_ok(c, job['id'], lease):
                        outcome = queue.fail(c, job['id'], lease, message)
                        reason = '生成重试已达上限' if outcome == 'dead' else '生成中断，稍后自动重试'
                        node(c, run['id'], 'explanation', '生成解释', agent, 'failed',
                             {'snapshot_version': snapshot['task']['version'], 'attempt': job['attempts']},
                             {**base, 'mode': 'fallback', 'fallback_reason': reason},
                             'fallback', message, attempts=job['attempts'], started=started)
                        if outcome == 'dead':
                            finish(c, run['id'], 'failed', mode='fallback')
                continue
            with self.db.transaction(True) as c:
                if not queue.lease_ok(c, job['id'], lease):
                    continue
                run = dict(c.execute('SELECT * FROM workflow_runs WHERE id=?', (job['key'],)).fetchone())
                task = c.execute('SELECT version FROM tasks WHERE id=?', (run['task_id'],)).fetchone()
                stale = task is None or task['version'] != snapshot['task']['version']
                if stale:
                    answer = {**base, 'mode': 'fallback',
                              'fallback_reason': '任务版本已变化；保留历史快照解释，不作为当前操作建议'}
                node(c, run['id'], 'explanation', '生成解释', agent, 'completed',
                     {'snapshot_version': snapshot['task']['version'], 'historical': stale}, answer,
                     answer['mode'], answer['fallback_reason'], (time.perf_counter() - started) * 1000,
                     attempts=job['attempts'], started=time.time() - (time.perf_counter() - started),
                     finished=time.time())
                c.execute('UPDATE workflow_runs SET summary=?,mode=?,updated=? WHERE id=?',
                          (answer['summary'], answer['mode'], time.time(), run['id']))
                queue.succeed(c, job['id'], lease, {'run_id': run['id'], 'mode': answer['mode']})

    def stats(self):
        with self.db.transaction() as c:
            runs = {key: 0 for key in ('queued', 'running', 'waiting_human', 'completed', 'failed', 'cancelled')}
            for row in c.execute('SELECT status,count(*) AS n FROM workflow_runs GROUP BY status'):
                runs[row['status']] = row['n']
            runs['total'] = sum(runs.values())
            return {'runs': runs, 'jobs': queue.stats(c)}

    def jobs(self, state='all', limit=50):
        if state != 'all' and state not in queue.STATES:
            raise HTTPException(422, '未知的任务状态')
        with self.db.transaction() as c:
            return queue.list_jobs(c, state, limit)

    def retry_job(self, job_id, actor='admin'):
        with self.db.transaction(True) as c:
            row = c.execute('SELECT * FROM jobs WHERE id=?', (job_id,)).fetchone()
            if not row:
                return None
            if row['state'] not in ('failed', 'dead', 'cancelled'):
                raise HTTPException(409, '只有失败、死信或已取消的任务可以重试')
            queue.retry(c, job_id)
            run = c.execute('SELECT * FROM workflow_runs WHERE id=?', (row['job_key'],)).fetchone()
            if run:
                node(c, run['id'], 'explanation', '生成解释',
                     'risk' if run['kind'] == 'risk' else 'review', 'queued',
                     {'snapshot_version': json.loads(run['snapshot'])['task']['version']}, {},
                     attempts=0)
                if run['status'] in ('failed', 'cancelled'):
                    c.execute("UPDATE workflow_runs SET status='queued',updated=? WHERE id=?",
                              (time.time(), run['id']))
            audit(c, actor, 'job_retry', job_id, {'kind': row['kind'], 'key': row['job_key']})
        self.drain(1)
        return {'id': job_id, 'state': 'queued'}

    def cancel_job(self, job_id, actor='admin'):
        with self.db.transaction(True) as c:
            row = c.execute('SELECT * FROM jobs WHERE id=?', (job_id,)).fetchone()
            if not row:
                return None
            if queue.cancel(c, job_id) is None:
                raise HTTPException(409, '只有排队或运行中的任务可以取消')
            run = c.execute('SELECT * FROM workflow_runs WHERE id=?', (row['job_key'],)).fetchone()
            if run:
                node(c, run['id'], 'explanation', '生成解释',
                     'risk' if run['kind'] == 'risk' else 'review', 'cancelled',
                     {'snapshot_version': json.loads(run['snapshot'])['task']['version']}, {},
                     error='管理员取消')
            audit(c, actor, 'job_cancel', job_id, {'kind': row['kind'], 'key': row['job_key']})
        return {'id': job_id, 'state': 'cancelled'}

    def retry_run(self, run_id, actor='admin'):
        with self.db.transaction(True) as c:
            run = c.execute('SELECT * FROM workflow_runs WHERE id=?', (run_id,)).fetchone()
            if not run:
                return None
            if run['status'] not in ('failed', 'cancelled'):
                raise HTTPException(409, '只有失败或已取消的流程可以重试')
            c.execute("UPDATE workflow_runs SET status='queued',mode='rules',summary='等待规则编排',updated=? WHERE id=?",
                      (time.time(), run_id))
            c.execute("DELETE FROM workflow_nodes WHERE run_id=? AND node_key IN ('explanation','schedule','confirmation')",
                      (run_id,))
            job = c.execute("SELECT id FROM jobs WHERE kind='explanation' AND job_key=? AND state IN ('failed','dead','cancelled')",
                            (run_id,)).fetchone()
            if job:
                queue.retry(c, job['id'])
            audit(c, actor, 'workflow_retry', run_id, {'kind': run['kind']})
        self.process()
        return {'id': run_id, 'status': 'queued'}

    def task_runs(self, c, task_id):
        return [run_detail(c, r[0]) for r in
                c.execute("SELECT id FROM workflow_runs WHERE task_id=? ORDER BY created DESC LIMIT 8", (task_id,))]
