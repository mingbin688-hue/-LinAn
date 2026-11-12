import 'package:flutter/material.dart';

import '../app_state.dart';
import '../labels.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// 家属 / 老人本人视角：只展示关联档案，操作以「报平安 / 请求联系 / 求助」为主。
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

    return LayoutBuilder(
      builder: (context, shell) {
        // 家属端内容较少，控制在 860 的阅读宽度内，避免宽屏上文字被拉得过长。
        final side = shell.maxWidth > 908 ? (shell.maxWidth - 860) / 2 : 24.0;
        final header = PageHeader(
          title: elder == null ? '我的照护档案' : '$_greeting，${elder.name}',
          subtitle: elder == null
              ? '这个页面只显示与你账号关联的老人档案和记录。'
              : '${elder.building} · 梧桐里社区 · ${elder.online ? '设备在线' : '设备离线'}',
          icon: Icons.volunteer_activism_outlined,
          accent: LinanColors.green,
          padding: EdgeInsets.fromLTRB(side, 22, side, 14),
        );

        if (elder == null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(side, 0, side, 28),
                  child: _notBound(),
                ),
              ),
            ],
          );
        }

        final records = state.incidents.take(8).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(side, 0, side, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _statusCard(elder),
                    SizedBox(height: 14),
                    _primaryActions(context, elder),
                    SizedBox(height: 14),
                    SectionCard(
                      title: '告诉社区你的安排',
                      subtitle: '外出、在家或休息，可以解释活动变化，但不会关掉未处理的紧急事件。',
                      icon: Icons.edit_calendar_outlined,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _secondary(context, elder, 'away', '我要外出', Icons.directions_walk_rounded, LinanColors.warm),
                          _secondary(context, elder, 'home', '我已到家', Icons.home_outlined, LinanColors.green),
                          _secondary(context, elder, 'rest', '我准备休息', Icons.bed_outlined, LinanColors.muted),
                        ],
                      ),
                    ),
                    SizedBox(height: 14),
                    SectionCard(
                      title: '最近状态记录',
                      subtitle: '社区能看到你上报的信息，也能看到系统判断的依据。',
                      icon: Icons.history_rounded,
                      child: records.isEmpty
                          ? EmptyHint('最近没有需要记录的变化', icon: Icons.spa_outlined)
                          : Column(
                              children: [
                                for (var i = 0; i < records.length; i++)
                                  ListRow(
                                    leading: IconTile(
                                      _recordIcon(records[i]),
                                      color: records[i].open ? LevelStyle.of(records[i].level).fg : LinanColors.muted,
                                      size: 30,
                                      iconSize: 15,
                                    ),
                                    title: records[i].title,
                                    subtitle: records[i].evidence.isEmpty ? null : records[i].evidence.first,
                                    trailing: Text(formatStamp(records[i].updated),
                                        style: TextStyle(fontSize: 11.5, color: LinanColors.faint)),
                                    showDivider: i != records.length - 1,
                                  ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 14),
                    _privacyNote(),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  IconData _recordIcon(Incident r) {
    if (!r.open) return Icons.check_rounded;
    if (r.level >= 2) return Icons.warning_amber_rounded;
    if (r.level >= 1) return Icons.visibility_outlined;
    return Icons.info_outline_rounded;
  }

  /// 大号状态卡：等级 + 最近一次风险事件。
  Widget _statusCard(Elder elder) {
    final style = LevelStyle.of(elder.level);
    final urgent = elder.level >= 2;
    final message = urgent
        ? '社区已收到需要关注的信号，工作人员会尽快联系你。'
        : '一切正常。如果有任何不舒服或需要帮忙，点下面的按钮就好。';
    return SectionCard(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 18),
      border: urgent ? Border.all(color: style.fg.withValues(alpha: .22)) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconTile(_levelIcon(elder.level), color: style.fg, size: 44, iconSize: 22),
              SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('当前状态', style: TextStyle(fontSize: 11.5, color: LinanColors.faint)),
                    SizedBox(height: 2),
                    Text(levelName(elder.level),
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700, color: style.fg, letterSpacing: -.3)),
                  ],
                ),
              ),
              LevelPill(elder.level),
            ],
          ),
          SizedBox(height: 13),
          Text(message, style: TextStyle(fontSize: 12.5, height: 1.7, color: LinanColors.muted)),
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: LinanColors.surfaceAlt,
              borderRadius: BorderRadius.circular(LinanColors.rControl),
            ),
            child: Row(
              children: [
                Icon(Icons.history_toggle_off_rounded, size: 14, color: LinanColors.faint),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    elder.latestIncident ?? '最近没有新的风险事件',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, height: 1.5, color: LinanColors.text),
                  ),
                ),
                SizedBox(width: 8),
                Text('累计关注 ${elder.incidentCount} 次',
                    style: TextStyle(fontSize: 11.5, color: LinanColors.faint)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _levelIcon(int level) {
    if (level >= 3) return Icons.crisis_alert_rounded;
    if (level >= 2) return Icons.priority_high_rounded;
    if (level >= 1) return Icons.visibility_outlined;
    if (level == 0) return Icons.help_outline_rounded;
    return Icons.check_circle_outline_rounded;
  }

  Widget _primaryActions(BuildContext context, Elder elder) {
    final buttons = [
      _actionButton(context, elder,
          kind: 'safe',
          label: '我很平安',
          note: '让社区放心',
          icon: Icons.favorite_outline_rounded,
          color: LinanColors.green,
          filled: true),
      _actionButton(context, elder,
          kind: 'contact',
          label: '请联系我',
          note: '想和社区说说话',
          icon: Icons.phone_outlined,
          color: LinanColors.warm,
          filled: false),
      _actionButton(context, elder,
          kind: 'sos',
          label: '我需要帮助',
          note: '立即通知工作人员',
          icon: Icons.emergency_outlined,
          color: LinanColors.danger,
          filled: true),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 520) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < buttons.length; i++) ...[
                if (i > 0) const SizedBox(height: 9),
                buttons[i],
              ],
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < buttons.length; i++) ...[
              if (i > 0) const SizedBox(width: 9),
              Expanded(child: buttons[i]),
            ],
          ],
        );
      },
    );
  }

  Widget _actionButton(
    BuildContext context,
    Elder elder, {
    required String kind,
    required String label,
    required String note,
    required IconData icon,
    required Color color,
    required bool filled,
  }) {
    Future<void> onTap() => _submit(context, elder, kind, label);
    final content = Row(
      children: [
        Icon(icon, size: 21, color: filled ? Colors.white : color),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, color: filled ? Colors.white : color)),
              const SizedBox(height: 2),
              Text(note,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11.5, color: filled ? Colors.white.withValues(alpha: .82) : LinanColors.muted)),
            ],
          ),
        ),
      ],
    );
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
    return SizedBox(
      height: 62,
      child: filled
          ? FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 15),
                shape: shape,
              ),
              child: content,
            )
          : OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                backgroundColor: LinanColors.tint(color, .1),
                foregroundColor: color,
                side: BorderSide(color: LinanColors.tint(color, .3)),
                padding: const EdgeInsets.symmetric(horizontal: 15),
                shape: shape,
              ),
              child: content,
            ),
    );
  }

  Widget _secondary(BuildContext context, Elder elder, String kind, String label, IconData icon, Color color) {
    return OutlinedButton.icon(
      onPressed: () => _submit(context, elder, kind, label),
      icon: Icon(icon, size: 15, color: color),
      label: Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: color)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        backgroundColor: LinanColors.tint(color, .08),
        side: BorderSide(color: LinanColors.tint(color, .28)),
      ),
    );
  }

  Widget _privacyNote() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: LinanColors.surfaceAlt,
          borderRadius: BorderRadius.circular(LinanColors.rControl),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_outline_rounded, size: 14, color: LinanColors.muted),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '你只能看到与自己关联的档案和记录。需要联系家属时，请让社区工作人员协助。',
                style: TextStyle(fontSize: 11, height: 1.6, color: LinanColors.muted),
              ),
            ),
          ],
        ),
      );

  /// 家属/老人账号没有关联档案时显示空态，不拿 elders.first 顶替（会看到别人的数据或直接崩溃）。
  Widget _notBound() {
    return SectionCard(
      title: '我的照护档案',
      subtitle: '这个页面只显示与你账号关联的老人档案和记录。',
      icon: Icons.badge_outlined,
      child: Column(
        children: [
          const EmptyHint('尚未绑定老人档案', icon: Icons.badge_outlined),
          const SizedBox(height: 4),
          Text(
            '请联系社区工作人员确认账号与老人档案的关联；绑定后即可上报状态、查看记录。',
            style: TextStyle(fontSize: 11.5, height: 1.6, color: LinanColors.muted),
            textAlign: TextAlign.center,
          ),
        ],
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
