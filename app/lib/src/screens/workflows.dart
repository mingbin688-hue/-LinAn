import 'dart:convert';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../labels.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

class WorkflowsPage extends StatefulWidget {
  final AppState state;
  const WorkflowsPage({super.key, required this.state});

  @override
  State<WorkflowsPage> createState() => _WorkflowsPageState();
}

class _WorkflowsPageState extends State<WorkflowsPage> {
  String _kind = 'all';
  String _status = 'all';

  AppState get s => widget.state;

  static const List<(String, String, List<String>)> _maps = [
    (
      '风险响应',
      '从感知到人工确认，每一步都留下证据。',
      ['活动 / 报平安事件', '规则与模型判断', '建立或升级事件', '人工确认派单'],
    ),
    (
      '处置复核',
      '接单、处置、反馈、复核，闭环不跳过人工。',
      ['负责人接单', '上门或电话处置', '提交处置结论', '管理员复核关闭'],
    ),
    (
      '对话查询',
      '先校验权限，再取数，最后解释。',
      ['用户提问', '角色与对象校验', '受限工具查询', '带引用的回答'],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final kinds = <String, String>{'all': '全部类型', ...runKindNames};
    final runs = s.runs.where((r) {
      if (_kind != 'all' && r.kind != _kind) return false;
      if (_status != 'all' && r.status != _status) return false;
      return true;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1240),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionCard(
                padding: const EdgeInsets.fromLTRB(18, 15, 18, 15),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(color: LinanColors.primarySoft, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.account_tree_outlined, size: 19, color: LinanColors.primary),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('自动派单', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          SizedBox(height: 3),
                          Text(
                            '仅覆盖 1 级关注、且需要电话核实的待派任务；数据未知、优先与紧急任务仍由管理员确认。',
                            style: TextStyle(fontSize: 10.5, height: 1.55, color: LinanColors.muted),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: s.autoDispatch,
                      onChanged: (v) async {
                        try {
                          await s.setAutoDispatch(v);
                        } on Object catch (e) {
                          s.toast('$e');
                        }
                      },
                    ),
                    const SizedBox(width: 4),
                    Text(s.autoDispatch ? '已开启' : '已关闭',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: s.autoDispatch ? LinanColors.primary : LinanColors.muted,
                          fontWeight: FontWeight.w600,
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, c) {
                  final cols = c.maxWidth >= 1000 ? 3 : 1;
                  final gap = 12.0;
                  final width = (c.maxWidth - gap * (cols - 1)) / cols;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final m in _maps) SizedBox(width: width, child: _MapCard(title: m.$1, note: m.$2, steps: m.$3)),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, c) {
                  final wide = c.maxWidth >= 900;
                  final catalogue = _agentCatalogue();
                  final runsPanel = _runsPanel(runs, kinds);
                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 330, child: catalogue),
                        const SizedBox(width: 12),
                        Expanded(child: runsPanel),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [catalogue, const SizedBox(height: 12), runsPanel],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _agentCatalogue() {
    final agents = (s.agentsInfo['agents'] as List? ?? const []);
    final mode = '${s.agentsInfo['mode'] ?? 'rules'}';
    return SectionCard(
      title: 'Agent 目录',
      subtitle: '业务 Agent 负责编排与解释；风险等级仍由规则与模型判断。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Tag(mode == 'llm' ? '模型模式' : '规则模式', color: LinanColors.primary, icon: Icons.memory),
              const SizedBox(width: 6),
              Tag('禁止自动升级', color: LinanColors.muted),
            ],
          ),
          const SizedBox(height: 10),
          if (agents.isEmpty)
            const Text('暂无 Agent 目录数据', style: TextStyle(fontSize: 10.5, color: LinanColors.faint))
          else
            for (final a in agents.take(8))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(padding: EdgeInsets.only(top: 4), child: Dot(LinanColors.primary, size: 5)),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${a['name'] ?? a['id'] ?? 'Agent'}',
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                          if ('${a['description'] ?? a['role'] ?? ''}'.isNotEmpty)
                            Text('${a['description'] ?? a['role']}',
                                style: const TextStyle(fontSize: 9.5, height: 1.5, color: LinanColors.muted)),
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

  Widget _runsPanel(List<WorkflowRun> runs, Map<String, String> kinds) {
    return SectionCard(
      title: '运行记录',
      subtitle: '每次风险响应、处置复核与对话查询都可追溯到节点。',
      trailing: IconButton(
        onPressed: () async {
          try {
            await s.loadRuns();
          } on Object catch (e) {
            s.toast('$e');
          }
        },
        icon: const Icon(Icons.refresh, size: 17),
        tooltip: '刷新运行记录',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final e in kinds.entries)
                ChoiceChip(
                  label: Text(e.value, style: const TextStyle(fontSize: 10)),
                  selected: _kind == e.key,
                  onSelected: (_) => setState(() => _kind = e.key),
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  selectedColor: LinanColors.primarySoft,
                  backgroundColor: LinanColors.surfaceAlt,
                  side: BorderSide.none,
                ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _status,
                underline: const SizedBox.shrink(),
                style: const TextStyle(fontSize: 10, color: LinanColors.muted),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('全部状态')),
                  DropdownMenuItem(value: 'completed', child: Text('已完成')),
                  DropdownMenuItem(value: 'running', child: Text('执行中')),
                  DropdownMenuItem(value: 'waiting_human', child: Text('等待人工')),
                  DropdownMenuItem(value: 'failed', child: Text('失败')),
                ],
                onChanged: (v) => setState(() => _status = v ?? 'all'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (runs.isEmpty)
            const EmptyHint('还没有运行记录', icon: Icons.account_tree_outlined)
          else
            for (final r in runs.take(20)) _runRow(r),
        ],
      ),
    );
  }

  Widget _runRow(WorkflowRun r) {
    return InkWell(
      onTap: () => _openRun(r),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: LinanColors.surfaceAlt.withValues(alpha: .5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: r.status == 'failed'
                    ? LinanColors.danger
                    : r.status == 'waiting_human'
                        ? LinanColors.amber
                        : LinanColors.primary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('${runKindName(r.kind)} #${r.id}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 6),
                      Tag(modeName(r.mode), color: LinanColors.primary),
                      if (r.historical) ...[
                        const SizedBox(width: 4),
                        const Tag('历史快照', color: LinanColors.amber),
                      ],
                    ],
                  ),
                  if (r.summary.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(r.summary,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 9.5, color: LinanColors.muted)),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(runStatusName(r.status), style: const TextStyle(fontSize: 9.5, color: LinanColors.muted)),
                Text(formatStamp(r.created), style: const TextStyle(fontSize: 8.5, color: LinanColors.faint)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openRun(WorkflowRun r) {
    showSideSheet(
      context,
      title: '${runKindName(r.kind)} #${r.id}',
      subtitle: '${modeName(r.mode)} · ${runStatusName(r.status)} · ${formatStamp(r.created)}',
      child: FutureBuilder<WorkflowRun>(
        future: s.runDetail(r.id),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          if (snap.hasError) return EmptyHint('${snap.error}', icon: Icons.error_outline);
          final detail = snap.data;
          if (detail == null) return const EmptyHint('没有运行详情');
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (detail.summary.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(color: LinanColors.surfaceAlt, borderRadius: BorderRadius.circular(8)),
                  child: Text(detail.summary, style: const TextStyle(fontSize: 11.5, height: 1.65)),
                ),
              const SizedBox(height: 12),
              for (var i = 0; i < detail.nodes.length; i++) _node(detail.nodes[i], i == detail.nodes.length - 1),
              if (detail.nodes.isEmpty) const EmptyHint('这条运行没有节点记录'),
            ],
          );
        },
      ),
    );
  }

  Widget _node(RunNode node, bool last) {
    final ok = node.status == 'completed' || node.status == 'ok';
    final color = node.error.isNotEmpty || node.status == 'failed'
        ? LinanColors.danger
        : ok
            ? LinanColors.green
            : LinanColors.amber;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 22,
            child: Column(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                if (!last)
                  Expanded(
                    child: Container(width: 1.2, color: LinanColors.border),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(node.name.isEmpty ? (agentNames[node.agent] ?? node.agent) : node.name,
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                      ),
                      Tag(node.mode.isEmpty ? '规则' : modeName(node.mode), color: LinanColors.muted),
                      const SizedBox(width: 5),
                      Text('${node.elapsedMs} ms', style: const TextStyle(fontSize: 8.5, color: LinanColors.faint)),
                    ],
                  ),
                  if (node.summary.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(node.summary, style: const TextStyle(fontSize: 10.5, height: 1.55, color: LinanColors.muted)),
                    ),
                  if (node.evidence.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final e in node.evidence.take(4))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text('· $e', style: const TextStyle(fontSize: 9.5, height: 1.5, color: LinanColors.muted)),
                            ),
                        ],
                      ),
                    ),
                  if (node.error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(node.error, style: const TextStyle(fontSize: 9.5, color: LinanColors.danger)),
                    ),
                  if (node.input.isNotEmpty || node.output.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: EdgeInsets.zero,
                        dense: true,
                        title: const Text('节点数据', style: TextStyle(fontSize: 9.5, color: LinanColors.faint)),
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: LinanColors.surfaceAlt, borderRadius: BorderRadius.circular(6)),
                            child: SelectableText(
                              const JsonEncoder.withIndent('  ').convert({
                                'input': node.input,
                                'output': node.output,
                              }),
                              style: const TextStyle(fontSize: 9, height: 1.5, fontFamily: 'monospace'),
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapCard extends StatelessWidget {
  final String title;
  final String note;
  final List<String> steps;
  const _MapCard({required this.title, required this.note, required this.steps});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(note, style: const TextStyle(fontSize: 9.5, height: 1.5, color: LinanColors.muted)),
          const SizedBox(height: 10),
          for (var i = 0; i < steps.length; i++)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 16,
                  height: 16,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == steps.length - 1 ? LinanColors.primary : LinanColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('${i + 1}',
                      style: TextStyle(fontSize: 8.5, color: i == steps.length - 1 ? Colors.white : LinanColors.muted)),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(steps[i], style: const TextStyle(fontSize: 10.5, height: 1.5)),
                  ),
                ),
              ],
            ),
          if (steps.length > 1)
            Padding(
              padding: const EdgeInsets.only(left: 7.5, top: 2, bottom: 2),
              child: Container(width: 1, height: 2, color: LinanColors.border),
            ),
        ],
      ),
    );
  }
}
