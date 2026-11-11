import 'package:flutter/material.dart';

import '../app_state.dart';
import '../labels.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

class TasksPage extends StatefulWidget {
  final AppState state;
  const TasksPage({super.key, required this.state});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  String _filter = 'active';
  String _query = '';

  static const List<(String, String)> _filters = [
    ('active', '进行中'),
    ('pending', '待确认'),
    ('dispatched', '已派单'),
    ('accepted', '已接单'),
    ('processing', '处理中'),
    ('review', '待复核'),
    ('closed', '已关闭'),
    ('all', '全部'),
  ];

  bool _matchFilter(CareTask t) {
    if (_filter == 'all') return true;
    if (_filter == 'active') return t.state != 'closed';
    return t.state == _filter;
  }

  bool _matchQuery(CareTask t) {
    if (_query.trim().isEmpty) return true;
    final q = _query.trim();
    return t.title.contains(q) ||
        t.elderName.contains(q) ||
        t.staffName.contains(q) ||
        t.id == q ||
        kindName(t.category).contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final rows = s.tasks.where((t) => _matchFilter(t) && _matchQuery(t)).toList()
      ..sort((a, b) {
        if ((a.state == 'closed') != (b.state == 'closed')) return a.state == 'closed' ? 1 : -1;
        if (a.level != b.level) return b.level.compareTo(a.level);
        if (a.overdue != b.overdue) return a.overdue ? -1 : 1;
        return b.updated.compareTo(a.updated);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
          decoration: const BoxDecoration(
            color: LinanColors.surface,
            border: Border(bottom: BorderSide(color: LinanColors.border)),
          ),
          child: LayoutBuilder(
            builder: (context, c) {
              final filters = SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final f in _filters) ...[
                      _filterChip(f.$1, f.$2, s),
                      const SizedBox(width: 5),
                    ],
                  ],
                ),
              );
              final right = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 170,
                    height: 32,
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: '搜索老人 / 任务 / 负责人',
                        prefixIcon: Icon(Icons.search, size: 15),
                        prefixIconConstraints: BoxConstraints(minWidth: 34),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      ),
                      style: const TextStyle(fontSize: 11),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                  if (s.user?.isAdmin == true) ...[
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: s.busy ? null : () => _recommend(context, s),
                      icon: const Icon(Icons.auto_awesome, size: 14),
                      label: const Text('计算派单建议', style: TextStyle(fontSize: 11)),
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 12)),
                    ),
                  ],
                ],
              );
              if (c.maxWidth >= 860) {
                return Row(children: [Expanded(child: filters), const SizedBox(width: 12), right]);
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  filters,
                  const SizedBox(height: 10),
                  Align(alignment: Alignment.centerLeft, child: right),
                ],
              );
            },
          ),
        ),
        Expanded(
          child: rows.isEmpty
              ? EmptyHint(
                  s.tasks.isEmpty ? '当前没有处置任务' : '没有符合筛选条件的任务',
                  icon: Icons.checklist_rtl,
                )
              : Scrollbar(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 14, 24, 26),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1240),
                        child: Column(
                          children: [
                            for (final t in rows) _TaskCard(state: s, task: t),
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

  Widget _filterChip(String key, String label, AppState s) {
    final count = key == 'all'
        ? s.tasks.length
        : key == 'active'
            ? s.tasks.where((t) => t.state != 'closed').length
            : s.tasks.where((t) => t.state == key).length;
    final selected = _filter == key;
    return ChoiceChip(
      label: Text('$label $count', style: TextStyle(fontSize: 10.5, color: selected ? LinanColors.primaryDeep : LinanColors.muted)),
      selected: selected,
      onSelected: (_) => setState(() => _filter = key),
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      selectedColor: LinanColors.primarySoft,
      backgroundColor: LinanColors.surfaceAlt,
      side: BorderSide(color: selected ? LinanColors.primary.withValues(alpha: .35) : LinanColors.borderSoft),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    );
  }

  Future<void> _recommend(BuildContext context, AppState s) async {
    try {
      await s.loadRecommendations();
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => _RecommendDialog(state: s),
      );
    } catch (e) {
      s.toast('$e');
    }
  }
}

class _TaskCard extends StatelessWidget {
  final AppState state;
  final CareTask task;
  const _TaskCard({required this.state, required this.task});

  @override
  Widget build(BuildContext context) {
    final admin = state.user?.isAdmin == true;
    final mine = task.staffId != null && task.staffId == state.user?.staffId;
    final actions = <Widget>[];

    void act(String action, {String outcome = '', String note = ''}) async {
      try {
        await state.taskAction(task.id, action, outcome: outcome, note: note);
        state.toast('操作已记录');
      } on Object catch (e) {
        state.toast('$e');
      }
    }

    if (!admin && mine) {
      if (task.state == 'dispatched') {
        actions.add(OutlinedButton(onPressed: () => act('reject'), child: const Text('拒单')));
        actions.add(FilledButton(onPressed: () => act('accept'), child: const Text('接单')));
      } else if (task.state == 'accepted') {
        actions.add(OutlinedButton(onPressed: () => act('reject'), child: const Text('拒单')));
        actions.add(OutlinedButton(onPressed: () => act('start'), child: const Text('开始处理')));
        actions.add(FilledButton(onPressed: () => _action(context, 'feedback'), child: const Text('提交处置结果')));
      } else if (task.state == 'processing') {
        actions.add(FilledButton(onPressed: () => _action(context, 'feedback'), child: const Text('提交处置结果')));
      }
    }
    if (admin && task.state == 'review') {
      actions.add(OutlinedButton(
        onPressed: () => act('followup'),
        child: const Text('继续跟进'),
      ));
      actions.add(FilledButton(onPressed: () => _action(context, 'close'), child: const Text('核实并关闭')));
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 12),
      decoration: BoxDecoration(
        color: LinanColors.surface,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: task.level >= 2 && task.state != 'closed'
              ? LevelStyle.of(task.level).fg.withValues(alpha: .22)
              : LinanColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LevelPill(task.level),
              const SizedBox(width: 7),
              StatePill(task.state),
              const SizedBox(width: 9),
              Text('任务 #${task.id}', style: const TextStyle(fontSize: 10, color: LinanColors.faint)),
              if (task.overdue) ...[
                const SizedBox(width: 8),
                const Tag('已超时', color: LinanColors.danger, icon: Icons.schedule),
              ],
              const Spacer(),
              if (task.due != null)
                Text(
                  task.overdue ? '应于 ${formatStamp(task.due)} 前完成' : '时限 ${formatStamp(task.due)}',
                  style: TextStyle(fontSize: 9.5, color: task.overdue ? LinanColors.danger : LinanColors.faint),
                ),
            ],
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => _detail(context),
            borderRadius: BorderRadius.circular(6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${task.elderName} · ${task.title}',
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: LinanColors.text),
                  ),
                ),
                const Icon(Icons.chevron_right, size: 16, color: LinanColors.border),
              ],
            ),
          ),
          if (task.advice.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(task.advice, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, height: 1.6, color: LinanColors.muted)),
          ],
          const SizedBox(height: 9),
          Wrap(
            spacing: 14,
            runSpacing: 5,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _meta(Icons.person_outline, task.staffName.isEmpty ? '待派单' : task.staffName),
              _meta(Icons.medical_services_outlined, skillName(task.requiredSkill)),
              _meta(Icons.schedule, formatStamp(task.created)),
              if (task.evidence.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: _meta(Icons.fact_check_outlined, task.evidence.first, ellipsis: true),
                ),
            ],
          ),
          if (actions.isNotEmpty) ...[
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  SizedBox(height: 30, child: actions[i]),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _meta(IconData icon, String text, {bool ellipsis = false}) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: LinanColors.faint),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: ellipsis ? 360 : 150),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: LinanColors.muted),
            ),
          ),
        ],
      );

  Future<void> _detail(BuildContext context) async {
    await showSideSheet(
      context,
      title: '任务 #${task.id} · ${task.elderName}',
      subtitle: task.title,
      child: _TaskDetailBody(state: state, taskId: task.id),
    );
  }

  Future<void> _action(BuildContext context, String kind) async {
    final result = await showDialog<_ActionInput>(
      context: context,
      builder: (ctx) => _ActionDialog(kind: kind),
    );
    if (result == null) return;
    try {
      await state.taskAction(task.id, kind, outcome: result.outcome, note: result.note);
      state.toast(kind == 'close' ? '任务已核实关闭' : '处置结果已提交');
    } on Object catch (e) {
      state.toast('$e');
    }
  }
}

class _ActionInput {
  final String outcome;
  final String note;
  const _ActionInput(this.outcome, this.note);
}

class _ActionDialog extends StatefulWidget {
  final String kind;
  const _ActionDialog({required this.kind});

  @override
  State<_ActionDialog> createState() => _ActionDialogState();
}

class _ActionDialogState extends State<_ActionDialog> {
  static const Map<String, String> _closeOutcomes = {'safe': '已确认安全', 'data_issue': '数据问题已核查'};
  String _outcome = 'safe';
  final TextEditingController _note = TextEditingController();
  String? _error;

  bool get _isFeedback => widget.kind == 'feedback';
  bool get _needsOutcome => _isFeedback || widget.kind == 'close';

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final outcomes = widget.kind == 'close' ? _closeOutcomes : outcomeNames;
    return AlertDialog(
      title: Text(
        _isFeedback ? '提交处置结果' : (widget.kind == 'close' ? '核实并关闭任务' : '确认操作'),
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.kind == 'close')
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  '关闭后风险事件会同步关闭，老人状态回到平稳。仅当联系或上门核实确实安全时使用。',
                  style: TextStyle(fontSize: 11, height: 1.6, color: LinanColors.muted),
                ),
              ),
            if (_needsOutcome) ...[
              const Text('处置结论', style: TextStyle(fontSize: 10.5, color: LinanColors.muted)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _outcome,
                decoration: const InputDecoration(isDense: true),
                items: [
                  for (final e in outcomes.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 12))),
                ],
                onChanged: (v) => setState(() => _outcome = v ?? 'safe'),
              ),
              const SizedBox(height: 12),
            ],
            const Text('记录说明（至少 2 个字）', style: TextStyle(fontSize: 10.5, color: LinanColors.muted)),
            const SizedBox(height: 6),
            TextField(
              controller: _note,
              minLines: 3,
              maxLines: 5,
              maxLength: 300,
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                hintText: '例如：已电话联系，老人表示一切正常。',
                counterStyle: TextStyle(fontSize: 9, color: LinanColors.faint),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_error!, style: const TextStyle(fontSize: 10.5, color: LinanColors.danger)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消')),
        FilledButton(
          onPressed: () {
            final note = _note.text.trim();
            if (note.length < 2) {
              setState(() => _error = '请填写至少 2 个字的记录说明');
              return;
            }
            Navigator.of(context).pop(_ActionInput(_needsOutcome ? _outcome : '', note));
          },
          child: const Text('提交'),
        ),
      ],
    );
  }
}

class _TaskDetailBody extends StatelessWidget {
  final AppState state;
  final String taskId;
  const _TaskDetailBody({required this.state, required this.taskId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TaskDetail>(
      future: state.taskDetail(taskId),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (snap.hasError) {
          return EmptyHint('${snap.error}', icon: Icons.error_outline);
        }
        final d = snap.data;
        if (d == null) return const EmptyHint('没有任务详情');
        final t = d.task;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                LevelPill(t.level),
                const SizedBox(width: 8),
                StatePill(t.state),
                const SizedBox(width: 8),
                Tag(skillName(t.requiredSkill)),
                const Spacer(),
                if (t.overdue) const Tag('已超时', color: LinanColors.danger),
              ],
            ),
            const SizedBox(height: 14),
            KeyValue('老人', d.task.elderName),
            KeyValue('负责人', t.staffName.isEmpty ? '待派单' : t.staffName),
            KeyValue('创建时间', formatStamp(t.created)),
            KeyValue('处理时限', formatStamp(t.due, empty: '未设置')),
            KeyValue('当前版本', '${t.version}'),
            const Divider(height: 22),
            const _SectionLabel('判断依据'),
            if (t.evidence.isEmpty)
              const Text('暂无补充依据', style: TextStyle(fontSize: 11, color: LinanColors.faint))
            else
              for (final line in t.evidence)
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(padding: EdgeInsets.only(top: 5), child: Dot(LinanColors.amber, size: 5)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(line, style: const TextStyle(fontSize: 11.5, height: 1.65))),
                    ],
                  ),
                ),
            const SizedBox(height: 8),
            const _SectionLabel('处置建议'),
            Text(t.advice.isEmpty ? '按社区流程核实并留痕。' : t.advice,
                style: const TextStyle(fontSize: 11.5, height: 1.7, color: LinanColors.muted)),
            const Divider(height: 24),
            const _SectionLabel('处置反馈'),
            if (d.feedback.isEmpty)
              const Text('尚未提交反馈', style: TextStyle(fontSize: 11, color: LinanColors.faint))
            else
              for (final f in d.feedback)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: LinanColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Tag(outcomeName('${f['outcome'] ?? ''}'),
                              color: '${f['outcome']}' == 'safe' ? LinanColors.green : LinanColors.amber),
                          const Spacer(),
                          Text(formatStamp(f['created'] is num ? f['created'] as num : null),
                              style: const TextStyle(fontSize: 9.5, color: LinanColors.faint)),
                        ],
                      ),
                      if ('${f['note'] ?? ''}'.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Text('${f['note']}', style: const TextStyle(fontSize: 11, height: 1.6)),
                        ),
                    ],
                  ),
                ),
            const Divider(height: 24),
            const _SectionLabel('审计时间线'),
            for (final a in d.audit.reversed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Dot(a['action'] == 'task_close' ? LinanColors.green : LinanColors.border, size: 6),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${auditName(a['action'])}${('${a['note'] ?? ''}').isEmpty ? '' : ' · ${a['note']}'}',
                        style: const TextStyle(fontSize: 11, height: 1.55),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(formatStamp(a['created'] is num ? a['created'] as num : null),
                        style: const TextStyle(fontSize: 9, color: LinanColors.faint)),
                  ],
                ),
              ),
            if (d.agentRuns.isNotEmpty) ...[
              const Divider(height: 24),
              const _SectionLabel('Agent 运行记录'),
              for (final run in d.agentRuns)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('${runKindName('${run['kind'] ?? ''}')} #${run['id']}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          Tag(modeName('${run['mode'] ?? ''}'), color: LinanColors.primary),
                          const Spacer(),
                          Text(runStatusName('${run['status'] ?? ''}'),
                              style: const TextStyle(fontSize: 9.5, color: LinanColors.muted)),
                        ],
                      ),
                      if ('${run['summary'] ?? ''}'.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text('${run['summary']}',
                              style: const TextStyle(fontSize: 10.5, height: 1.55, color: LinanColors.muted)),
                        ),
                    ],
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}

String auditName(dynamic action) => auditNames['$action'] ?? '$action';

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 9.5, letterSpacing: .8, color: LinanColors.faint)),
      );
}

class _RecommendDialog extends StatefulWidget {
  final AppState state;
  const _RecommendDialog({required this.state});

  @override
  State<_RecommendDialog> createState() => _RecommendDialogState();
}

class _RecommendDialogState extends State<_RecommendDialog> {
  final Map<String, int> _staffChoice = {};
  final Map<String, TextEditingController> _reasons = {};
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    for (final r in widget.state.recs) {
      _staffChoice[r.id] = r.staffId;
      _reasons[r.id] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final c in _reasons.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final recs = s.recs;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 640),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 12, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('派单建议', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        SizedBox(height: 3),
                        Text('按优先级与人员容量计算，确认时会再次校验版本与技能。',
                            style: TextStyle(fontSize: 10.5, color: LinanColors.muted)),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close, size: 18)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: recs.isEmpty
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          EmptyHint(s.recNote.isEmpty ? '当前没有待派任务' : s.recNote, icon: Icons.task_alt),
                          if (s.unassigned.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            const Text('未能分配的任务', style: TextStyle(fontSize: 11, color: LinanColors.muted)),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [for (final id in s.unassigned) Tag('任务 #$id', color: LinanColors.amber)],
                            ),
                          ],
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                      child: Column(
                        children: [
                          for (final r in recs) _recRow(s, r),
                          if (s.unassigned.isNotEmpty)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 4, bottom: 8),
                                child: Text('另有 ${s.unassigned.length} 条任务暂时无法分配：${s.unassigned.map((e) => '#$e').join('、')}',
                                    style: const TextStyle(fontSize: 10, color: LinanColors.amber)),
                              ),
                            ),
                          if (s.recNote.isNotEmpty)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 2, bottom: 10),
                                child: Text(s.recNote, style: const TextStyle(fontSize: 10, color: LinanColors.faint)),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
              child: Row(
                children: [
                  Text('推荐 ${recs.length} 条 · 5 分钟内有效',
                      style: const TextStyle(fontSize: 10, color: LinanColors.faint)),
                  const Spacer(),
                  TextButton(onPressed: _submitting ? null : () => Navigator.of(context).pop(), child: const Text('关闭')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recRow(AppState s, Recommendation r) {
    final task = s.taskById(r.taskId);
    final chosen = _staffChoice[r.id] ?? r.staffId;
    final changed = chosen != r.staffId;
    final candidates = s.staff.where((p) => p.onDuty && p.available).toList();
    if (!candidates.any((p) => p.id == chosen)) {
      final current = s.staffById(chosen);
      if (current != null) candidates.add(current);
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
      decoration: BoxDecoration(
        color: LinanColors.surfaceAlt.withValues(alpha: .5),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: LinanColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              LevelPill(r.level),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  task == null ? '任务 #${r.taskId}' : '${task.elderName} · ${task.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              Text(r.eta > 0 ? '预计 ${(r.eta / 60).ceil()} 分钟到达' : '等待计算到达时间',
                  style: const TextStyle(fontSize: 9.5, color: LinanColors.muted)),
            ],
          ),
          const SizedBox(height: 4),
          Text(r.reason, style: const TextStyle(fontSize: 10.5, height: 1.55, color: LinanColors.muted)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('负责人', style: TextStyle(fontSize: 10.5, color: LinanColors.muted)),
              const SizedBox(width: 8),
              SizedBox(
                width: 130,
                child: DropdownButton<int>(
                  value: chosen,
                  isDense: true,
                  underline: const SizedBox.shrink(),
                  style: const TextStyle(fontSize: 11, color: LinanColors.text),
                  items: [
                    for (final p in candidates)
                      DropdownMenuItem(value: p.id, child: Text('${p.name} · ${p.location}号楼', style: const TextStyle(fontSize: 11))),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _staffChoice[r.id] = v);
                  },
                ),
              ),
              if (changed) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _reasons[r.id],
                    style: const TextStyle(fontSize: 11),
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: '调整原因（至少 2 字）',
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                  ),
                ),
              ],
              const Spacer(),
              SizedBox(
                height: 30,
                child: FilledButton(
                  onPressed: _submitting
                      ? null
                      : () async {
                          final reason = (_reasons[r.id]?.text ?? '').trim();
                          if (changed && reason.length < 2) {
                            s.toast('调整负责人需要填写原因');
                            return;
                          }
                          setState(() => _submitting = true);
                          try {
                            await s.confirmRecommendation(r, chosen, changed ? reason : '');
                            if (!mounted) return;
                            setState(() {});
                          } on Object catch (e) {
                            s.toast('$e');
                          } finally {
                            if (mounted) setState(() => _submitting = false);
                          }
                        },
                  child: const Text('确认派单', style: TextStyle(fontSize: 11)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
