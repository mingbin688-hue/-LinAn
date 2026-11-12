"""Workflow runs, explanation jobs and the auto-dispatch policy switch."""
import time

from fastapi import APIRouter, Depends, HTTPException, Request

from ..db import audit
from ..deps import database, require_admin
from ..mcp import TOOLS as MCP_TOOLS
from ..schemas import WorkflowSettings
from ..workflow_store import run_detail

router = APIRouter()


@router.get('/api/workflows/stats')
def workflow_stats(request: Request, u=Depends(require_admin)):
    data = request.app.state.workflows.stats()
    with database(request).transaction() as c:
        data['mcp'] = {'tools': len(MCP_TOOLS),
                       'tokens': c.execute(
                           'SELECT count(*) FROM mcp_tokens WHERE revoked=0 AND (expires=0 OR expires>?)',
                           (time.time(),)).fetchone()[0]}
    return data


@router.get('/api/workflows/jobs')
def workflow_jobs(request: Request, state: str = 'all', limit: int = 50, u=Depends(require_admin)):
    return request.app.state.workflows.jobs(state, limit)


@router.post('/api/workflows/jobs/{jid}/retry')
def workflow_job_retry(request: Request, jid: str, u=Depends(require_admin)):
    value = request.app.state.workflows.retry_job(jid, u['username'])
    if value is None:
        raise HTTPException(404, '任务不存在')
    return value


@router.post('/api/workflows/jobs/{jid}/cancel')
def workflow_job_cancel(request: Request, jid: str, u=Depends(require_admin)):
    value = request.app.state.workflows.cancel_job(jid, u['username'])
    if value is None:
        raise HTTPException(404, '任务不存在')
    return value


@router.post('/api/workflows/runs/{rid}/retry')
def workflow_run_retry(request: Request, rid: str, u=Depends(require_admin)):
    value = request.app.state.workflows.retry_run(rid, u['username'])
    if value is None:
        raise HTTPException(404, '工作流记录不存在')
    return value


@router.get('/api/workflows/settings')
def workflow_settings(request: Request, u=Depends(require_admin)):
    with database(request).transaction() as c:
        return request.app.state.workflows.settings(c)


@router.put('/api/workflows/settings')
def update_workflow_settings(request: Request, body: WorkflowSettings, u=Depends(require_admin)):
    with database(request).transaction(True) as c:
        c.execute("UPDATE settings SET value=? WHERE key='auto_dispatch'",
                  ('true' if body.auto_dispatch else 'false',))
        audit(c, u['username'], 'workflow_settings_changed', 'auto_dispatch', body.model_dump())
    request.app.state.workflows.process()
    return body.model_dump()


@router.get('/api/workflows/runs')
def workflow_runs(request: Request, u=Depends(require_admin)):
    with database(request).transaction() as c:
        return [dict(r) for r in c.execute(
            "SELECT id,kind,elder_id,task_id,status,mode,summary,definition_version,context_digest,"
            "created,updated FROM workflow_runs WHERE kind!='chat' OR owner=? ORDER BY created DESC LIMIT 200",
            (u['username'],))]


@router.get('/api/workflows/runs/{rid}')
def workflow_run(request: Request, rid: str, u=Depends(require_admin)):
    with database(request).transaction() as c:
        owner = c.execute('SELECT kind,owner FROM workflow_runs WHERE id=?', (rid,)).fetchone()
        if owner and owner['kind'] == 'chat' and owner['owner'] != u['username']:
            raise HTTPException(403, '无权访问其他人的对话运行记录')
        value = run_detail(c, rid)
        if value is None:
            raise HTTPException(404, '工作流记录不存在')
        return value
