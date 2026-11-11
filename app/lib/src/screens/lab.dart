import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class LabPage extends StatefulWidget {
  final AppState state;
  const LabPage({super.key, required this.state});

  @override
  State<LabPage> createState() => _LabPageState();
}

class _LabPageState extends State<LabPage> {
  int? _elderId;
  int _offset = 0;
  bool _replaying = false;
  Map<String, dynamic>? _replayResult;

  AppState get s => widget.state;

  static const List<(String, String, String)> _scenarios = [
    ('story', '完整闭环', '注入未报平安、活动骤降与主动求助，走完派单与复核。'),
    ('offline', '数据离线', '设备离线时显示“未知”，不会当成安全。'),
    ('away', '确认外出', '外出确认能解释活动缺失，但不关闭紧急事件。'),
    ('cold_start', '冷启动', '历史不足时显示学习中，不虚构基线。'),
    ('conflict', '冲突信号', '求助与安全信号并存时，按更高风险处理。'),
    ('normal', '平稳日常', '恢复一组正常活动，观察状态回落。'),
  ];

  @override
  void initState() {
    super.initState();
    if (s.experiment == null) s.loadExperiment();
  }

  @override
  Widget build(BuildContext context) {
    final exp = s.experiment;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 30),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1240),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _scenarioSection(),
              const SizedBox(height: 12),
              _replaySection(),
              const SizedBox(height: 12),
              SectionCard(
                title: '实验对照',
                subtitle: '所有数字来自本地真实运行；个性化方法的事件召回率低于固定阈值，是已知局限。',
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: s.busy ? null : _runExperiments,
                      icon: const Icon(Icons.play_arrow, size: 14),
                      label: const Text('运行实验', style: TextStyle(fontSize: 10.5)),
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 30)),
                    ),
                    OutlinedButton.icon(
                      onPressed: exp == null ? null : () => _showJson('实验 JSON', exp),
                      icon: const Icon(Icons.code, size: 14),
                      label: const Text('查看 JSON', style: TextStyle(fontSize: 10.5)),
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 30)),
                    ),
                    OutlinedButton.icon(
                      onPressed: _exportFeedback,
                      icon: const Icon(Icons.download_outlined, size: 14),
                      label: const Text('导出反馈', style: TextStyle(fontSize: 10.5)),
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 30)),
                    ),
                  ],
                ),
                child: exp == null
                    ? const EmptyHint('还没有实验结果，先运行一次或查看历史 JSON', icon: Icons.science_outlined)
                    : _experimentTables(exp),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scenarioSection() {
    return SectionCard(
      title: '情景回放',
      subtitle: '一键注入可复现的社区情景，观察风险判断与处置链路。使用当前虚拟档案。',
      child: LayoutBuilder(
        builder: (context, c) {
          final cols = c.maxWidth >= 1000 ? 3 : (c.maxWidth >= 640 ? 2 : 1);
          final gap = 10.0;
          final width = (c.maxWidth - gap * (cols - 1)) / cols;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final sc in _scenarios)
                SizedBox(
                  width: width,
                  child: InkWell(
                    onTap: s.busy ? null : () => _runScenario(sc.$1, sc.$2),
                    borderRadius: BorderRadius.circular(9),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
                      decoration: BoxDecoration(
                        color: LinanColors.surfaceAlt.withValues(alpha: .55),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: LinanColors.borderSoft),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(sc.$2,
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                              ),
                              const Icon(Icons.play_circle_outline, size: 15, color: LinanColors.primary),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(sc.$3, style: const TextStyle(fontSize: 9.5, height: 1.55, color: LinanColors.muted)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _replaySection() {
    final elders = s.elders;
    final elderId = _elderId ?? (elders.isEmpty ? null : elders.first.id);
    return SectionCard(
      title: 'CASAS 窗口回放',
      subtitle: '把真实 Aruba 传感器窗口注入虚拟档案，验证同一套规则在真实数据上的反应。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 190,
                child: DropdownButtonFormField<int>(
                  initialValue: elderId,
                  decoration: const InputDecoration(labelText: '注入到老人', isDense: true),
                  items: [
                    for (final e in elders)
                      DropdownMenuItem(value: e.id, child: Text('${e.name} · ${e.building}', style: const TextStyle(fontSize: 11))),
                  ],
                  onChanged: (v) => setState(() => _elderId = v),
                ),
              ),
              SizedBox(
                width: 150,
                child: TextFormField(
                  initialValue: '$_offset',
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '窗口偏移', isDense: true),
                  style: const TextStyle(fontSize: 11.5),
                  onChanged: (v) => _offset = int.tryParse(v.trim()) ?? 0,
                ),
              ),
              SizedBox(
                height: 34,
                child: FilledButton.icon(
                  onPressed: _replaying || elderId == null ? null : () => _replay(elderId),
                  icon: const Icon(Icons.replay, size: 14),
                  label: const Text('回放该窗口', style: TextStyle(fontSize: 11)),
                ),
              ),
            ],
          ),
          if (_replayResult != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: LinanColors.primarySoft.withValues(alpha: .45),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: LinanColors.primary.withValues(alpha: .12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '第 ${_replayResult!['offset'] ?? _offset} / ${_replayResult!['total'] ?? '?'} 窗口 · '
                    '15 分钟 ${_replayResult!['count15'] ?? '?'} 次 · 最长静止 ${_replayResult!['gap'] ?? '?'} 分钟',
                    style: const TextStyle(fontSize: 10.5, height: 1.6, color: LinanColors.primaryDeep),
                  ),
                  if ('${_replayResult!['original_timestamp'] ?? ''}'.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text('原始时间：${_replayResult!['original_timestamp']}',
                          style: const TextStyle(fontSize: 9.5, color: LinanColors.muted)),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _experimentTables(Map<String, dynamic> exp) {
    final activityRaw = exp['activity'];
    final activity = activityRaw is Map ? activityRaw : const {};
    final scheduling = exp['scheduling'] as Map? ?? const {};
    final synthetic = activity['baseline'] is Map
        ? activity
        : (activity['synthetic'] is Map ? activity['synthetic'] as Map : const {});
    final casas = exp['casas'] is Map && (exp['casas'] as Map)['baseline'] is Map
        ? exp['casas'] as Map
        : (activity['casas'] is Map ? activity['casas'] as Map : const {});
    final activityTables = <Widget>[
      for (final pair in [('synthetic', synthetic), ('casas', casas)])
        if (pair.$2['baseline'] is Map)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _compareTable(
              title: '活动识别 · ${_originLabel(pair.$1)}',
              baseline: pair.$2['baseline'] as Map? ?? const {},
              personalized: pair.$2['personalized'] as Map? ?? const {},
              metrics: const [
                ('original_alarm_rate', '报警率', true),
                ('injected_window_recall', '窗口召回率', true),
                ('injected_episode_recall', '事件召回率', true),
                ('mean_detection_delay_minutes', '平均检测延迟（分钟）', false),
              ],
              note: '${pair.$2['interpretation'] ?? ''}',
            ),
          ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...activityTables,
        if (scheduling.containsKey('baseline'))
          _compareTable(
            title: '人员调度 · 20 任务 4 人',
            baseline: scheduling['baseline'] as Map? ?? const {},
            personalized: scheduling['optimized'] as Map? ?? const {},
            baselineLabel: '基线派单',
            personalizedLabel: '优化派单',
            metrics: const [
              ('mean_response_minutes', '平均响应（分钟）', false),
              ('p95_response_minutes', 'P95 响应（分钟）', false),
              ('urgent_mean_response_minutes', '紧急平均响应（分钟）', false),
              ('urgent_covered_within_30_minutes', '紧急 30 分钟覆盖', true),
              ('constraint_violations', '约束违反', false),
            ],
            note: '${scheduling['interpretation'] ?? ''}',
          ),
        if ('${exp['data_notice'] ?? ''}'.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text('数据说明：${exp['data_notice']}',
                style: const TextStyle(fontSize: 9.5, height: 1.55, color: LinanColors.faint)),
          ),
      ],
    );
  }

  Widget _compareTable({
    required String title,
    required Map baseline,
    required Map personalized,
    required List<(String, String, bool)> metrics,
    required String note,
    String baselineLabel = '固定阈值',
    String personalizedLabel = '个性化',
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 11),
      decoration: BoxDecoration(
        color: LinanColors.surfaceAlt.withValues(alpha: .35),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: LinanColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(2.2),
              1: FlexColumnWidth(1.4),
              2: FlexColumnWidth(1.4),
            },
            children: [
              TableRow(
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: LinanColors.border))),
                children: [
                  _cell('指标', header: true),
                  _cell(baselineLabel, header: true),
                  _cell(personalizedLabel, header: true),
                ],
              ),
              for (final m in metrics)
                TableRow(
                  children: [
                    _cell(m.$2),
                    _cell(_metricText(baseline[m.$1], m.$3)),
                    _cell(_metricText(personalized[m.$1], m.$3)),
                  ],
                ),
            ],
          ),
          if (note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(note, style: const TextStyle(fontSize: 9.5, height: 1.6, color: LinanColors.muted)),
            ),
        ],
      ),
    );
  }

  Widget _cell(String text, {bool header = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
        child: Text(
          text,
          style: TextStyle(
            fontSize: header ? 9 : 10.5,
            fontWeight: header ? FontWeight.w600 : FontWeight.w400,
            color: header ? LinanColors.muted : LinanColors.text,
          ),
        ),
      );

  String _metricText(dynamic value, bool percent) {
    if (value is! num) return '—';
    if (percent) return '${(value * 100).toStringAsFixed(1)}%';
    return value.toStringAsFixed(2);
  }

  String _originLabel(String key) {
    if (key == 'synthetic') return '合成社区数据';
    if (key == 'casas') return 'CASAS Aruba 真实数据';
    return key;
  }

  Future<void> _runScenario(String key, String label) async {
    try {
      final data = await s.runScenario(key);
      final events = (data['events'] as List?)?.length ?? 0;
      s.toast('已注入「$label」：$events 条事件');
    } on Object catch (e) {
      s.toast('$e');
    }
  }

  Future<void> _replay(int elderId) async {
    setState(() => _replaying = true);
    try {
      final data = await s.replay(elderId, _offset);
      if (!mounted) return;
      setState(() {
        _replayResult = data;
        _offset = (data['offset'] as num?)?.toInt() ?? _offset;
      });
      await s.refresh();
    } on Object catch (e) {
      s.toast('$e');
    } finally {
      if (mounted) setState(() => _replaying = false);
    }
  }

  Future<void> _runExperiments() async {
    try {
      final data = await s.runExperiments();
      s.toast('实验完成：${data.containsKey('activity') ? '已生成活动与调度对照' : '已返回结果'}');
    } on Object catch (e) {
      s.toast('$e');
    }
  }

  Future<void> _exportFeedback() async {
    try {
      final data = await s.exportFeedback();
      if (!mounted) return;
      _showJson('已复核反馈导出', data);
    } on Object catch (e) {
      s.toast('$e');
    }
  }

  void _showJson(String title, Map<String, dynamic> data) {
    final text = const JsonEncoder.withIndent('  ').convert(data);
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 620),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 8, 10),
                child: Row(
                  children: [
                    Expanded(child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                    IconButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: text));
                        s.toast('已复制到剪贴板');
                      },
                      icon: const Icon(Icons.copy_all_outlined, size: 16),
                      tooltip: '复制',
                    ),
                    IconButton(onPressed: () => Navigator.of(ctx).pop(), icon: const Icon(Icons.close, size: 17)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(14),
                  child: SelectableText(text, style: const TextStyle(fontSize: 9.5, height: 1.55, fontFamily: 'monospace')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
