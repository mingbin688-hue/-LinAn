"""Transactional workflow outbox. Never calls a model or changes task state."""
import json
import secrets
import time

from .db import dumps
from .workflow_defs import definition


def enqueue(c, kind, task_id, trigger_key, context_digest=''):
    task = dict(c.execute('SELECT * FROM tasks WHERE id=?', (task_id,)).fetchone())
    elder = dict(c.execute('SELECT * FROM elders WHERE id=?', (task['elder_id'],)).fetchone())
    incident = dict(c.execute('SELECT * FROM incidents WHERE id=?', (task['incident_id'],)).fetchone())
    elder['profile'] = json.loads(elder['profile'])
    elder['state'] = json.loads(elder['state'])
    incident['evidence'] = json.loads(incident['evidence'])
    feedback = [dict(r) for r in c.execute('SELECT * FROM feedback WHERE task_id=? ORDER BY created,id', (task_id,))]
    history = [{'action': r['action'], 'created': r['created']} for r in
               c.execute("SELECT action,created FROM audit WHERE entity_id=? AND (action LIKE 'task_%' OR action='dispatch_confirmed') ORDER BY id", (task_id,))]
    stamp = time.time()
    run_id = 'WF-' + secrets.token_hex(6)
    c.execute('''INSERT OR IGNORE INTO workflow_runs
        (id,kind,trigger_key,elder_id,task_id,owner,status,mode,summary,snapshot,
         definition_version,context_digest,created,updated)
        VALUES(?,?,?,?,?,NULL,'queued','rules','等待规则编排',?,?,?,?,?)''',
              (run_id, kind, trigger_key, task['elder_id'], task_id,
               dumps({'elder': elder, 'task': task, 'incident': incident, 'feedback': feedback, 'history': history}),
               definition(kind)['version'], context_digest or '', stamp, stamp))
    return run_id


def node(c, run_id, key, name, agent, status, input_data, output, mode='rules', error=None,
         elapsed_ms=0, attempts=0, started=0.0, finished=0.0):
    c.execute('''INSERT INTO workflow_nodes(run_id,node_key,name,agent,status,input,output,elapsed_ms,
        mode,error,attempts,started,finished) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)
        ON CONFLICT(run_id,node_key) DO UPDATE SET
        name=excluded.name,agent=excluded.agent,status=excluded.status,input=excluded.input,
        output=excluded.output,elapsed_ms=excluded.elapsed_ms,mode=excluded.mode,error=excluded.error,
        attempts=excluded.attempts,
        started=CASE WHEN excluded.started>0 THEN excluded.started ELSE workflow_nodes.started END,
        finished=CASE WHEN excluded.finished>0 THEN excluded.finished ELSE workflow_nodes.finished END''',
              (run_id, key, name, agent, status, dumps(input_data), dumps(output), elapsed_ms,
               mode, error, attempts, started, finished))


def finish(c, run_id, status, summary=None, mode=None):
    """Close a run in one statement; ``None`` leaves the column untouched."""
    stamp = time.time()
    c.execute('UPDATE workflow_runs SET status=?,summary=COALESCE(?,summary),mode=COALESCE(?,mode),updated=? WHERE id=?',
              (status, summary, mode, stamp, run_id))


def run_detail(c, run_id):
    row = c.execute('SELECT * FROM workflow_runs WHERE id=?', (run_id,)).fetchone()
    if not row:
        return None
    result = {k: v for k, v in dict(row).items() if k not in ('snapshot', 'trigger_key', 'owner')}
    definition_meta = definition(row['kind'])
    result['definition'] = dict(version=definition_meta['version'], title=definition_meta['title'],
                                nodes=definition_meta['nodes'])
    if row['task_id']:
        snapshot = json.loads(row['snapshot'])
        current = c.execute('SELECT version FROM tasks WHERE id=?', (row['task_id'],)).fetchone()
        result['snapshot_version'] = snapshot['task']['version']
        result['historical'] = current is None or current['version'] != result['snapshot_version']
    result['nodes'] = []
    for item in c.execute('SELECT * FROM workflow_nodes WHERE run_id=? ORDER BY id', (run_id,)):
        node_item = dict(item)
        try:
            node_item['input'] = json.loads(node_item['input'])
        except (TypeError, ValueError):
            node_item['input'] = {}
        try:
            node_item['output'] = json.loads(node_item['output'])
        except (TypeError, ValueError):
            node_item['output'] = {}
        result['nodes'].append(node_item)
    return result
