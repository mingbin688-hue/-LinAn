import 'package:flutter/material.dart';

import '../app_state.dart';
import '../labels.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

class AssistantPage extends StatefulWidget {
  final AppState state;
  const AssistantPage({super.key, required this.state});

  @override
  State<AssistantPage> createState() => _AssistantPageState();
}

class _ChatBubble {
  final String role; // user / assistant
  final String text;
  final List<Map<String, dynamic>> citations;
  final String mode;
  final String fallbackReason;
  final ContextSummary? context;
  final bool error;

  const _ChatBubble({
    required this.role,
    required this.text,
    this.citations = const [],
    this.mode = '',
    this.fallbackReason = '',
    this.context,
    this.error = false,
  });
}

class _AssistantPageState extends State<AssistantPage> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<_ChatBubble> _messages = [];
  String? _sessionId;
  int? _elderId;
  String? _taskId;
  bool _sending = false;

  AppState get s => widget.state;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  List<String> get _suggestions {
    final user = s.user;
    if (user == null) return const [];
    if (user.isAdmin) {
      return const [
        '今天有哪些老人需要重点关注？',
        '王桂兰最近的状态怎么样？',
        '现在有哪些任务还没有接单？',
        '解释一下最近一条紧急判断的依据',
      ];
    }
    if (user.isStaff) {
      return const [
        '我今天还有哪些任务？',
        '我负责的老人里谁需要优先处理？',
        '帮我整理一下待提交的处置反馈',
      ];
    }
    if (user.isElder) {
      return const [
        '我最近的状态怎么样？',
        '我上次报平安是什么时候？',
        '社区一般多久会联系我？',
      ];
    }
    return const [
      '我母亲最近的状态怎么样？',
      '最近有一次未报平安，后来怎么处理了？',
      '家里老人今天有没有异常？',
    ];
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _messages.add(_ChatBubble(role: 'user', text: text));
      _input.clear();
    });
    _jump();
    try {
      final reply = await s.assistant(
        message: text,
        sessionId: _sessionId,
        elderId: _elderId,
        taskId: _taskId,
      );
      if (!mounted) return;
      setState(() {
        _sessionId = reply.sessionId.isEmpty ? _sessionId : reply.sessionId;
        _messages.add(_ChatBubble(
          role: 'assistant',
          text: reply.reply,
          citations: reply.citations,
          mode: reply.mode,
          fallbackReason: reply.fallbackReason,
          context: reply.context,
        ));
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _messages.add(_ChatBubble(role: 'assistant', text: '$e', error: true)));
    } finally {
      if (mounted) setState(() => _sending = false);
      _jump();
    }
  }

  void _jump() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 160,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final agents = s.agentsInfo;
    final mode = '${agents['mode'] ?? 'rules'}';
    final configured = agents['configured'] == true;
    final fallback = '${agents['fallback_reason'] ?? ''}';

    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 900;
        final pad = wide ? 24.0 : 16.0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: PageHeader(
                  padding: EdgeInsets.fromLTRB(pad, 26, pad, 16),
                  title: '邻安助手',
                  subtitle: '只解释证据与记录，不改变风险等级，也不越过你的权限。',
                  icon: Icons.auto_awesome_rounded,
                  accent: LinanColors.primary,
                  actions: [
                    Tag(
                      configured ? modeName(mode) : '规则模式',
                      color: configured ? LinanColors.primary : LinanColors.muted,
                      icon: Icons.memory_rounded,
                    ),
                    OutlinedButton.icon(
                      onPressed: () => setState(() {
                        _messages.clear();
                        _sessionId = null;
                      }),
                      icon: const Icon(Icons.add_comment_outlined, size: 15),
                      label: const Text('新对话'),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(pad, 0, pad, 0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: _scopeCard(fallback: fallback, configured: configured),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: _messages.isEmpty
                      ? SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(pad, 6, pad, 18),
                          child: _emptyState(wide),
                        )
                      : ListView.builder(
                          controller: _scroll,
                          padding: EdgeInsets.fromLTRB(pad, 10, pad, 10),
                          itemCount: _messages.length,
                          itemBuilder: (context, i) => _bubble(_messages[i]),
                        ),
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(pad, 4, pad, 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [LinanColors.bg.withValues(alpha: 0), LinanColors.bg.withValues(alpha: .92)],
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_messages.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (final q in _suggestions) ...[
                                  _SuggestionPill(
                                    text: q,
                                    onTap: _sending ? null : () => _send(q),
                                  ),
                                  const SizedBox(width: 7),
                                ],
                              ],
                            ),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
                        decoration: BoxDecoration(
                          color: LinanColors.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: LinanColors.borderSoft),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _input,
                                minLines: 1,
                                maxLines: 4,
                                enabled: !_sending,
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => _send(),
                                style: const TextStyle(fontSize: 13.5, height: 1.45),
                                decoration: const InputDecoration(
                                  hintText: '问点具体的，比如“王桂兰最近怎么样？”',
                                  filled: false,
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                ),
                              ),
                            ),
                            const SizedBox(width: 2),
                            SizedBox(
                              width: 42,
                              height: 42,
                              child: Tooltip(
                                message: '发送',
                                child: FilledButton(
                                  onPressed: _sending ? null : _send,
                                  style: FilledButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    shape: const CircleBorder(),
                                  ),
                                  child: _sending
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : const Icon(Icons.arrow_upward_rounded, size: 20),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '助手查询的是当前账号可见的记录；涉及处置的判断仍由人工确认。',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11.5, color: LinanColors.faint),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 对话范围与运行状态：关联老人/任务、当前模式，以及（模型启用时的）回退原因。
  Widget _scopeCard({required String fallback, required bool configured}) {
    return SectionCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _selector<int?>(
                width: 214,
                value: _elderId,
                hint: '关联老人（可选）',
                icon: Icons.elderly_rounded,
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('不限定老人', style: TextStyle(fontSize: 11.5))),
                  for (final e in s.elders)
                    DropdownMenuItem<int?>(
                      value: e.id,
                      child: Text('${e.name} · ${e.building}', style: const TextStyle(fontSize: 11.5)),
                    ),
                ],
                onChanged: (v) => setState(() => _elderId = v),
              ),
              if (!s.isCareSide)
                _selector<String?>(
                  width: 214,
                  value: _taskId,
                  hint: '关联任务（可选）',
                  icon: Icons.checklist_rounded,
                  items: [
                    DropdownMenuItem<String?>(value: null, child: Text('不限定任务', style: TextStyle(fontSize: 11.5))),
                    for (final t in s.tasks.take(30))
                      DropdownMenuItem<String?>(
                        value: t.id,
                        child: Text('#${t.id} ${t.elderName} · ${stateName(t.state)}',
                            style: const TextStyle(fontSize: 11.5)),
                      ),
                  ],
                  onChanged: (v) => setState(() => _taskId = v),
                ),
              Tag('只查询当前权限内的记录', color: LinanColors.muted, icon: Icons.verified_user_outlined),
            ],
          ),
          if (fallback.isNotEmpty && configured) ...[
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                color: LinanColors.tint(LinanColors.amber, .1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: 14, color: LinanColors.amber),
                  SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      '模型回退：$fallback',
                      style: TextStyle(fontSize: 11, height: 1.5, color: LinanColors.amber),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _selector<T>({
    required double width,
    required T value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    IconData? icon,
  }) {
    return Container(
      width: width,
      height: 34,
      padding: EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: LinanColors.surfaceAlt,
        borderRadius: BorderRadius.circular(LinanColors.rControl),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: LinanColors.muted),
            SizedBox(width: 6),
          ],
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                isExpanded: true,
                isDense: true,
                hint: Text(hint, style: TextStyle(fontSize: 11.5, color: LinanColors.faint)),
                icon: Icon(Icons.expand_more_rounded, size: 17, color: LinanColors.muted),
                style: TextStyle(fontSize: 11.5, color: LinanColors.text),
                items: items,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(bool wide) {
    final chips = <Widget>[
      for (final q in _suggestions)
        _StarterCard(
          text: q,
          onTap: _sending ? null : () => _send(q),
        ),
    ];
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 760),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 10),
            Center(
              child: Container(
                width: 58,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: LinanColors.tint(LinanColors.primary, .12),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(Icons.forum_rounded, size: 27, color: LinanColors.primary),
              ),
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text('可以试着这样问',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -.3)),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text('助手会先按权限查询记录，再解释判断依据。',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: LinanColors.muted)),
            ),
            const SizedBox(height: 18),
            if (wide) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Column(children: chips.take(2).toList())),
                  const SizedBox(width: 10),
                  Expanded(child: Column(children: chips.skip(2).toList())),
                ],
              ),
            ] else
              for (final chip in chips) ...[
                chip,
                const SizedBox(height: 8),
              ],
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: LinanColors.surfaceAlt,
                borderRadius: BorderRadius.circular(LinanColors.rControl),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined, size: 16, color: LinanColors.muted),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '边界说明：助手不会修改风险等级、不会自动派单，也不会把未关闭的紧急事件说成“已解决”。',
                      style: TextStyle(fontSize: 11.5, height: 1.6, color: LinanColors.muted),
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

  Widget _bubble(_ChatBubble m) {
    final user = m.role == 'user';
    final bubble = Container(
      padding: const EdgeInsets.fromLTRB(15, 11, 15, 12),
      decoration: BoxDecoration(
        color: user
            ? LinanColors.primary
            : (m.error ? LinanColors.tint(LinanColors.danger, .06) : LinanColors.surface),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(user ? 18 : 6),
          bottomRight: Radius.circular(user ? 6 : 18),
        ),
        border: user
            ? null
            : Border.all(color: m.error ? LinanColors.tint(LinanColors.danger, .25) : LinanColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            m.text,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.7,
              color: user ? Colors.white : (m.error ? LinanColors.danger : LinanColors.text),
            ),
          ),
          if (!user && m.citations.isNotEmpty) ...[
            SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in m.citations) _citationChip(c),
              ],
            ),
          ],
          if (!user && m.context != null) _contextPanel(m.context!, m.citations.length),
          if (!user && m.mode.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    m.mode == 'llm' ? Icons.auto_awesome : Icons.rule,
                    size: 11,
                    color: LinanColors.faint,
                  ),
                  SizedBox(width: 4),
                  Text(
                    m.mode == 'llm' ? '由模型解释 · 规则判定等级' : '规则模式回答',
                    style: TextStyle(fontSize: 11, color: LinanColors.faint),
                  ),
                ],
              ),
            ),
          if (!user && m.fallbackReason.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('回退原因：${m.fallbackReason}',
                  style: TextStyle(fontSize: 11, color: LinanColors.amber)),
            ),
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: user ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!user) ...[
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: LinanColors.tint(LinanColors.primary, .12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(Icons.auto_awesome, size: 15, color: LinanColors.primary),
            ),
            const SizedBox(width: 9),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 680),
              child: bubble,
            ),
          ),
        ],
      ),
    );
  }

  /// 回复下方的上下文摘要：chars/budget、引用数、脱敏数与截断提示，可展开看明细。
  Widget _contextPanel(ContextSummary c, int citationCount) {
    return Padding(
      padding: EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Tag(
                '上下文 ${_compactCount(c.chars)}/${_compactCount(c.budget)}',
                color: LinanColors.primary,
                icon: Icons.description_outlined,
              ),
              Tag('引用 $citationCount', color: LinanColors.muted, icon: Icons.link_rounded),
              Tag(
                '脱敏 ${c.redactions}',
                color: c.redactions > 0 ? LinanColors.warm : LinanColors.muted,
                icon: Icons.visibility_off_outlined,
              ),
              if (c.truncated) Tag('已截断', color: LinanColors.amber, icon: Icons.content_cut_rounded),
            ],
          ),
          if (c.hasDetails)
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent, splashFactory: NoSplash.splashFactory),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.only(bottom: 2),
                dense: true,
                visualDensity: VisualDensity.compact,
                iconColor: LinanColors.muted,
                collapsedIconColor: LinanColors.faint,
                title: Text('上下文明细', style: TextStyle(fontSize: 11, color: LinanColors.muted)),
                children: [
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.fromLTRB(11, 10, 11, 10),
                    decoration: BoxDecoration(
                      color: LinanColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (c.sections.isNotEmpty) ...[
                          Text('上下文分区',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: LinanColors.muted)),
                          SizedBox(height: 4),
                          for (final section in c.sections)
                            Padding(
                              padding: EdgeInsets.only(bottom: 2),
                              child: Text(
                                '· ${section.title.isEmpty ? section.key : section.title}'
                                '　${section.records} 条 · ${section.chars} 字符',
                                style: TextStyle(fontSize: 11.5, height: 1.5, color: LinanColors.muted),
                              ),
                            ),
                        ],
                        if (c.gaps.isNotEmpty) ...[
                          SizedBox(height: 6),
                          Text('数据缺口（未知，不推断安全）',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: LinanColors.amber)),
                          SizedBox(height: 3),
                          for (final gap in c.gaps)
                            Padding(
                              padding: EdgeInsets.only(bottom: 2),
                              child: Text('· $gap',
                                  style: TextStyle(fontSize: 11.5, height: 1.5, color: LinanColors.warm)),
                            ),
                        ],
                        if (c.redactionRules.isNotEmpty) ...[
                          SizedBox(height: 6),
                          Text('脱敏规则（共 ${c.redactions} 处）',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: LinanColors.muted)),
                          SizedBox(height: 3),
                          for (final rule in c.redactionRules)
                            Padding(
                              padding: EdgeInsets.only(bottom: 2),
                              child: Text('· $rule',
                                  style: TextStyle(fontSize: 11.5, height: 1.5, color: LinanColors.muted)),
                            ),
                        ],
                        if (c.tools.isNotEmpty) ...[
                          SizedBox(height: 6),
                          Text('受限工具查询',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: LinanColors.muted)),
                          SizedBox(height: 3),
                          for (final tool in c.tools)
                            Padding(
                              padding: EdgeInsets.only(bottom: 2),
                              child: Text(
                                '· ${tool.query.isEmpty ? '记录查询' : tool.query}'
                                '${tool.elderId == null ? '' : ' · 老人 #${tool.elderId}'}'
                                '${tool.taskId == null ? '' : ' · 任务 ${tool.taskId}'}'
                                '　${tool.records} 条',
                                style: TextStyle(fontSize: 11.5, height: 1.5, color: LinanColors.faint),
                              ),
                            ),
                        ],
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

  Widget _citationChip(Map<String, dynamic> c) {
    final type = '${c['type'] ?? c['kind'] ?? ''}';
    final label = '${c['label'] ?? c['title'] ?? c['name'] ?? c['summary'] ?? ''}';
    if (label.isEmpty) return SizedBox.shrink();
    final icon = type == 'task'
        ? Icons.checklist_rounded
        : type == 'incident'
            ? Icons.report_outlined
            : type == 'workflow'
                ? Icons.account_tree_outlined
                : Icons.person_outline_rounded;
    return Material(
      color: LinanColors.surfaceAlt,
      borderRadius: BorderRadius.circular(LinanColors.rPill),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openCitation(c, type),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: LinanColors.primary),
              SizedBox(width: 4),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 220),
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: LinanColors.primaryDeep, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openCitation(Map<String, dynamic> c, String type) {
    // 后端 scope / context_pack 会把引用 id 统一转成字符串（type/id/label），
    // 所以这里按字符串比较，不能再判断 `id is num`。
    final id = '${c['id'] ?? ''}'.trim();
    final label = '${c['label'] ?? c['title'] ?? c['name'] ?? c['summary'] ?? ''}'.trim();
    if (id.isEmpty || id == 'null') {
      _showCitationRaw(c);
      return;
    }
    if (type == 'task') {
      _goto('tasks');
      _showCitationSheet(
        title: '任务 #$id',
        subtitle: label.isEmpty ? '引用任务详情' : label,
        child: _CitationTaskBody(state: s, taskId: id),
      );
    } else if (type == 'elder') {
      final elderId = int.tryParse(id);
      if (elderId == null) {
        _showCitationRaw(c);
        return;
      }
      _goto('elders');
      _showCitationSheet(
        title: '老人档案 #$id',
        subtitle: label.isEmpty ? '引用老人详情' : label,
        child: _CitationElderBody(state: s, elderId: elderId),
      );
    } else if (type == 'workflow') {
      // 运行记录页只对管理员开放；无权限时仍回退到原始引用信息。
      if (!_goto('workflows')) _showCitationRaw(c);
    } else {
      // 未知类型仍回退为原始 key:value 详情弹窗。
      _showCitationRaw(c);
    }
  }

  /// 只跳到当前角色导航里存在的页面，避免家属/老人被切到不存在的页面。
  bool _goto(String key) {
    if (!s.navs.any((n) => n.key == key)) return false;
    s.selectPage(key);
    return true;
  }

  void _showCitationSheet({required String title, required String subtitle, required Widget child}) {
    // showSideSheet 自带滚动容器与内边距，这里不再套一层 SingleChildScrollView。
    showSideSheet(context, title: title, subtitle: subtitle, child: child);
  }

  void _showCitationRaw(Map<String, dynamic> c) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('依据详情', style: TextStyle(fontSize: 16)),
        content: SingleChildScrollView(
          child: Text(
            c.entries.map((e) => '${e.key}: ${e.value}').join('\n'),
            style: const TextStyle(fontSize: 12, height: 1.7),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('知道了'))],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    if (!s.isCareSide && s.tasks.length == 1) _taskId = s.tasks.first.id;
  }
}

/// 输入区上方的横向快捷问题胶囊。
class _SuggestionPill extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  const _SuggestionPill({required this.text, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: LinanColors.surface,
      borderRadius: BorderRadius.circular(LinanColors.rPill),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            border: Border.all(color: LinanColors.borderSoft),
            borderRadius: BorderRadius.circular(LinanColors.rPill),
          ),
          child: Text(text, style: TextStyle(fontSize: 11.5, color: LinanColors.text)),
        ),
      ),
    );
  }
}

/// 空状态里的提问入口卡片。
class _StarterCard extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  const _StarterCard({required this.text, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: LinanColors.surface,
      borderRadius: BorderRadius.circular(LinanColors.rCard),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: [
              Expanded(
                child: Text(text, style: TextStyle(fontSize: 12.5, color: LinanColors.text, height: 1.45)),
              ),
              SizedBox(width: 8),
              Icon(Icons.north_east_rounded, size: 15, color: LinanColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

/// 1234 → 1.2K，6000 → 6K；不足 1000 保持原值。
String _compactCount(int value) {
  if (value < 1000) return '$value';
  final k = value / 1000;
  if (k < 999.5) return '${_compactScaled(k)}K';
  return '${_compactScaled(value / 1000000)}M';
}

String _compactScaled(double value) {
  if (value >= 10) return '${value.round()}';
  final text = value.toStringAsFixed(1);
  return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
}

/// 助手引用里的任务：按 /api/tasks/{id} 取详情展示。
/// future 在 initState 中缓存一次，避免每次重建都重新发起请求。
class _CitationTaskBody extends StatefulWidget {
  final AppState state;
  final String taskId;
  const _CitationTaskBody({required this.state, required this.taskId});

  @override
  State<_CitationTaskBody> createState() => _CitationTaskBodyState();
}

class _CitationTaskBodyState extends State<_CitationTaskBody> {
  late Future<TaskDetail> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.state.taskDetail(widget.taskId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TaskDetail>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Padding(
            padding: EdgeInsets.only(top: 36),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (snap.hasError) {
          return EmptyHint('任务 ${widget.taskId} 加载失败：${snap.error}', icon: Icons.error_outline);
        }
        final d = snap.data;
        if (d == null) return EmptyHint('没有任务 #${widget.taskId} 的详情', icon: Icons.error_outline);
        final t = d.task;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                LevelPill(t.level),
                StatePill(t.state),
                if (t.requiredSkill.isNotEmpty) Tag(skillName(t.requiredSkill), icon: Icons.handyman_outlined),
                if (t.overdue) Tag('已超时', color: LinanColors.danger, icon: Icons.timer_off_outlined),
              ],
            ),
            const SizedBox(height: 12),
            SectionCard(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                children: [
                  KeyValue('老人', '${t.elderName} · 档案 #${t.elderId}'),
                  KeyValue('任务', t.title),
                  KeyValue('负责人', t.staffName.isEmpty ? '待派单' : t.staffName),
                  KeyValue('截止', t.due == null ? '不设截止时间' : formatStamp(t.due)),
                  KeyValue('建议', t.advice.isEmpty ? '暂无建议' : t.advice),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '可前往「任务中心」按权限跟进或提交处置结果。',
              style: TextStyle(fontSize: 11, height: 1.6, color: LinanColors.faint),
            ),
          ],
        );
      },
    );
  }
}

/// 助手引用里的老人：按 /api/elders/{id} 取档案摘要展示（future 在 initState 中缓存）。
class _CitationElderBody extends StatefulWidget {
  final AppState state;
  final int elderId;
  const _CitationElderBody({required this.state, required this.elderId});

  @override
  State<_CitationElderBody> createState() => _CitationElderBodyState();
}

class _CitationElderBodyState extends State<_CitationElderBody> {
  late Future<Elder> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.state.elderDetail(widget.elderId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Elder>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Padding(
            padding: EdgeInsets.only(top: 36),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (snap.hasError) {
          return EmptyHint('老人档案 #${widget.elderId} 加载失败：${snap.error}', icon: Icons.error_outline);
        }
        final e = snap.data;
        if (e == null) return EmptyHint('没有老人 #${widget.elderId} 的档案', icon: Icons.error_outline);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                LevelPill(e.level),
                if (e.dataUnknown) Tag('数据缺失 = 未知', color: LinanColors.warm),
              ],
            ),
            const SizedBox(height: 12),
            SectionCard(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                children: [
                  KeyValue('姓名', e.name),
                  KeyValue('年龄 / 楼栋', '${e.age} 岁 · ${e.building}'),
                  KeyValue('数据来源', e.origin),
                  KeyValue('历史基线', '${e.historyDays} 天 · ${e.baselineReady ? '可用于个性化判断' : '学习中，暂不生成成熟基线'}'),
                  KeyValue('未关闭事件', '${e.incidentCount} 条'),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '可前往「老人档案」查看完整详情与最近上报。',
              style: TextStyle(fontSize: 11, height: 1.6, color: LinanColors.faint),
            ),
          ],
        );
      },
    );
  }
}
