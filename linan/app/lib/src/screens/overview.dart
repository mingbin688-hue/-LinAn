import 'package:flutter/material.dart';

import '../app_state.dart';
import '../labels.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/report_dialog.dart';

class OverviewPage extends StatelessWidget {
  final AppState state;
  const OverviewPage({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final watched = state.watchedElders;
    final urgent = state.openIncidents.where((i) => i.level >= 2).length;
    final pendingTasks = state.tasks.where((t) => t.state == 'pending' || t.state == 'dispatched').length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(wide ? 26 : 16, 20, wide ? 26 : 16, 30),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1240),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Hero(
                    state: state,
                    watched: watched.length,
                    urgent: urgent,
                  ),
                  const SizedBox(height: 14),
                  _stats(wide, state, urgent, pendingTasks),
                  const SizedBox(height: 14),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 7, child: _attention(context)),
                        const SizedBox(width: 14),
                        Expanded(flex: 5, child: Column(children: [_team(context), const SizedBox(height: 14), _loop(context)])),
                      ],
                    )
                  else ...[
                    _attention(context),
                    const SizedBox(height: 14),
                    _team(context),
                    const SizedBox(height: 14),
                    _loop(context),
                  ],
                  const SizedBox(height: 14),
                  _activity(context, wide),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _stats(bool wide, AppState state, int urgent, int pendingTasks) {
    final tiles = [
      StatTile(
        label: '老人档案',
        value: '${state.elders.length}',
        unit: '位',
        note: '在线 ${state.elders.where((e) => e.online).length} 位 · 数据未知 ${state.elders.where((e) => e.dataUnknown).length} 位',
        accent: LinanColors.green,
      ),
      StatTile(
        label: '未关闭事件',
        value: '${state.openIncidents.length}',
        unit: '条',
        note: urgent > 0 ? '优先/紧急 $urgent 条需要处置' : '暂无优先或紧急事件',
        accent: urgent > 0 ? LinanColors.danger : LinanColors.green,
      ),
      StatTile(
        label: '处置任务',
        value: '${state.activeTasks.length}',
        unit: '项',
        note: '待确认或待接单 $pendingTasks 项',
        accent: LinanColors.amber,
      ),
      StatTile(
        label: '可用照护力量',
        value: '${state.availableCount}',
        unit: '人',
        note: '值班 ${state.onDutyStaff.length} 人 · 人员总数 ${state.staff.length} 人',
        accent: LinanColors.primary,
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
            for (final t in tiles)
              SizedBox(width: two ? (c.maxWidth - 10) / 2 : c.maxWidth, child: t),
          ],
        );
      },
    );
  }

  Widget _attention(BuildContext context) {
    final rows = state.watchedElders.take(5).toList();
    return SectionCard(
      title: '需要多看一眼的老人',
      subtitle: '按未关闭事件等级排序；等级来自规则与模型，不由对话生成',
      trailing: TextButton(
        onPressed: () => state.selectPage('elders'),
        child: const Text('全部档案'),
      ),
      child: rows.isEmpty
          ? const EmptyHint('当前没有需要重点关注的对象', icon: Icons.verified_outlined)
          : Column(
              children: [
                for (final e in rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: InkWell(
                      onTap: () => state.selectPage('elders'),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
                        child: Row(
                          children: [
                            LevelPill(e.level),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(e.name, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: LinanColors.text)),
                                      const SizedBox(width: 6),
                                      Text('${e.age} 岁 · ${e.building}',
                                          style: const TextStyle(fontSize: 10, color: LinanColors.faint)),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    e.evidence.isEmpty ? (e.latestIncident ?? '等待最新状态') : e.evidence.first,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 10.5, color: LinanColors.muted),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              e.dataUnknown ? '数据未知' : (e.online ? '在线' : '离线'),
                              style: TextStyle(fontSize: 9.5, color: e.dataUnknown ? LinanColors.warm : LinanColors.faint),
                            ),
                            const Icon(Icons.chevron_right, size: 15, color: LinanColors.border),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _team(BuildContext context) {
    final rows = state.onDutyStaff.isEmpty ? state.staff : state.onDutyStaff;
    return SectionCard(
      title: '协同照护力量',
      subtitle: '值班、技能与容量在派单时一并校验',
      trailing: TextButton(onPressed: () => state.selectPage('staff'), child: const Text('人员资源')),
      child: rows.isEmpty
          ? const EmptyHint('还没有人员记录')
          : Column(
              children: [
                for (final p in rows.take(5))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 13,
                          backgroundColor: LinanColors.surfaceAlt,
                          child: Text(p.name.characters.first,
                              style: const TextStyle(fontSize: 10.5, color: LinanColors.primary, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.name, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: LinanColors.text)),
                              Text(
                                '${p.location} 号楼 · ${p.skills.map(skillName).join(' / ')}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 9.5, color: LinanColors.muted),
                              ),
                            ],
                          ),
                        ),
                        Tag(
                          p.busy ? '执行中' : (p.available ? '可接单' : '暂停接单'),
                          color: p.busy ? LinanColors.amber : (p.available ? LinanColors.green : LinanColors.muted),
                        ),
                        const SizedBox(width: 6),
                        Dot(p.onDuty ? LinanColors.green : LinanColors.border),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _loop(BuildContext context) {
    const steps = [
      ('感知', '活动窗口、报平安、SOS 与外部数据源'),
      ('判断', '规则优先分级；未知就是未知'),
      ('调度', '按优先级与技能匹配；管理员确认'),
      ('复核', '反馈必须留痕；关闭需要人工核实'),
    ];
    return SectionCard(
      title: '守护闭环',
      subtitle: 'DECISION LOOP · 每一步都留痕',
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 21,
                    height: 21,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: LinanColors.primarySoft,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('${i + 1}', style: const TextStyle(fontSize: 9.5, color: LinanColors.primary, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(steps[i].$1, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: LinanColors.text)),
                        const SizedBox(height: 2),
                        Text(steps[i].$2, style: const TextStyle(fontSize: 9.5, color: LinanColors.muted, height: 1.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _activity(BuildContext context, bool wide) {
    final rows = [...state.elders]..sort((a, b) => b.count15.compareTo(a.count15));
    final top = rows.take(wide ? 20 : 12).toList();
    final maxCount = rows.isEmpty ? 1 : rows.map((e) => e.count15).reduce((a, b) => a > b ? a : b);
    return SectionCard(
      title: '15 分钟活动感知',
      subtitle: '每根柱子是一位老人的最近窗口；颜色对应未关闭事件等级',
      trailing: Text(
        '最大 $maxCount 次 · 更新于 ${formatStamp(state.lastUpdated?.millisecondsSinceEpoch == null ? null : state.lastUpdated!.millisecondsSinceEpoch ~/ 1000)}',
        style: const TextStyle(fontSize: 9.5, color: LinanColors.faint),
      ),
      child: top.isEmpty
          ? const EmptyHint('还没有活动窗口数据')
          : SizedBox(
              height: 132,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (final e in top)
                            Tooltip(
                              message: '${e.name}\n15 分钟 ${e.count15} 次 · 60 分钟 ${e.count60} 次\n静止 ${e.gap} 分钟',
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text('${e.count15}',
                                        style: const TextStyle(fontSize: 8.5, color: LinanColors.faint)),
                                    const SizedBox(height: 3),
                                    Container(
                                      width: wide ? 20 : 16,
                                      height: (88 * (e.count15 / (maxCount == 0 ? 1 : maxCount))).clamp(3, 88),
                                      decoration: BoxDecoration(
                                        color: LevelStyle.of(e.level).fg.withValues(alpha: e.level > 0 ? .9 : .28),
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final e in top)
                          SizedBox(
                            width: wide ? 28 : 24,
                            child: Text(
                              e.name.characters.take(3).toString(),
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 8.5, color: LinanColors.muted),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _Hero extends StatelessWidget {
  final AppState state;
  final int watched;
  final int urgent;

  const _Hero({required this.state, required this.watched, required this.urgent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 22, 22, 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E5F4C), Color(0xFF143F33)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 720;
          final left = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('TODAY\'S WATCH', style: TextStyle(fontSize: 8.5, letterSpacing: 2, color: Color(0xFF8FB9A4))),
              const SizedBox(height: 8),
              Text(
                watched == 0 ? '今天的守护状态平稳' : '今天有 $watched 位老人需要多看一眼',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: wide ? 26 : 21,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                urgent > 0
                    ? '其中 $urgent 条优先/紧急事件等待处置。SOS 直接进入紧急人工处理，报平安不会降低未关闭事件。'
                    : '暂未出现优先或紧急事件。规则与模型仍在持续判断，未知数据会被如实标记。',
                style: const TextStyle(color: Color(0xFFC3DACD), fontSize: 11, height: 1.8),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 9,
                runSpacing: 8,
                children: [
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFF2F7EF),
                      foregroundColor: LinanColors.primaryDeep,
                    ),
                    onPressed: () => state.selectPage('tasks'),
                    child: const Text('查看派单建议'),
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withValues(alpha: .32)),
                    ),
                    onPressed: () => showReportDialog(context, state),
                    child: const Text('上报一条信息'),
                  ),
                ],
              ),
            ],
          );

          final right = Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: .1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('数据与判断', style: TextStyle(fontSize: 9.5, color: Color(0xFFA8C7B7), letterSpacing: .6)),
                const SizedBox(height: 8),
                _heroRow('活动数据', '${state.elders.where((e) => e.online).length} / ${state.elders.length} 位在线'),
                _heroRow('风险规则', 'risk-rules-v1 · 规则优先'),
                _heroRow('对话模式', modeName('${state.agentsInfo['mode'] ?? 'rules'}')),
                _heroRow('派单方式', state.autoDispatch ? '自动派单（仅 1 级电话核实）' : '管理员逐单确认'),
              ],
            ),
          );

          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: left),
                const SizedBox(width: 22),
                SizedBox(width: 240, child: right),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [left, const SizedBox(height: 16), right],
          );
        },
      ),
    );
  }

  Widget _heroRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        children: [
          SizedBox(width: 58, child: Text(label, style: const TextStyle(fontSize: 9.5, color: Color(0xFF94B7A5)))),
          Expanded(
            child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
