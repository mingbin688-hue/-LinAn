"""Transactional workflow outbox. Never calls a model or changes task state."""
import json
import secrets
import time
from .db import dumps


def enqueue(c, kind, task_id, trigger_key):
    task = dict(c.execute('SELECT * FROM tasks WHERE id=?', (task_id,)).fetchone())
    elder = dict(c.execute('SELECT * FROM elders WHERE id=?', (task['elder_id'],)).fetchone())
    incident = dict(c.execute('SELECT * FROM incidents WHERE id=?', (task['incident_id'],)).fetchone())
    elder['profile'] = json.loads(elder['profile'])
    elder['state'] = json.loads(elder['state'])
    incident['evidence'] = json.loads(incident['evidence'])
    feedback = [dict(r) for r in c.execute('SELECT * FROM feedback WHERE task_id=? ORDER BY created,id', (task_id,))]
    history = [{'action':r['action'],'created':r['created']} for r in
               c.execute("SELECT action,created FROM audit WHERE entity_id=? AND (action LIKE 'task_%' OR action='dispatch_confirmed') ORDER BY id",(task_id,))]
    stamp = time.time()
    c.execute('''INSERT OR IGNORE INTO workflow_runs
        VALUES(?,?,?,?,?,NULL,'queued','rules','等待规则编排',?,?,?)''',
        ('WF-'+secrets.token_hex(6), kind, trigger_key, task['elder_id'], task_id,
         dumps({'elder': elder, 'task': task, 'incident': incident, 'feedback': feedback,'history':history}), stamp, stamp))


def node(c, run_id, key, name, agent, status, input_data, output, mode='rules', error=None, elapsed_ms=0):
    c.execute('''INSERT INTO workflow_nodes(run_id,node_key,name,agent,status,input,output,elapsed_ms,mode,error)
        VALUES(?,?,?,?,?,?,?,?,?,?) ON CONFLICT(run_id,node_key) DO UPDATE SET
        status=excluded.status,input=excluded.input,output=excluded.output,
        elapsed_ms=excluded.elapsed_ms,mode=excluded.mode,error=excluded.error''',
        (run_id, key, name, agent, status, dumps(input_data), dumps(output), elapsed_ms, mode, error))


def run_detail(c, run_id):
    row = c.execute('SELECT * FROM workflow_runs WHERE id=?', (run_id,)).fetchone()
    if not row:
        return None
    result = {k:v for k,v in dict(row).items() if k not in ('snapshot', 'trigger_key', 'owner')}
    if row['task_id']:
        snapshot = json.loads(row['snapshot'])
        current = c.execute('SELECT version FROM tasks WHERE id=?',(row['task_id'],)).fetchone()
        result['snapshot_version'] = snapshot['task']['version']
        result['historical'] = current['version']!=result['snapshot_version']
    result['nodes'] = []
    for row in c.execute('SELECT * FROM workflow_nodes WHERE run_id=? ORDER BY id', (run_id,)):
        item = dict(row)
        item['input'] = json.loads(item['input'])
        item['output'] = json.loads(item['output'])
        result['nodes'].append(item)
    return result
