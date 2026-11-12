import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'models.dart';

/// 演示环境的统一初始密码（仅对应虚拟档案）。
const String demoPassword = 'Demo2026!';

final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();

class NavDef {
  final String key;
  final String label;
  const NavDef(this.key, this.label);
}

const List<NavDef> adminNav = [
  NavDef('overview', '守护总览'),
  NavDef('elders', '老人档案与状态'),
  NavDef('incidents', '风险事件'),
  NavDef('tasks', '任务中心'),
  NavDef('staff', '人员资源'),
  NavDef('assistant', '邻安助手'),
  NavDef('workflows', '工作流中心'),
  NavDef('lab', '回放与实验'),
];

const List<NavDef> staffNav = [
  NavDef('tasks', '我的任务'),
  NavDef('elders', '服务对象'),
  NavDef('staff', '我的状态'),
  NavDef('assistant', '邻安助手'),
];

const List<NavDef> careNav = [
  NavDef('care', '安心守护'),
  NavDef('incidents', '状态记录'),
  NavDef('assistant', '邻安助手'),
];

class AppState extends ChangeNotifier {
  AppState();

  /// 全局唯一的 API 客户端；401 时通过回调清会话，UI 自动回到登录页。
  late final ApiClient api = ApiClient(onUnauthorized: _handleUnauthorized);

  User? user;
  bool booting = true;
  bool loading = false;
  bool busy = false;
  String page = 'overview';
  DateTime? lastUpdated;
  String? bootError;

  List<Elder> elders = [];
  List<Incident> incidents = [];
  List<CareTask> tasks = [];
  List<Staff> staff = [];
  List<Notice> notices = [];
  List<WorkflowRun> runs = [];
  List<WorkflowJob> jobs = [];
  WorkflowStats? workflowStats;
  McpStatus? mcpStatus;
  bool workflowsLoading = false;
  Map<String, dynamic> agentsInfo = {};
  /// 后端健康信息（规则/模型/数据结构版本），由 refresh 的重接口轮次更新。
  Map<String, dynamic>? health;
  Map<String, dynamic>? experiment;
  bool autoDispatch = false;
  List<Recommendation> recs = [];
  List<int> unassigned = [];
  String recNote = '';

  Timer? _timer;
  bool _refreshing = false;
  bool _disposed = false;

  /// 轮询轮次：人员与工作流等重接口每 3 轮（15 秒）刷新一次。
  int _pollTick = 0;
  static const int _heavyEveryTicks = 3;

  List<NavDef> get navs {
    final role = user?.role;
    if (role == 'admin') return adminNav;
    if (role == 'staff') return staffNav;
    return careNav;
  }

  bool get isCareSide => user?.isCareSide ?? false;

  Elder? elderById(int? id) {
    for (final e in elders) {
      if (e.id == id) return e;
    }
    return null;
  }

  CareTask? taskById(String? id) {
    for (final t in tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  Staff? staffById(int? id) {
    for (final s in staff) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// 当前查看的老人档案：优先按用户绑定的 elderId 匹配，其次取列表第一条。
  ///
  /// 家属/老人端只下发关联档案，因此匹配失败时仍回退第一条；列表为空返回 null。
  Elder? elderFor(User? user) {
    final id = user?.elderId;
    if (id != null) {
      final matched = elderById(id);
      if (matched != null) return matched;
    }
    return elders.isEmpty ? null : elders.first;
  }

  List<Incident> get openIncidents => incidents.where((i) => i.open).toList();

  List<Elder> get watchedElders {
    final rows = elders.where((e) => e.level > 0).toList();
    rows.sort((a, b) => b.level.compareTo(a.level));
    return rows;
  }

  List<CareTask> get activeTasks =>
      tasks.where((t) => t.state != 'closed').toList()..sort((a, b) => b.level.compareTo(a.level));

  List<Staff> get onDutyStaff => staff.where((s) => s.onDuty).toList();

  int get availableCount => staff.where((s) => s.onDuty && s.available && !s.busy).length;

  Future<void> boot() async {
    final prefs = await SharedPreferences.getInstance();
    final savedBase = prefs.getString('linan.base');
    if (savedBase != null && savedBase.trim().isNotEmpty) {
      api.setBase(savedBase);
    } else if (ApiClient.compileTimeBase.isNotEmpty) {
      api.setBase(ApiClient.compileTimeBase);
    }
    final token = prefs.getString('linan.token');
    if (token != null && token.isNotEmpty) {
      api.token = token;
      try {
        user = await api.me();
        page = _defaultPage(user!);
        await refresh();
      } on ApiException catch (e) {
        if (e.status == 401 || e.status == 403) {
          api.token = null;
          await prefs.remove('linan.token');
        } else {
          bootError = e.message;
        }
      } catch (_) {
        bootError = '无法连接后端服务，请确认已启动 Linan 后端';
      }
    }
    booting = false;
    _notify();
    _timer ??= Timer.periodic(const Duration(seconds: 5), (_) => _poll());
  }

  String _defaultPage(User u) {
    if (u.isAdmin) return 'overview';
    if (u.isStaff) return 'tasks';
    return 'care';
  }

  Future<void> login(String username, String password) async {
    busy = true;
    _notify();
    try {
      final data = await api.login(username.trim(), password);
      // 响应格式异常时抛 ApiException，避免裸 as 转换抛出 TypeError。
      final rawToken = data['token'];
      final rawUser = data['user'];
      if (rawToken is! String || rawToken.isEmpty || rawUser is! Map) {
        throw const ApiException(0, '登录响应格式异常，请确认后端服务版本');
      }
      api.token = rawToken;
      user = User.fromJson(Map<String, dynamic>.from(rawUser));
      bootError = null;
      page = _defaultPage(user!);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('linan.token', rawToken);
      await refresh();
    } on ApiException catch (e) {
      if (e.status == 401 || e.status == 403) await _clearSession();
      rethrow;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> logout() async {
    await api.logout();
    await _clearSession();
    _notify();
  }

  Future<void> _clearSession() async {
    api.token = null;
    user = null;
    elders = [];
    incidents = [];
    tasks = [];
    staff = [];
    notices = [];
    runs = [];
    jobs = [];
    workflowStats = null;
    mcpStatus = null;
    recs = [];
    unassigned = [];
    experiment = null;
    agentsInfo = {};
    health = null;
    page = 'overview';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('linan.token');
  }

  /// [ApiClient] 收到 401 时的统一回调：清空会话，界面随之回到登录页。
  void _handleUnauthorized() {
    if (user == null && api.token == null) return;
    unawaited(_clearSession());
    _notify();
  }

  Future<void> setBase(String value) async {
    final v = value.trim();
    api.setBase(v);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('linan.base', v);
    _notify();
  }

  String get displayBase => api.baseUrl.isEmpty ? Uri.base.origin : api.baseUrl;

  void selectPage(String key) {
    if (page == key) return;
    page = key;
    _notify();
    if (key == 'lab' && experiment == null) {
      loadExperiment();
    }
    if (key == 'workflows' && user?.isAdmin == true) {
      loadWorkflows();
    }
  }

  /// 拉取页面数据。
  ///
  /// [force] 为 false 时按轮询降载策略执行：老人、事件、通知与任务每轮（5 秒）刷新，
  /// 人员、自动派单开关这类重接口每 3 轮（15 秒）刷新，运行记录只在工作流页拉取。
  Future<void> refresh({bool quiet = false, bool force = true}) async {
    if (user == null || _refreshing) return;
    _refreshing = true;
    if (!quiet) {
      loading = true;
      _notify();
    }
    try {
      final u = user!;
      final futures = <Future<void>>[
        api.elders().then((v) => elders = v),
        api.incidents().then((v) => incidents = v),
        api.notifications().then((v) => notices = v),
        api.agents().then((v) => agentsInfo = v),
      ];
      if (!u.isCareSide) {
        futures.add(api.tasks().then((v) => tasks = v));
      }
      // 重接口：人员、自动派单开关与运行记录每 3 轮（15 秒）刷新一次。
      final heavy = force || _pollTick % _heavyEveryTicks == 0;
      if (heavy) {
        futures.add(api.health().then((v) => health = v));
        if (!u.isCareSide) {
          futures.add(api.staff().then((v) => staff = v));
        }
        if (u.isAdmin) {
          futures.add(api.workflowSettings().then((v) => autoDispatch = v['auto_dispatch'] == true));
        }
        // 运行记录只在管理工作流页可见时轮询；进入该页已由 loadWorkflows 拉取，避免并发重复请求。
        if (u.isAdmin && !workflowsLoading && page == 'workflows') {
          futures.add(api.workflowRuns().then((v) => runs = v));
        }
      }
      await Future.wait(futures);
      lastUpdated = DateTime.now();
    } on ApiException catch (e) {
      if (e.status == 401) {
        await _clearSession();
        _toast('会话已过期，请重新登录');
      } else if (!quiet) {
        _toast(e.message);
      }
    } catch (_) {
      if (!quiet) _toast('刷新失败，请检查后端连接');
    } finally {
      _refreshing = false;
      loading = false;
      _notify();
    }
  }

  Future<void> _poll() async {
    if (user == null || booting || busy || loading || workflowsLoading || _refreshing) return;
    _pollTick++;
    await refresh(quiet: true, force: false);
  }

  Future<void> loadExperiment() async {
    try {
      experiment = await api.experiments();
      _notify();
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  Future<void> loadRuns() async {
    try {
      runs = await api.workflowRuns();
      if (user?.isAdmin == true) autoDispatch = (await api.workflowSettings())['auto_dispatch'] == true;
      _notify();
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  /// 进入工作流页时并行加载运行记录、持久化任务、统计与 MCP 状态（仅管理员）。
  Future<void> loadWorkflows() async {
    if (user?.isAdmin != true) return;
    workflowsLoading = true;
    _notify();
    final errors = <String>[];
    var expired = false;
    Future<void> track(Future<void> Function() task) async {
      if (expired) return;
      try {
        await task();
      } on ApiException catch (e) {
        if (e.status == 401) {
          expired = true;
          await _clearSession();
        } else {
          errors.add(e.message);
        }
      }
    }

    await Future.wait([
      track(() async => runs = await api.workflowRuns()),
      track(() async => jobs = await api.workflowJobs()),
      track(() async => workflowStats = await api.workflowStats()),
      track(() async => mcpStatus = await api.mcpStatus()),
      track(() async => autoDispatch = (await api.workflowSettings())['auto_dispatch'] == true),
    ]);
    workflowsLoading = false;
    _notify();
    if (expired) {
      _toast('会话已过期，请重新登录');
    } else if (errors.isNotEmpty) {
      _toast(errors.length == 1 ? errors.first : '${errors.first}（另有 ${errors.length - 1} 项加载失败）');
    }
  }

  Future<void> loadJobs() async {
    try {
      jobs = await api.workflowJobs();
      workflowStats = await api.workflowStats();
      _notify();
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  Future<void> loadMcp() async {
    try {
      mcpStatus = await api.mcpStatus();
      _notify();
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  Future<void> retryJob(String id) async {
    try {
      await api.retryJob(id);
    } on Object catch (e) {
      _toast('$e');
      rethrow;
    }
    await loadJobs();
    _toast('任务已重新排队');
  }

  Future<void> cancelJob(String id) async {
    try {
      await api.cancelJob(id);
    } on Object catch (e) {
      _toast('$e');
      rethrow;
    }
    await loadJobs();
    _toast('任务已取消');
  }

  Future<void> retryRun(String id) async {
    try {
      await api.retryRun(id);
    } on Object catch (e) {
      _toast('$e');
      rethrow;
    }
    await loadRuns();
    await loadJobs();
    _toast('运行已重新排队');
  }

  Future<IssuedMcpToken> createMcpToken({required String label, required int expiresHours}) async {
    late final IssuedMcpToken issued;
    try {
      issued = await api.createMcpToken(label: label, expiresHours: expiresHours);
    } on Object catch (e) {
      _toast('$e');
      rethrow;
    }
    await loadMcp();
    _toast('已创建 MCP 令牌，明文仅显示一次');
    return issued;
  }

  Future<void> revokeMcpToken(String id) async {
    try {
      await api.revokeMcpToken(id);
    } on Object catch (e) {
      _toast('$e');
      rethrow;
    }
    await loadMcp();
    _toast('令牌已撤销');
  }

  Future<void> loadRecommendations() async {
    final data = await api.recommend();
    recs = (data['recommendations'] as List? ?? const [])
        .map((e) => Recommendation.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    unassigned = (data['unassigned'] as List? ?? const []).map((e) => (e as num).toInt()).toList();
    recNote = '${data['note'] ?? ''}';
    _notify();
  }

  Future<void> confirmRecommendation(Recommendation rec, int staffId, String reason) async {
    busy = true;
    _notify();
    try {
      await api.confirm({
        'recommendation_id': rec.id,
        'staff_id': staffId,
        if (reason.trim().isNotEmpty) 'reason': reason.trim(),
      });
      await refresh();
      recs.removeWhere((r) => r.id == rec.id);
      _toast('已确认派单');
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> taskAction(String taskId, String action, {String outcome = '', String note = ''}) async {
    busy = true;
    _notify();
    try {
      await api.taskAction(taskId, action, outcome: outcome, note: note);
      await refresh();
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> reportEvent(int elderId, String kind, Map<String, dynamic> payload) async {
    busy = true;
    _notify();
    try {
      await api.ingest({
        'elder_id': elderId,
        'kind': kind,
        'source': 'manual',
        'payload': payload,
      });
      await refresh();
      _toast('信息已上报，风险判断已更新');
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> saveElder(Map<String, dynamic> body, {int? id}) async {
    busy = true;
    _notify();
    try {
      await api.saveElder(body, id: id);
      await refresh();
      _toast(id == null ? '已为老人建档' : '档案已更新');
    } finally {
      busy = false;
      _notify();
    }
  }

  /// 更新人员值班/接单/楼栋。
  ///
  /// 后端 `WorkerUpdate` 三个字段必填，未传入的字段先用已加载的 staff 列表补全；
  /// 失败只 toast 一次并返回 false，不向调用方抛异常。
  Future<bool> updateStaff(int staffId, {bool? onDuty, bool? available, int? location}) async {
    final current = staffById(staffId);
    final duty = onDuty ?? current?.onDuty;
    final accept = available ?? current?.available;
    final loc = location ?? current?.location;
    if (duty == null || accept == null || loc == null) {
      _toast('人员状态尚未加载，暂时无法修改');
      return false;
    }
    if (loc < 1 || loc > 5) {
      _toast('负责楼栋需在 1–5 号楼之间');
      return false;
    }
    try {
      await api.updateStaff(staffId, {'on_duty': duty, 'available': accept, 'location': loc});
      await refresh();
      return true;
    } on ApiException catch (e) {
      _toast(e.message);
      return false;
    } catch (_) {
      _toast('人员状态更新失败，请稍后重试');
      return false;
    } finally {
      _notify();
    }
  }

  Future<void> setAutoDispatch(bool value) async {
    try {
      final data = await api.setAutoDispatch(value);
      autoDispatch = data['auto_dispatch'] == true;
      runs = await api.workflowRuns();
      _toast(autoDispatch ? '自动派单已开启（仅 1 级电话核实）' : '自动派单已关闭');
    } finally {
      _notify();
    }
  }

  Future<Map<String, dynamic>> runScenario(String key, {int? elderId}) async {
    busy = true;
    _notify();
    try {
      final data = await api.scenario(key, elderId: elderId);
      await refresh();
      return data;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<Map<String, dynamic>> replay(int elderId, int offset) async =>
      api.replay(elderId, offset);

  Future<Map<String, dynamic>> runExperiments() async {
    busy = true;
    _notify();
    try {
      final data = await api.runExperiments();
      experiment = data;
      return data;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<Map<String, dynamic>> exportFeedback() => api.feedbackExport();

  Future<AssistantReply> assistant({
    required String message,
    String? sessionId,
    int? elderId,
    String? taskId,
  }) async {
    busy = true;
    _notify();
    try {
      final data = await api.assistant(message: message, sessionId: sessionId, elderId: elderId, taskId: taskId);
      return AssistantReply.fromJson(data);
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<TaskDetail> taskDetail(String id) => api.taskDetail(id);
  Future<Elder> elderDetail(int id) => api.elder(id);
  Future<WorkflowRun> runDetail(String id) => api.workflowRun(id);

  void toast(String message) => _toast(message);

  void _toast(String message) {
    final messenger = messengerKey.currentState;
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}

String navLabel(String key) {
  for (final n in [...adminNav, ...staffNav, ...careNav]) {
    if (n.key == key) return n.label;
  }
  return key;
}

String pageSubtitle(AppState state) {
  switch (state.page) {
    case 'overview':
      return '把分散的感知、判断与照护动作，收进同一条守护链路。';
    case 'elders':
      return state.user?.isAdmin == true ? '档案、作息与实时状态都在这里。' : '你正在服务的老人。';
    case 'incidents':
      return state.user?.isCareSide == true ? '最近的状态变化与处置进展。' : '所有未关闭的风险判断与依据。';
    case 'tasks':
      return state.user?.isAdmin == true ? '派单、接单、处置与复核的完整记录。' : '接单、处置、反馈，按步骤完成。';
    case 'staff':
      return state.user?.isAdmin == true ? '技能、值班与容量，派单时一并校验。' : '值班状态与可接单容量。';
    case 'assistant':
      return '只查询你有权查看的记录；大模型负责解释，不改变风险等级。';
    case 'workflows':
      return '风险响应、处置复核与对话查询的运行轨迹。';
    case 'lab':
      return '回放、对照实验与可复核的证据导出。';
    case 'care':
      return '一次点击，把“我很好”或“我需要帮助”送到社区。';
    default:
      return '';
  }
}
