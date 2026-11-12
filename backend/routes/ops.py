"""Task lifecycle, dispatch confirmation and worker availability."""
import json

from fastapi import APIRouter, Depends, HTTPException, Request

from ..db import audit
from ..deps import database, require_admin, require_operator
from ..engine import getrow
from ..schemas import Action, Confirmation, WorkerUpdate
from ..serializers import decorated_task, decorate_tasks

router = APIRouter()


@router.get('/api/tasks')
def tasks(request: Request, u=Depends(require_operator)):
    with database(request).transaction() as c:
        return decorate_tasks(c, [r for r in c.execute('SELECT * FROM tasks ORDER BY level DESC,created')
                                  if u['role'] == 'admin' or r['staff_id'] == u['staff_id']])


@router.get('/api/tasks/{tid}')
def task_detail(request: Request, tid: str, u=Depends(require_operator)):
    with database(request).transaction() as c:
        task = getrow(c, 'tasks', tid)
        if u['role'] == 'staff' and task['staff_id'] != u['staff_id']:
            raise HTTPException(403, '无权访问此任务')
        result = decorated_task(c, task)
        result['feedback'] = [dict(r) for r in c.execute(
            'SELECT * FROM feedback WHERE task_id=? ORDER BY created', (tid,))]
        entities = (tid, task['incident_id'])
        result['audit'] = [dict(r) for r in c.execute(
            'SELECT * FROM audit WHERE entity_id IN (?,?) ORDER BY created', entities)]
        for row in result['audit']:
            row['payload'] = json.loads(row['payload'])
        result['agent_runs'] = request.app.state.workflows.task_runs(c, tid)
        return result


@router.post('/api/dispatch/recommend')
def recommend(request: Request, u=Depends(require_admin)):
    with database(request).transaction(True) as c:
        return request.app.state.engine.recommendations(c, u['username'])


@router.post('/api/dispatch/confirm')
def confirm(request: Request, body: Confirmation, u=Depends(require_admin)):
    with database(request).transaction(True) as c:
        result = request.app.state.engine.confirm(c, u['username'], body.recommendation_id,
                                                  body.staff_id, body.reason)
    request.app.state.workflows.process()
    return result


@router.post('/api/tasks/{tid}/action')
def task_action(request: Request, tid: str, body: Action, u=Depends(require_operator)):
    with database(request).transaction(True) as c:
        if body.action in ('followup', 'close') and u['role'] != 'admin':
            raise HTTPException(403, '复核操作需要管理员权限')
        result = request.app.state.engine.action(c, u, tid, body.action, body.outcome, body.note)
    request.app.state.workflows.process()
    return result


@router.get('/api/staff')
def staff(request: Request, u=Depends(require_operator)):
    with database(request).transaction() as c:
        rows = request.app.state.engine.worker_list(c)
        for worker in rows:
            worker['skills'] = json.loads(worker['skills'])
            worker['on_duty'] = bool(worker['on_duty'])
            worker['available'] = bool(worker['available'])
            worker['busy'] = bool(worker['busy'])
        return rows if u['role'] == 'admin' else [w for w in rows if w['id'] == u['staff_id']]


@router.put('/api/staff/{sid}')
def staff_update(request: Request, sid: int, body: WorkerUpdate, u=Depends(require_operator)):
    if u['role'] == 'staff' and sid != u['staff_id']:
        raise HTTPException(403, '只能更新自己的人员状态')
    with database(request).transaction(True) as c:
        row = dict(getrow(c, 'staff', sid))
        changes = {key: value for key, value in body.model_dump().items() if value is not None}
        if not changes:
            raise HTTPException(422, '至少需要提供一个要更新的人员字段')
        merged = {**row, **changes}
        c.execute('UPDATE staff SET available=?,on_duty=?,location=?,version=version+1 WHERE id=?',
                  (int(merged['available']), int(merged['on_duty']), int(merged['location']), sid))
        audit(c, u['username'], 'staff_updated', str(sid), changes)
    request.app.state.workflows.process()
    return {'ok': True}
