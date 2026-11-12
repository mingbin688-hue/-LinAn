"""Resident records, reported events and open incidents."""
import json
import time

from fastapi import APIRouter, Depends, HTTPException, Request

from ..db import audit, dumps
from ..deps import current_user, database, require_admin, require_elder
from ..engine import getrow
from ..schemas import ElderProfile, Event
from ..serializers import decorate_elders, decorated_elder
from ..scope import visible_ids

router = APIRouter()


@router.get('/api/elders')
def elders(request: Request, u=Depends(current_user)):
    with database(request).transaction() as c:
        ids = visible_ids(c, u)
        return decorate_elders(c, [r for r in c.execute('SELECT * FROM elders ORDER BY id') if r['id'] in ids])


@router.get('/api/elders/{eid}')
def elder_detail(request: Request, eid: int, u=Depends(current_user)):
    with database(request).transaction() as c:
        require_elder(c, u, eid)
        elder = decorated_elder(c, getrow(c, 'elders', eid))
        elder['events'] = [dict(r) for r in c.execute(
            'SELECT * FROM events WHERE elder_id=? ORDER BY received_at DESC LIMIT 80', (eid,))]
        for event in elder['events']:
            event['payload'] = json.loads(event['payload'])
        return elder


@router.post('/api/elders')
def add_elder(request: Request, body: ElderProfile, u=Depends(require_admin)):
    now = time.time()
    engine = request.app.state.engine
    with database(request).transaction(True) as c:
        profile = {'routine': body.routine, 'checkin_hour': body.checkin_hour, 'history_days': 0,
                   'activity_scale': 1, 'origin': 'manual-demo', 'note': '新档案尚无活动历史'}
        state = {'online': False, 'last_seen': 0, 'last_checkin': now, 'observed_at': 0, 'presence': 'unknown',
                 'count15': 0, 'count60': 0, 'gap': 0, 'score': 0, 'anomaly': False, 'evidence': [],
                 'source': '尚未接入数据'}
        cur = c.execute('INSERT INTO elders(name,age,building,contact,profile,state) VALUES(?,?,?,?,?,?)',
                        (body.name, body.age, body.building, body.contact, dumps(profile), dumps(state)))
        engine.evaluate(c, cur.lastrowid, u['username'])
        audit(c, u['username'], 'elder_created', str(cur.lastrowid), body.model_dump())
        eid = cur.lastrowid
    request.app.state.workflows.process()
    return {'id': eid}


@router.put('/api/elders/{eid}')
def edit_elder(request: Request, eid: int, body: ElderProfile, u=Depends(require_admin)):
    with database(request).transaction(True) as c:
        row = getrow(c, 'elders', eid)
        profile = json.loads(row['profile'])
        profile.update(routine=body.routine, checkin_hour=body.checkin_hour)
        c.execute('UPDATE elders SET name=?,age=?,building=?,contact=?,profile=?,version=version+1 WHERE id=?',
                  (body.name, body.age, body.building, body.contact, dumps(profile), eid))
        audit(c, u['username'], 'elder_updated', str(eid), body.model_dump())
    return {'ok': True}


@router.post('/api/events')
def event(request: Request, body: Event, u=Depends(current_user)):
    with database(request).transaction(True) as c:
        require_elder(c, u, body.elder_id)
        if u['role'] in ('elder', 'family') and body.kind not in ('safe', 'contact', 'sos', 'away', 'home', 'rest'):
            raise HTTPException(403, '当前角色不能提交此类型事件')
        if body.kind == 'activity' and any(k not in body.payload for k in ('count15', 'count60', 'gap')):
            raise HTTPException(422, '活动窗口需包含count15、count60、gap')
        if body.kind == 'activity' and body.payload['count60'] < body.payload['count15']:
            raise HTTPException(422, '60分钟活动数不能小于15分钟活动数')
        result = request.app.state.engine.ingest(c, u['username'], body.model_dump())
    request.app.state.workflows.process()
    return result


@router.get('/api/incidents')
def incidents(request: Request, u=Depends(current_user)):
    with database(request).transaction() as c:
        ids = visible_ids(c, u)
        names = {r['id']: r['name'] for r in c.execute('SELECT id,name FROM elders')}
        results = []
        for row in c.execute('SELECT * FROM incidents ORDER BY status DESC,level DESC,created'):
            if row['elder_id'] in ids:
                incident = dict(row)
                incident['evidence'] = json.loads(incident['evidence'])
                incident['elder_name'] = names.get(incident['elder_id'], '未知老人')
                results.append(incident)
        return results
