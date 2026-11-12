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

  static const List<String> _statusOptions = [
    'all',
    'queued',
    'running',
    'waiting_human',
    'completed',
    'failed',
    'cancelled',
  ];

  @override
  Widget build(BuildContext context) {
    final kinds = <String, String>{'all': '全部类型', ...runKindNames};
    final runs = s.runs.where((r) {
      if (_kind != 'all' && r.kind != _kind) return false;
      if (_status != 'all' && r.status != _status) return false;
      return true;
    }).toList();

    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 980;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(wide ? 24 : 16, 0, wide ? 24 : 16, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PageHeader(
                    padding: const EdgeInsets.only(top: 26, bottom: 16),
                    title: '工作流中心',
                    subtitle: '风险响应、处置复核与对话查询的运行轨迹。',
                    icon: Icons.account_tree_rounded,
                    accent: LinanColors.indigo,
                    actions: [
                      Tag(
                        s.workflowsLoading ? '同步中' : '可追溯',
                        color: s.workflowsLoading ? LinanColors.amber : LinanColors.green,
                        icon: s.workflowsLoading ? Icons.sync_rounded : Icons.verified_rounded,
                      ),
                    ],
                  ),
                  _autoDispatchCard(),
                  const SizedBox(height: 12),
                  _flowMaps(),
                  const SizedBox(height: 12),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 340,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _agentCatalogue(),
                              const SizedBox(height: 12),
                              _mcpCard(),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _runsPanel(runs, kinds),
                              const SizedBox(height: 12),
                              _jobsPanel(),
                            ],
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _runsPanel(runs, kinds),
                        const SizedBox(height: 12),
                        _jobsPanel(),
                        const SizedBox(height: 12),
                        _agentCatalogue(),
                        const SizedBox(height: 12),
                        _mcpCard(),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _autoDispatchCard() {
    return SectionCard(
      padding: EdgeInsets.fromLTRB(18, 15, 16, 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconTile(Icons.bolt_rounded, color: LinanColors.amber, size: 38, iconSize: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('自动派单',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: LinanColors.text)),
                SizedBox(height: 3),
                Text(
                  '仅覆盖 1 级关注、且需要电话核实的待派任务；数据未知、优先与紧急任务仍由管理员确认。',
                  style: TextStyle(fontSize: 11.5, height: 1.55, color: LinanColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Tag(
            s.autoDispatch ? '已开启' : '已关闭',
            color: s.autoDispatch ? LinanColors.green : LinanColors.muted,
            icon: s.autoDispatch ? Icons.check_circle_outline : Icons.pause_circle_outline,
          ),
          const SizedBox(width: 8),
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
        ],
      ),
    );
  }

  Widget _flowMaps() {
    return LayoutBuilder(
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
    );
  }

  Widget _agentCatalogue() {
    final agents = (s.agentsInfo['agents'] as List? ?? []);
    final mode = '${s.agentsInfo['mode'] ?? 'rules'}';
    return SectionCard(
      title: 'Agent 目录',
      subtitle: '业务 Agent 负责编排与解释；风险等级仍由规则与模型判断。',
      icon: Icons.smart_toy_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Tag(mode == 'llm' ? '模型模式' : '规则模式',
                  color: LinanColors.primary, icon: Icons.memory_rounded),
              Tag('禁止自动升级', color: LinanColors.muted, icon: Icons.lock_outline_rounded),
            ],
          ),
          SizedBox(height: 12),
          if (agents.isEmpty)
            EmptyHint('暂无 Agent 目录数据', icon: Icons.smart_toy_outlined)
          else
            for (var i = 0; i < agents.take(8).length; i++)
              Padding(
                padding: EdgeInsets.only(bottom: i == agents.take(8).length - 1 ? 0 : 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(padding: EdgeInsets.only(top: 5), child: Dot(LinanColors.primary, size: 6)),
                    SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${agents[i]['name'] ?? agents[i]['id'] ?? 'Agent'}',
                              style: TextStyle(
                                  fontSize: 12.5, fontWeight: FontWeight.w600, color: LinanColors.text)),
                          if ('${agents[i]['description'] ?? agents[i]['role'] ?? ''}'.isNotEmpty)
                            Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Text('${agents[i]['description'] ?? agents[i]['role']}',
                                  style: TextStyle(fontSize: 11, height: 1.5, color: LinanColors.muted)),
                            ),
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
      icon: Icons.cable_rounded,
      trailing: IconButton(
        onPressed: s.loadMcp,
        icon: const Icon(Icons.refresh_rounded, size: 18),
        tooltip: '刷新 MCP 状态',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (mcp == null)
            s.workflowsLoading
                ? Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
                  )
                : EmptyHint('尚未获取 MCP 状态', icon: Icons.cable_outlined)
          else ...[
            Container(
              padding: EdgeInsets.fromLTRB(12, 11, 12, 11),
              decoration: BoxDecoration(
                color: LinanColors.surfaceAlt,
                borderRadius: BorderRadius.circular(LinanColors.rControl),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          mcp.endpoint.isEmpty ? '/mcp' : mcp.endpoint,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w600, fontFamily: 'Consolas'),
                        ),
                      ),
                      if (mcp.protocol.isNotEmpty) Tag('协议 ${mcp.protocol}', color: LinanColors.primary),
                    ],
                  ),
                  SizedBox(height: 5),
                  Text(
                    '工具 ${mcp.tools} · 资源 ${mcp.resources} · 提示 ${mcp.prompts}',
                    style: TextStyle(fontSize: 11, color: LinanColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text('访问令牌',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: LinanColors.text)),
                ),
                TextButton.icon(
                  onPressed: _createToken,
                  icon: const Icon(Icons.add_rounded, size: 15),
                  label: const Text('新建令牌'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 28),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            if (tokens.isEmpty)
              Padding(
                padding: EdgeInsets.only(top: 2, bottom: 2),
                child: Text('还没有签发令牌', style: TextStyle(fontSize: 11, color: LinanColors.faint)),
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
      margin: EdgeInsets.only(top: 8),
      padding: EdgeInsets.fromLTRB(11, 10, 11, 8),
      decoration: BoxDecoration(
        color: LinanColors.surfaceAlt.withValues(alpha: .7),
        borderRadius: BorderRadius.circular(LinanColors.rControl),
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
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: LinanColors.text),
                ),
              ),
              if (status.isNotEmpty)
                Tag(status,
                    color: token.revoked ? LinanColors.faint : LinanColors.danger,
                    icon: token.revoked ? null : Icons.error_outline_rounded),
            ],
          ),
          SizedBox(height: 4),
          Text(
            '${token.username.isEmpty ? '—' : token.username} · ${_tokenExpiry(token)}',
            style: TextStyle(fontSize: 11, color: LinanColors.muted),
          ),
          Text(
            '最后使用 ${formatStamp(token.lastUsed, empty: '未使用')}',
            style: TextStyle(fontSize: 11.5, color: LinanColors.faint),
          ),
          if (!token.revoked)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _revokeToken(token),
                style: TextButton.styleFrom(
                  foregroundColor: LinanColors.danger,
                  minimumSize: const Size(0, 26),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('撤销', style: TextStyle(fontSize: 11)),
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
      icon: Icons.route_rounded,
      trailing: IconButton(
        onPressed: () async {
          try {
            await s.loadRuns();
          } on Object catch (e) {
            s.toast('$e');
          }
        },
        icon: Icon(Icons.refresh_rounded, size: 18),
        tooltip: '刷新运行记录',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (stats != null)
            Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  Tag('共 ${stats.runsTotal} 次运行', color: LinanColors.muted, icon: Icons.history_rounded),
                  Tag('等待人工 ${stats.runsWaitingHuman}',
                      color: stats.runsWaitingHuman > 0 ? LinanColors.amber : LinanColors.muted,
                      icon: Icons.pan_tool_outlined),
                  Tag('失败 ${stats.runsFailed}',
                      color: stats.runsFailed > 0 ? LinanColors.danger : LinanColors.muted,
                      icon: Icons.error_outline_rounded),
                ],
              ),
            ),
          SegmentedControl(
            labels: [for (final e in kinds.entries) e.value],
            selected: kinds.keys.toList().indexOf(_kind).clamp(0, kinds.length - 1),
            onChanged: (i) => setState(() => _kind = kinds.keys.elementAt(i)),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.filter_alt_outlined, size: 14, color: LinanColors.faint),
              SizedBox(width: 6),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _status,
                  isDense: true,
                  borderRadius: BorderRadius.circular(LinanColors.rControl),
                  style: TextStyle(fontSize: 11.5, color: LinanColors.muted),
                  items: [
                    for (final status in _statusOptions)
                      DropdownMenuItem(
                        value: status,
                        child: Text(status == 'all' ? '全部状态' : runStatusName(status),
                            style: const TextStyle(fontSize: 11.5)),
                      ),
                  ],
                  onChanged: (v) => setState(() => _status = v ?? 'all'),
                ),
              ),
              Spacer(),
              Text('${runs.length} 条', style: TextStyle(fontSize: 11.5, color: LinanColors.faint)),
            ],
          ),
          SizedBox(height: 8),
          if (runs.isEmpty)
            s.workflowsLoading && s.runs.isEmpty
                ? Padding(
                    padding: EdgeInsets.symmetric(vertical: 22),
                    child: Center(
                        child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
                  )
                : EmptyHint(s.runs.isEmpty ? '还没有运行记录' : '没有符合筛选条件的运行',
                    icon: Icons.account_tree_outlined)
          else ...[
            Container(
              decoration: BoxDecoration(
                color: LinanColors.surfaceAlt.withValues(alpha: .45),
                borderRadius: BorderRadius.circular(LinanColors.rControl),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < runs.length; i++) ...[
                    _runRow(runs[i]),
                    if (i != runs.length - 1) const Divider(height: .6, indent: 52, endIndent: 10),
                  ],
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                '已展示全部 ${runs.length} 条；后端最多返回最近 200 条运行记录。',
                style: TextStyle(fontSize: 11.5, color: LinanColors.faint),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _runRow(WorkflowRun r) {
    final kindIcon = r.kind == 'risk'
        ? Icons.warning_amber_rounded
        : r.kind == 'review'
            ? Icons.fact_check_outlined
            : Icons.chat_bubble_outline_rounded;
    final color = _runStatusColor(r.status);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openRun(r),
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            children: [
              IconTile(kindIcon, color: color, size: 34, iconSize: 17),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text('${runKindName(r.kind)} #${r.id}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600, color: LinanColors.text)),
                        ),
                        SizedBox(width: 6),
                        Tag(modeName(r.mode), color: LinanColors.primary),
                        if (r.historical) ...[
                          SizedBox(width: 4),
                          Tag('历史快照', color: LinanColors.amber),
                        ],
                      ],
                    ),
                    if (r.summary.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: 3),
                        child: Text(r.summary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: LinanColors.muted)),
                      ),
                  ],
                ),
              ),
              SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _RunStatusPill(r.status),
                  SizedBox(height: 4),
                  Text(formatStamp(r.created),
                      style: TextStyle(fontSize: 11, color: LinanColors.faint)),
                ],
              ),
              Icon(Icons.chevron_right_rounded, size: 19, color: LinanColors.faint),
            ],
          ),
        ),
      ),
    );
  }

  Widget _jobsPanel() {
    final stats = s.workflowStats;
    return SectionCard(
      title: '持久化任务',
      subtitle: '解释生成任务先写入队列，再由调度器执行；失败与死信可以重试。',
      icon: Icons.dns_outlined,
      trailing: IconButton(
        onPressed: s.loadJobs,
        icon: Icon(Icons.refresh_rounded, size: 18),
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
                Tag('排队 ${stats.jobsQueued}', color: LinanColors.amber, icon: Icons.schedule_rounded),
                Tag('执行中 ${stats.jobsRunning}', color: LinanColors.primary, icon: Icons.play_circle_outline_rounded),
                Tag('已完成 ${stats.jobsDone}', color: LinanColors.green, icon: Icons.check_circle_outline_rounded),
                Tag('失败 ${stats.jobsFailed}', color: LinanColors.danger, icon: Icons.error_outline_rounded),
                Tag('死信 ${stats.jobsDead}', color: LinanColors.danger, icon: Icons.report_gmailerrorred_rounded),
                Tag('最久排队 ${_secondsText(stats.oldestQueuedSeconds)}',
                    color: LinanColors.warm, icon: Icons.timer_outlined),
              ],
            ),
          if (stats != null) SizedBox(height: 10),
          if (s.jobs.isEmpty)
            s.workflowsLoading
                ? Padding(
                    padding: EdgeInsets.symmetric(vertical: 22),
                    child: Center(
                        child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
                  )
                : EmptyHint('还没有持久化任务', icon: Icons.dns_outlined)
          else ...[
            for (final job in s.jobs) _jobRow(job),
            Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                '已展示全部 ${s.jobs.length} 条；后端最多返回最近 50 条持久化任务。',
                style: TextStyle(fontSize: 11.5, color: LinanColors.faint),
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
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: LinanColors.surfaceAlt.withValues(alpha: .5),
        borderRadius: BorderRadius.circular(LinanColors.rControl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Dot(color, size: 7),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${job.id} · ${jobKindLabel(job.kind)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w600, color: LinanColors.text),
                ),
              ),
              SizedBox(width: 6),
              Tag(jobStateLabel(job.state), color: color),
            ],
          ),
          SizedBox(height: 4),
          Row(
            children: [
              Text('尝试 ${job.attempts}/${job.maxAttempts}',
                  style: TextStyle(fontSize: 11, color: LinanColors.muted)),
              SizedBox(width: 10),
              Text('优先级 ${job.priority}', style: TextStyle(fontSize: 11, color: LinanColors.faint)),
              Spacer(),
              Text(formatStamp(job.created), style: TextStyle(fontSize: 11.5, color: LinanColors.faint)),
            ],
          ),
          if (job.key.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 2),
              child: Text('关联 ${job.key}', style: TextStyle(fontSize: 11.5, color: LinanColors.faint)),
            ),
          if (job.lastError.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 5),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                decoration: BoxDecoration(
                  color: LinanColors.tint(LinanColors.danger, .07),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  job.lastError,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, height: 1.5, color: LinanColors.danger),
                ),
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
                        minimumSize: const Size(0, 28),
                        padding: const EdgeInsets.symmetric(horizontal: 9),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('取消', style: TextStyle(fontSize: 11)),
                    ),
                  if (job.retryable)
                    TextButton(
                      onPressed: () => _retryJob(job),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 28),
                        padding: const EdgeInsets.symmetric(horizontal: 9),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('重试', style: TextStyle(fontSize: 11)),
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
    final draft = await showDialog<_TokenDraft>(context: context, builder: (_) => _NewTokenDialog());
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
        title: Row(
          children: [
            Icon(Icons.vpn_key_outlined, size: 18, color: LinanColors.primary),
            SizedBox(width: 8),
            Text('令牌已创建', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${issued.label} · ${issued.username}',
                  style: TextStyle(fontSize: 12, color: LinanColors.muted)),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: LinanColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(LinanColors.rControl),
                  border: Border.all(color: LinanColors.borderSoft),
                ),
                child: SelectableText(
                  issued.token,
                  style: TextStyle(fontSize: 11.5, fontFamily: 'Consolas', height: 1.5),
                ),
              ),
              SizedBox(height: 8),
              Text('明文只显示这一次，关闭后无法再次查看。',
                  style: TextStyle(fontSize: 11, color: LinanColors.amber)),
              if (issued.expires > 0)
                Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: Text('有效期至 ${formatStamp(issued.expires)}',
                      style: TextStyle(fontSize: 11.5, color: LinanColors.faint)),
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

/// 运行状态的 pill（运行状态与任务状态口径不同，单独取色）。
class _RunStatusPill extends StatelessWidget {
  final String status;
  const _RunStatusPill(this.status);

  static (Color, Color) _colorsFor(String status) {
    switch (status) {
      case 'queued':
      case 'waiting_human':
        return (LinanColors.stateAmberBg, LinanColors.stateAmberFg);
      case 'running':
        return (LinanColors.stateBlueBg, LinanColors.stateBlueFg);
      case 'completed':
        return (LinanColors.stateGreenBg, LinanColors.stateGreenFg);
      case 'failed':
        return (LinanColors.stateRedBg, LinanColors.stateRedFg);
      default:
        return (LinanColors.stateNeutralBg, LinanColors.stateNeutralFg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _colorsFor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
      decoration: BoxDecoration(color: colors.$1, borderRadius: BorderRadius.circular(LinanColors.rPill)),
      child: Text(
        runStatusName(status),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors.$2, height: 1.2),
      ),
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

  Future<void> _retry(String id) async {
    setState(() => _retrying = true);
    try {
      await s.retryRun(id);
      if (!mounted) return;
      Navigator.of(context).pop();
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
          return Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (snap.hasError) return EmptyHint('${snap.error}', icon: Icons.error_outline);
        final detail = snap.data;
        if (detail == null) return EmptyHint('没有运行详情');
        final definition = detail.definition;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _RunStatusPill(detail.status),
                Tag(modeName(detail.mode), color: LinanColors.primary, icon: Icons.memory_rounded),
                if (definition != null) ...[
                  Tag('定义 v${definition.version}', color: LinanColors.indigo, icon: Icons.schema_outlined),
                  if (definition.title.isNotEmpty)
                    Text(definition.title, style: TextStyle(fontSize: 11.5, color: LinanColors.muted)),
                ],
                if (detail.retryable)
                  FilledButton.icon(
                    onPressed: _retrying ? null : () => _retry(detail.id),
                    icon: _retrying
                        ? const SizedBox(
                            width: 13,
                            height: 13,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.replay_rounded, size: 15),
                    label: const Text('重试运行', style: TextStyle(fontSize: 12)),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
              ],
            ),
            if (detail.summary.isNotEmpty) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: LinanColors.surface,
                  borderRadius: BorderRadius.circular(LinanColors.rCard),
                ),
                child: Text(detail.summary, style: TextStyle(fontSize: 12.5, height: 1.65, color: LinanColors.text)),
              ),
            ],
            const SizedBox(height: 12),
            SectionCard(
              title: '步骤时间线',
              icon: Icons.timeline_rounded,
              child: detail.nodes.isEmpty
                  ? const EmptyHint('这条运行没有节点记录')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < detail.nodes.length; i++)
                          _node(detail.nodes[i], i == detail.nodes.length - 1),
                      ],
                    ),
            ),
            if (detail.nodes.isNotEmpty) ...[
              const SizedBox(height: 12),
              _logCard(detail),
            ],
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
            width: 20,
            child: Column(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  margin: const EdgeInsets.only(top: 5),
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                if (!last) Expanded(child: Container(width: 1.2, color: LinanColors.border)),
              ],
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(node.name.isEmpty ? (agentNames[node.agent] ?? node.agent) : node.name,
                            style: TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.w600, color: LinanColors.text)),
                      ),
                      Tag(node.mode.isEmpty ? '规则' : modeName(node.mode), color: LinanColors.muted),
                      SizedBox(width: 6),
                      Text('${node.elapsedMs} ms', style: TextStyle(fontSize: 11, color: LinanColors.faint)),
                    ],
                  ),
                  if (timeNote.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Text(timeNote, style: TextStyle(fontSize: 11, color: LinanColors.faint)),
                    ),
                  if (node.summary.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(node.summary,
                          style: TextStyle(fontSize: 11.5, height: 1.55, color: LinanColors.muted)),
                    ),
                  if (node.evidence.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: 5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final e in node.evidence.take(4))
                            Padding(
                              padding: EdgeInsets.only(bottom: 2),
                              child: Text('· $e',
                                  style: TextStyle(fontSize: 11, height: 1.5, color: LinanColors.muted)),
                            ),
                        ],
                      ),
                    ),
                  if (node.error.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(node.error, style: TextStyle(fontSize: 11, color: LinanColors.danger)),
                    ),
                  if (node.input.isNotEmpty || node.output.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          dividerColor: Colors.transparent,
                          splashFactory: NoSplash.splashFactory,
                        ),
                        child: ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          childrenPadding: EdgeInsets.zero,
                          dense: true,
                          iconColor: LinanColors.muted,
                          collapsedIconColor: LinanColors.faint,
                          title: Text('节点数据',
                              style: TextStyle(fontSize: 11.5, color: LinanColors.muted)),
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: LinanColors.surfaceAlt,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: SelectableText(
                                const JsonEncoder.withIndent('  ').convert({
                                  'input': node.input,
                                  'output': node.output,
                                }),
                                style: const TextStyle(fontSize: 11, height: 1.5, fontFamily: 'Consolas'),
                              ),
                            ),
                            const SizedBox(height: 6),
                          ],
                        ),
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

  Widget _logCard(WorkflowRun detail) {
    final lines = <String>[
      '# run ${detail.id} · ${runKindName(detail.kind)} · ${runStatusName(detail.status)}',
      '# mode ${modeName(detail.mode)} · created ${formatStamp(detail.created)} · updated ${formatStamp(detail.updated)}',
      for (final node in detail.nodes)
        [
          formatClock(node.started ?? detail.created),
          node.status.padRight(12),
          '${node.elapsedMs.toString().padLeft(5)} ms',
          node.name.isEmpty ? (agentNames[node.agent] ?? node.agent) : node.name,
        ].join('  '),
      for (final node in detail.nodes)
        if (node.error.isNotEmpty) '! ${node.name}: ${node.error}',
    ];
    final text = lines.join('\n');
    return SectionCard(
      title: '运行日志',
      subtitle: '等宽字体展示本次运行的节点状态与错误。',
      icon: Icons.terminal_rounded,
      trailing: IconButton(
        onPressed: () {
          Clipboard.setData(ClipboardData(text: text));
          s.toast('已复制运行日志');
        },
        icon: Icon(Icons.copy_all_outlined, size: 17),
        tooltip: '复制日志',
      ),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: LinanColors.surfaceAlt,
          borderRadius: BorderRadius.circular(LinanColors.rControl),
        ),
        child: SelectableText(
          text,
          style: TextStyle(fontSize: 11.5, height: 1.65, fontFamily: 'Consolas', color: LinanColors.text),
        ),
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
      padding: EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: LinanColors.text)),
          SizedBox(height: 3),
          Text(note, style: TextStyle(fontSize: 11, height: 1.5, color: LinanColors.muted)),
          SizedBox(height: 12),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == steps.length - 1 ? 0 : 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == steps.length - 1 ? LinanColors.primary : LinanColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('${i + 1}',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: i == steps.length - 1 ? Colors.white : LinanColors.muted)),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Text(steps[i], style: TextStyle(fontSize: 11.5, height: 1.5, color: LinanColors.text)),
                    ),
                  ),
                ],
              ),
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
    final selected = _presets.indexWhere((p) => p.$1 == _hours);
    return AlertDialog(
      title: Text('新建 MCP 令牌', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
              decoration: InputDecoration(labelText: '令牌标签', hintText: '例如：桌面客户端'),
            ),
            if (_error != null)
              Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(_error!, style: TextStyle(fontSize: 11, color: LinanColors.danger)),
              ),
            const SizedBox(height: 14),
            const Text('有效期', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            SegmentedControl(
              labels: [for (final preset in _presets) preset.$2],
              selected: selected < 0 ? 1 : selected,
              onChanged: (i) => setState(() => _hours = _presets[i].$1),
            ),
            const SizedBox(height: 12),
            Text(
              '明文 token 只在创建成功时显示一次；请立即复制并妥善保存。',
              style: TextStyle(fontSize: 11.5, height: 1.6, color: LinanColors.faint),
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
