"""Demo scenarios, offline experiments and the public-data replay window."""
import json
import time

from fastapi import APIRouter, Depends, HTTPException, Request

from ..db import audit, dumps
from ..deps import database, require_admin
from ..engine import getrow, uid
from ..ml import PersonalModel, casas_split
from ..schemas import ReplayWindow, Scenario

router = APIRouter()


@router.post('/api/demo/scenario')
def scenario(request: Request, body: Scenario, u=Depends(require_admin)):
    engine = request.app.state.engine
    kinds = {'story': [(1, 'missed_checkin', {}), (2, 'activity', {'count15': 0, 'count60': 0, 'gap': 180}),
                       (3, 'sos', {})],
             'offline': [(body.elder_id, 'data_offline', {})],
             'away': [(body.elder_id, 'away', {'hours': 4})],
             'normal': [(body.elder_id, 'safe', {})],
             'conflict': [(4, 'sos', {}), (5, 'need_help', {}), (6, 'sos', {})],
             'cold_start': [(body.elder_id, 'activity', {'count15': 0, 'count60': 0, 'gap': 60})]}
    with database(request).transaction(True) as c:
        if body.scenario == 'cold_start':
            elder = getrow(c, 'elders', body.elder_id)
            profile = json.loads(elder['profile'])
            profile['history_days'] = 3
            c.execute('UPDATE elders SET profile=? WHERE id=?', (dumps(profile), body.elder_id))
        results = [engine.ingest(c, u['username'],
                                 {'id': uid('SIM'), 'elder_id': eid, 'kind': kind, 'payload': payload,
                                  'observed_at': time.time(), 'source': '合成情景回放'})
                   for eid, kind, payload in kinds[body.scenario]]
        audit(c, u['username'], 'scenario_played', body.scenario, {'origin': 'synthetic', 'events': results})
    request.app.state.workflows.process()
    return {'events': results, 'origin': 'synthetic'}


@router.post('/api/experiments/run')
def run_experiment(request: Request, u=Depends(require_admin)):
    from ..experiments import run_all
    result = run_all()
    with database(request).transaction(True) as c:
        eid = uid('EXP')
        c.execute('INSERT INTO experiments VALUES(?,?,?,?)', (eid, 'synthetic', dumps(result), time.time()))
        audit(c, u['username'], 'experiment_run', eid, {'origin': 'synthetic', 'seed': 42})
    return result


@router.post('/api/replay/window')
def replay_window(request: Request, body: ReplayWindow, u=Depends(require_admin)):
    engine = request.app.state.engine
    cache = request.app.state.replay_cache
    if 'rows' not in cache:
        split = casas_split()
        if split is None:
            raise HTTPException(409, '尚未准备公开数据，请先运行 scripts/data_pipeline.py')
        cache.update(rows=split['replay'], train_days=split['train_days'],
                     model=PersonalModel(split['train'], split['validation']))
    rows = cache['rows']
    if body.offset >= len(rows):
        raise HTTPException(422, f'窗口偏移超出测试段，允许0至{len(rows)-1}')
    row = rows[body.offset]
    with database(request).transaction(True) as c:
        elder = getrow(c, 'elders', body.elder_id)
        profile = json.loads(elder['profile'])
        profile.update(origin='CASAS Aruba replay', history_days=cache['train_days'], baseline_ready=True)
        c.execute('UPDATE elders SET profile=? WHERE id=?', (dumps(profile), body.elder_id))
        engine.models.remember(body.elder_id, profile, cache['model'])
        result = engine.ingest(c, u['username'], {
            'id': f'CASAS-{body.elder_id}-{int(row["timestamp"])}', 'elder_id': body.elder_id,
            'kind': 'activity', 'observed_at': time.time(), 'source': 'CASAS Aruba 公开数据窗口回放',
            'payload': {'count15': row['count15'], 'count60': row['count60'], 'gap': row['gap'],
                        'original_timestamp': row['timestamp']}})
    request.app.state.workflows.process()
    return {**result, 'offset': body.offset, 'total': len(rows), 'original_timestamp': row['timestamp'],
            'count15': row['count15'], 'gap': row['gap'], 'origin': 'CASAS replay in virtual profile'}


@router.get('/api/experiments')
def experiments(request: Request, u=Depends(require_admin)):
    with database(request).transaction() as c:
        row = c.execute('SELECT * FROM experiments ORDER BY created DESC LIMIT 1').fetchone()
        return json.loads(row['result']) if row else None


@router.get('/api/feedback/export')
def export_feedback(request: Request, u=Depends(require_admin)):
    with database(request).transaction() as c:
        return {'purpose': '已复核反馈供离线分析；不直接修改在线模型',
                'items': [dict(r) for r in c.execute(
                    "SELECT f.*,t.elder_id FROM feedback f JOIN tasks t ON t.id=f.task_id "
                    "WHERE t.state='closed' ORDER BY f.created")]}
