import 'package:flutter/material.dart';

import '../app_state.dart';
import '../labels.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

class CarePage extends StatelessWidget {
  final AppState state;
  const CarePage({super.key, required this.state});

  int get _hour => DateTime.now().hour;

  String get _greeting {
    if (_hour < 6) return '夜深了';
    if (_hour < 11) return '早上好';
    if (_hour < 14) return '中午好';
    if (_hour < 18) return '下午好';
    return '晚上好';
  }

  @override
  Widget build(BuildContext context) {
    // 家属/老人账号必须用关联档案，不能靠 elders 列表顺序。
    final elder = state.elderFor(state.user);
    if (elder == null) return _notBound();
    final records = state.incidents.take(8).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1F5C4A), Color(0xFF143F33)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$_greeting，${elder.name}',
                        style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600, color: Colors.white)),
                    const SizedBox(height: 5),
                    Text(
                      '${elder.building} · 梧桐里社区 · ${elder.online ? '设备在线' : '设备离线'}',
                      style: const TextStyle(fontSize: 11, color: Color(0xCCE8F1EA)),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      elder.level >= 2
                          ? '社区已收到需要关注的信号，工作人员会尽快联系你。'
                          : '一切正常。如果有任何不舒服或需要帮忙，点下面的按钮就好。',
                      style: const TextStyle(fontSize: 11.5, height: 1.7, color: Color(0xDDEAF2EC)),
                    ),
                    const SizedBox(height: 18),
                    _primaryActions(context, elder),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: '告诉社区你的安排',
                subtitle: '外出、在家或休息，可以解释活动变化，但不会关掉未处理的紧急事件。',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _secondary(context, elder, 'away', '我要外出', Icons.directions_walk, LinanColors.warm),
                    _secondary(context, elder, 'home', '我已到家', Icons.home_outlined, LinanColors.green),
                    _secondary(context, elder, 'rest', '我准备休息', Icons.bed_outlined, LinanColors.muted),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: '最近状态记录',
                subtitle: '社区能看到你上报的信息，也能看到系统判断的依据。',
                child: records.isEmpty
                    ? const EmptyHint('最近没有需要记录的变化', icon: Icons.spa_outlined)
                    : Column(
                        children: [
                          for (final r in records)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Dot(
                                      r.open ? LevelStyle.of(r.level).fg : LinanColors.border,
                                      size: 6,
                                    ),
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(r.title, style: const TextStyle(fontSize: 11.5, height: 1.5)),
                                        if (r.evidence.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 2),
                                            child: Text(r.evidence.first,
                                                style: const TextStyle(fontSize: 9.5, height: 1.5, color: LinanColors.muted)),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(formatStamp(r.updated), style: const TextStyle(fontSize: 9, color: LinanColors.faint)),
                                ],
                              ),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: LinanColors.surfaceAlt, borderRadius: BorderRadius.circular(10)),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lock_outline, size: 14, color: LinanColors.muted),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '你只能看到与自己关联的档案和记录。需要联系家属时，请让社区工作人员协助。',
                        style: TextStyle(fontSize: 9.5, height: 1.6, color: LinanColors.muted),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 家属/老人账号没有关联档案时显示空态，不拿 elders.first 顶替（会看到别人的数据或直接崩溃）。
  Widget _notBound() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: SectionCard(
            title: '我的照护档案',
            subtitle: '这个页面只显示与你账号关联的老人档案和记录。',
            child: Column(
              children: [
                const EmptyHint('尚未绑定老人档案', icon: Icons.badge_outlined),
                const SizedBox(height: 4),
                Text(
                  '请联系社区工作人员确认账号与老人档案的关联；绑定后即可上报状态、查看记录。',
                  style: const TextStyle(fontSize: 10, height: 1.6, color: LinanColors.muted),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _primaryActions(BuildContext context, Elder? elder) {
    return LayoutBuilder(
      builder: (context, c) {
        final narrow = c.maxWidth < 520;
        final buttons = [
          _bigAction(context, elder, 'safe', '我很平安', '让社区放心', Icons.favorite_outline, const Color(0xFFEAF3EC), const Color(0xFF2E6B4F)),
          _bigAction(context, elder, 'contact', '请联系我', '想和社区说说话', Icons.phone_outlined, const Color(0xFFFFF4E2), const Color(0xFF8A5A1E)),
          _bigAction(context, elder, 'sos', '我需要帮助', '立即通知工作人员', Icons.emergency_outlined, const Color(0xFFFFECE9), const Color(0xFFB23A2E)),
        ];
        if (narrow) {
          return Column(
            children: [
              for (var i = 0; i < buttons.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                SizedBox(width: double.infinity, child: buttons[i]),
              ],
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < buttons.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: buttons[i]),
            ],
          ],
        );
      },
    );
  }

  Widget _bigAction(
    BuildContext context,
    Elder? elder,
    String kind,
    String label,
    String note,
    IconData icon,
    Color bg,
    Color fg,
  ) {
    return InkWell(
      onTap: elder == null ? null : () => _submit(context, elder, kind, label),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: fg),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: fg)),
            const SizedBox(height: 2),
            Text(note, style: TextStyle(fontSize: 9.5, color: fg.withValues(alpha: .75))),
          ],
        ),
      ),
    );
  }

  Widget _secondary(BuildContext context, Elder? elder, String kind, String label, IconData icon, Color color) {
    return OutlinedButton.icon(
      onPressed: elder == null ? null : () => _submit(context, elder, kind, label),
      icon: Icon(icon, size: 15, color: color),
      label: Text(label, style: TextStyle(fontSize: 11, color: color)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        side: BorderSide(color: color.withValues(alpha: .25)),
      ),
    );
  }

  Future<void> _submit(BuildContext context, Elder elder, String kind, String label) async {
    final urgent = kind == 'sos';
    final ok = await confirmDialog(
      context,
      title: urgent ? '立即求助' : label,
      body: urgent
          ? '社区会立即收到紧急求助，并安排工作人员上门或电话核实。确定现在发送吗？'
          : '将向社区上报「$label」，工作人员会看到这条记录。',
      confirmText: kind == 'safe' ? '报平安' : '确认发送',
      danger: urgent,
    );
    if (!ok || !context.mounted) return;
    final payload = <String, dynamic>{};
    if (kind == 'away') {
      final hours = await _askHours(context);
      if (hours == null) return;
      payload['hours'] = hours;
    } else if (kind == 'rest') {
      payload['hours'] = 8;
    }
    try {
      await state.reportEvent(elder.id, kind, payload);
    } on Object catch (e) {
      state.toast('$e');
    }
  }

  Future<int?> _askHours(BuildContext context) {
    return showDialog<int>(
      context: context,
      builder: (_) => _HoursDialog(state: state),
    );
  }
}

/// 外出时长输入；控制器由 State 持有并在 dispose 释放，取消和确认都不会泄漏。
class _HoursDialog extends StatefulWidget {
  final AppState state;
  const _HoursDialog({required this.state});

  @override
  State<_HoursDialog> createState() => _HoursDialogState();
}

class _HoursDialogState extends State<_HoursDialog> {
  late final TextEditingController _controller = TextEditingController(text: '2');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final h = int.tryParse(_controller.text.trim());
    if (h == null || h < 1 || h > 24) {
      widget.state.toast('请输入 1–24 之间的小时数');
      return;
    }
    Navigator.of(context).pop(h);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('大概外出多久？', style: TextStyle(fontSize: 15)),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        autofocus: true,
        onSubmitted: (_) => _confirm(),
        decoration: const InputDecoration(labelText: '小时（1–24）', isDense: true),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消')),
        FilledButton(onPressed: _confirm, child: const Text('确定')),
      ],
    );
  }
}
