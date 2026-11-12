import 'package:flutter_test/flutter_test.dart';
import 'package:linan_app/src/labels.dart';
import 'package:linan_app/src/models.dart';

void main() {
  test('后台任务的可重试与可取消状态与后端一致', () {
    final expected = {
      'queued': [false, true],
      'running': [false, true],
      'failed': [true, false],
      'dead': [true, false],
      'cancelled': [true, false],
      'done': [false, false],
    };
    for (final entry in expected.entries) {
      final job = WorkflowJob.fromJson({'id': 'JOB-1', 'kind': 'explanation', 'key': 'k', 'state': entry.key});
      expect(job.retryable, entry.value[0], reason: '${entry.key} 可重试');
      expect(job.cancellable, entry.value[1], reason: '${entry.key} 可取消');
    }
  });

  test('业务编号保持后端字符串形式，不被解析成整数', () {
    final incident = Incident.fromJson({
      'id': 'IN-4f2c9a',
      'elder_id': 1,
      'category': 'safety',
      'level': 3,
      'title': '老人主动求助',
      'evidence': ['主动求助'],
      'created': 1762900000,
    });
    expect(incident.id, 'IN-4f2c9a');
    final task = CareTask.fromJson({
      'id': 'TK-9a1b2c',
      'elder_id': 1,
      'incident_id': 'IN-4f2c9a',
      'level': 3,
      'state': 'pending',
      'required_skill': 'visit',
      'version': 2,
    });
    expect(task.id, 'TK-9a1b2c');
    expect(task.incidentId, 'IN-4f2c9a');
  });

  test('风险等级与任务状态的文案覆盖后端全部取值', () {
    for (final level in [-1, 0, 1, 2, 3]) {
      expect(levelNames.containsKey(level), isTrue, reason: '等级 $level 缺少文案');
    }
    for (final state in ['pending', 'dispatched', 'accepted', 'processing', 'review', 'closed']) {
      expect(stateName(state), isNot(state), reason: '状态 $state 缺少文案');
    }
    for (final state in ['queued', 'running', 'done', 'failed', 'dead', 'cancelled']) {
      expect(jobStateLabel(state), isNot(state), reason: '任务状态 $state 缺少文案');
    }
    for (final kind in [
      'safe', 'contact', 'sos', 'away', 'home', 'rest', 'need_help',
      'unreachable', 'data_offline', 'data_online', 'missed_checkin', 'activity',
    ]) {
      expect(kindName(kind), isNot(kind), reason: '事件类型 $kind 缺少文案');
    }
    for (final skill in ['phone', 'visit', 'device']) {
      expect(skillName(skill), isNot(skill), reason: '技能 $skill 缺少文案');
    }
    expect(levelName(-1), '平稳');
    expect(levelName(3), '紧急');
  });
}
