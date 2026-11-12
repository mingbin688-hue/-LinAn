import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
                  final mcpCard = _mcpCard();
                  final runsPanel = _runsPanel(runs, kinds);
                  final jobsPanel = _jobsPanel();
                  final left = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [catalogue, const SizedBox(height: 12), mcpCard],
                  );
                  final right = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [runsPanel, const SizedBox(height: 12), jobsPanel],
                  );
                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 330, child: left),
                        const SizedBox(width: 12),
                        Expanded(child: right),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [left, const SizedBox(height: 12), right],
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

  Widget _mcpCard() {
    final mcp = s.mcpStatus;
    final tokens = mcp?.tokens ?? const <McpToken>[];
    return SectionCard(
      title: 'MCP 接入',
      subtitle: '模型客户端通过受限 MCP 接口访问记录；令牌由管理员签发。',
      trailing: IconButton(
        onPressed: s.loadMcp,
        icon: const Icon(Icons.refresh, size: 17),
        tooltip: '刷新 MCP 状态',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (mcp == null)
            s.workflowsLoading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
                  )
                : const EmptyHint('尚未获取 MCP 状态', icon: Icons.cable_outlined)
          else ...[
            Container(
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
              decoration: BoxDecoration(color: LinanColors.surfaceAlt, borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          mcp.endpoint.isEmpty ? '/mcp' : mcp.endpoint,
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, fontFamily: 'monospace'),
                        ),
                      ),
                      if (mcp.protocol.isNotEmpty) Tag('协议 ${mcp.protocol}', color: LinanColors.primary),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '工具 ${mcp.tools} · 资源 ${mcp.resources} · 提示 ${mcp.prompts}',
                    style: const TextStyle(fontSize: 9.5, color: LinanColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(
                  child: Text('访问令牌', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                ),
                TextButton.icon(
                  onPressed: _createToken,
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('新建令牌', style: TextStyle(fontSize: 10)),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 26),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            if (tokens.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 2, bottom: 2),
                child: Text('还没有签发令牌', style: TextStyle(fontSize: 10, color: LinanColors.faint)),
              )
            else
              for (final t in tokens) _tokenRow(t),
          ],
        ],
      ),
    );
  }

  Widget _tokenRow(McpToken token) {
    final expired = token.expired;
    final status = token.revoked ? '已撤销' : (expired ? '已过期' : '');
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
      decoration: BoxDecoration(
        color: LinanColors.surfaceAlt.withValues(alpha: .6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: LinanColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  token.label.isEmpty ? token.id : token.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
              if (status.isNotEmpty)
                Tag(status, color: token.revoked ? LinanColors.faint : LinanColors.danger,
                    icon: token.revoked ? null : Icons.error_outline),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            '${token.username.isEmpty ? '—' : token.username} · ${_tokenExpiry(token)}',
            style: const TextStyle(fontSize: 9.5, color: LinanColors.muted),
          ),
          Text(
            '最后使用 ${formatStamp(token.lastUsed, empty: '未使用')}',
            style: const TextStyle(fontSize: 9, color: LinanColors.faint),
          ),
          if (!token.revoked)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _revokeToken(token),
                style: TextButton.styleFrom(
                  foregroundColor: LinanColors.danger,
                  minimumSize: const Size(0, 24),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('撤销', style: TextStyle(fontSize: 10)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _runsPanel(List<WorkflowRun> runs, Map<String, String> kinds) {
    final stats = s.workflowStats;
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
          if (stats != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '共 ${stats.runsTotal} 次运行 · 等待人工 ${stats.runsWaitingHuman} · 失败 ${stats.runsFailed}',
                style: const TextStyle(fontSize: 9.5, color: LinanColors.faint),
              ),
            ),
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
                items: [
                  const DropdownMenuItem(value: 'all', child: Text('全部状态')),
                  for (final status in const ['queued', 'running', 'waiting_human', 'completed', 'failed', 'cancelled'])
                    DropdownMenuItem(value: status, child: Text(runStatusName(status))),
                ],
                onChanged: (v) => setState(() => _status = v ?? 'all'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (runs.isEmpty)
            s.workflowsLoading && s.runs.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 22),
                    child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
                  )
                : EmptyHint(s.runs.isEmpty ? '还没有运行记录' : '没有符合筛选条件的运行', icon: Icons.account_tree_outlined)
          else ...[
            for (final r in runs) _runRow(r),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '已展示全部 ${runs.length} 条；后端最多返回最近 200 条运行记录。',
                style: const TextStyle(fontSize: 9, color: LinanColors.faint),
              ),
            ),
          ],
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
              decoration: BoxDecoration(color: _runStatusColor(r.status), shape: BoxShape.circle),
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

  Widget _jobsPanel() {
    final stats = s.workflowStats;
    return SectionCard(
      title: '持久化任务',
      subtitle: '解释生成任务先写入队列，再由调度器执行；失败与死信可以重试。',
      trailing: IconButton(
        onPressed: s.loadJobs,
        icon: const Icon(Icons.refresh, size: 17),
        tooltip: '刷新持久化任务',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (stats != null)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Tag('排队 ${stats.jobsQueued}', color: LinanColors.amber, icon: Icons.schedule),
                Tag('执行中 ${stats.jobsRunning}', color: LinanColors.primary, icon: Icons.play_circle_outline),
                Tag('已完成 ${stats.jobsDone}', color: LinanColors.green, icon: Icons.check_circle_outline),
                Tag('失败 ${stats.jobsFailed}', color: LinanColors.danger, icon: Icons.error_outline),
                Tag('死信 ${stats.jobsDead}', color: LinanColors.danger, icon: Icons.report_gmailerrorred_outlined),
                Tag('最久排队 ${_secondsText(stats.oldestQueuedSeconds)}', color: LinanColors.warm, icon: Icons.timer_outlined),
              ],
            ),
          if (stats != null) const SizedBox(height: 10),
          if (s.jobs.isEmpty)
            s.workflowsLoading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 22),
                    child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
                  )
                : const EmptyHint('还没有持久化任务', icon: Icons.dns_outlined)
          else ...[
            for (final job in s.jobs) _jobRow(job),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '已展示全部 ${s.jobs.length} 条；后端最多返回最近 50 条持久化任务。',
                style: const TextStyle(fontSize: 9, color: LinanColors.faint),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _jobRow(WorkflowJob job) {
    final color = _jobStateColor(job.state);
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 7),
      decoration: BoxDecoration(
        color: LinanColors.surfaceAlt.withValues(alpha: .5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Dot(color, size: 6),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${job.id} · ${jobKindLabel(job.kind)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 6),
              Tag(jobStateLabel(job.state), color: color),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text('尝试 ${job.attempts}/${job.maxAttempts}', style: const TextStyle(fontSize: 9.5, color: LinanColors.muted)),
              const SizedBox(width: 10),
              Text('优先级 ${job.priority}', style: const TextStyle(fontSize: 9.5, color: LinanColors.faint)),
              const Spacer(),
              Text(formatStamp(job.created), style: const TextStyle(fontSize: 9.5, color: LinanColors.faint)),
            ],
          ),
          if (job.key.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('关联 ${job.key}', style: const TextStyle(fontSize: 9, color: LinanColors.faint)),
            ),
          if (job.lastError.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                job.lastError,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 9.5, height: 1.5, color: LinanColors.danger),
              ),
            ),
          if (job.retryable || job.cancellable)
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (job.cancellable)
                    TextButton(
                      onPressed: () => _cancelJob(job),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 26),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('取消', style: TextStyle(fontSize: 10)),
                    ),
                  if (job.retryable)
                    TextButton(
                      onPressed: () => _retryJob(job),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 26),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('重试', style: TextStyle(fontSize: 10)),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _retryJob(WorkflowJob job) async {
    try {
      await s.retryJob(job.id);
    } on Object catch (_) {
      // 失败已由状态层 toast 提示。
    }
  }

  Future<void> _cancelJob(WorkflowJob job) async {
    final ok = await confirmDialog(
      context,
      title: '取消任务',
      body: '取消「${job.id}」后，该任务不会再被执行。',
      confirmText: '取消任务',
      cancelText: '保留',
      danger: true,
    );
    if (!ok || !mounted) return;
    try {
      await s.cancelJob(job.id);
    } on Object catch (_) {
      // 失败已由状态层 toast 提示。
    }
  }

  Future<void> _createToken() async {
    final draft = await showDialog<_TokenDraft>(context: context, builder: (_) => const _NewTokenDialog());
    if (draft == null || !mounted) return;
    try {
      final issued = await s.createMcpToken(label: draft.label, expiresHours: draft.hours);
      if (!mounted) return;
      await _revealToken(issued);
    } on Object catch (_) {
      // 失败已由状态层 toast 提示。
    }
  }

  Future<void> _revealToken(IssuedMcpToken issued) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.vpn_key_outlined, size: 18, color: LinanColors.primary),
            SizedBox(width: 8),
            Text('令牌已创建', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${issued.label} · ${issued.username}',
                  style: const TextStyle(fontSize: 11, color: LinanColors.muted)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: LinanColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: LinanColors.borderSoft),
                ),
                child: SelectableText(
                  issued.token,
                  style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace', height: 1.5),
                ),
              ),
              const SizedBox(height: 8),
              const Text('明文只显示这一次，关闭后无法再次查看。',
                  style: TextStyle(fontSize: 10, color: LinanColors.amber)),
              if (issued.expires > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text('有效期至 ${formatStamp(issued.expires)}',
                      style: const TextStyle(fontSize: 9.5, color: LinanColors.faint)),
                ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: issued.token));
              s.toast('已复制令牌明文');
            },
            icon: const Icon(Icons.copy_all_outlined, size: 15),
            label: const Text('复制'),
          ),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('我已保存')),
        ],
      ),
    );
  }

  Future<void> _revokeToken(McpToken token) async {
    final ok = await confirmDialog(
      context,
      title: '撤销令牌',
      body: '撤销「${token.label.isEmpty ? token.id : token.label}」后，使用该令牌的客户端会立即失去访问权限。',
      confirmText: '撤销',
      danger: true,
    );
    if (!ok || !mounted) return;
    try {
      await s.revokeMcpToken(token.id);
    } on Object catch (_) {
      // 失败已由状态层 toast 提示。
    }
  }

  void _openRun(WorkflowRun r) {
    showSideSheet(
      context,
      title: '${runKindName(r.kind)} #${r.id}',
      subtitle: '${modeName(r.mode)} · ${runStatusName(r.status)} · ${formatStamp(r.created)}',
      child: _RunDetail(state: s, runId: r.id),
    );
  }
}

/// 运行详情侧栏：定义版本、失败/取消重试与节点时间线。
class _RunDetail extends StatefulWidget {
  final AppState state;
  final String runId;
  const _RunDetail({required this.state, required this.runId});

  @override
  State<_RunDetail> createState() => _RunDetailState();
}

class _RunDetailState extends State<_RunDetail> {
  late Future<WorkflowRun> _future;
  bool _retrying = false;

  AppState get s => widget.state;

  @override
  void initState() {
    super.initState();
    _future = s.runDetail(widget.runId);
  }

  Future<void> _retry(BuildContext dialogContext, String id) async {
    setState(() => _retrying = true);
    try {
      await s.retryRun(id);
      if (!mounted || !dialogContext.mounted) return;
      Navigator.of(dialogContext).pop();
    } on Object catch (_) {
      // 失败已由状态层 toast 提示。
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WorkflowRun>(
      future: _future,
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
        final definition = detail.definition;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (definition != null || detail.retryable)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (definition != null) ...[
                      Tag('定义 v${definition.version}', color: LinanColors.primary, icon: Icons.schema_outlined),
                      if (definition.title.isNotEmpty)
                        Text(definition.title, style: const TextStyle(fontSize: 10.5, color: LinanColors.muted)),
                    ],
                    if (detail.retryable)
                      FilledButton.icon(
                        onPressed: _retrying ? null : () => _retry(context, detail.id),
                        icon: _retrying
                            ? const SizedBox(
                                width: 13,
                                height: 13,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.replay, size: 15),
                        label: const Text('重试运行', style: TextStyle(fontSize: 11.5)),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 32),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                  ],
                ),
              ),
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
    );
  }

  Widget _node(RunNode node, bool last) {
    final ok = node.status == 'completed' || node.status == 'ok';
    final color = node.error.isNotEmpty || node.status == 'failed'
        ? LinanColors.danger
        : ok
            ? LinanColors.green
            : LinanColors.amber;
    final timeNote = [
      if (node.attempts > 1) '第 ${node.attempts} 次尝试',
      if (node.started != null)
        '${formatClock(node.started)}${node.finished != null ? '–${formatClock(node.finished)}' : ' 起'}',
    ].join(' · ');
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
                  if (timeNote.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(timeNote, style: const TextStyle(fontSize: 8.5, color: LinanColors.faint)),
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

class _TokenDraft {
  final String label;
  final int hours;
  const _TokenDraft(this.label, this.hours);
}

class _NewTokenDialog extends StatefulWidget {
  const _NewTokenDialog();

  @override
  State<_NewTokenDialog> createState() => _NewTokenDialogState();
}

class _NewTokenDialogState extends State<_NewTokenDialog> {
  static const List<(int, String)> _presets = [
    (24, '1 天'),
    (168, '7 天'),
    (720, '30 天'),
    (8760, '365 天'),
  ];

  final TextEditingController _label = TextEditingController();
  int _hours = 168;
  String? _error;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  void _submit() {
    final label = _label.text.trim();
    if (label.isEmpty) {
      setState(() => _error = '请填写令牌标签');
      return;
    }
    Navigator.of(context).pop(_TokenDraft(label, _hours));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('新建 MCP 令牌', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _label,
              autofocus: true,
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(labelText: '令牌标签', hintText: '例如：桌面客户端'),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(_error!, style: const TextStyle(fontSize: 10, color: LinanColors.danger)),
              ),
            const SizedBox(height: 14),
            const Text('有效期', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final preset in _presets)
                  ChoiceChip(
                    label: Text(preset.$2, style: const TextStyle(fontSize: 10)),
                    selected: _hours == preset.$1,
                    onSelected: (_) => setState(() => _hours = preset.$1),
                    showCheckmark: false,
                    visualDensity: VisualDensity.compact,
                    selectedColor: LinanColors.primarySoft,
                    backgroundColor: LinanColors.surfaceAlt,
                    side: BorderSide.none,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              '明文 token 只在创建成功时显示一次；请立即复制并妥善保存。',
              style: TextStyle(fontSize: 9.5, height: 1.6, color: LinanColors.faint),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消')),
        FilledButton(onPressed: _submit, child: const Text('创建')),
      ],
    );
  }
}

Color _runStatusColor(String status) {
  switch (status) {
    case 'failed':
      return LinanColors.danger;
    case 'waiting_human':
      return LinanColors.amber;
    case 'cancelled':
      return LinanColors.faint;
    case 'queued':
      return LinanColors.warm;
    default:
      return LinanColors.primary;
  }
}

Color _jobStateColor(String state) {
  switch (state) {
    case 'running':
      return LinanColors.primary;
    case 'done':
      return LinanColors.green;
    case 'failed':
    case 'dead':
      return LinanColors.danger;
    case 'queued':
      return LinanColors.amber;
    default:
      return LinanColors.faint;
  }
}

String _secondsText(double value) {
  if (value <= 0) return '0 秒';
  if (value < 10) return '${value.toStringAsFixed(1)} 秒';
  return '${value.round()} 秒';
}

String _tokenExpiry(McpToken token) {
  if (token.expires <= 0) return '长期有效';
  if (token.expired) return '已于 ${formatStamp(token.expires)} 到期';
  return '有效期至 ${formatStamp(token.expires)}';
}
