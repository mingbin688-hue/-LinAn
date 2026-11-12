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
  final TextEditingController _search = TextEditingController();

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

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

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
    final active = s.tasks.where((t) => t.state != 'closed').length;
    final review = s.tasks.where((t) => t.state == 'review').length;

    return LayoutBuilder(
      builder: (context, shell) {
        // 宽屏把内容收进 1180 的中栏，窄屏保留 24 的边距。
        final side = shell.maxWidth > 1228 ? (shell.maxWidth - 1180) / 2 : 24.0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: '处置任务',
              subtitle: '共 ${s.tasks.length} 条任务 · 进行中 $active 条 · 待复核 $review 条',
              icon: Icons.task_alt_rounded,
              padding: EdgeInsets.fromLTRB(side, 22, side, 14),
              actions: [
                if (s.user?.isAdmin == true)
                  FilledButton.icon(
                    onPressed: s.busy ? null : () => _recommend(context, s),
                    icon: const Icon(Icons.auto_awesome_rounded, size: 17),
                    label: const Text('计算派单建议'),
                  ),
              ],
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(side, 0, side, 12),
              child: _controls(s),
            ),
            Expanded(
              child: rows.isEmpty
                  ? EmptyHint(
                      s.tasks.isEmpty ? '当前没有处置任务' : '没有符合筛选条件的任务',
                      icon: Icons.checklist_rtl_rounded,
                    )
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(side, 2, side, 28),
                      itemCount: rows.length,
                      itemBuilder: (context, i) => _TaskCard(
                        key: ValueKey(rows[i].id),
                        state: s,
                        task: rows[i],
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  /// 筛选 + 搜索：宽屏并排，窄屏上下堆叠。
  Widget _controls(AppState s) {
    final index = _filters.indexWhere((f) => f.$1 == _filter);
    final segmented = SegmentedControl(
      labels: [for (final f in _filters) f.$2],
      selected: index < 0 ? 0 : index,
      onChanged: (i) => setState(() => _filter = _filters[i].$1),
    );
    final search = Container(
      height: 38,
      padding: EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: LinanColors.fill,
        borderRadius: BorderRadius.circular(LinanColors.rControl),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 16, color: LinanColors.faint),
          SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _search,
              style: TextStyle(fontSize: 12.5, color: LinanColors.text),
              cursorColor: LinanColors.primary,
              decoration: InputDecoration(
                hintText: '搜索老人、任务或负责人',
                hintStyle: TextStyle(fontSize: 12.5, color: LinanColors.faint),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 9),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          if (_query.isNotEmpty)
            GestureDetector(
              onTap: () {
                _search.clear();
                setState(() => _query = '');
              },
              child: Icon(Icons.cancel_outlined, size: 15, color: LinanColors.faint),
            ),
        ],
      ),
    );
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth >= 760) {
          return Row(
            children: [
              Expanded(child: segmented),
              const SizedBox(width: 12),
              SizedBox(width: 250, child: search),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            segmented,
            const SizedBox(height: 10),
            search,
          ],
        );
      },
    );
  }

  Future<void> _recommend(BuildContext context, AppState s) async {
    try {
      await s.loadRecommendations();
      if (!context.mounted) return;
      await showSideSheet(
        context,
        title: '派单建议',
        subtitle: '按优先级与人员容量计算，确认时会再次校验版本与技能。',
        child: _RecommendDialog(state: s),
      );
    } catch (e) {
      s.toast('$e');
    }
  }
}

class _TaskCard extends StatelessWidget {
  final AppState state;
  final CareTask task;
  const _TaskCard({super.key, required this.state, required this.task});

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
        actions.add(_secondary('拒单', () => act('reject'), color: LinanColors.danger));
        actions.add(_primary('接单', () => act('accept')));
      } else if (task.state == 'accepted') {
        actions.add(_secondary('拒单', () => act('reject'), color: LinanColors.danger));
        actions.add(_secondary('开始处理', () => act('start')));
        actions.add(_primary('提交处置结果', () => _action(context, 'feedback')));
      } else if (task.state == 'processing') {
        actions.add(_primary('提交处置结果', () => _action(context, 'feedback')));
      }
    }
    if (admin && task.state == 'review') {
      actions.add(_secondary('继续跟进', () => act('followup')));
      actions.add(_primary('核实并关闭', () => _action(context, 'close')));
    }

    final hot = task.level >= 2 && task.state != 'closed';
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: LinanColors.surface,
        borderRadius: BorderRadius.circular(LinanColors.rCard),
        border: Border.all(
          color: hot ? LevelStyle.of(task.level).fg.withValues(alpha: .28) : LinanColors.borderSoft,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _detail(context),
          child: Padding(
            padding: EdgeInsets.fromLTRB(18, 15, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          LevelPill(task.level),
                          StatePill(task.state),
                          if (task.overdue)
                            Tag('已超时', color: LinanColors.danger, icon: Icons.schedule_rounded),
                        ],
                      ),
                    ),
                    SizedBox(width: 8),
                    Padding(
                      padding: EdgeInsets.only(top: 3),
                      child: Text('任务 #${task.id}',
                          style: TextStyle(fontSize: 11.5, color: LinanColors.faint, letterSpacing: .2)),
                    ),
                  ],
                ),
                SizedBox(height: 11),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        '${task.elderName} · ${task.title}',
                        style: TextStyle(
                            fontSize: 15.5, fontWeight: FontWeight.w600, color: LinanColors.text, height: 1.35, letterSpacing: -.2),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(left: 8, top: 2),
                      child: Icon(Icons.chevron_right_rounded, size: 19, color: LinanColors.faint),
                    ),
                  ],
                ),
                if (task.advice.isNotEmpty) ...[
                  SizedBox(height: 5),
                  Text(
                    task.advice,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, height: 1.6, color: LinanColors.muted),
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 14,
                  runSpacing: 7,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _meta(
                      Icons.person_outline_rounded,
                      task.staffName.isEmpty ? '待派单' : task.staffName,
                      color: task.staffName.isEmpty ? LinanColors.amber : null,
                    ),
                    _meta(Icons.medical_services_outlined, skillName(task.requiredSkill)),
                    _meta(
                      Icons.event_outlined,
                      task.due == null
                          ? '未设时限'
                          : task.overdue
                              ? '应于 ${formatStamp(task.due)} 前完成'
                              : '截止 ${formatStamp(task.due)}',
                      color: task.overdue ? LinanColors.danger : null,
                      maxWidth: 240,
                    ),
                    _meta(Icons.history_rounded, formatStamp(task.created)),
                    if (task.evidence.isNotEmpty)
                      _meta(Icons.fact_check_outlined, task.evidence.first, maxWidth: 300),
                  ],
                ),
                if (actions.isNotEmpty) ...[
                  const Divider(height: 24),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: actions,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _meta(IconData icon, String text, {Color? color, double maxWidth = 200}) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13.5, color: color ?? LinanColors.faint),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, color: color ?? LinanColors.muted),
            ),
          ),
        ],
      );

  Widget _primary(String label, VoidCallback onPressed) => FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 34),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
        ),
        child: Text(label),
      );

  Widget _secondary(String label, VoidCallback onPressed, {Color? color}) {
    final c = color ?? LinanColors.primary;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: c,
        backgroundColor: LinanColors.tint(c, .09),
        minimumSize: const Size(0, 34),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
      ),
      child: Text(label),
    );
  }

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
  static final Map<String, String> _closeOutcomes = {'safe': '已确认安全', 'data_issue': '数据问题已核查'};
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
      title: Text(_isFeedback ? '提交处置结果' : (widget.kind == 'close' ? '核实并关闭任务' : '确认操作')),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.kind == 'close')
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: LinanColors.tint(LinanColors.amber, .1),
                  borderRadius: BorderRadius.circular(LinanColors.rControl),
                ),
                child: Text(
                  '关闭后风险事件会同步关闭，老人状态回到平稳。仅当联系或上门核实确实安全时使用。',
                  style: TextStyle(fontSize: 11.5, height: 1.6, color: LinanColors.text),
                ),
              ),
            if (_needsOutcome) ...[
              Text('处置结论', style: TextStyle(fontSize: 11.5, color: LinanColors.muted, fontWeight: FontWeight.w500)),
              SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _outcome,
                decoration: InputDecoration(isDense: true),
                items: [
                  for (final e in outcomes.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 12.5))),
                ],
                onChanged: (v) => setState(() => _outcome = v ?? 'safe'),
              ),
              SizedBox(height: 14),
            ],
            Text('记录说明（至少 2 个字）',
                style: TextStyle(fontSize: 11.5, color: LinanColors.muted, fontWeight: FontWeight.w500)),
            SizedBox(height: 6),
            TextField(
              controller: _note,
              minLines: 3,
              maxLines: 5,
              maxLength: 300,
              style: TextStyle(fontSize: 12.5),
              decoration: InputDecoration(
                hintText: '例如：已电话联系，老人表示一切正常。',
                counterStyle: TextStyle(fontSize: 11.5, color: LinanColors.faint),
              ),
            ),
            if (_error != null)
              Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(_error!, style: TextStyle(fontSize: 11, color: LinanColors.danger)),
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

class _TaskDetailBody extends StatefulWidget {
  final AppState state;
  final String taskId;
  const _TaskDetailBody({required this.state, required this.taskId});

  @override
  State<_TaskDetailBody> createState() => _TaskDetailBodyState();
}

class _TaskDetailBodyState extends State<_TaskDetailBody> {
  /// 详情只在进入面板、任务切换或手动刷新时请求；写在 build 里会每次重建都重新 GET。
  late Future<TaskDetail> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.state.taskDetail(widget.taskId);
  }

  @override
  void didUpdateWidget(covariant _TaskDetailBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 任务 id 变化时重建 Future（不调用 setState，随后的 build 会使用新 Future）。
    if (oldWidget.taskId != widget.taskId) {
      _future = widget.state.taskDetail(widget.taskId);
    }
  }

  void _reload() {
    setState(() => _future = widget.state.taskDetail(widget.taskId));
  }

  Widget _refreshButton() => IconButton(
        onPressed: _reload,
        tooltip: '重新读取详情',
        icon: Icon(Icons.refresh_rounded, size: 16),
        color: LinanColors.muted,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          backgroundColor: LinanColors.surfaceAlt,
          minimumSize: Size(28, 28),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TaskDetail>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
          );
        }
        if (snap.hasError) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: EdgeInsets.fromLTRB(12, 10, 8, 10),
                decoration: BoxDecoration(
                  color: LinanColors.tint(LinanColors.danger, .09),
                  borderRadius: BorderRadius.circular(LinanColors.rControl),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded, size: 16, color: LinanColors.danger),
                    SizedBox(width: 9),
                    Expanded(
                      child: Text('${snap.error}',
                          style: TextStyle(fontSize: 11.5, height: 1.55, color: LinanColors.danger)),
                    ),
                    const SizedBox(width: 6),
                    _refreshButton(),
                  ],
                ),
              ),
            ],
          );
        }
        final d = snap.data;
        if (d == null) return EmptyHint('没有任务详情');
        return _body(d);
      },
    );
  }

  Widget _body(TaskDetail d) {
    final t = d.task;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          padding: EdgeInsets.fromLTRB(18, 15, 18, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  LevelPill(t.level),
                  SizedBox(width: 8),
                  StatePill(t.state),
                  if (t.requiredSkill.isNotEmpty) ...[
                    SizedBox(width: 8),
                    Tag(skillName(t.requiredSkill)),
                  ],
                  Spacer(),
                  if (t.overdue) Tag('已超时', color: LinanColors.danger),
                  SizedBox(width: 6),
                  _refreshButton(),
                ],
              ),
              SizedBox(height: 10),
              KeyValue('老人', t.elderName),
              KeyValue('负责人', t.staffName.isEmpty ? '待派单' : t.staffName),
              KeyValue('创建时间', formatStamp(t.created)),
              KeyValue('处理时限', formatStamp(t.due, empty: '未设置')),
              KeyValue('当前版本', '${t.version}'),
            ],
          ),
        ),
        SizedBox(height: 14),
        SectionCard(
          title: '判断依据',
          icon: Icons.fact_check_outlined,
          child: t.evidence.isEmpty
              ? Text('暂无补充依据', style: TextStyle(fontSize: 12, color: LinanColors.faint))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final line in t.evidence)
                      Padding(
                        padding: EdgeInsets.only(bottom: 7),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(padding: EdgeInsets.only(top: 6), child: Dot(LinanColors.amber, size: 5)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(line, style: TextStyle(fontSize: 12, height: 1.65, color: LinanColors.text)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        SizedBox(height: 14),
        SectionCard(
          title: '处置建议',
          icon: Icons.lightbulb_outline_rounded,
          child: Text(
            t.advice.isEmpty ? '按社区流程核实并留痕。' : t.advice,
            style: TextStyle(fontSize: 12, height: 1.7, color: LinanColors.muted),
          ),
        ),
        SizedBox(height: 14),
        SectionCard(
          title: '处置反馈',
          icon: Icons.forum_outlined,
          child: d.feedback.isEmpty
              ? Text('尚未提交反馈', style: TextStyle(fontSize: 12, color: LinanColors.faint))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final f in d.feedback)
                      Container(
                        margin: EdgeInsets.only(bottom: 8),
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: LinanColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(LinanColors.rControl),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Tag(outcomeName('${f['outcome'] ?? ''}'),
                                    color: '${f['outcome']}' == 'safe' ? LinanColors.green : LinanColors.amber),
                                Spacer(),
                                Text(formatStamp(f['created'] is num ? f['created'] as num : null),
                                    style: TextStyle(fontSize: 11, color: LinanColors.faint)),
                              ],
                            ),
                            if ('${f['note'] ?? ''}'.isNotEmpty)
                              Padding(
                                padding: EdgeInsets.only(top: 6),
                                child: Text('${f['note']}',
                                    style: TextStyle(fontSize: 12, height: 1.6, color: LinanColors.text)),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        SizedBox(height: 14),
        SectionCard(
          title: '审计时间线',
          icon: Icons.history_rounded,
          child: d.audit.isEmpty
              ? Text('暂无审计记录', style: TextStyle(fontSize: 12, color: LinanColors.faint))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final a in d.audit.reversed) _auditRow(a),
                  ],
                ),
        ),
        if (d.agentRuns.isNotEmpty) ...[
          SizedBox(height: 14),
          SectionCard(
            title: 'Agent 运行记录',
            icon: Icons.auto_awesome_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final run in d.agentRuns)
                  Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${runKindName('${run['kind'] ?? ''}')} #${run['id']}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: LinanColors.text),
                              ),
                            ),
                            SizedBox(width: 8),
                            Tag(modeName('${run['mode'] ?? ''}'), color: LinanColors.primary),
                            SizedBox(width: 8),
                            Text(runStatusName('${run['status'] ?? ''}'),
                                style: TextStyle(fontSize: 11.5, color: LinanColors.muted)),
                          ],
                        ),
                        if ('${run['summary'] ?? ''}'.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text('${run['summary']}',
                                style: TextStyle(fontSize: 11.5, height: 1.55, color: LinanColors.muted)),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// 审计行：action 中文名 + payload 关键字段；没有可读字段时退回操作者与时间。
  Widget _auditRow(Map<String, dynamic> a) {
    final detail = auditDetail(a);
    final actor = auditActor(a['actor']);
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 5),
            child: Dot(a['action'] == 'task_close' ? LinanColors.green : LinanColors.border, size: 6),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              detail.isEmpty ? '${auditName(a['action'])} · $actor' : '${auditName(a['action'])} · $detail',
              style: TextStyle(fontSize: 11.5, height: 1.55, color: LinanColors.text),
            ),
          ),
          SizedBox(width: 8),
          Text(formatStamp(a['created'] is num ? a['created'] as num : null),
              style: TextStyle(fontSize: 11, color: LinanColors.faint)),
        ],
      ),
    );
  }
}

String auditName(dynamic action) => auditNames['$action'] ?? '$action';

/// audit 表没有 note 列，关键说明在 payload 里；按可读性挑出有内容的字段。
String auditDetail(Map<String, dynamic> row) {
  final payload = row['payload'];
  if (payload is! Map) return '';
  final parts = <String>[];

  final note = '${payload['note'] ?? ''}'.trim();
  if (note.isNotEmpty) parts.add(note);

  final reason = '${payload['adjustment_reason'] ?? ''}'.trim();
  if (reason.isNotEmpty) parts.add('调整原因：$reason');

  final outcome = '${payload['outcome'] ?? ''}'.trim();
  if (outcome.isNotEmpty) parts.add('结论：${outcomeName(outcome)}');

  final after = '${payload['after'] ?? ''}'.trim();
  if (after.isNotEmpty) parts.add('状态转至${stateName(after)}');

  final level = payload['level'];
  if (level is num) parts.add(levelName(level.toInt()));

  final kind = '${payload['kind'] ?? ''}'.trim();
  if (kind.isNotEmpty) parts.add(kindName(kind));

  final chosen = payload['chosen_staff'];
  if (chosen != null) parts.add('负责人 #$chosen');

  return parts.join(' · ');
}

String auditActor(dynamic actor) {
  final name = '${actor ?? ''}'.trim();
  if (name.isEmpty) return '系统';
  return name == 'system' ? '系统' : name;
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
    }
  }

  /// 推荐结果可能在面板打开期间刷新，这里按需创建原因输入框的控制器。
  TextEditingController _reason(String id) => _reasons.putIfAbsent(id, () => TextEditingController());

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
    if (recs.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EmptyHint(s.recNote.isEmpty ? '当前没有待派任务' : s.recNote, icon: Icons.task_alt_rounded),
          if (s.unassigned.isNotEmpty) ...[
            SizedBox(height: 8),
            SectionCard(
              title: '未能分配的任务',
              icon: Icons.report_outlined,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [for (final id in s.unassigned) Tag('任务 #$id', color: LinanColors.amber)],
              ),
            ),
          ],
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final r in recs) _recRow(s, r),
        if (s.unassigned.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: 2, bottom: 8),
            child: Text(
              '另有 ${s.unassigned.length} 条任务暂时无法分配：${s.unassigned.map((e) => '#$e').join('、')}',
              style: TextStyle(fontSize: 11, height: 1.55, color: LinanColors.amber),
            ),
          ),
        if (s.recNote.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: 2, bottom: 8),
            child: Text(s.recNote, style: TextStyle(fontSize: 11, height: 1.55, color: LinanColors.faint)),
          ),
        SizedBox(height: 4),
        Text('推荐 ${recs.length} 条 · 5 分钟内有效',
            style: TextStyle(fontSize: 11, color: LinanColors.faint)),
      ],
    );
  }

  Widget _recRow(AppState s, Recommendation r) {
    final task = s.taskById(r.taskId);
    final chosen = _staffChoice[r.id] ?? r.staffId;
    final changed = chosen != r.staffId;
    final candidates = s.staff.where((p) => p.onDuty && p.available && !p.busy).toList();
    if (!candidates.any((p) => p.id == chosen)) {
      // 推荐结果里的人员可能刚变得不可派单；保留为选项，避免下拉值与 item 列表不一致。
      final current = s.staffById(chosen);
      if (current != null) candidates.add(current);
    }
    final value = candidates.any((p) => p.id == chosen) ? chosen : null;
    return SectionCard(
      padding: EdgeInsets.fromLTRB(15, 13, 15, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              LevelPill(r.level),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  task == null ? '任务 #${r.taskId}' : '${task.elderName} · ${task.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: LinanColors.text),
                ),
              ),
              SizedBox(width: 8),
              Text(
                r.eta > 0 ? '预计 ${r.eta} 分钟到达' : '等待计算到达时间',
                style: TextStyle(fontSize: 11.5, color: LinanColors.muted),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(r.reason, style: TextStyle(fontSize: 11.5, height: 1.55, color: LinanColors.muted)),
          SizedBox(height: 10),
          Row(
            children: [
              Text('负责人', style: TextStyle(fontSize: 11.5, color: LinanColors.muted)),
              SizedBox(width: 10),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: DropdownButton<int>(
                    value: value,
                    isDense: true,
                    underline: SizedBox.shrink(),
                    borderRadius: BorderRadius.circular(LinanColors.rControl),
                    hint: Text('暂无可用人员', style: TextStyle(fontSize: 11.5, color: LinanColors.faint)),
                    style: TextStyle(fontSize: 12, color: LinanColors.text, fontWeight: FontWeight.w500),
                    items: [
                      for (final p in candidates)
                        DropdownMenuItem(
                          value: p.id,
                          child: Text('${p.name} · ${p.location}号楼', style: const TextStyle(fontSize: 12)),
                        ),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _staffChoice[r.id] = v);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: _submitting
                    ? null
                    : () async {
                        final reason = _reason(r.id).text.trim();
                        if (changed && reason.length < 2) {
                          s.toast('调整负责人需要填写原因');
                          return;
                        }
                        setState(() => _submitting = true);
                        try {
                          await s.confirmRecommendation(r, value ?? chosen, changed ? reason : '');
                          if (!mounted) return;
                          setState(() {});
                        } on Object catch (e) {
                          s.toast('$e');
                        } finally {
                          if (mounted) setState(() => _submitting = false);
                        }
                      },
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
                child: const Text('确认派单'),
              ),
            ],
          ),
          if (changed) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _reason(r.id),
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                isDense: true,
                hintText: '调整原因（至少 2 字）',
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
