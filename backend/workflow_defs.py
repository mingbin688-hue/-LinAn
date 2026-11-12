"""Declarative workflow definitions. Nodes are data, not code, so an older
database can still describe and resume a run after an application upgrade."""

DEFINITIONS = {
    'risk': {
        'version': 2,
        'title': '风险响应',
        'description': '核对数据与任务范围，解释规则结果，再调度全量任务并等待人工确认。',
        'nodes': [
            {'key': 'scope', 'name': '身份与范围校验', 'agent': 'context'},
            {'key': 'context', 'name': '上下文整理', 'agent': 'context'},
            {'key': 'assessment', 'name': '风险依据', 'agent': 'risk'},
            {'key': 'schedule', 'name': '全量任务调度', 'agent': 'dispatch'},
            {'key': 'confirmation', 'name': '派单确认', 'agent': 'dispatch'},
            {'key': 'explanation', 'name': '生成解释', 'agent': 'risk'},
        ],
    },
    'review': {
        'version': 2,
        'title': '处置复核',
        'description': '汇总处置经过与反馈，保留未解决问题，等待管理员复核。',
        'nodes': [
            {'key': 'scope', 'name': '身份与范围校验', 'agent': 'context'},
            {'key': 'context', 'name': '上下文整理', 'agent': 'context'},
            {'key': 'assessment', 'name': '处置反馈复核', 'agent': 'review'},
            {'key': 'confirmation', 'name': '人工复核', 'agent': 'review'},
            {'key': 'explanation', 'name': '生成解释', 'agent': 'review'},
        ],
    },
    'chat': {
        'version': 2,
        'title': '对话查询',
        'description': '校验会话所有权与对象权限，执行授权查询并生成可引用的回答。',
        'nodes': [
            {'key': 'scope', 'name': '身份与范围校验', 'agent': 'context'},
            {'key': 'query', 'name': '授权业务查询', 'agent': 'context'},
            {'key': 'answer', 'name': '生成回答', 'agent': 'risk'},
        ],
    },
}

_FALLBACK = {'version': 1, 'title': '通用运行', 'description': '未登记的工作流定义。', 'nodes': []}


def definition(kind):
    return DEFINITIONS.get(kind, _FALLBACK)


def version(kind):
    return definition(kind)['version']


def node_spec(kind, key):
    for item in definition(kind)['nodes']:
        if item['key'] == key:
            return item
    return {'key': key, 'name': key, 'agent': 'context'}
