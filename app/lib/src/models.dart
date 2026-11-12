int _i(dynamic v, [int d = 0]) => v is num ? v.toInt() : d;
double _d(dynamic v, [double d = 0]) => v is num ? v.toDouble() : d;
bool _b(dynamic v) => v == true || v == 1;
String _s(dynamic v, [String d = '']) => v == null ? d : '$v';
Map<String, dynamic> _m(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

List<String> _ls(dynamic v) {
  if (v is! List) return const [];
  return v
      .map((e) {
        if (e is String) return e;
        if (e is Map) return _s(e['label'] ?? e['title'] ?? e['text'] ?? e['summary']);
        return '$e';
      })
      .where((e) => e.isNotEmpty)
      .toList();
}

class User {
  final String username;
  final String name;
  final String role;
  final int? staffId;
  final int? elderId;

  const User({
    required this.username,
    required this.name,
    required this.role,
    this.staffId,
    this.elderId,
  });

  bool get isAdmin => role == 'admin';
  bool get isStaff => role == 'staff';
  bool get isFamily => role == 'family';
  bool get isElder => role == 'elder';
  bool get isCareSide => isFamily || isElder;

  factory User.fromJson(Map<String, dynamic> json) => User(
        username: _s(json['username']),
        name: _s(json['name']),
        role: _s(json['role'], 'elder'),
        staffId: json['staff_id'] == null ? null : _i(json['staff_id']),
        elderId: json['elder_id'] == null ? null : _i(json['elder_id']),
      );
}

class Elder {
  final int id;
  final String name;
  final int age;
  final String building;
  final String contact;
  final Map<String, dynamic> profile;
  final Map<String, dynamic> state;
  final int level;
  final bool dataUnknown;
  final int incidentCount;
  final String? latestIncident;
  final double version;
  final List<Map<String, dynamic>> events;

  const Elder({
    required this.id,
    required this.name,
    required this.age,
    required this.building,
    required this.contact,
    required this.profile,
    required this.state,
    required this.level,
    required this.dataUnknown,
    required this.incidentCount,
    required this.latestIncident,
    required this.version,
    this.events = const [],
  });

  factory Elder.fromJson(Map<String, dynamic> json) => Elder(
        id: _i(json['id']),
        name: _s(json['name']),
        age: _i(json['age']),
        building: _s(json['building']),
        contact: _s(json['contact']),
        profile: _m(json['profile']),
        state: _m(json['state']),
        level: _i(json['level'], -1),
        dataUnknown: _b(json['data_unknown']),
        incidentCount: _i(json['incident_count']),
        latestIncident: json['latest_incident'] == null ? null : _s(json['latest_incident']),
        version: _d(json['version']),
        events: (json['events'] as List? ?? const []).map((e) => _m(e)).toList(),
      );

  int get historyDays => _i(profile['history_days']);
  int get checkinHour => _i(profile['checkin_hour'], 8);
  String get routine => _s(profile['routine']);
  String get origin => _s(profile['origin'], '演示档案');
  bool get baselineReady => _i(profile['history_days']) >= 14 || _b(profile['baseline_ready']);
  bool get online => _b(state['online']);
  int get count15 => _i(state['count15']);
  int get count60 => _i(state['count60']);
  int get gap => _i(state['gap']);
  bool get anomaly => _b(state['anomaly']);
  String get presence => _s(state['presence'], '在家');
  String get source => _s(state['source'], 'activity');
  double? get lastCheckin => state['last_checkin'] == null ? null : _d(state['last_checkin']);
  List<String> get evidence => _ls(state['evidence']);
  double get score => _d(state['score']);
}

class Incident {
  final String id;
  final int elderId;
  final String category;
  final int level;
  final String title;
  final List<String> evidence;
  final String advice;
  final String status;
  final int created;
  final int updated;
  final String elderName;

  const Incident({
    required this.id,
    required this.elderId,
    required this.category,
    required this.level,
    required this.title,
    required this.evidence,
    required this.advice,
    required this.status,
    required this.created,
    required this.updated,
    required this.elderName,
  });

  bool get open => status == 'open';

  factory Incident.fromJson(Map<String, dynamic> json) => Incident(
        id: _s(json['id']),
        elderId: _i(json['elder_id']),
        category: _s(json['category']),
        level: _i(json['level']),
        title: _s(json['title']),
        evidence: _ls(json['evidence']),
        advice: _s(json['advice']),
        status: _s(json['status'], 'open'),
        created: _i(json['created']),
        updated: _i(json['updated']),
        elderName: _s(json['elder_name']),
      );
}

class CareTask {
  final String id;
  final int elderId;
  final String incidentId;
  final int level;
  final String state;
  final String requiredSkill;
  final int? staffId;
  final String staffName;
  final String title;
  final String category;
  final List<String> evidence;
  final String advice;
  final int created;
  final int updated;
  final int? due;
  final bool overdue;
  final int version;
  final String elderName;

  const CareTask({
    required this.id,
    required this.elderId,
    required this.incidentId,
    required this.level,
    required this.state,
    required this.requiredSkill,
    required this.staffId,
    required this.staffName,
    required this.title,
    required this.category,
    required this.evidence,
    required this.advice,
    required this.created,
    required this.updated,
    required this.due,
    required this.overdue,
    required this.version,
    required this.elderName,
  });

  factory CareTask.fromJson(Map<String, dynamic> json) => CareTask(
        id: _s(json['id']),
        elderId: _i(json['elder_id']),
        incidentId: _s(json['incident_id']),
        level: _i(json['level']),
        state: _s(json['state'], 'pending'),
        requiredSkill: _s(json['required_skill']),
        staffId: json['staff_id'] == null ? null : _i(json['staff_id']),
        staffName: _s(json['staff_name']),
        title: _s(json['title']),
        category: _s(json['category']),
        evidence: _ls(json['evidence']),
        advice: _s(json['advice']),
        created: _i(json['created']),
        updated: _i(json['updated']),
        due: json['due'] == null ? null : _i(json['due']),
        overdue: _b(json['overdue']),
        version: _i(json['version']),
        elderName: _s(json['elder_name']),
      );

  bool get pending => state == 'pending' || state == 'dispatched';
}

class Staff {
  final int id;
  final String name;
  final List<String> skills;
  final bool onDuty;
  final bool available;
  final int location;
  final double version;
  final bool busy;
  final String? activeTask;

  const Staff({
    required this.id,
    required this.name,
    required this.skills,
    required this.onDuty,
    required this.available,
    required this.location,
    required this.version,
    required this.busy,
    required this.activeTask,
  });

  factory Staff.fromJson(Map<String, dynamic> json) => Staff(
        id: _i(json['id']),
        name: _s(json['name']),
        skills: _ls(json['skills']),
        onDuty: _b(json['on_duty']),
        available: _b(json['available']),
        location: _i(json['location'], 3),
        version: _d(json['version']),
        busy: _b(json['busy']),
        activeTask: json['active_task'] == null ? null : _s(json['active_task']),
      );
}

class Notice {
  final String id;
  final String title;
  final String body;
  final int created;

  const Notice({required this.id, required this.title, required this.body, required this.created});

  factory Notice.fromJson(Map<String, dynamic> json) => Notice(
        id: _s(json['id']),
        title: _s(json['title']),
        body: _s(json['body']),
        created: _i(json['created']),
      );
}

class Recommendation {
  final String id;
  final String taskId;
  final int staffId;
  final String staffName;
  final int level;
  final int eta;
  final String reason;
  final int taskVersion;

  const Recommendation({
    required this.id,
    required this.taskId,
    required this.staffId,
    required this.staffName,
    required this.level,
    required this.eta,
    required this.reason,
    required this.taskVersion,
  });

  factory Recommendation.fromJson(Map<String, dynamic> json) => Recommendation(
        id: _s(json['id']),
        taskId: _s(json['task_id']),
        staffId: _i(json['staff_id']),
        staffName: _s(json['staff_name']),
        level: _i(json['level']),
        eta: _i(json['eta']),
        reason: _s(json['reason']),
        taskVersion: _i(json['task_version']),
      );
}

class RunNode {
  final String id;
  final String name;
  final String agent;
  final String mode;
  final String status;
  final int elapsedMs;
  final int attempts;
  final int? started;
  final int? finished;
  final Map<String, dynamic> input;
  final Map<String, dynamic> output;
  final String error;

  const RunNode({
    required this.id,
    required this.name,
    required this.agent,
    required this.mode,
    required this.status,
    required this.elapsedMs,
    this.attempts = 0,
    this.started,
    this.finished,
    required this.input,
    required this.output,
    required this.error,
  });

  factory RunNode.fromJson(Map<String, dynamic> json) => RunNode(
        id: _s(json['id']),
        name: _s(json['name']),
        agent: _s(json['agent']),
        mode: _s(json['mode']),
        status: _s(json['status']),
        elapsedMs: _i(json['elapsed_ms']),
        attempts: _i(json['attempts']),
        started: _i(json['started']) > 0 ? _i(json['started']) : null,
        finished: _i(json['finished']) > 0 ? _i(json['finished']) : null,
        input: _m(json['input']),
        output: _m(json['output']),
        error: _s(json['error']),
      );

  String get summary => _s(output['summary']);
  List<String> get actions => _ls(output['actions']);
  List<String> get evidence => _ls(output['evidence']);
  String get fallbackReason => _s(output['fallback_reason']);
}

/// 运行定义里的编排节点（新接口 `definition.nodes`）。
class DefinitionNode {
  final String key;
  final String name;
  final String agent;

  const DefinitionNode({required this.key, required this.name, required this.agent});

  factory DefinitionNode.fromJson(Map<String, dynamic> json) => DefinitionNode(
        key: _s(json['key']),
        name: _s(json['name'], _s(json['key'])),
        agent: _s(json['agent']),
      );
}

/// 运行引用的编排定义版本，旧服务可能不下发。
class WorkflowDefinition {
  final int version;
  final String title;
  final List<DefinitionNode> nodes;

  const WorkflowDefinition({
    required this.version,
    required this.title,
    this.nodes = const [],
  });

  factory WorkflowDefinition.fromJson(Map<String, dynamic> json) => WorkflowDefinition(
        version: _i(json['version']),
        title: _s(json['title']),
        nodes: (json['nodes'] as List? ?? const []).map((e) => DefinitionNode.fromJson(_m(e))).toList(),
      );

  static WorkflowDefinition? tryParse(dynamic v) {
    if (v is! Map) return null;
    final map = Map<String, dynamic>.from(v);
    if (map.isEmpty) return null;
    return WorkflowDefinition.fromJson(map);
  }
}

class WorkflowRun {
  final String id;
  final String kind;
  final int? elderId;
  final String? taskId;
  final String status;
  final String mode;
  final String summary;
  final int created;
  final int updated;
  final List<RunNode> nodes;
  final WorkflowDefinition? definition;
  final bool historical;
  final int snapshotVersion;

  const WorkflowRun({
    required this.id,
    required this.kind,
    required this.elderId,
    required this.taskId,
    required this.status,
    required this.mode,
    required this.summary,
    required this.created,
    required this.updated,
    this.nodes = const [],
    this.definition,
    this.historical = false,
    this.snapshotVersion = 0,
  });

  /// 后端允许 failed / dead / cancelled 的运行与任务重试。
  bool get retryable => status == 'failed' || status == 'dead' || status == 'cancelled';

  factory WorkflowRun.fromJson(Map<String, dynamic> json) => WorkflowRun(
        id: _s(json['id']),
        kind: _s(json['kind']),
        elderId: json['elder_id'] == null ? null : _i(json['elder_id']),
        taskId: json['task_id'] == null ? null : _s(json['task_id']),
        status: _s(json['status']),
        mode: _s(json['mode']),
        summary: _s(json['summary']),
        created: _i(json['created']),
        updated: _i(json['updated']),
        nodes: (json['nodes'] as List? ?? const []).map((e) => RunNode.fromJson(_m(e))).toList(),
        definition: WorkflowDefinition.tryParse(json['definition']),
        historical: _b(json['historical']),
        snapshotVersion: _i(json['snapshot_version']),
      );
}

/// 助手上下文的单个分区（身份与范围、风险事件……）。
class ContextSection {
  final String key;
  final String title;
  final int records;
  final int chars;

  const ContextSection({required this.key, required this.title, required this.records, required this.chars});

  factory ContextSection.fromJson(Map<String, dynamic> json) => ContextSection(
        key: _s(json['key']),
        title: _s(json['title'], _s(json['key'])),
        records: _i(json['records']),
        chars: _i(json['chars']),
      );
}

/// 一次受限工具查询的记录数。
class ContextTool {
  final String query;
  final int? elderId;
  final String? taskId;
  final int records;

  const ContextTool({required this.query, required this.elderId, required this.taskId, required this.records});

  factory ContextTool.fromJson(Map<String, dynamic> json) => ContextTool(
        query: _s(json['query']),
        elderId: json['elder_id'] == null ? null : _i(json['elder_id']),
        taskId: json['task_id'] == null ? null : _s(json['task_id']),
        records: _i(json['records']),
      );
}

/// 助手回复附带的上下文摘要；旧服务不返回时保持 null。
class ContextSummary {
  final String fingerprint;
  final int chars;
  final int budget;
  final bool truncated;
  final List<ContextSection> sections;
  final int redactions;
  final List<String> redactionRules;
  final List<String> gaps;
  final List<ContextTool> tools;

  const ContextSummary({
    required this.fingerprint,
    required this.chars,
    required this.budget,
    required this.truncated,
    this.sections = const [],
    this.redactions = 0,
    this.redactionRules = const [],
    this.gaps = const [],
    this.tools = const [],
  });

  factory ContextSummary.fromJson(Map<String, dynamic> json) => ContextSummary(
        fingerprint: _s(json['fingerprint']),
        chars: _i(json['chars']),
        budget: _i(json['budget']),
        truncated: _b(json['truncated']),
        sections: (json['sections'] as List? ?? const []).map((e) => ContextSection.fromJson(_m(e))).toList(),
        redactions: _i(json['redactions']),
        redactionRules: _ls(json['redaction_rules']),
        gaps: _ls(json['gaps']),
        tools: (json['tools'] as List? ?? const []).map((e) => ContextTool.fromJson(_m(e))).toList(),
      );

  bool get hasDetails => sections.isNotEmpty || gaps.isNotEmpty || redactionRules.isNotEmpty || tools.isNotEmpty;

  static ContextSummary? tryParse(dynamic v) {
    if (v is! Map) return null;
    final map = Map<String, dynamic>.from(v);
    if (map.isEmpty) return null;
    return ContextSummary.fromJson(map);
  }
}

class AssistantReply {
  final String reply;
  final List<Map<String, dynamic>> citations;
  final String mode;
  final String? runId;
  final String sessionId;
  final String fallbackReason;
  final ContextSummary? context;

  const AssistantReply({
    required this.reply,
    required this.citations,
    required this.mode,
    required this.runId,
    required this.sessionId,
    required this.fallbackReason,
    this.context,
  });

  factory AssistantReply.fromJson(Map<String, dynamic> json) => AssistantReply(
        reply: _s(json['reply']),
        citations: (json['citations'] as List? ?? const []).map((e) => _m(e)).toList(),
        mode: _s(json['mode'], 'rules'),
        runId: json['run_id'] == null ? null : _s(json['run_id']),
        sessionId: _s(json['session_id']),
        fallbackReason: _s(json['fallback_reason']),
        context: ContextSummary.tryParse(json['context']),
      );
}

class TaskDetail {
  final CareTask task;
  final List<Map<String, dynamic>> feedback;
  final List<Map<String, dynamic>> audit;
  final List<Map<String, dynamic>> agentRuns;

  const TaskDetail({
    required this.task,
    required this.feedback,
    required this.audit,
    required this.agentRuns,
  });

  factory TaskDetail.fromJson(Map<String, dynamic> json) => TaskDetail(
        task: CareTask.fromJson(json),
        feedback: (json['feedback'] as List? ?? const []).map((e) => _m(e)).toList(),
        audit: (json['audit'] as List? ?? const []).map((e) => _m(e)).toList(),
        agentRuns: (json['agent_runs'] as List? ?? const []).map((e) => _m(e)).toList(),
      );
}

/// 持久化任务队列中的一条任务（解释生成等）。
class WorkflowJob {
  final String id;
  final String kind;
  final String key;
  final String state;
  final int attempts;
  final int maxAttempts;
  final int priority;
  final double runAt;
  final double leaseUntil;
  final String lastError;
  final int created;
  final int updated;

  const WorkflowJob({
    required this.id,
    required this.kind,
    required this.key,
    required this.state,
    required this.attempts,
    required this.maxAttempts,
    required this.priority,
    required this.runAt,
    required this.leaseUntil,
    required this.lastError,
    required this.created,
    required this.updated,
  });

  /// 后端只允许 failed / dead / cancelled 的任务重试。
  bool get retryable => state == 'failed' || state == 'dead' || state == 'cancelled';

  /// 后端允许取消 queued 与 running 的任务。
  bool get cancellable => state == 'queued' || state == 'running';

  bool get terminal => state == 'done' || state == 'failed' || state == 'dead' || state == 'cancelled';

  factory WorkflowJob.fromJson(Map<String, dynamic> json) => WorkflowJob(
        id: _s(json['id']),
        kind: _s(json['kind']),
        key: _s(json['key']),
        state: _s(json['state'], 'queued'),
        attempts: _i(json['attempts']),
        maxAttempts: _i(json['max_attempts'], 3),
        priority: _i(json['priority']),
        runAt: _d(json['run_at']),
        leaseUntil: _d(json['lease_until']),
        lastError: _s(json['last_error']),
        created: _i(json['created']),
        updated: _i(json['updated']),
      );
}

/// 工作流统计（运行/任务队列/MCP）。
class WorkflowStats {
  final int runsTotal;
  final int runsQueued;
  final int runsRunning;
  final int runsWaitingHuman;
  final int runsCompleted;
  final int runsFailed;
  final int jobsQueued;
  final int jobsRunning;
  final int jobsDone;
  final int jobsFailed;
  final int jobsDead;
  final int jobsCancelled;
  final double oldestQueuedSeconds;
  final int mcpTools;
  final int mcpTokens;

  const WorkflowStats({
    required this.runsTotal,
    required this.runsQueued,
    required this.runsRunning,
    required this.runsWaitingHuman,
    required this.runsCompleted,
    required this.runsFailed,
    required this.jobsQueued,
    required this.jobsRunning,
    required this.jobsDone,
    required this.jobsFailed,
    required this.jobsDead,
    required this.jobsCancelled,
    required this.oldestQueuedSeconds,
    required this.mcpTools,
    required this.mcpTokens,
  });

  factory WorkflowStats.fromJson(Map<String, dynamic> json) {
    final runs = _m(json['runs']);
    final jobs = _m(json['jobs']);
    final mcp = _m(json['mcp']);
    return WorkflowStats(
      runsTotal: _i(runs['total']),
      runsQueued: _i(runs['queued']),
      runsRunning: _i(runs['running']),
      runsWaitingHuman: _i(runs['waiting_human']),
      runsCompleted: _i(runs['completed']),
      runsFailed: _i(runs['failed']),
      jobsQueued: _i(jobs['queued']),
      jobsRunning: _i(jobs['running']),
      jobsDone: _i(jobs['done']),
      jobsFailed: _i(jobs['failed']),
      jobsDead: _i(jobs['dead']),
      jobsCancelled: _i(jobs['cancelled']),
      oldestQueuedSeconds: _d(jobs['oldest_queued_seconds']),
      mcpTools: _i(mcp['tools']),
      mcpTokens: _i(mcp['tokens']),
    );
  }
}

class McpToken {
  final String id;
  final String username;
  final String label;
  final int created;
  final int expires;
  final int lastUsed;
  final bool revoked;

  const McpToken({
    required this.id,
    required this.username,
    required this.label,
    required this.created,
    required this.expires,
    required this.lastUsed,
    required this.revoked,
  });

  /// `expires <= 0` 表示长期有效；过期判断按当前时间计算。
  bool get expired {
    if (expires <= 0) return false;
    return DateTime.now().millisecondsSinceEpoch / 1000 >= expires;
  }

  factory McpToken.fromJson(Map<String, dynamic> json) => McpToken(
        id: _s(json['id']),
        username: _s(json['username']),
        label: _s(json['label']),
        created: _i(json['created']),
        expires: _i(json['expires']),
        lastUsed: _i(json['last_used']),
        revoked: _b(json['revoked']),
      );
}

class McpStatus {
  final String endpoint;
  final String protocol;
  final int tools;
  final int resources;
  final int prompts;
  final List<McpToken> tokens;

  const McpStatus({
    required this.endpoint,
    required this.protocol,
    required this.tools,
    required this.resources,
    required this.prompts,
    this.tokens = const [],
  });

  factory McpStatus.fromJson(Map<String, dynamic> json) => McpStatus(
        endpoint: _s(json['endpoint'], '/mcp'),
        protocol: _s(json['protocol']),
        tools: _i(json['tools']),
        resources: _i(json['resources']),
        prompts: _i(json['prompts']),
        tokens: (json['tokens'] as List? ?? const []).map((e) => McpToken.fromJson(_m(e))).toList(),
      );
}

/// 新建 MCP 令牌的响应：明文 token 只在创建时返回一次。
class IssuedMcpToken {
  final String id;
  final String token;
  final String label;
  final String username;
  final int expires;

  const IssuedMcpToken({
    required this.id,
    required this.token,
    required this.label,
    required this.username,
    required this.expires,
  });

  factory IssuedMcpToken.fromJson(Map<String, dynamic> json) => IssuedMcpToken(
        id: _s(json['id']),
        token: _s(json['token']),
        label: _s(json['label']),
        username: _s(json['username']),
        expires: _i(json['expires']),
      );
}

/// 距离（秒）格式化为「N 分钟 / N 小时 / N 天」。
String formatSpan(num? seconds) {
  if (seconds == null) return '—';
  final s = seconds.toInt();
  if (s <= 0) return '刚刚';
  if (s < 60) return '$s 秒';
  final m = (s / 60).round();
  if (m < 60) return '$m 分钟';
  final h = (s / 3600).floor();
  final rm = ((s % 3600) / 60).round();
  if (h < 24) return rm > 0 ? '$h 小时 $rm 分' : '$h 小时';
  final d = (s / 86400).floor();
  return '$d 天';
}

/// 管理员可编辑的云端模型配置；服务端只回传密钥尾号提示，不回传明文。
class LlmSettings {
  final bool enabled;
  final bool requested;
  final bool configured;
  final String mode;
  final String baseUrl;
  final String model;
  final bool apiKeySet;
  final String apiKeyHint;
  final String source;
  final String? fallbackReason;
  final double? updatedAt;
  final String? updatedBy;

  const LlmSettings({
    required this.enabled,
    required this.requested,
    required this.configured,
    required this.mode,
    required this.baseUrl,
    required this.model,
    required this.apiKeySet,
    required this.apiKeyHint,
    required this.source,
    this.fallbackReason,
    this.updatedAt,
    this.updatedBy,
  });

  bool get usesModel => mode == 'llm';
  String get sourceLabel => switch (source) {
        'database' => '本机设置',
        'environment' => '环境变量',
        _ => '未配置',
      };

  factory LlmSettings.fromJson(Map<String, dynamic> json) => LlmSettings(
        enabled: _b(json['enabled']),
        requested: _b(json['requested']),
        configured: _b(json['configured']),
        mode: _s(json['mode'], 'rules'),
        baseUrl: _s(json['base_url']),
        model: _s(json['model']),
        apiKeySet: _b(json['api_key_set']),
        apiKeyHint: _s(json['api_key_hint']),
        source: _s(json['source']),
        fallbackReason: json['fallback_reason'] == null ? null : _s(json['fallback_reason']),
        updatedAt: json['updated_at'] is num ? (json['updated_at'] as num).toDouble() : null,
        updatedBy: json['updated_by'] == null ? null : _s(json['updated_by']),
      );
}
