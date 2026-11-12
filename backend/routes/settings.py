"""Administrator-managed model connection settings.

Secrets are write-only: GET and PUT responses only expose whether a key is set
and its last four characters, never the key itself.
"""
import time
from urllib.parse import urlsplit

from fastapi import APIRouter, Depends, HTTPException, Request, Response

from ..db import audit
from ..deps import database, require_admin
from ..schemas import LlmModelsIn, LlmSettingsIn, LlmTestIn

router = APIRouter()
NO_STORE = {'Cache-Control': 'no-store'}


def _base_url(value):
    value = (value or '').strip().rstrip('/')
    if not value:
        return ''
    parts = urlsplit(value)
    if parts.scheme not in ('http', 'https') or not parts.netloc:
        raise HTTPException(400, '基础地址必须是 http:// 或 https:// 开头的完整地址')
    if parts.username or parts.password:
        raise HTTPException(400, '基础地址不能包含用户名或密码')
    return value


def _api_key(value):
    value = (value or '').strip()
    if any(ch.isspace() for ch in value):
        raise HTTPException(400, 'API Key 不能包含空白字符')
    return value


@router.get('/api/settings/llm')
def llm_settings(response: Response, request: Request, u=Depends(require_admin)):
    response.headers.update(NO_STORE)
    return request.app.state.provider.describe()


@router.put('/api/settings/llm')
def update_llm_settings(body: LlmSettingsIn, response: Response, request: Request,
                        u=Depends(require_admin)):
    response.headers.update(NO_STORE)
    provider = request.app.state.provider
    base_url = _base_url(body.base_url)
    model = (body.model or '').strip()
    if body.api_key is not None and body.clear_api_key:
        raise HTTPException(400, '不能同时提交新密钥和清除密钥')
    if body.clear_api_key:
        api_key = ''
    elif body.api_key is not None:
        api_key = _api_key(body.api_key)
    else:
        api_key = provider.key
    if body.enabled and not (base_url and model and api_key):
        raise HTTPException(400, '启用模型前请完整填写基础地址、模型名称和 API Key')
    now = time.time()
    values = {
        'llm.base_url': base_url,
        'llm.model': model,
        'llm.api_key': api_key,
        'llm.enabled': 'true' if body.enabled else 'false',
        'llm.updated_at': str(now),
        'llm.updated_by': u['username'],
    }
    with database(request).transaction(True) as c:
        for key, value in values.items():
            c.execute('INSERT INTO settings(key,value) VALUES(?,?) '
                      'ON CONFLICT(key) DO UPDATE SET value=excluded.value', (key, value))
        audit(c, u['username'], 'llm_settings_updated', 'settings:llm', {
            'enabled': body.enabled, 'base_url': base_url, 'model': model,
            'api_key_set': bool(api_key)})
    provider.load(database(request))
    return provider.describe()


@router.post('/api/settings/llm/test')
def test_llm_settings(body: LlmTestIn, response: Response, request: Request,
                      u=Depends(require_admin)):
    response.headers.update(NO_STORE)
    provider = request.app.state.provider
    base_url = _base_url(body.base_url) if body.base_url is not None else provider.base_url
    model = (body.model or provider.model).strip()
    if body.api_key is not None:
        api_key = _api_key(body.api_key)
        if not api_key:
            raise HTTPException(400, '请先填写 API Key')
    else:
        api_key = provider.key
    result = provider.test_connection(base_url, model, api_key)
    with database(request).transaction(True) as c:
        audit(c, u['username'], 'llm_connection_tested', 'settings:llm', {
            'ok': result['ok'], 'base_url': base_url, 'model': model})
    return result


@router.post('/api/settings/llm/models')
def list_llm_models(body: LlmModelsIn, response: Response, request: Request,
                    u=Depends(require_admin)):
    response.headers.update(NO_STORE)
    provider = request.app.state.provider
    base_url = _base_url(body.base_url) if body.base_url is not None else provider.base_url
    if body.api_key is not None:
        api_key = _api_key(body.api_key)
        if not api_key:
            raise HTTPException(400, '请先填写 API Key')
    else:
        api_key = provider.key
    if not (base_url and api_key):
        raise HTTPException(400, '请先填写基础地址和 API Key')
    result = provider.list_models(base_url, api_key)
    with database(request).transaction(True) as c:
        audit(c, u['username'], 'llm_models_listed', 'settings:llm', {
            'ok': result['ok'], 'base_url': base_url,
            'count': len(result.get('models') or [])})
    return result
