"""Read-only MCP server (JSON-RPC 2.0, protocol 2025-06-18) for 邻安.

The same handler serves the stateless Streamable HTTP endpoint at POST /mcp and
the stdio bridge used by desktop MCP clients. Every call re-checks the caller's
role and object scope; the server never mutates tasks, incidents or settings.
"""
import hashlib
import json
import secrets
import time

from fastapi import HTTPException

from . import jobs as queue
from .db import Database, audit, dumps
from .scheduler import assign
from .scope import visible_ids
from .workflow_store import run_detail

PROTOCOL = '2025-06-18'
SERVER = {'name': 'linan-mcp', 'version': '1.0.0'}
INSTRUCTIONS = ('邻安社区守护只读工具。先调用 linan_scope 确认授权范围；'
                '数据缺失或超过30分钟未更新时视为未知，不能推断安全；'
                '风险等级、派单与关闭只能由现有规则和人工流程改变。')

TOOLS = [
    {'name': 'linan_scope', 'description': '当前令牌的授权范围：可见老人、任务与上下文摘要',
     'inputSchema': {'type': 'object', 'properties': {}, 'additionalProperties': False}},
    {'name': 'linan_elders', 'description': '按权限查询老人档案与在线状态；联系人不返回',
     'inputSchema': {'type': 'object', 'properties': {'elder_id': {'type': 'integer'}},
                     'additionalProperties': False}},
    {'name': 'linan_incidents', 'description': '查询未关闭的风险事件与规则依据',
     'inputSchema': {'type': 'object', 'properties': {'elder_id': {'type': 'integer'}},
                     'additionalProperties': False}},
    {'name': 'linan_tasks', 'description': '查询未关闭任务；照护人员只返回自己的任务',
     'inputSchema': {'type': 'object', 'properties': {'elder_id': {'type': 'integer'}},
                     'additionalProperties': False}},
    {'name': 'linan_task_detail', 'description': '查询单个任务的老人、事件、反馈与流程运行摘要',
     'inputSchema': {'type': 'object', 'properties': {'task_id': {'type': 'string'}},
                     'required': ['task_id'], 'additionalProperties': False}},
    {'name': 'linan_context', 'description': '按角色生成有预算上限的上下文包（含缺口与脱敏说明）',
     'inputSchema': {'type': 'object', 'properties': {
         'query': {'type': 'string'}, 'elder_id': {'type': 'integer'}, 'task_id': {'type': 'string'}},
         'additionalProperties': False}},
    {'name': 'linan_dispatch_recommendations', 'description': '管理员查看全量待派任务的只读调度建议',
     'inputSchema': {'type': 'object', 'properties': {}, 'additionalProperties': False}},
    {'name': 'linan_workflow_runs', 'description': '查询最近的流程运行记录',
     'inputSchema': {'type': 'object', 'properties': {'limit': {'type': 'integer'}},
                     'additionalProperties': False}},
    {'name': 'linan_workflow_run', 'description': '查询单个流程运行的节点时间线',
     'inputSchema': {'type': 'object', 'properties': {'run_id': {'type': 'string'}},
                     'required': ['run_id'], 'additionalProperties': False}},
    {'name': 'linan_jobs', 'description': '管理员查看持久化任务队列（不含载荷与结果）',
     'inputSchema': {'type': 'object', 'properties': {'state': {'type': 'string'}},
                     'additionalProperties': False}},
    {'name': 'linan_health', 'description': '数据库、流程与队列的只读健康摘要',
     'inputSchema': {'type': 'object', 'properties': {}, 'additionalProperties': False}},
]

RESOURCES = [
    {'uri': 'linan://scope', 'name': '当前授权范围', 'description': '角色可见的老人与任务',
     'mimeType': 'application/json'},
    {'uri': 'linan://elders', 'name': '老人档案', 'description': '授权范围内老人状态', 'mimeType': 'application/json'},
    {'uri': 'linan://incidents', 'name': '未关闭风险事件', 'description': '规则证据与建议', 'mimeType': 'application/json'},
    {'uri': 'linan://tasks', 'name': '未关闭任务', 'description': '任务状态与负责人', 'mimeType': 'application/json'},
]
RESOURCE_TEMPLATES = [
    {'uriTemplate': 'linan://elders/{elder_id}', 'name': '老人详情', 'description': '单个老人档案',
     'mimeType': 'application/json'},
    {'uriTemplate': 'linan://tasks/{task_id}', 'name': '任务详情', 'description': '单个任务与运行记录',
     'mimeType': 'application/json'},
    {'uriTemplate': 'linan://workflows/{run_id}', 'name': '流程详情', 'description': '单个流程节点时间线',
     'mimeType': 'application/json'},
]
PROMPTS = [
    {'name': 'risk_brief', 'description': '为管理员生成风险研判简报（只引用工具返回的证据）',
     'arguments': [{'name': 'elder_id', 'description': '老人ID，可省略', 'required': False}]},
    {'name': 'shift_handover', 'description': '生成值班交接摘要：待办任务、未关闭事件与数据缺口',
     'arguments': []},
]


def _error(mid, code, message):
    return {'jsonrpc': '2.0', 'id': mid, 'error': {'code': code, 'message': message}}


def _ok(mid, result):
    return {'jsonrpc': '2.0', 'id': mid, 'result': result}


def _user(row):
    return {k: row[k] for k in ('username', 'role', 'name', 'elder_id', 'staff_id')}


class LinAnMcp:
    def __init__(self, db: Database, engine, assistant):
        self.db, self.engine, self.assistant = db, engine, assistant
        self.handlers = {
            'linan_scope': self._scope,
            'linan_elders': self._elders,
            'linan_incidents': self._incidents,
            'linan_tasks': self._tasks,
            'linan_task_detail': self._task_detail,
            'linan_context': self._context,
            'linan_dispatch_recommendations': self._recommendations,
            'linan_workflow_runs': self._runs,
            'linan_workflow_run': self._run,
            'linan_jobs': self._jobs,
            'linan_health': self._health,
        }

    # ----- authentication and tokens -----
    @staticmethod
    def digest(token):
        return hashlib.sha256(token.encode()).hexdigest()

    def authenticate(self, c, token):
        if not token:
            return None
        digest = self.digest(token)
        row = c.execute("SELECT t.*,u.role,u.name,u.elder_id,u.staff_id FROM mcp_tokens t "
                        "JOIN users u ON u.username=t.username WHERE t.token_hash=? AND t.revoked=0",
                        (digest,)).fetchone()
        if row and (row['expires'] == 0 or row['expires'] > time.time()):
            c.execute('UPDATE mcp_tokens SET last_used=? WHERE id=?', (time.time(), row['id']))
            return _user(row)
        # Only dedicated MCP tokens are accepted; interactive login sessions stay in the UI.
        return None

    @staticmethod
    def mint_token(c, username, label='', expires_hours=24):
        label = (label or '').strip()[:60] or 'MCP 客户端'
        try:
            hours = int(expires_hours)
        except (TypeError, ValueError):
            raise HTTPException(422, '有效期必须是整数小时')
        if not 0 <= hours <= 8760:
            raise HTTPException(422, '有效期需在 0 到 8760 小时之间')
        token = 'mcp_' + secrets.token_urlsafe(32)
        token_id = 'MCP-' + secrets.token_hex(6)
        now = time.time()
        expires = now + hours * 3600 if hours else 0
        c.execute('INSERT INTO mcp_tokens(id,token_hash,username,label,created,expires,last_used,revoked) '
                  'VALUES(?,?,?,?,?,?,0,0)',
                  (token_id, LinAnMcp.digest(token), username, label, now, expires))
        audit(c, username, 'mcp_token_created', token_id, {'label': label, 'expires': expires})
        return {'id': token_id, 'token': token, 'label': label, 'expires': expires, 'username': username}

    @staticmethod
    def token_list(c):
        return [{**dict(row), 'revoked': bool(row['revoked'])}
                for row in c.execute('SELECT id,username,label,created,expires,last_used,revoked '
                                     'FROM mcp_tokens ORDER BY created DESC')]

    @staticmethod
    def revoke_token(c, token_id, actor):
        cur = c.execute('UPDATE mcp_tokens SET revoked=1 WHERE id=?', (token_id,))
        if not cur.rowcount:
            return False
        audit(c, actor, 'mcp_token_revoked', token_id, {})
        return True

    def status(self):
        with self.db.transaction() as c:
            return {'endpoint': '/mcp', 'protocol': PROTOCOL, 'tools': len(TOOLS),
                    'resources': len(RESOURCES) + len(RESOURCE_TEMPLATES),
                    'prompts': len(PROMPTS), 'tokens': self.token_list(c)}

    # ----- JSON-RPC -----
    def handle(self, payload, user):
        if isinstance(payload, list):
            answers = [self.handle_one(item, user) for item in payload]
            answers = [item for item in answers if item is not None]
            return answers or None
        return self.handle_one(payload, user)

    def handle_one(self, request, user):
        if not isinstance(request, dict) or request.get('jsonrpc') != '2.0' or not isinstance(request.get('method'), str):
            return _error(None, -32600, '无效的 JSON-RPC 请求')
        mid = request.get('id')
        is_notification = mid is None
        try:
            result = self._dispatch(request['method'], request.get('params') or {}, user)
        except HTTPException as exc:
            return None if is_notification else _error(mid, -32003, str(exc.detail))
        except PermissionError as exc:
            return None if is_notification else _error(mid, -32003, str(exc))
        except Exception:
            return None if is_notification else _error(mid, -32603, '服务内部错误')
        return None if is_notification else _ok(mid, result)

    def _dispatch(self, method, params, user):
        if method == 'initialize':
            return {'protocolVersion': PROTOCOL,
                    'capabilities': {'tools': {'listChanged': False},
                                     'resources': {'subscribe': False, 'listChanged': False},
                                     'prompts': {'listChanged': False}},
                    'serverInfo': SERVER, 'instructions': INSTRUCTIONS}
        if method in ('notifications/initialized', 'notifications/cancelled'):
            return {}
        if method == 'ping':
            return {}
        if method == 'tools/list':
            return {'tools': TOOLS}
        if method == 'tools/call':
            return self._call_tool(params, user)
        if method == 'resources/list':
            return {'resources': RESOURCES}
        if method == 'resources/templates/list':
            return {'resourceTemplates': RESOURCE_TEMPLATES}
        if method == 'resources/read':
            return self._read_resource(str(params.get('uri') or ''), user)
        if method == 'prompts/list':
            return {'prompts': PROMPTS}
        if method == 'prompts/get':
            return self._get_prompt(str(params.get('name') or ''), params.get('arguments') or {}, user)
        raise HTTPException(404, '未知的 MCP 方法')

    def _call_tool(self, params, user):
        name = params.get('name')
        handler = self.handlers.get(name)
        if not handler:
            return {'content': [{'type': 'text', 'text': '未知工具'}], 'isError': True}
        arguments = params.get('arguments') or {}
        if not isinstance(arguments, dict):
            return {'content': [{'type': 'text', 'text': '参数必须是对象'}], 'isError': True}
        try:
            with self.db.transaction() as c:
                value = handler(c, user, arguments)
            self._audit(user, 'tool:' + name, None, {'args': list(arguments)})
            return {'content': [{'type': 'text', 'text': dumps(value)}], 'isError': False}
        except HTTPException as exc:
            self._audit(user, 'mcp_denied', name, {'reason': str(exc.detail)})
            return {'content': [{'type': 'text', 'text': str(exc.detail)}], 'isError': True}

    def _audit(self, user, action, entity, payload):
        with self.db.transaction(True) as c:
            audit(c, user['username'], action, entity, payload)

    # ----- tool handlers -----
    def _pack(self, c, user, query='', elder_id=None, task_id=None):
        return self.assistant.context.build(c, user, query, elder_id, task_id)

    def _scope(self, c, user, args):
        pack = self._pack(c, user)
        elders = pack['records']['elders']
        tasks = pack['records']['tasks']
        return {'user': {'username': user['username'], 'role': user['role'], 'name': user['name']},
                'elders': [{'id': e['id'], 'name': e['name']} for e in elders],
                'tasks': [{'id': t['id'], 'elder_id': t['elder_id'], 'state': t['state']} for t in tasks],
                'summary': pack['summary'], 'citations': pack['citations']}

    def _elders(self, c, user, args):
        pack = self._pack(c, user, elder_id=args.get('elder_id'))
        return {'elders': pack['records']['elders'], 'citations': pack['citations'],
                'summary': pack['summary']}

    def _incidents(self, c, user, args):
        pack = self._pack(c, user, elder_id=args.get('elder_id'))
        return {'incidents': pack['records']['incidents'], 'citations': pack['citations'],
                'summary': pack['summary']}

    def _tasks(self, c, user, args):
        pack = self._pack(c, user, elder_id=args.get('elder_id'))
        return {'tasks': pack['records']['tasks'], 'citations': pack['citations'],
                'summary': pack['summary']}

    def _task_detail(self, c, user, args):
        task_id = str(args.get('task_id') or '').strip()
        if not task_id:
            raise HTTPException(422, '缺少 task_id')
        pack = self._pack(c, user, task_id=task_id)
        task = pack['records']['tasks'][0] if pack['records']['tasks'] else None
        if not task:
            raise HTTPException(404, '任务不存在或无权访问')
        feedback = [dict(r) for r in c.execute('SELECT actor,outcome,note,created FROM feedback WHERE task_id=? ORDER BY created DESC LIMIT 10', (task_id,))]
        runs = [run_detail(c, r[0]) for r in c.execute(
            'SELECT id FROM workflow_runs WHERE task_id=? ORDER BY created DESC LIMIT 5', (task_id,))]
        return {'task': task, 'elder': pack['records']['elders'], 'incidents': pack['records']['incidents'],
                'feedback': feedback, 'runs': runs, 'summary': pack['summary'],
                'citations': pack['citations']}

    def _context(self, c, user, args):
        query = str(args.get('query') or '')[:500]
        pack = self._pack(c, user, query, args.get('elder_id'), args.get('task_id'))
        return {'context': pack['summary'], 'records': pack['records'],
                'citations': pack['citations'], 'gaps': pack['gaps']}

    def _recommendations(self, c, user, args):
        if user['role'] != 'admin':
            raise HTTPException(403, '只读调度建议仅管理员可用')
        pending = [dict(r) for r in c.execute("SELECT * FROM tasks WHERE state='pending' ORDER BY level DESC,created")]
        workers = self.engine.worker_list(c)
        names = {w['id']: w['name'] for w in workers}
        matches = [{**m, 'staff_name': names.get(m['staff_id'], '未知')} for m in assign(pending, workers)]
        return {'recommendations': matches, 'pending': len(pending), 'workers': len(workers),
                'note': '只读建议；确认派单仍由管理员按现有校验执行'}

    def _visible_run(self, c, user, row):
        if row['kind'] == 'chat':
            return row['owner'] == user['username']
        if user['role'] == 'admin':
            return True
        if user['role'] == 'staff':
            task = c.execute('SELECT staff_id FROM tasks WHERE id=?', (row['task_id'],)).fetchone()
            return bool(task and task['staff_id'] == user['staff_id'])
        return row['elder_id'] == user['elder_id']

    def _runs(self, c, user, args):
        limit = max(1, min(int(args.get('limit') or 20), 50))
        items = []
        for row in c.execute('SELECT * FROM workflow_runs ORDER BY created DESC LIMIT 100'):
            if not self._visible_run(c, user, row):
                continue
            items.append({k: row[k] for k in ('id', 'kind', 'status', 'mode', 'summary', 'elder_id',
                                              'task_id', 'definition_version', 'context_digest',
                                              'created', 'updated')})
            if len(items) >= limit:
                break
        return {'runs': items}

    def _run(self, c, user, args):
        run_id = str(args.get('run_id') or '').strip()
        row = c.execute('SELECT * FROM workflow_runs WHERE id=?', (run_id,)).fetchone()
        if not row:
            raise HTTPException(404, '流程不存在')
        if not self._visible_run(c, user, row):
            raise HTTPException(403, '无权访问该流程')
        return {'run': run_detail(c, run_id)}

    def _jobs(self, c, user, args):
        if user['role'] != 'admin':
            raise HTTPException(403, '任务队列仅管理员可见')
        return {'jobs': queue.list_jobs(c, str(args.get('state') or 'all'), 50)}

    def _health(self, c, user, args):
        return {'ok': True, 'elders': c.execute('SELECT count(*) FROM elders').fetchone()[0],
                'open_incidents': c.execute("SELECT count(*) FROM incidents WHERE status='open'").fetchone()[0],
                'open_tasks': c.execute("SELECT count(*) FROM tasks WHERE state!='closed'").fetchone()[0],
                'active_runs': c.execute("SELECT count(*) FROM workflow_runs WHERE status IN ('queued','running','waiting_human')").fetchone()[0],
                'active_jobs': queue.count_active(c),
                'schema_version': (c.execute("SELECT value FROM settings WHERE key='schema_version'").fetchone() or ['?'])[0]}

    # ----- resources and prompts -----
    def _read_resource(self, uri, user):
        if uri in ('linan://scope', 'linan://elders', 'linan://incidents', 'linan://tasks'):
            name = {'linan://scope': 'linan_scope', 'linan://elders': 'linan_elders',
                    'linan://incidents': 'linan_incidents', 'linan://tasks': 'linan_tasks'}[uri]
            with self.db.transaction() as c:
                value = self.handlers[name](c, user, {})
            return {'contents': [{'uri': uri, 'mimeType': 'application/json', 'text': dumps(value)}]}
        parts = uri.replace('linan://', '').split('/', 1)
        if len(parts) == 2 and parts[0] in ('elders', 'tasks', 'workflows'):
            kind, ident = parts
            if kind == 'workflows':
                with self.db.transaction() as c:
                    value = self._run(c, user, {'run_id': ident})
            elif kind == 'tasks':
                with self.db.transaction() as c:
                    value = self._task_detail(c, user, {'task_id': ident})
            else:
                try:
                    elder_id = int(ident)
                except (TypeError, ValueError):
                    raise HTTPException(404, '未知资源')
                with self.db.transaction() as c:
                    value = self._elders(c, user, {'elder_id': elder_id})
            return {'contents': [{'uri': uri, 'mimeType': 'application/json', 'text': dumps(value)}]}
        raise HTTPException(404, '未知资源')

    def _get_prompt(self, name, arguments, user):
        if name == 'risk_brief':
            elder_id = arguments.get('elder_id')
            target = f'老人ID {elder_id}。' if elder_id else '当前授权范围内全部老人。'
            text = (f'请为社区管理员生成风险研判简报。范围：{target}\n'
                    '先调用 linan_scope，再调用 linan_incidents 与 linan_tasks 获取证据；'
                    '只引用工具返回的 evidence，不推测未返回的数据。数据缺失或超过30分钟未更新时明确写“未知，不能推断安全”。'
                    '不要建议绕过人工确认，不要改变风险等级、派单或关闭状态。')
        elif name == 'shift_handover':
            text = ('请生成值班交接摘要：调用 linan_tasks 与 linan_incidents，按紧急程度列出未关闭任务、'
                    '未解决事件、数据缺口和需要管理员确认的派单；不得声称已派单或已关闭。')
        else:
            raise HTTPException(404, '未知提示')
        return {'description': '邻安只读研判提示', 'messages': [
            {'role': 'user', 'content': {'type': 'text', 'text': text}}]}


def serve_stdio(server, user, stdin, stdout):
    """Line-delimited JSON-RPC for stdio MCP bridges."""
    for line in stdin:
        line = line.strip()
        if not line:
            continue
        try:
            payload = json.loads(line)
        except ValueError:
            stdout.write(json.dumps(_error(None, -32700, 'JSON 解析失败'), ensure_ascii=False) + '\n')
            stdout.flush()
            continue
        answer = server.handle(payload, user)
        if answer is not None:
            stdout.write(json.dumps(answer, ensure_ascii=False) + '\n')
            stdout.flush()
