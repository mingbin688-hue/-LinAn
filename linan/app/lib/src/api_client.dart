import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';
import 'platform_base.dart';

class ApiException implements Exception {
  final int status;
  final String message;

  const ApiException(this.status, this.message);

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({String? baseUrl}) : _base = (baseUrl ?? defaultApiBase()).trim();

  static const _envBase = String.fromEnvironment('API_BASE');
  static const _timeout = Duration(seconds: 20);

  String _base;
  String? token;

  String get baseUrl => _base;

  /// 网页端使用同源地址；桌面/移动端默认本机 8765，可在登录页覆盖。
  Uri _uri(String path, [Map<String, String>? query]) {
    var origin = _base.isEmpty ? Uri.base.origin : _base;
    if (origin.endsWith('/')) origin = origin.substring(0, origin.length - 1);
    final base = Uri.parse('$origin$path');
    if (query == null || query.isEmpty) return base;
    return base.replace(queryParameters: {...base.queryParameters, ...query});
  }

  void setBase(String value) {
    _base = value.trim();
  }

  static String get compileTimeBase => _envBase;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
  }) async {
    final uri = _uri(path, query);
    late http.Response res;
    try {
      final payload = body == null ? null : jsonEncode(body);
      switch (method) {
        case 'GET':
          res = await http.get(uri, headers: _headers).timeout(_timeout);
        case 'POST':
          res = await http.post(uri, headers: _headers, body: payload).timeout(_timeout);
        case 'PUT':
          res = await http.put(uri, headers: _headers, body: payload).timeout(_timeout);
        default:
          throw const ApiException(0, '不支持的请求方法');
      }
    } on TimeoutException {
      throw const ApiException(0, '请求超时，请确认后端服务已启动');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(0, '无法连接后端：$uri');
    }

    if (res.statusCode == 204) return null;
    final text = utf8.decode(res.bodyBytes);
    dynamic data;
    if (text.isNotEmpty) {
      try {
        data = jsonDecode(text);
      } catch (_) {
        data = text;
      }
    }
    if (res.statusCode >= 400) {
      String message = '请求失败（${res.statusCode}）';
      if (data is Map && data['detail'] != null) {
        final detail = data['detail'];
        message = detail is String ? detail : _flattenDetail(detail);
      }
      throw ApiException(res.statusCode, message);
    }
    return data;
  }

  String _flattenDetail(dynamic detail) {
    if (detail is List) {
      return detail
          .map((e) {
            if (e is Map) return '${e['loc'] is List ? (e['loc'] as List).join('.') : ''} ${e['msg'] ?? ''}'.trim();
            return '$e';
          })
          .where((e) => e.isNotEmpty)
          .join('；');
    }
    return '$detail';
  }

  Map<String, dynamic> _map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
  List<Map<String, dynamic>> _list(dynamic v) =>
      v is List ? v.map((e) => _map(e)).toList() : <Map<String, dynamic>>[];

  Future<Map<String, dynamic>> login(String username, String password) async =>
      _map(await _send('POST', '/api/auth/login', body: {'username': username, 'password': password}));

  Future<void> logout() async {
    try {
      await _send('POST', '/api/auth/logout');
    } catch (_) {
      // 会话可能已过期，忽略退出失败。
    }
  }

  Future<User> me() async => User.fromJson(_map(await _send('GET', '/api/me')));

  Future<List<Elder>> elders() async =>
      _list(await _send('GET', '/api/elders')).map(Elder.fromJson).toList();

  Future<Elder> elder(int id) async => Elder.fromJson(_map(await _send('GET', '/api/elders/$id')));

  Future<Map<String, dynamic>> saveElder(Map<String, dynamic> body, {int? id}) async =>
      _map(await _send(id == null ? 'POST' : 'PUT', id == null ? '/api/elders' : '/api/elders/$id', body: body));

  Future<Map<String, dynamic>> ingest(Map<String, dynamic> body) async =>
      _map(await _send('POST', '/api/events', body: body));

  Future<List<Incident>> incidents() async =>
      _list(await _send('GET', '/api/incidents')).map(Incident.fromJson).toList();

  Future<List<CareTask>> tasks() async =>
      _list(await _send('GET', '/api/tasks')).map(CareTask.fromJson).toList();

  Future<TaskDetail> taskDetail(String id) async =>
      TaskDetail.fromJson(_map(await _send('GET', '/api/tasks/$id')));

  Future<List<Staff>> staff() async =>
      _list(await _send('GET', '/api/staff')).map(Staff.fromJson).toList();

  Future<Map<String, dynamic>> updateStaff(int id, Map<String, dynamic> body) async =>
      _map(await _send('PUT', '/api/staff/$id', body: body));

  Future<Map<String, dynamic>> recommend() async => _map(await _send('POST', '/api/dispatch/recommend'));

  Future<Map<String, dynamic>> confirm(Map<String, dynamic> body) async =>
      _map(await _send('POST', '/api/dispatch/confirm', body: body));

  Future<Map<String, dynamic>> taskAction(String id, String action, {String outcome = '', String note = ''}) async =>
      _map(await _send('POST', '/api/tasks/$id/action', body: {'action': action, 'outcome': outcome, 'note': note}));

  Future<List<Notice>> notifications() async =>
      _list(await _send('GET', '/api/notifications')).map(Notice.fromJson).toList();

  Future<Map<String, dynamic>> scenario(String name, {int? elderId}) async {
    final body = <String, dynamic>{'scenario': name};
    if (elderId != null) body['elder_id'] = elderId;
    return _map(await _send('POST', '/api/demo/scenario', body: body));
  }

  Future<Map<String, dynamic>> replay(int elderId, int offset) async =>
      _map(await _send('POST', '/api/replay/window', body: {'elder_id': elderId, 'offset': offset}));

  Future<Map<String, dynamic>> runExperiments() async => _map(await _send('POST', '/api/experiments/run'));

  Future<Map<String, dynamic>?> experiments() async {
    final data = await _send('GET', '/api/experiments');
    if (data == null) return null;
    return _map(data);
  }

  Future<Map<String, dynamic>> feedbackExport() async => _map(await _send('GET', '/api/feedback/export'));

  Future<Map<String, dynamic>> agents() async => _map(await _send('GET', '/api/agents'));

  Future<Map<String, dynamic>> assistant({
    required String message,
    String? sessionId,
    int? elderId,
    String? taskId,
  }) async {
    final body = <String, dynamic>{'message': message};
    if (sessionId != null && sessionId.isNotEmpty) body['session_id'] = sessionId;
    if (elderId != null) body['elder_id'] = elderId;
    if (taskId != null) body['task_id'] = taskId;
    return _map(await _send('POST', '/api/assistant/messages', body: body));
  }

  Future<Map<String, dynamic>> workflowSettings() async => _map(await _send('GET', '/api/workflows/settings'));

  Future<Map<String, dynamic>> setAutoDispatch(bool value) async =>
      _map(await _send('PUT', '/api/workflows/settings', body: {'auto_dispatch': value}));

  Future<List<WorkflowRun>> workflowRuns() async =>
      _list(await _send('GET', '/api/workflows/runs')).map(WorkflowRun.fromJson).toList();

  Future<WorkflowRun> workflowRun(String id) async =>
      WorkflowRun.fromJson(_map(await _send('GET', '/api/workflows/runs/$id')));
}
