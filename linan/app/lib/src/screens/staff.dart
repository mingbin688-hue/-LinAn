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
                          SizedBox(width: width, child: _StaffCard(state: state, staff: p, editable: admin || p.id == state.user?.staffId)),
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

class _StaffCard extends StatelessWidget {
  final AppState state;
  final Staff staff;
  final bool editable;

  const _StaffCard({required this.state, required this.staff, required this.editable});

  @override
  Widget build(BuildContext context) {
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
                    Text('人员 #${staff.id} · ${staff.location} 号楼',
                        style: const TextStyle(fontSize: 9.5, color: LinanColors.muted)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: staff.busy ? LinanColors.amber.withValues(alpha: .12) : LinanColors.green.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  staff.busy ? '执行中' : (staff.available ? '可接单' : '暂停接单'),
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
                    value: staff.onDuty,
                    onChanged: (v) => state.updateStaff(staff.id, {'on_duty': v}),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  )
                : Text(staff.onDuty ? '值班中' : '未值班', style: const TextStyle(fontSize: 11)),
          ),
          _line(
            '接受新任务',
            editable
                ? Switch(
                    value: staff.available,
                    onChanged: staff.onDuty ? (v) => state.updateStaff(staff.id, {'available': v}) : null,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  )
                : Text(staff.available ? '可接单' : '暂停', style: const TextStyle(fontSize: 11)),
          ),
          _line(
            '负责楼栋',
            editable
                ? DropdownButton<int>(
                    value: staff.location,
                    underline: const SizedBox.shrink(),
                    style: const TextStyle(fontSize: 11, color: LinanColors.text),
                    items: [
                      for (var i = 1; i <= 5; i++) DropdownMenuItem(value: i, child: Text('$i 号楼', style: const TextStyle(fontSize: 11))),
                    ],
                    onChanged: (v) {
                      if (v != null) state.updateStaff(staff.id, {'location': v});
                    },
                  )
                : Text('${staff.location} 号楼', style: const TextStyle(fontSize: 11)),
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
                  onPressed: () => state.selectPage('tasks'),
                  child: const Text('查看'),
                ),
            ],
          ),
          if (staff.id == state.user?.staffId)
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
