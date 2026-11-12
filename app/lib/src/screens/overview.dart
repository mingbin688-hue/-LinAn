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
          padding: EdgeInsets.fromLTRB(wide ? 28 : 16, 0, wide ? 28 : 16, 34),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1240),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PageHeader(
                    title: '守护总览',
                    subtitle: '${formatToday()} · 虚拟社区运行状态一屏掌握',
                    icon: Icons.space_dashboard_rounded,
                    actions: [
                      OutlinedButton.icon(
                        onPressed: () => state.refresh(),
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('刷新'),
                      ),
                    ],
                  ),
                  _Hero(state: state, watched: watched.length, urgent: urgent),
                  const SizedBox(height: 16),
                  _stats(wide, urgent, pendingTasks),
                  const SizedBox(height: 16),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 7, child: _attention(context)),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 5,
                          child: Column(
                            children: [
                              _team(context),
                              const SizedBox(height: 16),
                              _loop(context),
                            ],
                          ),
                        ),
                      ],
                    )
                  else ...[
                    _attention(context),
                    const SizedBox(height: 16),
                    _team(context),
                    const SizedBox(height: 16),
                    _loop(context),
                  ],
                  const SizedBox(height: 16),
                  _activity(context, wide),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _stats(bool wide, int urgent, int pendingTasks) {
    final tiles = [
      StatTile(
        label: '老人档案',
        value: '${state.elders.length}',
        unit: '位',
        note: '在线 ${state.elders.where((e) => e.online).length} 位 · 数据未知 ${state.elders.where((e) => e.dataUnknown).length} 位',
        accent: LinanColors.green,
        icon: Icons.elderly_rounded,
      ),
      StatTile(
        label: '未关闭事件',
        value: '${state.openIncidents.length}',
        unit: '条',
        note: urgent > 0 ? '优先/紧急 $urgent 条需要处置' : '暂无优先或紧急事件',
        accent: urgent > 0 ? LinanColors.danger : LinanColors.green,
        icon: Icons.warning_amber_rounded,
      ),
      StatTile(
        label: '处置任务',
        value: '${state.activeTasks.length}',
        unit: '项',
        note: '待确认或待接单 $pendingTasks 项',
        accent: LinanColors.amber,
        icon: Icons.checklist_rounded,
      ),
      StatTile(
        label: '可用照护力量',
        value: '${state.availableCount}',
        unit: '人',
        note: '值班 ${state.onDutyStaff.length} 人 · 人员总数 ${state.staff.length} 人',
        accent: LinanColors.primary,
        icon: Icons.groups_rounded,
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
    final rows = state.watchedElders.take(6).toList();
    return SectionCard(
      title: '需要多看一眼的老人',
      subtitle: '按未关闭事件等级排序；等级来自规则与模型，不由对话生成',
      icon: Icons.visibility_rounded,
      trailing: TextButton(
        onPressed: () => state.selectPage('elders'),
        child: const Text('全部档案'),
      ),
      child: rows.isEmpty
          ? const EmptyHint('当前没有需要重点关注的对象', icon: Icons.verified_rounded)
          : Column(
              children: [
                for (var i = 0; i < rows.length; i++)
                  ListRow(
                    leading: _Avatar(name: rows[i].name),
                    title: rows[i].name,
                    subtitle: '${rows[i].age} 岁 · ${rows[i].building} · '
                        '${rows[i].evidence.isEmpty ? (rows[i].latestIncident ?? '等待最新状态') : rows[i].evidence.first}',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        LevelPill(rows[i].level, compact: true),
                        const SizedBox(width: 8),
                        Tag(
                          rows[i].dataUnknown ? '数据未知' : (rows[i].online ? '在线' : '离线'),
                          color: rows[i].dataUnknown
                              ? LinanColors.warm
                              : (rows[i].online ? LinanColors.green : LinanColors.faint),
                        ),
                      ],
                    ),
                    onTap: () => state.selectPage('elders'),
                    showChevron: true,
                    showDivider: i != rows.length - 1,
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
      icon: Icons.groups_rounded,
      trailing: TextButton(onPressed: () => state.selectPage('staff'), child: const Text('人员资源')),
      child: rows.isEmpty
          ? const EmptyHint('还没有人员记录', icon: Icons.person_off_rounded)
          : Column(
              children: [
                for (var i = 0; i < rows.take(5).length; i++)
                  ListRow(
                    leading: _Avatar(name: rows[i].name, small: true),
                    title: rows[i].name,
                    subtitle: '${rows[i].location} 号楼 · ${rows[i].skills.map(skillName).join(' / ')}',
                    trailing: Tag(
                      rows[i].busy ? '执行中' : (rows[i].available ? '可接单' : '暂停接单'),
                      color: rows[i].busy
                          ? LinanColors.amber
                          : (rows[i].available ? LinanColors.green : LinanColors.muted),
                    ),
                    showDivider: i != rows.take(5).length - 1,
                  ),
              ],
            ),
    );
  }

  Widget _loop(BuildContext context) {
    final steps = [
      (Icons.sensors_rounded, '感知', '活动窗口、报平安、SOS 与外部数据源'),
      (Icons.rule_rounded, '判断', '规则优先分级；未知就是未知'),
      (Icons.route_rounded, '调度', '按优先级与技能匹配；管理员确认'),
      (Icons.fact_check_rounded, '复核', '反馈必须留痕；关闭需要人工核实'),
    ];
    return SectionCard(
      title: '守护闭环',
      subtitle: '每一步都留痕',
      icon: Icons.loop_rounded,
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconTile(steps[i].$1, size: 30, iconSize: 16, color: i == 3 ? LinanColors.green : LinanColors.primary),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${i + 1}. ${steps[i].$2}',
                            style: TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.w600, color: LinanColors.text)),
                        SizedBox(height: 2),
                        Text(steps[i].$3,
                            style: TextStyle(fontSize: 11, color: LinanColors.muted, height: 1.5)),
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
    final top = rows.take(wide ? 24 : 12).toList();
    final maxCount = rows.isEmpty ? 1 : rows.map((e) => e.count15).reduce((a, b) => a > b ? a : b);
    return SectionCard(
      title: '15 分钟活动感知',
      subtitle: '每根柱子是一位老人的最近窗口；颜色对应未关闭事件等级',
      icon: Icons.bar_chart_rounded,
      trailing: Text(
        '最大 $maxCount 次 · 更新于 ${formatStamp(state.lastUpdated?.millisecondsSinceEpoch == null ? null : state.lastUpdated!.millisecondsSinceEpoch ~/ 1000)}',
        style: TextStyle(fontSize: 11, color: LinanColors.faint),
      ),
      child: top.isEmpty
          ? EmptyHint('还没有活动窗口数据', icon: Icons.sensors_off_rounded)
          : SizedBox(
              height: 150,
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
                                padding: EdgeInsets.symmetric(horizontal: 5),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text('${e.count15}',
                                        style: TextStyle(fontSize: 11, color: LinanColors.faint)),
                                    const SizedBox(height: 4),
                                    Container(
                                      width: wide ? 22 : 18,
                                      height: (100 * (e.count15 / (maxCount == 0 ? 1 : maxCount))).clamp(3, 100),
                                      decoration: BoxDecoration(
                                        color: LevelStyle.of(e.level).fg.withValues(alpha: e.level > 0 ? .9 : .32),
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
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
                  SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final e in top)
                          SizedBox(
                            width: wide ? 32 : 28,
                            child: Text(
                              e.name.characters.take(3).toString(),
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 11, color: LinanColors.muted),
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

class _Avatar extends StatelessWidget {
  final String name;
  final bool small;
  const _Avatar({required this.name, this.small = false});

  @override
  Widget build(BuildContext context) {
    final size = small ? 30.0 : 34.0;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: LinanColors.primarySoft,
        shape: BoxShape.circle,
      ),
      child: Text(
        name.isEmpty ? '安' : name.characters.first,
        style: TextStyle(
            fontSize: small ? 11 : 12, color: LinanColors.primaryText, fontWeight: FontWeight.w600),
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
    final solid = MediaQuery.maybeOf(context)?.highContrast ?? false;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 22, 24, 22),
      decoration: BoxDecoration(
        color: LinanColors.surface,
        borderRadius: BorderRadius.circular(LinanColors.rCard + 4),
        border: Border.all(color: solid ? LinanColors.border : LinanColors.borderSoft),
        boxShadow: solid
            ? null
            : [BoxShadow(color: Colors.black.withValues(alpha: .045), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 760;
          final left = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Tag('今日守护', color: LinanColors.primary, icon: Icons.wb_sunny_rounded),
                  SizedBox(width: 8),
                  Text(formatToday(), style: TextStyle(fontSize: 11.5, color: LinanColors.muted)),
                ],
              ),
              SizedBox(height: 12),
              Text(
                watched == 0 ? '今天的守护状态平稳' : '今天有 $watched 位老人需要多看一眼',
                style: TextStyle(
                  color: LinanColors.text,
                  fontSize: wide ? 26 : 21,
                  fontWeight: FontWeight.w700,
                  height: 1.28,
                  letterSpacing: -.5,
                ),
              ),
              SizedBox(height: 7),
              Text(
                urgent > 0
                    ? '其中 $urgent 条优先/紧急事件等待处置。SOS 直接进入紧急人工处理，报平安不会降低未关闭事件。'
                    : '暂未出现优先或紧急事件。规则与模型仍在持续判断，未知数据会被如实标记。',
                style: TextStyle(color: LinanColors.muted, fontSize: 12.5, height: 1.65),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 9,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: () => state.selectPage('tasks'),
                    child: const Text('查看派单建议'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => showReportDialog(context, state),
                    icon: const Icon(Icons.edit_note_rounded, size: 17),
                    label: const Text('上报一条信息'),
                  ),
                ],
              ),
            ],
          );

          final right = Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: LinanColors.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: LinanColors.borderSoft),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.analytics_rounded, size: 14, color: LinanColors.muted),
                    SizedBox(width: 6),
                    Text('数据与判断',
                        style: TextStyle(
                            fontSize: 11.5, color: LinanColors.muted, fontWeight: FontWeight.w600, letterSpacing: .2)),
                  ],
                ),
                const SizedBox(height: 10),
                _heroRow('活动数据', '${state.elders.where((e) => e.online).length} / ${state.elders.length} 位在线'),
                _VersionRows(state: state),
                _heroRow('对话模式', modeName('${state.agentsInfo['mode'] ?? 'rules'}')),
                _heroRow('派单方式', state.autoDispatch ? '自动派单（仅 1 级电话核实）' : '管理员逐单确认'),
              ],
            ),
          );

          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: left),
                const SizedBox(width: 24),
                SizedBox(width: 268, child: right),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [left, SizedBox(height: 16), right],
          );
        },
      ),
    );
  }
}

Widget _heroRow(String label, String value) {
  return Padding(
    padding: EdgeInsets.symmetric(vertical: 4.5),
    child: Row(
      children: [
        SizedBox(
            width: 60,
            child: Text(label, style: TextStyle(fontSize: 11.5, color: LinanColors.muted))),
        Expanded(
          child: Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: LinanColors.text, fontWeight: FontWeight.w500)),
        ),
      ],
    ),
  );
}

/// 规则、模型与数据结构版本来自统一缓存 `AppState.health`（refresh 的重接口轮次刷新）。
/// 读取失败或尚未返回时如实显示“未知版本”，不再把 risk-rules-v1 当作固定值写死在界面里。
class _VersionRows extends StatelessWidget {
  final AppState state;
  const _VersionRows({required this.state});

  String _value(String key) {
    final health = state.health;
    if (health == null) return '读取中…';
    final value = '${health[key] ?? ''}'.trim();
    return value.isEmpty ? '未知版本' : value;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heroRow('规则版本', _value('rule_version')),
        _heroRow('模型版本', _value('model_version')),
        _heroRow('数据版本', _value('schema_version')),
      ],
    );
  }
}
