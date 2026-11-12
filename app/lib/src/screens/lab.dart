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
  final TextEditingController _offsetCtrl = TextEditingController(text: '0');
  bool _replaying = false;
  Map<String, dynamic>? _replayResult;

  AppState get s => widget.state;

  @override
  void dispose() {
    _offsetCtrl.dispose();
    super.dispose();
  }

  static const List<(String, String, String)> _scenarios = [
    ('story', '完整闭环', '注入未报平安、活动骤降与主动求助，走完派单与复核。'),
    ('offline', '数据离线', '设备离线时显示“未知”，不会当成安全。'),
    ('away', '确认外出', '外出确认能解释活动缺失，但不关闭紧急事件。'),
    ('cold_start', '冷启动', '历史不足时显示学习中，不虚构基线。'),
    ('conflict', '冲突信号', '求助与安全信号并存时，按更高风险处理。'),
    ('normal', '平稳日常', '恢复一组正常活动，观察状态回落。'),
  ];

  @override
  Widget build(BuildContext context) {
    final exp = s.experiment;
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 980;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(wide ? 24 : 16, 0, wide ? 24 : 16, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PageHeader(
                    padding: const EdgeInsets.only(top: 26, bottom: 16),
                    title: '回放与实验',
                    subtitle: '回放、对照实验与可复核的证据导出。',
                    icon: Icons.science_rounded,
                    accent: LinanColors.purple,
                    actions: [
                      OutlinedButton.icon(
                        onPressed: exp == null ? null : () => _showJson('实验 JSON', exp),
                        icon: const Icon(Icons.code_rounded, size: 15),
                        label: const Text('查看 JSON'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _exportFeedback,
                        icon: const Icon(Icons.download_outlined, size: 15),
                        label: const Text('导出反馈'),
                      ),
                      FilledButton.icon(
                        onPressed: s.busy ? null : _runExperiments,
                        icon: const Icon(Icons.play_arrow_rounded, size: 16),
                        label: const Text('运行实验'),
                      ),
                    ],
                  ),
                  _scenarioSection(),
                  const SizedBox(height: 12),
                  _replaySection(),
                  if (exp != null) ...[
                    const SizedBox(height: 12),
                    _headlineStats(exp, wide),
                  ],
                  const SizedBox(height: 12),
                  _experimentSection(exp),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _scenarioSection() {
    return SectionCard(
      title: '情景回放',
      subtitle: '一键注入可复现的社区情景，观察风险判断与处置链路。使用当前虚拟档案。',
      icon: Icons.theaters_outlined,
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
                  child: Material(
                    color: LinanColors.surfaceAlt.withValues(alpha: .55),
                    borderRadius: BorderRadius.circular(LinanColors.rControl),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: s.busy ? null : () => _runScenario(sc.$1, sc.$2),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(14, 12, 14, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(sc.$2,
                                      style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: LinanColors.text)),
                                ),
                                Icon(Icons.play_circle_outline_rounded,
                                    size: 16, color: LinanColors.primary),
                              ],
                            ),
                            SizedBox(height: 4),
                            Text(sc.$3,
                                style: TextStyle(fontSize: 11, height: 1.5, color: LinanColors.muted)),
                          ],
                        ),
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
      icon: Icons.history_toggle_off_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 210,
                child: DropdownButtonFormField<int>(
                  key: ValueKey<int?>(elderId),
                  initialValue: elderId,
                  hint: const Text('暂无老人档案', style: TextStyle(fontSize: 12)),
                  decoration: const InputDecoration(labelText: '注入到老人', isDense: true),
                  items: [
                    for (final e in elders)
                      DropdownMenuItem(
                        value: e.id,
                        child: Text('${e.name} · ${e.building}', style: const TextStyle(fontSize: 12)),
                      ),
                  ],
                  onChanged: (v) => setState(() => _elderId = v),
                ),
              ),
              SizedBox(
                width: 160,
                child: TextFormField(
                  controller: _offsetCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '窗口偏移', isDense: true),
                  style: const TextStyle(fontSize: 12),
                  onChanged: (v) => _offset = int.tryParse(v.trim()) ?? 0,
                ),
              ),
              SizedBox(
                height: 40,
                child: FilledButton.icon(
                  onPressed: _replaying || elderId == null ? null : () => _replay(elderId),
                  icon: _replaying
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(Icons.replay_rounded, size: 15),
                  label: Text('回放该窗口'),
                ),
              ),
            ],
          ),
          if (_replayResult != null) ...[
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.fromLTRB(13, 11, 13, 11),
              decoration: BoxDecoration(
                color: LinanColors.tint(LinanColors.primary, .07),
                borderRadius: BorderRadius.circular(LinanColors.rControl),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: 15, color: LinanColors.primary),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '第 ${_replayResult!['offset'] ?? _offset} / ${_replayResult!['total'] ?? '?'} 窗口 · '
                          '15 分钟 ${_replayResult!['count15'] ?? '?'} 次 · 最长静止 ${_replayResult!['gap'] ?? '?'} 分钟',
                          style: TextStyle(fontSize: 12, height: 1.6, color: LinanColors.primaryDeep),
                        ),
                        if ('${_replayResult!['original_timestamp'] ?? ''}'.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(top: 3),
                            child: Text('原始时间：${_replayResult!['original_timestamp']}',
                                style: TextStyle(fontSize: 11, color: LinanColors.muted)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 用实验数据里的真实字段生成顶部指标块，不引入额外计算或虚构数据。
  Widget _headlineStats(Map<String, dynamic> exp, bool wide) {
    final activityRaw = exp['activity'];
    final activity = activityRaw is Map ? activityRaw : const {};
    final synthetic = activity['baseline'] is Map
        ? activity
        : (activity['synthetic'] is Map ? activity['synthetic'] as Map : const {});
    final casas = exp['casas'] is Map && (exp['casas'] as Map)['baseline'] is Map
        ? exp['casas'] as Map
        : (activity['casas'] is Map ? activity['casas'] as Map : const {});
    final picked = casas['baseline'] is Map ? casas : synthetic;
    final personalized = picked['personalized'] is Map ? picked['personalized'] as Map : const {};
    final scheduling = exp['scheduling'] is Map ? exp['scheduling'] as Map : const {};
    final optimized = scheduling['optimized'] is Map ? scheduling['optimized'] as Map : const {};
    final violations = optimized['constraint_violations'];
    final noViolation = violations is num && violations == 0;

    final source = identical(picked, casas) ? 'CASAS Aruba 真实数据' : '合成社区数据';
    final tiles = <Widget>[
      StatTile(
        label: '事件召回率',
        value: _metricText(personalized['injected_episode_recall'], true),
        note: '个性化方法 · $source',
        accent: LinanColors.primary,
        icon: Icons.track_changes_rounded,
      ),
      StatTile(
        label: '平均检测延迟',
        value: _metricText(personalized['mean_detection_delay_minutes'], false),
        unit: personalized['mean_detection_delay_minutes'] is num ? '分钟' : '',
        note: '报警率 ${_metricText(personalized['original_alarm_rate'], true)} · 窗口召回 '
            '${_metricText(personalized['injected_window_recall'], true)}',
        accent: LinanColors.amber,
        icon: Icons.timer_outlined,
      ),
      StatTile(
        label: '紧急 30 分钟覆盖',
        value: _metricText(optimized['urgent_covered_within_30_minutes'], true),
        note: '优化派单 · 20 任务 4 人',
        accent: LinanColors.green,
        icon: Icons.emergency_outlined,
      ),
      StatTile(
        label: '约束违反',
        value: _metricText(optimized['constraint_violations'], false),
        note: '技能、值班与容量校验',
        accent: noViolation ? LinanColors.green : LinanColors.danger,
        icon: Icons.rule_rounded,
      ),
    ];

    if (wide) {
      return Row(
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            Expanded(child: tiles[i]),
            if (i != tiles.length - 1) const SizedBox(width: 12),
          ],
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, c) {
        final two = c.maxWidth >= 560;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final t in tiles) SizedBox(width: two ? (c.maxWidth - 10) / 2 : c.maxWidth, child: t),
          ],
        );
      },
    );
  }

  Widget _experimentSection(Map<String, dynamic>? exp) {
    return SectionCard(
      title: '实验对照',
      subtitle: '所有数字来自本地真实运行；个性化方法的事件召回率低于固定阈值，是已知局限。',
      icon: Icons.compare_arrows_rounded,
      child: exp == null
          ? const EmptyHint('还没有实验结果，先运行一次或查看历史 JSON', icon: Icons.science_outlined)
          : _experimentTables(exp),
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
            padding: const EdgeInsets.only(bottom: 12),
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
            metrics: [
              ('mean_response_minutes', '平均响应（分钟）', false),
              ('p95_response_minutes', 'P95 响应（分钟）', false),
              ('urgent_mean_response_minutes', '紧急平均响应（分钟）', false),
              ('urgent_covered_within_30_minutes', '紧急 30 分钟覆盖', true),
              ('constraint_violations', '约束违反', false),
            ],
            note: '${scheduling['interpretation'] ?? ''}',
          ),
        SizedBox(height: 12),
        Container(
          padding: EdgeInsets.fromLTRB(13, 11, 13, 11),
          decoration: BoxDecoration(
            color: LinanColors.tint(LinanColors.teal, .08),
            borderRadius: BorderRadius.circular(LinanColors.rControl),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.model_training_rounded, size: 16, color: LinanColors.teal),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '模型只在本地离线训练与评估，不会自动替换在线模型；在线模型仍由管理员在设置中手动配置。',
                  style: TextStyle(fontSize: 11.5, height: 1.6, color: LinanColors.muted),
                ),
              ),
            ],
          ),
        ),
        if ('${exp['data_notice'] ?? ''}'.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text('数据说明：${exp['data_notice']}',
                style: TextStyle(fontSize: 11, height: 1.55, color: LinanColors.faint)),
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
      padding: EdgeInsets.fromLTRB(15, 13, 15, 13),
      decoration: BoxDecoration(
        color: LinanColors.surfaceAlt.withValues(alpha: .45),
        borderRadius: BorderRadius.circular(LinanColors.rControl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: LinanColors.text)),
          SizedBox(height: 8),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(2.2),
              1: FlexColumnWidth(1.4),
              2: FlexColumnWidth(1.4),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: LinanColors.border)),
                ),
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
                    _cell(_metricText(personalized[m.$1], m.$3), emphasized: true),
                  ],
                ),
            ],
          ),
          if (note.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 9),
              child: Text(note,
                  style: TextStyle(fontSize: 11, height: 1.6, color: LinanColors.muted)),
            ),
        ],
      ),
    );
  }

  Widget _cell(String text, {bool header = false, bool emphasized = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Text(
          text,
          style: TextStyle(
            fontSize: header ? 10.5 : 12,
            fontWeight: header ? FontWeight.w600 : (emphasized ? FontWeight.w600 : FontWeight.w400),
            color: header ? LinanColors.muted : (emphasized ? LinanColors.primaryDeep : LinanColors.text),
          ),
        ),
      );

  String _metricText(dynamic value, bool percent) {
    if (value is! num) return '—';
    if (percent) return '${(value * 100).toStringAsFixed(1)}%';
    // 计数类字段（如约束违反）是整数，不要显示成 0.00。
    if (value is int) return '$value';
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
      // 回放会推进窗口偏移，输入框是受控组件，需要同步显示后端返回的值。
      _offsetCtrl.text = '$_offset';
      await s.refresh();
    } on Object catch (e) {
      s.toast('$e');
    } finally {
      if (mounted) setState(() => _replaying = false);
    }
  }

  Future<void> _runExperiments() async {
    final ok = await confirmDialog(
      context,
      title: '运行对照实验',
      body: '将在本地重新生成活动与调度对照数据，可能需要一段时间；已有结果会被本次结果覆盖。',
      confirmText: '开始运行',
    );
    if (!ok || !mounted) return;
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
    final text = JsonEncoder.withIndent('  ').convert(data);
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 760, maxHeight: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 10, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(title,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: LinanColors.text)),
                    ),
                    IconButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: text));
                        s.toast('已复制到剪贴板');
                      },
                      icon: const Icon(Icons.copy_all_outlined, size: 17),
                      tooltip: '复制',
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      tooltip: '关闭',
                    ),
                  ],
                ),
              ),
              const Divider(height: .6),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(
                    text,
                    style: const TextStyle(fontSize: 11, height: 1.6, fontFamily: 'Consolas'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
