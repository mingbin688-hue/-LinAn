import 'package:flutter/material.dart';

import '../api_client.dart';
import '../app_state.dart';
import '../labels.dart';
import '../models.dart';
import '../theme.dart';

const List<String> _reportKinds = [
  'safe',
  'contact',
  'sos',
  'missed_checkin',
  'activity',
  'away',
  'home',
  'rest',
  'need_help',
  'unreachable',
  'data_offline',
  'data_online',
];

Future<void> showReportDialog(BuildContext context, AppState state, {int? elderId}) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _ReportDialog(state: state, initialElderId: elderId),
  );
}

class _ReportDialog extends StatefulWidget {
  final AppState state;
  final int? initialElderId;

  const _ReportDialog({required this.state, this.initialElderId});

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  final _formKey = GlobalKey<FormState>();
  final _hours = TextEditingController(text: '2');
  final _count15 = TextEditingController();
  final _count60 = TextEditingController();
  final _gap = TextEditingController();
  int? _elderId;
  String _kind = 'safe';
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _elderId = _defaultElderId;
  }

  /// 默认老人：账号关联档案优先；家属/老人未绑定则留空（不能拿 elders.first 顶替，会 403）。
  int? get _defaultElderId {
    final state = widget.state;
    final user = state.user;
    final linked = state.elderFor(user);
    final preferred = widget.initialElderId ?? linked?.id;
    if (preferred != null && state.elders.any((e) => e.id == preferred)) {
      return preferred;
    }
    if (linked != null) return linked.id;
    if (user?.isCareSide ?? true) return null;
    return state.elders.isEmpty ? null : state.elders.first.id;
  }

  /// 下拉选项：列表里没有的关联档案也要补进去，否则 Dropdown 的值不在 items 中会报错。
  List<Elder> get _elderOptions {
    final list = List<Elder>.of(widget.state.elders);
    final linked = widget.state.elderFor(widget.state.user);
    if (linked != null && list.every((e) => e.id != linked.id)) {
      list.insert(0, linked);
    }
    return list;
  }

  @override
  void dispose() {
    _hours.dispose();
    _count15.dispose();
    _count60.dispose();
    _gap.dispose();
    super.dispose();
  }

  bool get _needsHours => _kind == 'away' || _kind == 'home' || _kind == 'rest';
  bool get _needsActivity => _kind == 'activity';

  Future<void> _submit() async {
    final elderId = _elderId;
    if (elderId == null) {
      setState(() => _error = '请先选择要上报的老人，或联系社区完成档案绑定');
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final payload = <String, dynamic>{};
    if (_needsHours) payload['hours'] = int.parse(_hours.text.trim());
    if (_needsActivity) {
      payload['count15'] = int.parse(_count15.text.trim());
      payload['count60'] = int.parse(_count60.text.trim());
      payload['gap'] = int.parse(_gap.text.trim());
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.state.reportEvent(elderId, _kind, payload);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = '上报失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final elders = _elderOptions;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 470),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('信息上报', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: LinanColors.text)),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, size: 17),
                      color: LinanColors.faint,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                Text('上报会立即进入风险判断；报平安、外出确认不会降低未关闭的紧急事件。',
                    style: TextStyle(fontSize: 11.5, color: LinanColors.muted, height: 1.6)),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: _elderId,
                  decoration: const InputDecoration(labelText: '老人'),
                  hint: const Text('尚未绑定老人', style: TextStyle(fontSize: 12)),
                  items: [
                    for (final e in elders)
                      DropdownMenuItem(value: e.id, child: Text('${e.name} · ${e.building}', style: const TextStyle(fontSize: 12))),
                  ],
                  onChanged: (v) => setState(() => _elderId = v ?? _elderId),
                ),
                if (_elderId == null)
                  Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      '当前账号尚未关联老人档案，请先选择老人或联系社区完成绑定后再上报。',
                      style: TextStyle(fontSize: 11.5, color: LinanColors.danger, height: 1.5),
                    ),
                  ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _kind,
                  decoration: const InputDecoration(labelText: '上报类型'),
                  items: [
                    for (final k in _reportKinds)
                      DropdownMenuItem(value: k, child: Text(kindName(k), style: const TextStyle(fontSize: 12))),
                  ],
                  onChanged: (v) => setState(() => _kind = v ?? 'safe'),
                ),
                if (_needsHours) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _hours,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 12.5),
                    decoration: const InputDecoration(labelText: '预计时长（小时，1–24）'),
                    validator: (v) {
                      final n = int.tryParse(v?.trim() ?? '');
                      if (n == null || n < 1 || n > 24) return '请输入 1–24 的整数';
                      return null;
                    },
                  ),
                ],
                if (_needsActivity) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _count15,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 12.5),
                          decoration: const InputDecoration(labelText: '15 分钟活动次数'),
                          validator: (v) => int.tryParse(v?.trim() ?? '') == null ? '必填' : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _count60,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 12.5),
                          decoration: const InputDecoration(labelText: '60 分钟累计'),
                          validator: (v) {
                            final n = int.tryParse(v?.trim() ?? '');
                            final m = int.tryParse(_count15.text.trim());
                            if (n == null) return '必填';
                            if (m != null && n < m) return '需 ≥ 15 分钟值';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _gap,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 12.5),
                          decoration: const InputDecoration(labelText: '静止时长（分）'),
                          validator: (v) => int.tryParse(v?.trim() ?? '') == null ? '必填' : null,
                        ),
                      ),
                    ],
                  ),
                ],
                if (_error != null) ...[
                  SizedBox(height: 10),
                  Text(_error!, style: TextStyle(fontSize: 11, color: LinanColors.danger)),
                ],
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: const Text('取消')),
                    const SizedBox(width: 6),
                    FilledButton(
                      onPressed: (_saving || _elderId == null) ? null : _submit,
                      child: _saving
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.6, color: Colors.white))
                          : const Text('提交上报'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
