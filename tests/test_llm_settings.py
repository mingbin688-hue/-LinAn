"""Administrator-owned model settings: no secret leaks, DB authority, safe probes."""
import json

import httpx
import pytest
from fastapi.testclient import TestClient

from backend.api import create_app

PASSWORD = 'Demo2026!'
SECRET = '{{SECRET_9d4kq2xm}}'


@pytest.fixture
def env(tmp_path, monkeypatch):
    monkeypatch.setenv('LINAN_LLM_ENABLED', '0')
    for name in ('LINAN_LLM_BASE_URL', 'LINAN_LLM_MODEL', 'LINAN_LLM_API_KEY'):
        monkeypatch.delenv(name, raising=False)
    path = tmp_path / 'settings.sqlite3'
    app = create_app(path, demo=False, background=False)
    client = TestClient(app)

    def headers(account='admin'):
        result = client.post('/api/auth/login', json={'username': account, 'password': PASSWORD})
        assert result.status_code == 200, result.text
        return {'Authorization': 'Bearer ' + result.json()['token']}

    return app, client, headers, path


def save(client, headers, **body):
    return client.put('/api/settings/llm', headers=headers, json=body)


def complete(**extra):
    return {'enabled': True, 'base_url': 'https://model.example/v1',
            'model': 'demo-model', 'api_key': SECRET, **extra}


def test_model_settings_are_admin_only_and_never_return_the_secret(env):
    app, client, headers, _ = env
    family = headers('family')
    assert client.get('/api/settings/llm', headers=family).status_code == 403
    assert save(client, family).status_code == 403
    assert client.post('/api/settings/llm/test', headers=family).status_code == 403

    admin = headers('admin')
    before = client.get('/api/settings/llm', headers=admin)
    assert before.status_code == 200
    assert before.headers.get('cache-control') == 'no-store'
    assert before.json()['configured'] is False
    assert before.json()['api_key_set'] is False
    assert before.json()['source'] == 'environment'

    response = save(client, admin, **complete())
    assert response.status_code == 200, response.text
    assert response.headers.get('cache-control') == 'no-store'
    body = response.json()
    assert body['enabled'] is True and body['mode'] == 'llm' and body['configured'] is True
    assert body['api_key_set'] is True
    assert body['api_key_hint'].endswith(SECRET[-4:])
    assert SECRET not in json.dumps(body)
    assert SECRET not in json.dumps(client.get('/api/settings/llm', headers=admin).json())
    assert client.get('/api/agents', headers=admin).json()['mode'] == 'llm'
    # The audit trail records that a key is set, never the key.
    with app.state.db.transaction() as c:
        rows = [dict(r) for r in c.execute(
            "SELECT payload FROM audit WHERE action='llm_settings_updated'")]
    assert rows and all(SECRET not in row['payload'] for row in rows)
    assert 'api_key_set' in rows[-1]['payload']


def test_saved_key_survives_restart_and_drives_openai_compatible_requests(env):
    app, client, headers, path = env
    assert save(client, headers(), **complete()).status_code == 200

    restarted = create_app(path, demo=False, background=False)
    provider = restarted.state.provider
    assert provider.enabled and provider.configured and provider.base_url == 'https://model.example/v1'
    seen = {}

    def handler(request):
        seen['url'] = str(request.url)
        seen['auth'] = request.headers['authorization']
        seen['body'] = json.loads(request.content)
        return httpx.Response(200, json={'choices': [{'message': {'content': json.dumps({
            'summary': '模型只解释已有记录。', 'evidence': [], 'actions': ['人工核实']})}}]})

    provider.client.close()
    provider.client = httpx.Client(transport=httpx.MockTransport(handler))
    try:
        answer = provider.generate({'summary': '规则结果', 'evidence': [], 'actions': [],
                                   'mode': 'rules'}, {'elder': '王桂兰'})
    finally:
        provider.client.close()
    assert answer['mode'] == 'llm' and answer['summary'] == '模型只解释已有记录。'
    assert seen['url'] == 'https://model.example/v1/chat/completions'
    assert seen['auth'] == 'Bearer ' + SECRET
    assert seen['body']['model'] == 'demo-model'


def test_clearing_the_key_requires_disabling_and_does_not_resurrect_env(env, tmp_path, monkeypatch):
    app, client, headers, path = env
    admin = headers()
    assert save(client, admin, **complete(enabled=False)).status_code == 200

    refused = save(client, admin, enabled=True, base_url='https://model.example/v1',
                   model='demo-model', clear_api_key=True)
    assert refused.status_code == 400
    assert '完整填写' in refused.json()['detail']
    both = save(client, admin, **complete(clear_api_key=True))
    assert both.status_code == 400
    assert '同时' in both.json()['detail']

    cleared = save(client, admin, enabled=False, base_url='https://model.example/v1',
                   model='demo-model', clear_api_key=True)
    assert cleared.status_code == 200, cleared.text
    assert cleared.json()['api_key_set'] is False
    assert cleared.json()['configured'] is False and cleared.json()['mode'] == 'rules'

    # Once llm.* rows exist they remain authoritative even if env has a full config.
    monkeypatch.setenv('LINAN_LLM_ENABLED', '1')
    monkeypatch.setenv('LINAN_LLM_BASE_URL', 'https://env.example/v1')
    monkeypatch.setenv('LINAN_LLM_MODEL', 'env-model')
    monkeypatch.setenv('LINAN_LLM_API_KEY', 'env-secret-key')
    restarted = create_app(path, demo=False, background=False)
    assert restarted.state.provider.configured is False
    assert restarted.state.provider.key == ''
    assert restarted.state.provider.source == 'database'


def test_settings_validation_and_partial_saves(env):
    app, client, headers, _ = env
    admin = headers()
    assert save(client, admin, enabled=True, base_url='ftp://model.example', model='m',
                api_key=SECRET).status_code == 400
    assert save(client, admin, enabled=True, base_url='https://model.example/v1', model='m',
                api_key='has space').status_code == 400
    assert save(client, admin, **complete(clear_api_key=True)).status_code == 400
    missing = save(client, admin, enabled=True, base_url='https://model.example/v1',
                   model='m', api_key=None)
    assert missing.status_code == 400
    assert '完整填写' in missing.json()['detail']

    partial = save(client, admin, enabled=False, base_url='https://model.example/v1', model='m')
    assert partial.status_code == 200
    assert partial.json()['configured'] is False and partial.json()['mode'] == 'rules'
    # A later save without api_key keeps the (still empty) stored secret.
    assert save(client, admin, enabled=False, base_url='https://model.example/v1',
                model='m2').json()['api_key_set'] is False


def test_connection_probe_reports_safe_errors_and_success(env):
    app, client, headers, _ = env
    provider = app.state.provider
    provider.client.close()
    seen = []

    def handler(request):
        seen.append(request)
        return httpx.Response(200, json={'model': 'demo-model',
                                         'choices': [{'message': {'content': 'pong'}}]})

    provider.client = httpx.Client(transport=httpx.MockTransport(handler))
    admin = headers()
    try:
        ok = client.post('/api/settings/llm/test', headers=admin, json={
            'base_url': 'https://model.example/v1', 'model': 'demo-model', 'api_key': SECRET})
    finally:
        provider.client.close()
    assert ok.status_code == 200 and ok.json()['ok'] is True
    assert ok.json()['latency_ms'] >= 0
    assert SECRET not in ok.text
    assert str(seen[0].url) == 'https://model.example/v1/chat/completions'
    assert seen[0].headers['authorization'] == 'Bearer ' + SECRET

    def failing(status):
        provider.client = httpx.Client(
            transport=httpx.MockTransport(lambda request: httpx.Response(status, json={'error': SECRET})))
        return client.post('/api/settings/llm/test', headers=admin, json={
            'base_url': 'https://model.example/v1', 'model': 'demo-model', 'api_key': SECRET})

    try:
        unauthorized = failing(401)
        assert unauthorized.status_code == 200
        assert unauthorized.json()['ok'] is False and 'API Key' in unauthorized.json()['error']
        assert SECRET not in unauthorized.text
        assert failing(429).json()['error'].startswith('模型服务配额')
    finally:
        provider.client.close()


def test_model_catalog_is_fetched_from_the_provider_and_never_leaks_the_key(env):
    app, client, headers, _ = env
    provider = app.state.provider
    provider.client.close()
    seen = []

    def handler(request):
        seen.append(request)
        return httpx.Response(200, json={'data': [
            {'id': 'zeta-model'}, {'id': 'alpha-model'},
            {'id': 'alpha-model'}, {'id': 'beta-model', 'object': 'model'}]})

    provider.client = httpx.Client(transport=httpx.MockTransport(handler))
    admin = headers()
    try:
        assert client.post('/api/settings/llm/models', headers=admin, json={}).status_code == 400
        response = client.post('/api/settings/llm/models', headers=admin, json={
            'base_url': 'https://model.example/v1', 'api_key': SECRET})
    finally:
        provider.client.close()
    assert response.status_code == 200, response.text
    body = response.json()
    assert body['ok'] is True
    assert body['models'] == ['alpha-model', 'beta-model', 'zeta-model']
    assert SECRET not in response.text
    assert str(seen[0].url) == 'https://model.example/v1/models'
    assert seen[0].headers['authorization'] == 'Bearer ' + SECRET

    # Saved credentials are reused when the form leaves the key untouched.
    assert save(client, admin, enabled=False, base_url='https://model.example/v1',
                model='alpha-model', api_key=SECRET).status_code == 200
    provider.client = httpx.Client(transport=httpx.MockTransport(handler))
    try:
        reused = client.post('/api/settings/llm/models', headers=admin, json={})
    finally:
        provider.client.close()
    assert reused.status_code == 200 and reused.json()['models'][0] == 'alpha-model'

    # Providers without a catalog endpoint get an actionable message.
    provider.client = httpx.Client(transport=httpx.MockTransport(
        lambda request: httpx.Response(404, json={'error': SECRET})))
    try:
        missing = client.post('/api/settings/llm/models', headers=admin, json={
            'base_url': 'https://model.example/v1', 'api_key': SECRET})
    finally:
        provider.client.close()
    assert missing.status_code == 200
    assert missing.json()['ok'] is False and '手动填写' in missing.json()['error']
    assert SECRET not in missing.text
    assert client.post('/api/settings/llm/models', headers=headers('family'), json={}).status_code == 403


def test_saved_incomplete_configuration_falls_back_to_rules_with_a_reason(tmp_path, monkeypatch):
    monkeypatch.setenv('LINAN_LLM_ENABLED', '0')
    for name in ('LINAN_LLM_BASE_URL', 'LINAN_LLM_MODEL', 'LINAN_LLM_API_KEY'):
        monkeypatch.delenv(name, raising=False)
    path = tmp_path / 'incomplete.sqlite3'
    app = create_app(path, demo=False, background=False)
    with app.state.db.transaction(True) as c:
        for key, value in (('llm.enabled', 'true'), ('llm.base_url', 'https://model.example/v1'),
                           ('llm.model', 'demo-model'), ('llm.api_key', '')):
            c.execute('INSERT OR REPLACE INTO settings(key,value) VALUES(?,?)', (key, value))
    restarted = create_app(path, demo=False, background=False)
    provider = restarted.state.provider
    assert provider.enabled is False and provider.configured is False
    assert provider.configuration_reason
    client = TestClient(restarted)
    token = client.post('/api/auth/login', json={'username': 'admin', 'password': PASSWORD}).json()['token']
    agents = client.get('/api/agents', headers={'Authorization': 'Bearer ' + token}).json()
    assert agents['mode'] == 'rules' and agents['fallback_reason'] == provider.configuration_reason
