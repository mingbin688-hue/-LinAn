import 'package:flutter/material.dart';

import '../app_state.dart';
import '../labels.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// 风险事件：未关闭优先、按等级排序的事件流与处置详情。
///
/// 外层 Shell 已提供侧栏、工具栏与背景，本页只负责内容区。
class IncidentsPage extends StatefulWidget {
  final AppState state;

  const IncidentsPage({super.key, required this.state});

  @override
  State<IncidentsPage> createState() => _IncidentsPageState();
}

class _IncidentsPageState extends State<IncidentsPage> {
  static const List<String> _openLabels = ['未关闭', '全部', '已关闭'];
  static const List<String> _levelLabels = ['全部等级', '紧急', '优先', '关注', '未知'];
  static const List<int?> _levelValues = [null, 3, 2, 1, 0];

  bool? _openFilter = true;
  int? _levelFilter;

  int get _openIndex => _openFilter == true ? 0 : (_openFilter == null ? 1 : 2);

  int get _levelIndex {
    final index = _levelValues.indexOf(_levelFilter);
    return index < 0 ? 0 : index;
  }

  List<Incident> _rows(AppState state) {
    return state.incidents.where((i) {
      if (_openFilter != null && i.open != _openFilter) return false;
      if (_levelFilter != null && i.level != _levelFilter) return false;
      return true;
    }).toList()
      ..sort((a, b) {
        if (a.open != b.open) return a.open ? -1 : 1;
        final byLevel = b.level.compareTo(a.level);
        if (byLevel != 0) return byLevel;
        return b.updated.compareTo(a.updated);
      });
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final rows = _rows(state);
    final openRows = state.incidents.where((i) => i.open).toList();
    final urgent = openRows.where((i) => i.level >= 3).length;
    final priority = openRows.where((i) => i.level == 2).length;
    final filtered = _openFilter != true || _levelFilter != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        final side = wide ? 28.0 : 16.0;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(side, 0, side, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PageHeader(
                    title: '风险事件',
                    subtitle: '未关闭事件优先 · 按风险等级与更新时间排序',
                    icon: Icons.warning_amber_rounded,
                    accent: LinanColors.danger,
                    padding: const EdgeInsets.fromLTRB(0, 22, 0, 16),
                    actions: [
                      OutlinedButton.icon(
                        onPressed: state.loading ? null : () => state.refresh(),
                        icon: state.loading
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh_rounded, size: 16),
                        label: Text(state.loading ? '刷新中' : '刷新'),
                      ),
                    ],
                  ),
                  _stats(openRows.length, urgent, priority, state.incidents.length - openRows.length),
                  const SizedBox(height: 14),
                  _filterCard(rows.length),
                  const SizedBox(height: 14),
                  if (rows.isEmpty)
                    SectionCard(
                      child: EmptyHint(
                        filtered ? '没有符合条件的风险事件' : '还没有风险事件',
                        icon: Icons.verified_outlined,
                      ),
                    )
                  else
                    for (var i = 0; i < rows.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      _IncidentCard(
                        incident: rows[i],
                        task: _taskFor(state, rows[i].id),
                        onOpen: () => _open(context, rows[i]),
                        onTask: () => state.selectPage('tasks'),
                      ),
                    ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _stats(int open, int urgent, int priority, int closed) {
    final tiles = [
      StatTile(
        label: '未关闭',
        value: '$open',
        unit: '条',
        accent: LinanColors.amber,
        icon: Icons.pending_actions_rounded,
      ),
      StatTile(
        label: '紧急',
        value: '$urgent',
        unit: '条',
        accent: LinanColors.danger,
        icon: Icons.priority_high_rounded,
      ),
      StatTile(
        label: '优先',
        value: '$priority',
        unit: '条',
        accent: LinanColors.warm,
        icon: Icons.flag_outlined,
      ),
      StatTile(
        label: '已关闭',
        value: '$closed',
        unit: '条',
        accent: LinanColors.green,
        icon: Icons.task_alt_rounded,
      ),
    ];
    return LayoutBuilder(
      builder: (context, box) {
        final cols = box.maxWidth >= 880 ? 4 : 2;
        const gap = 12.0;
        final width = (box.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final tile in tiles) SizedBox(width: width, child: tile),
          ],
        );
      },
    );
  }

  Widget _filterCard(int count) {
    return SectionCard(
      padding: EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, box) {
              final openControl = SegmentedControl(
                labels: _openLabels,
                selected: _openIndex,
                onChanged: (i) => setState(
                  () => _openFilter = i == 0 ? true : (i == 1 ? null : false),
                ),
              );
              final levelControl = SegmentedControl(
                labels: _levelLabels,
                selected: _levelIndex,
                onChanged: (i) => setState(() => _levelFilter = _levelValues[i]),
              );
              if (box.maxWidth >= 640) {
                return Row(
                  children: [
                    Expanded(child: openControl),
                    const SizedBox(width: 12),
                    Expanded(child: levelControl),
                  ],
                );
              }
              return Column(
                children: [
                  openControl,
                  const SizedBox(height: 10),
                  levelControl,
                ],
              );
            },
          ),
          SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.sort_rounded, size: 13, color: LinanColors.faint),
              SizedBox(width: 5),
              Expanded(
                child: Text(
                  '未关闭优先 · 按风险等级排序',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: LinanColors.faint),
                ),
              ),
              SizedBox(width: 8),
              Text(
                '$count 条',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: LinanColors.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  CareTask? _taskFor(AppState state, String incidentId) {
    for (final task in state.tasks) {
      if (task.incidentId == incidentId) return task;
    }
    return null;
  }

  Future<void> _open(BuildContext context, Incident incident) {
    final state = widget.state;
    final related = state.tasks.where((t) => t.incidentId == incident.id).toList();
    return showSideSheet(
      context,
      title: '${incident.elderName} · ${incident.title}',
      subtitle:
          '事件 #${incident.id} · ${categoryLabel(incident.category)} · ${incident.open ? '未关闭' : '已关闭'}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              LevelPill(incident.level),
              SizedBox(width: 8),
              Tag(
                incident.open ? '仍待处置' : '已人工关闭',
                color: incident.open ? LinanColors.amber : LinanColors.green,
              ),
              Expanded(
                child: Text(
                  '更新 ${formatStamp(incident.updated)}',
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: LinanColors.faint),
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          SectionCard(
            title: '判断依据',
            icon: Icons.rule_rounded,
            child: incident.evidence.isEmpty
                ? const EmptyHint('暂无补充依据', icon: Icons.notes_rounded)
                : _BulletList(incident.evidence),
          ),
          SizedBox(height: 12),
          SectionCard(
            title: '处置建议',
            icon: Icons.lightbulb_outline_rounded,
            child: Text(
              incident.advice.isEmpty ? '按社区流程核实并留痕。' : incident.advice,
              style: TextStyle(fontSize: 12.5, height: 1.65, color: LinanColors.text),
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: '关联任务',
            icon: Icons.checklist_rounded,
            trailing: Tag('${related.length} 个'),
            padding: const EdgeInsets.fromLTRB(18, 17, 18, 8),
            child: related.isEmpty
                ? const EmptyHint('该事件还没有对应处置任务。', icon: Icons.assignment_outlined)
                : Column(
                    children: [
                      for (var i = 0; i < related.length; i++)
                        ListRow(
                          leading: IconTile(
                            Icons.assignment_rounded,
                            size: 30,
                            iconSize: 15,
                            color: LinanColors.primary,
                          ),
                          title: '任务 #${related[i].id} · ${skillName(related[i].requiredSkill)}',
                          subtitle:
                              '${related[i].staffName.isEmpty ? '待派单' : related[i].staffName} · 更新 ${formatStamp(related[i].updated)}',
                          trailing: StatePill(related[i].state, compact: true),
                          showChevron: true,
                          showDivider: i != related.length - 1,
                          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 9),
                          onTap: () {
                            Navigator.of(context).pop();
                            state.selectPage('tasks');
                          },
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                state.selectPage('tasks');
              },
              icon: const Icon(Icons.arrow_forward_rounded, size: 15),
              label: const Text('前往任务中心'),
            ),
          ),
        ],
      ),
    );
  }
}

/// 事件卡片：左侧等级色条 + 依据摘要 + 处置进度。
class _IncidentCard extends StatelessWidget {
  final Incident incident;
  final CareTask? task;
  final VoidCallback onOpen;
  final VoidCallback onTask;

  const _IncidentCard({
    required this.incident,
    required this.task,
    required this.onOpen,
    required this.onTask,
  });

  @override
  Widget build(BuildContext context) {
    final style = LevelStyle.of(incident.level);
    final bar = incident.open ? style.fg : LinanColors.green;
    final emergency = incident.open && incident.level >= 3;
    final evidence = incident.evidence.isEmpty ? '暂无补充依据' : incident.evidence.first;

    return Material(
      color: emergency ? LinanColors.tint(LinanColors.danger, .05) : LinanColors.surface,
      borderRadius: BorderRadius.circular(LinanColors.rCard),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: EdgeInsets.fromLTRB(14, 13, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 42,
                margin: EdgeInsets.only(right: 11, top: 2),
                decoration: BoxDecoration(
                  color: bar,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            incident.elderName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: LinanColors.text,
                              height: 1.3,
                            ),
                          ),
                        ),
                        SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            '${categoryLabel(incident.category)} · #${incident.id}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11.5, color: LinanColors.faint),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          formatStamp(incident.updated),
                          style: TextStyle(fontSize: 11, color: LinanColors.faint),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      incident.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: LinanColors.text,
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      evidence,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: LinanColors.muted, height: 1.5),
                    ),
                    SizedBox(height: 9),
                    Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              LevelPill(incident.level, compact: true),
                              if (task != null)
                                _TaskPill(task: task!, onTap: onTask)
                              else
                                const Tag('无任务'),
                              Tag(
                                incident.open ? '未关闭' : '已关闭',
                                color: incident.open ? LinanColors.amber : LinanColors.green,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.chevron_right_rounded, size: 18, color: LinanColors.faint),
                      ],
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
}

/// 事件卡片上的任务胶囊，点击直达任务中心。
class _TaskPill extends StatelessWidget {
  final CareTask task;
  final VoidCallback onTap;

  const _TaskPill({required this.task, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: LinanColors.tint(LinanColors.primary, .1),
      borderRadius: BorderRadius.circular(LinanColors.rPill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(LinanColors.rPill),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.assignment_outlined, size: 11, color: LinanColors.primary),
              const SizedBox(width: 4),
              Text(
                '任务 #${task.id} · ${stateName(task.state)}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: LinanColors.primary,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BulletList extends StatelessWidget {
  final List<String> lines;

  const _BulletList(this.lines);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          Padding(
            padding: EdgeInsets.only(bottom: 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Dot(LinanColors.amber, size: 5),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    line,
                    style: TextStyle(fontSize: 12, height: 1.6, color: LinanColors.text),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
