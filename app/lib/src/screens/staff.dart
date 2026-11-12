import 'package:flutter/material.dart';

import '../app_state.dart';
import '../labels.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

class StaffPage extends StatelessWidget {
  final AppState state;
  const StaffPage({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final admin = state.user?.isAdmin == true;
    final rows = admin ? state.staff : state.staff.where((s) => s.id == state.user?.staffId).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1240),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: LinanColors.primarySoft.withValues(alpha: .55),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: LinanColors.primary.withValues(alpha: .12)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 15, color: LinanColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        admin
                            ? '派单会同时校验技能、值班、可用性、楼栋与单任务容量；人员版本变化后，旧推荐会失效。'
                            : '你只能查看和维护自己的值班状态；任务范围也仅限本人。',
                        style: const TextStyle(fontSize: 10.5, color: LinanColors.primaryDeep, height: 1.6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (rows.isEmpty)
                const Padding(padding: EdgeInsets.only(top: 40), child: EmptyHint('没有人员记录'))
              else
                LayoutBuilder(
                  builder: (context, c) {
                    final cols = c.maxWidth >= 1100 ? 3 : (c.maxWidth >= 760 ? 2 : 1);
                    final gap = 12.0;
                    final width = (c.maxWidth - gap * (cols - 1)) / cols;
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        for (final p in rows)
                          SizedBox(
                            width: width,
                            child: _StaffCard(
                              key: ValueKey(p.id),
                              state: state,
                              staff: p,
                              editable: admin || p.id == state.user?.staffId,
                            ),
                          ),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StaffCard extends StatefulWidget {
  final AppState state;
  final Staff staff;
  final bool editable;

  const _StaffCard({super.key, required this.state, required this.staff, required this.editable});

  @override
  State<_StaffCard> createState() => _StaffCardState();
}

class _StaffCardState extends State<_StaffCard> {
  /// 请求进行中：禁用开关与下拉，避免重复 PUT。
  bool _saving = false;

  /// 乐观状态；null 表示跟随服务端返回的对象。
  bool? _onDuty;
  bool? _available;
  int? _location;

  bool get _duty => _onDuty ?? widget.staff.onDuty;
  bool get _accepting => _available ?? widget.staff.available;
  int get _building => _location ?? widget.staff.location;

  @override
  void didUpdateWidget(covariant _StaffCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 服务端数据发生变化（轮询、他人修改）时以服务端为准。
    final changed = widget.staff.onDuty != oldWidget.staff.onDuty ||
        widget.staff.available != oldWidget.staff.available ||
        widget.staff.location != oldWidget.staff.location;
    if (!_saving && changed) {
      _onDuty = null;
      _available = null;
      _location = null;
    }
  }

  /// 后端 WorkerUpdate 要求 on_duty / available / location 三字段齐全，
  /// 因此每次都从当前人员对象合并出完整载荷后整体提交。
  Future<void> _save({bool? onDuty, bool? available, int? location}) async {
    if (_saving) return;
    final nextDuty = onDuty ?? _duty;
    final nextAccepting = available ?? _accepting;
    final nextBuilding = location ?? _building;
    final unchanged = nextDuty == widget.staff.onDuty &&
        nextAccepting == widget.staff.available &&
        nextBuilding == widget.staff.location;
    if (unchanged) return;

    setState(() {
      _saving = true;
      _onDuty = nextDuty;
      _available = nextAccepting;
      _location = nextBuilding;
    });

    var ok = false;
    try {
      ok = await widget.state.updateStaff(
        widget.staff.id,
        onDuty: nextDuty,
        available: nextAccepting,
        location: nextBuilding,
      );
    } on Object {
      // updateStaff 约定不抛异常；这里兜底，避免异常导致开关永久禁用。
      ok = false;
    }

    if (!mounted) return;
    setState(() {
      _saving = false;
      if (!ok) {
        // 失败回滚到服务端状态，控件恢复可操作以便重试。
        _onDuty = null;
        _available = null;
        _location = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final staff = widget.staff;
    final editable = widget.editable;
    return SectionCard(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: LinanColors.primarySoft,
                child: Text(staff.name.characters.first,
                    style: const TextStyle(fontSize: 14, color: LinanColors.primary, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(staff.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: LinanColors.text)),
                    const SizedBox(height: 2),
                    Text('人员 #${staff.id} · $_building 号楼',
                        style: const TextStyle(fontSize: 9.5, color: LinanColors.muted)),
                  ],
                ),
              ),
              if (_saving)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.6)),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: staff.busy ? LinanColors.amber.withValues(alpha: .12) : LinanColors.green.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  staff.busy ? '执行中' : (_accepting ? '可接单' : '暂停接单'),
                  style: TextStyle(fontSize: 9.5, color: staff.busy ? LinanColors.amber : LinanColors.green, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [for (final skill in staff.skills) Tag(skillName(skill), color: LinanColors.primary, icon: Icons.verified_outlined)],
          ),
          const Divider(height: 20),
          _line(
            '值班状态',
            editable
                ? Switch(
                    value: _duty,
                    onChanged: _saving ? null : (v) => _save(onDuty: v),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  )
                : Text(_duty ? '值班中' : '未值班', style: const TextStyle(fontSize: 11)),
          ),
          _line(
            '接受新任务',
            editable
                ? Switch(
                    value: _accepting,
                    onChanged: _saving || !_duty ? null : (v) => _save(available: v),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  )
                : Text(_accepting ? '可接单' : '暂停', style: const TextStyle(fontSize: 11)),
          ),
          _line(
            '负责楼栋',
            editable
                ? DropdownButton<int>(
                    value: _building,
                    underline: const SizedBox.shrink(),
                    style: const TextStyle(fontSize: 11, color: LinanColors.text),
                    items: [
                      for (var i = 1; i <= 5; i++) DropdownMenuItem(value: i, child: Text('$i 号楼', style: const TextStyle(fontSize: 11))),
                    ],
                    onChanged: _saving ? null : (v) {
                      if (v != null) _save(location: v);
                    },
                  )
                : Text('$_building 号楼', style: const TextStyle(fontSize: 11)),
          ),
          const Divider(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  staff.activeTask == null ? '当前没有未关闭任务' : '执行中任务 #${staff.activeTask}',
                  style: const TextStyle(fontSize: 10, color: LinanColors.muted),
                ),
              ),
              if (staff.activeTask != null)
                TextButton(
                  onPressed: () => widget.state.selectPage('tasks'),
                  child: const Text('查看'),
                ),
            ],
          ),
          if (staff.id == widget.state.user?.staffId)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('这是你自己的服务身份；切换状态会立即影响可派单性。',
                  style: TextStyle(fontSize: 9, color: LinanColors.faint.withValues(alpha: .9), height: 1.5)),
            ),
        ],
      ),
    );
  }

  Widget _line(String label, Widget trailing) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(width: 82, child: Text(label, style: const TextStyle(fontSize: 10.5, color: LinanColors.muted))),
            Expanded(child: Align(alignment: Alignment.centerLeft, child: trailing)),
          ],
        ),
      );
}
