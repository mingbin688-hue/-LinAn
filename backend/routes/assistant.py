"""Scoped assistants and the MCP surface they expose."""
from fastapi import APIRouter, Depends, Header, HTTPException, Request
from fastapi.responses import JSONResponse, Response

from ..agents import CATALOG
from ..db import audit
from ..deps import current_user, database, require_admin
from ..schemas import AssistantMessage, McpTokenIn

router = APIRouter()


@router.get('/api/agents')
def agents(request: Request, u=Depends(current_user)):
    provider = request.app.state.assistant.provider
    return {'agents': CATALOG, 'mode': 'llm' if provider.enabled else 'rules',
            'configured': provider.configured, 'fallback_reason': provider.configuration_reason}


@router.post('/api/assistant/messages')
def assistant_message(body: AssistantMessage, request: Request, u=Depends(current_user)):
    return request.app.state.assistant.message(u, **body.model_dump())


@router.get('/api/assistant/sessions/{sid}')
def assistant_session(sid: str, request: Request, u=Depends(current_user)):
    with database(request).transaction() as c:
        return request.app.state.assistant.session(c, u, sid)


@router.post('/mcp')
async def mcp_endpoint(request: Request, authorization: str | None = Header(default=None)):
    if not authorization or not authorization.startswith('Bearer '):
        raise HTTPException(401, '需要 MCP Bearer 令牌', headers={'WWW-Authenticate': 'Bearer'})
    with database(request).transaction(True) as c:
        caller = request.app.state.mcp.authenticate(c, authorization[7:].strip())
    if not caller:
        raise HTTPException(401, 'MCP 令牌无效、已过期或已撤销', headers={'WWW-Authenticate': 'Bearer'})
    try:
        payload = await request.json()
    except ValueError:
        raise HTTPException(400, '请求体必须是 JSON')
    answer = request.app.state.mcp.handle(payload, caller)
    if answer is None:
        return Response(status_code=202)
    return JSONResponse(answer)


@router.get('/api/mcp/status')
def mcp_status(request: Request, u=Depends(require_admin)):
    return request.app.state.mcp.status()


@router.post('/api/mcp/tokens')
def mcp_token(body: McpTokenIn, request: Request, u=Depends(require_admin)):
    with database(request).transaction(True) as c:
        return request.app.state.mcp.mint_token(c, u['username'], body.label, body.expires_hours)


@router.delete('/api/mcp/tokens/{tid}')
def mcp_revoke(tid: str, request: Request, u=Depends(require_admin)):
    with database(request).transaction(True) as c:
        if not request.app.state.mcp.revoke_token(c, tid, u['username']):
            raise HTTPException(404, '令牌不存在')
    return {'ok': True}
