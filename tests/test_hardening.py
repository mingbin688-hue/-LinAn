"""Regression contracts for audit fixes: scoped reads, strict inputs, durable failures."""
import httpx
import pytest
from fastapi.testclient import TestClient

from backend.api import create_app
from backend.db import Database, notify


@pytest.fixture
def env(tmp_path, monkeypatch):
    monkeypatch.setenv('LINAN_LLM_ENABLED', '0')
    for name in ('LINAN_LLM_BASE_URL', 'LINAN_LLM_MODEL', 'LINAN_LLM_API_KEY'):
        monkeypatch.delenv(name, raising=False)
    app = create_app(tmp_path / 'hardening.sqlite3', demo=False, background=False)
    client = TestClient(app)
    tokens = {}

    def headers(account='admin'):
        if account not in tokens:
            result = client.post('/api/auth/login', json={
                'username': account, 'password': 'Demo2026!'})
            assert result.status_code == 200, result.text
            tokens[account] = {'Authorization': 'Bearer ' + result.json()['token']}
        return tokens[account]

    return app, client, headers


def test_memory_database_is_rejected_with_an_actionable_message():
    """Each transaction opens its own connection, so :memory: would lose the schema silently."""
    with pytest.raises(ValueError, match='内存数据库不受支持'):
        Database(':memory:')


def test_notifications_are_scoped_before_the_limit(env):
    app, client, headers = env
    with app.state.db.transaction(True) as c:
        notify(c, '照护任务提醒', '请核对待派任务', role='staff', staff_id=1)
        notify(c, '其他人员提醒', '不属于当前人员', role='staff', staff_id=2)
        for index in range(320):
            notify(c, '社区广播', f'巡检通过 {index}', role='admin')
    staff = client.get('/api/notifications', headers=headers('staff1')).json()
    assert [item['title'] for item in staff] == ['照护任务提醒']
    assert staff[0]['staff_id'] == 1
    assert client.get('/api/notifications', headers=headers('staff2')).json()[0]['staff_id'] == 2
    family = client.get('/api/notifications', headers=headers('family')).json()
    assert all(item['role'] == 'family' and item['elder_id'] == 1 for item in family)


def test_staff_update_accepts_a_partial_body(env):
    app, client, headers = env
    admin = headers('admin')
    before = next(w for w in client.get('/api/staff', headers=admin).json() if w['id'] == 1)
    result = client.put('/api/staff/1', headers=admin, json={'on_duty': False})
    assert result.status_code == 200, result.text
    after = next(w for w in client.get('/api/staff', headers=admin).json() if w['id'] == 1)
    assert after['on_duty'] is False
    assert after['available'] == before['available'] and after['location'] == before['location']
    assert after['version'] == before['version'] + 1
    empty = client.put('/api/staff/1', headers=admin, json={})
    assert empty.status_code == 422 and '至少需要提供一个要更新的人员字段' in empty.text
    assert client.put('/api/staff/2', headers=headers('staff1'),
                      json={'available': True}).status_code == 403


def test_activity_payload_rejects_booleans_and_non_finite_numbers(env):
    app, client, headers = env
    admin = headers('admin')
    for payload in ({'count15': True, 'count60': 10, 'gap': 0},
                    {'count15': 3, 'count60': '10', 'gap': 0}):
        result = client.post('/api/events', headers=admin,
                             json={'elder_id': 1, 'kind': 'activity', 'payload': payload})
        assert result.status_code == 422, (payload, result.text)
    infinite = client.post('/api/events', headers=admin, content=(
        '{"elder_id":1,"kind":"activity","payload":{"count15":3,"count60":10,"gap":Infinity}}'))
    assert infinite.status_code == 422, infinite.text
    assert client.post('/api/events', headers=admin, json={
        'elder_id': 1, 'kind': 'activity',
        'payload': {'count15': 3, 'count60': 10, 'gap': 2}}).status_code == 200


def test_unknown_job_state_filter_is_rejected(env):
    app, client, headers = env
    admin = headers('admin')
    assert client.get('/api/workflows/jobs?state=bogus', headers=admin).status_code == 422
    assert client.get('/api/workflows/jobs?state=done', headers=admin).status_code == 200
    assert client.get('/api/workflows/jobs?state=bogus',
                      headers=headers('staff1')).status_code == 403


def test_health_reports_the_versions_in_use(env):
    app, client, _headers = env
    body = client.get('/api/health').json()
    assert body['rule_version'] == 'risk-rules-v1'
    assert body['model_version']
    assert body['schema_version'] == '3'


def test_failed_explanation_is_requeued_and_a_later_pass_finishes_it(env):
    app, client, headers = env
    admin = headers('admin')
    provider = app.state.assistant.provider
    provider.enabled = provider.configured = True
    provider.configuration_reason = None
    client.post('/api/events', headers=admin, json={'elder_id': 1, 'kind': 'sos'})
    with app.state.db.transaction() as c:
        job = dict(c.execute("SELECT * FROM jobs WHERE kind='explanation'").fetchone())

    def explode(base, snapshot):
        raise RuntimeError('transport exploded')

    provider.generate = explode
    app.state.workflows.drain(1)
    with app.state.db.transaction() as c:
        failed = dict(c.execute('SELECT * FROM jobs WHERE id=?', (job['id'],)).fetchone())
        node = dict(c.execute("SELECT * FROM workflow_nodes WHERE run_id=? AND node_key='explanation'",
                              (job['job_key'],)).fetchone())
        run = dict(c.execute('SELECT * FROM workflow_runs WHERE id=?', (job['job_key'],)).fetchone())
    assert failed['state'] == 'queued' and failed['attempts'] == 1
    assert '解释生成异常：RuntimeError' in failed['last_error']
    assert node['status'] == 'failed' and 'RuntimeError' in node['error']
    # The run keeps waiting for a human; only a dead-lettered job fails the run.
    assert run['status'] == 'waiting_human'

    provider.generate = lambda base, snapshot: {**base, 'mode': 'llm', 'summary': '模型解释：已核实求助记录。'}
    with app.state.db.transaction(True) as c:
        c.execute('UPDATE jobs SET run_at=0 WHERE id=?', (job['id'],))
    app.state.workflows.drain(1)
    with app.state.db.transaction() as c:
        done = dict(c.execute('SELECT * FROM jobs WHERE id=?', (job['id'],)).fetchone())
        node = dict(c.execute("SELECT * FROM workflow_nodes WHERE run_id=? AND node_key='explanation'",
                              (job['job_key'],)).fetchone())
    assert done['state'] == 'done' and done['attempts'] == 2
    assert node['status'] == 'completed' and node['mode'] == 'llm'


def test_mcp_resource_rejects_a_non_numeric_identifier(env):
    app, client, _headers = env
    with app.state.db.transaction(True) as c:
        issued = app.state.mcp.mint_token(c, 'admin', '资源解析', 1)
    result = client.post('/mcp', headers={'Authorization': 'Bearer ' + issued['token']}, json={
        'jsonrpc': '2.0', 'id': 1, 'method': 'resources/read',
        'params': {'uri': 'linan://elders/not-a-number'}})
    body = result.json()
    assert body['error']['code'] == -32003
    assert '未知资源' in body['error']['message']


def test_mcp_endpoint_rejects_a_login_session_token(env):
    """An interactive login token must not be usable as an MCP bearer credential."""
    _app, client, headers = env
    result = client.post('/mcp', headers=headers('admin'), json={
        'jsonrpc': '2.0', 'id': 1, 'method': 'initialize',
        'params': {'protocolVersion': '2025-06-18', 'capabilities': {},
                   'clientInfo': {'name': 'session-token', 'version': '1'}}})
    assert result.status_code == 401


def test_durable_job_failure_survives_a_restart(tmp_path, monkeypatch):
    monkeypatch.setenv('LINAN_LLM_ENABLED', '0')
    path = tmp_path / 'restart.sqlite3'
    app = create_app(path, demo=False, background=False)
    client = TestClient(app)
    admin = {'Authorization': 'Bearer ' + client.post('/api/auth/login', json={
        'username': 'admin', 'password': 'Demo2026!'}).json()['token']}
    provider = app.state.assistant.provider
    provider.enabled = provider.configured = True
    provider.generate = lambda base, snapshot: (_ for _ in ()).throw(RuntimeError('offline'))
    client.post('/api/events', headers=admin, json={'elder_id': 1, 'kind': 'sos'})
    app.state.workflows.drain(1)
    with app.state.db.transaction() as c:
        job = dict(c.execute("SELECT * FROM jobs WHERE kind='explanation'").fetchone())
    assert job['state'] == 'queued' and job['attempts'] == 1
    assert '解释生成异常' in job['last_error']
    reopened = create_app(path, demo=False, background=False)
    with reopened.state.db.transaction(True) as c:
        c.execute('UPDATE jobs SET run_at=0 WHERE kind=?', ('explanation',))
    reopened.state.workflows.drain(1)
    with reopened.state.db.transaction() as c:
        job = dict(c.execute("SELECT * FROM jobs WHERE kind='explanation'").fetchone())
    assert job['state'] == 'done' and job['attempts'] == 2
