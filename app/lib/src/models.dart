import 'dart:math' as math;

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

  Elder withEvents(List<Map<String, dynamic>> rows) => Elder(
        id: id,
        name: name,
        age: age,
        building: building,
        contact: contact,
        profile: profile,
        state: state,
        level: level,
        dataUnknown: dataUnknown,
        incidentCount: incidentCount,
        latestIncident: latestIncident,
        version: version,
        events: rows,
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
        input: _m(json['input']),
        output: _m(json['output']),
        error: _s(json['error']),
      );

  String get summary => _s(output['summary']);
  List<String> get actions => _ls(output['actions']);
  List<String> get evidence => _ls(output['evidence']);
  String get fallbackReason => _s(output['fallback_reason']);
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
    this.historical = false,
    this.snapshotVersion = 0,
  });

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
        historical: _b(json['historical']),
        snapshotVersion: _i(json['snapshot_version']),
      );
}

class AssistantReply {
  final String reply;
  final List<Map<String, dynamic>> citations;
  final String mode;
  final String? runId;
  final String sessionId;
  final String fallbackReason;

  const AssistantReply({
    required this.reply,
    required this.citations,
    required this.mode,
    required this.runId,
    required this.sessionId,
    required this.fallbackReason,
  });

  factory AssistantReply.fromJson(Map<String, dynamic> json) => AssistantReply(
        reply: _s(json['reply']),
        citations: (json['citations'] as List? ?? const []).map((e) => _m(e)).toList(),
        mode: _s(json['mode'], 'rules'),
        runId: json['run_id'] == null ? null : _s(json['run_id']),
        sessionId: _s(json['session_id']),
        fallbackReason: _s(json['fallback_reason']),
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

int minutesBetween(num? from, num? to) {
  if (from == null || to == null || from <= 0 || to <= 0) return 0;
  return math.max(0, ((to - from) / 60).round());
}
