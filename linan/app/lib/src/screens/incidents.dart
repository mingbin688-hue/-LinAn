import 'package:flutter/material.dart';

import '../app_state.dart';
import '../labels.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

class IncidentsPage extends StatefulWidget {
  final AppState state;
  const IncidentsPage({super.key, required this.state});

  @override
  State<IncidentsPage> createState() => _IncidentsPageState();
}

class _IncidentsPageState extends State<IncidentsPage> {
  bool? _openFilter = true;
  int? _levelFilter;

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final rows = s.incidents.where((i) {
      if (_openFilter != null && i.open != _openFilter) return false;
      if (_levelFilter != null && i.level != _levelFilter) return false;
      return true;
    }).toList()
      ..sort((a, b) {
        if (a.open != b.open) return a.open ? -1 : 1;
        if (a.level != b.level) return b.level.compareTo(a.level);
        return b.updated.compareTo(a.updated);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 12),
          decoration: const BoxDecoration(
            color: LinanColors.surface,
            border: Border(bottom: BorderSide(color: LinanColors.border)),
          ),
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('未关闭', style: TextStyle(fontSize: 10.5)),
                selected: _openFilter == true,
                onSelected: (_) => setState(() => _openFilter = true),
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                label: const Text('全部', style: TextStyle(fontSize: 10.5)),
                selected: _openFilter == null,
                onSelected: (_) => setState(() => _openFilter = null),
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                label: const Text('已关闭', style: TextStyle(fontSize: 10.5)),
                selected: _openFilter == false,
                onSelected: (_) => setState(() => _openFilter = false),
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 14),
              const Text('等级', style: TextStyle(fontSize: 10, color: LinanColors.faint)),
              const SizedBox(width: 6),
              DropdownButton<int?>(
                value: _levelFilter,
                underline: const SizedBox.shrink(),
                style: const TextStyle(fontSize: 10.5, color: LinanColors.text),
                items: const [
                  DropdownMenuItem(value: null, child: Text('全部')),
                  DropdownMenuItem(value: 3, child: Text('紧急')),
                  DropdownMenuItem(value: 2, child: Text('优先')),
                  DropdownMenuItem(value: 1, child: Text('关注')),
                  DropdownMenuItem(value: 0, child: Text('状态未知')),
                ],
                onChanged: (v) => setState(() => _levelFilter = v),
              ),
              const Spacer(),
              Text('共 ${rows.length} 条', style: const TextStyle(fontSize: 10, color: LinanColors.faint)),
            ],
          ),
        ),
        Expanded(
          child: rows.isEmpty
              ? const EmptyHint('没有符合条件的风险事件', icon: Icons.verified_outlined)
              : Scrollbar(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 26),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1240),
                        child: Column(
                          children: [
                            for (final i in rows)
                              _IncidentRow(
                                incident: i,
                                task: _taskFor(s, i.id),
                                onTap: () => _open(context, i),
                                onTask: () {
                                  s.selectPage('tasks');
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  void _open(BuildContext context, Incident incident) {
    final s = widget.state;
    final related = s.tasks.where((t) => t.incidentId == incident.id).toList();
    showSideSheet(
      context,
      title: '${incident.elderName} · ${incident.title}',
      subtitle: '事件 #${incident.id} · ${categoryName(incident.category)} · ${incident.open ? '未关闭' : '已关闭'}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              LevelPill(incident.level),
              const SizedBox(width: 8),
              Tag(incident.open ? '仍待处置' : '已人工关闭', color: incident.open ? LinanColors.amber : LinanColors.green),
              const Spacer(),
              Text('更新 ${formatStamp(incident.updated)}', style: const TextStyle(fontSize: 9.5, color: LinanColors.faint)),
            ],
          ),
          const SizedBox(height: 14),
          const _MiniTitle('判断依据'),
          for (final line in incident.evidence)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(padding: EdgeInsets.only(top: 5), child: Dot(LinanColors.amber, size: 5)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(line, style: const TextStyle(fontSize: 11.5, height: 1.65, color: LinanColors.text))),
                ],
              ),
            ),
          const SizedBox(height: 10),
          const _MiniTitle('处置建议'),
          Text(incident.advice.isEmpty ? '按社区流程核实并留痕。' : incident.advice,
              style: const TextStyle(fontSize: 11.5, height: 1.7, color: LinanColors.muted)),
          const SizedBox(height: 18),
          const _MiniTitle('关联任务'),
          if (related.isEmpty)
            const Text('该事件还没有对应处置任务。', style: TextStyle(fontSize: 11, color: LinanColors.faint))
          else
            for (final t in related)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: LinanColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: LinanColors.borderSoft),
                ),
                child: Row(
                  children: [
                    StatePill(t.state, compact: true),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('任务 #${t.id} · ${skillName(t.requiredSkill)} · ${t.staffName.isEmpty ? '待派单' : t.staffName}',
                          style: const TextStyle(fontSize: 10.5, color: LinanColors.text)),
                    ),
                    Text('查看', style: const TextStyle(fontSize: 10, color: LinanColors.primary)),
                  ],
                ),
              ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => s.selectPage('tasks'),
              icon: const Icon(Icons.arrow_forward, size: 13),
              label: const Text('前往任务中心'),
            ),
          ),
        ],
      ),
    );
  }
}

String categoryName(String category) => categoryNames[category] ?? category;

CareTask? _taskFor(AppState s, String incidentId) {
  for (final t in s.tasks) {
    if (t.incidentId == incidentId) return t;
  }
  return null;
}

class _IncidentRow extends StatelessWidget {
  final Incident incident;
  final CareTask? task;
  final VoidCallback onTap;
  final VoidCallback onTask;

  const _IncidentRow({required this.incident, required this.task, required this.onTap, required this.onTask});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: LinanColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: LinanColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 760;
              final main = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: wide ? 168 : 132,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(incident.elderName,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: LinanColors.text)),
                        const SizedBox(height: 2),
                        Text('${categoryName(incident.category)} · #${incident.id}',
                            style: const TextStyle(fontSize: 9.5, color: LinanColors.faint)),
                      ],
                    ),
                  ),
                  LevelPill(incident.level),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(incident.title, style: const TextStyle(fontSize: 12, color: LinanColors.text, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 3),
                        Text(
                          incident.evidence.isEmpty ? '暂无补充依据' : incident.evidence.first,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10, color: LinanColors.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (task != null)
                    _taskBadge(task!)
                  else
                    const Tag('无任务'),
                  const SizedBox(width: 10),
                  Tag(incident.open ? '未关闭' : '已关闭',
                      color: incident.open ? LinanColors.amber : LinanColors.green),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 76,
                    child: Text(formatStamp(incident.updated),
                        textAlign: TextAlign.right, style: const TextStyle(fontSize: 9.5, color: LinanColors.faint)),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right, size: 15, color: LinanColors.border),
                ],
              );
              if (wide) return main;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  main,
                  if (task != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: GestureDetector(
                        onTap: onTask,
                        child: _taskBadge(task!, detailed: true),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _taskBadge(CareTask t, {bool detailed = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: LinanColors.surfaceAlt,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        '任务 #${t.id} · ${stateName(t.state)}${detailed ? ' · ${skillName(t.requiredSkill)}' : ''}',
        style: const TextStyle(fontSize: 9, color: LinanColors.muted),
      ),
    );
  }
}

class _MiniTitle extends StatelessWidget {
  final String text;
  const _MiniTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Text(text, style: const TextStyle(fontSize: 9.5, letterSpacing: .8, color: LinanColors.faint)),
      );
}
