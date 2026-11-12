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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 12),
          decoration: const BoxDecoration(
            color: LinanColors.surface,
            border: Border(bottom: BorderSide(color: LinanColors.border)),
          ),
          child: LayoutBuilder(
            builder: (context, c) {
              final intro = Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(color: LinanColors.primarySoft, borderRadius: BorderRadius.circular(9)),
                    child: const Icon(Icons.auto_awesome, size: 18, color: LinanColors.primary),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('邻安助手', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: configured ? LinanColors.primarySoft : LinanColors.surfaceAlt,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              configured ? modeName(mode) : '规则模式',
                              style: TextStyle(
                                fontSize: 9,
                                color: configured ? LinanColors.primary : LinanColors.muted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text('只解释证据与记录，不改变风险等级，也不越过你的权限。',
                          style: TextStyle(fontSize: 10, color: LinanColors.muted)),
                    ],
                  ),
                ],
              );
              final controls = Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _selector<int?>(
                    width: 150,
                    value: _elderId,
                    hint: '关联老人（可选）',
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('不限定老人', style: TextStyle(fontSize: 10.5))),
                      for (final e in s.elders)
                        DropdownMenuItem<int?>(value: e.id, child: Text('${e.name} · ${e.building}', style: const TextStyle(fontSize: 10.5))),
                    ],
                    onChanged: (v) => setState(() => _elderId = v),
                  ),
                  if (!s.isCareSide)
                    _selector<String?>(
                      width: 150,
                      value: _taskId,
                      hint: '关联任务（可选）',
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('不限定任务', style: TextStyle(fontSize: 10.5))),
                        for (final t in s.tasks.take(30))
                          DropdownMenuItem<String?>(
                              value: t.id,
                              child: Text('#${t.id} ${t.elderName} · ${stateName(t.state)}',
                                  style: const TextStyle(fontSize: 10.5))),
                      ],
                      onChanged: (v) => setState(() => _taskId = v),
                    ),
                  OutlinedButton.icon(
                    onPressed: () => setState(() {
                      _messages.clear();
                      _sessionId = null;
                    }),
                    icon: const Icon(Icons.add_comment_outlined, size: 13),
                    label: const Text('新对话', style: TextStyle(fontSize: 10.5)),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 30), padding: const EdgeInsets.symmetric(horizontal: 10)),
                  ),
                ],
              );
              if (c.maxWidth >= 900) {
                return Row(
                  children: [
                    Expanded(child: intro),
                    const SizedBox(width: 12),
                    controls,
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [intro, const SizedBox(height: 10), controls],
              );
            },
          ),
        ),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: _messages.isEmpty
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
                      child: _emptyState(),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                      itemCount: _messages.length,
                      itemBuilder: (context, i) => _bubble(_messages[i]),
                    ),
            ),
          ),
        ),
        if (fallback.isNotEmpty && configured)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text('模型回退：$fallback', style: const TextStyle(fontSize: 9.5, color: LinanColors.amber)),
          ),
        Container(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_messages.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final q in _suggestions) ...[
                              ActionChip(
                                label: Text(q, style: const TextStyle(fontSize: 10.5)),
                                onPressed: _sending ? null : () => _send(q),
                                visualDensity: VisualDensity.compact,
                                side: const BorderSide(color: LinanColors.borderSoft),
                              ),
                              const SizedBox(width: 6),
                            ],
                          ],
                        ),
                      ),
                    ),
                  Row(
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
                          style: const TextStyle(fontSize: 12.5),
                          decoration: InputDecoration(
                            hintText: '问点具体的，比如“王桂兰最近怎么样？”',
                            filled: true,
                            fillColor: LinanColors.surface,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 42,
                        child: FilledButton(
                          onPressed: _sending ? null : _send,
                          child: _sending
                              ? const SizedBox(
                                  width: 16, height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('发送'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text('助手查询的是当前账号可见的记录；涉及处置的判断仍由人工确认。',
                      style: TextStyle(fontSize: 9, color: LinanColors.faint)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _selector<T>({
    required double width,
    required T value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      width: width,
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: LinanColors.surfaceAlt,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: LinanColors.borderSoft),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          isDense: true,
          hint: Text(hint, style: const TextStyle(fontSize: 10.5, color: LinanColors.faint)),
          icon: const Icon(Icons.expand_more, size: 15, color: LinanColors.muted),
          style: const TextStyle(fontSize: 10.5, color: LinanColors.text),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Center(
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: LinanColors.primarySoft, borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.forum_outlined, size: 24, color: LinanColors.primary),
          ),
        ),
        const SizedBox(height: 12),
        const Center(
          child: Text('可以试着这样问', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 4),
        const Center(
          child: Text('助手会先按权限查询记录，再解释判断依据。',
              style: TextStyle(fontSize: 10.5, color: LinanColors.muted)),
        ),
        const SizedBox(height: 18),
        for (final q in _suggestions)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: _sending ? null : () => _send(q),
              borderRadius: BorderRadius.circular(9),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: LinanColors.surface,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: LinanColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(q, style: const TextStyle(fontSize: 12, color: LinanColors.text))),
                    const Icon(Icons.north_east, size: 14, color: LinanColors.primary),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: LinanColors.surfaceAlt,
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined, size: 14, color: LinanColors.muted),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '边界说明：助手不会修改风险等级、不会自动派单，也不会把未关闭的紧急事件说成“已解决”。',
                  style: TextStyle(fontSize: 10, height: 1.6, color: LinanColors.muted),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bubble(_ChatBubble m) {
    final user = m.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: user ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!user) ...[
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(color: LinanColors.primarySoft, borderRadius: BorderRadius.circular(7)),
              child: const Icon(Icons.auto_awesome, size: 13, color: LinanColors.primary),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.fromLTRB(13, 10, 13, 11),
              decoration: BoxDecoration(
                color: user
                    ? LinanColors.primary
                    : (m.error ? LinanColors.danger.withValues(alpha: .06) : LinanColors.surface),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(user ? 12 : 4),
                  topRight: Radius.circular(user ? 4 : 12),
                  bottomLeft: const Radius.circular(12),
                  bottomRight: const Radius.circular(12),
                ),
                border: user ? null : Border.all(color: m.error ? LinanColors.danger.withValues(alpha: .25) : LinanColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    m.text,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.75,
                      color: user ? Colors.white : (m.error ? LinanColors.danger : LinanColors.text),
                    ),
                  ),
                  if (!user && m.citations.isNotEmpty) ...[
                    const SizedBox(height: 9),
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
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        m.mode == 'llm' ? '由模型解释 · 规则判定等级' : '规则模式回答',
                        style: const TextStyle(fontSize: 8.5, color: LinanColors.faint),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (user) const SizedBox(width: 34),
        ],
      ),
    );
  }

  /// 回复下方的上下文摘要：chars/budget、引用数、脱敏数与截断提示，可展开看明细。
  Widget _contextPanel(ContextSummary c, int citationCount) {
    return Padding(
      padding: const EdgeInsets.only(top: 9),
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
              Tag('引用 $citationCount', color: LinanColors.muted, icon: Icons.link),
              Tag(
                '脱敏 ${c.redactions}',
                color: c.redactions > 0 ? LinanColors.warm : LinanColors.muted,
                icon: Icons.visibility_off_outlined,
              ),
              if (c.truncated) const Tag('已截断', color: LinanColors.amber, icon: Icons.content_cut),
            ],
          ),
          if (c.hasDetails)
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 2),
                dense: true,
                visualDensity: VisualDensity.compact,
                title: const Text('上下文明细', style: TextStyle(fontSize: 9.5, color: LinanColors.faint)),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
                    decoration: BoxDecoration(color: LinanColors.surfaceAlt, borderRadius: BorderRadius.circular(7)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (c.sections.isNotEmpty) ...[
                          const Text('上下文分区',
                              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: LinanColors.muted)),
                          const SizedBox(height: 4),
                          for (final section in c.sections)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                '· ${section.title.isEmpty ? section.key : section.title}'
                                '　${section.records} 条 · ${section.chars} 字符',
                                style: const TextStyle(fontSize: 9.5, height: 1.5, color: LinanColors.muted),
                              ),
                            ),
                        ],
                        if (c.gaps.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          const Text('数据缺口（未知，不推断安全）',
                              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: LinanColors.amber)),
                          const SizedBox(height: 3),
                          for (final gap in c.gaps)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text('· $gap',
                                  style: const TextStyle(fontSize: 9.5, height: 1.5, color: LinanColors.warm)),
                            ),
                        ],
                        if (c.redactionRules.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text('脱敏规则（共 ${c.redactions} 处）',
                              style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: LinanColors.muted)),
                          const SizedBox(height: 3),
                          for (final rule in c.redactionRules)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text('· $rule',
                                  style: const TextStyle(fontSize: 9.5, height: 1.5, color: LinanColors.muted)),
                            ),
                        ],
                        if (c.tools.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          const Text('受限工具查询',
                              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: LinanColors.muted)),
                          const SizedBox(height: 3),
                          for (final tool in c.tools)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                '· ${tool.query.isEmpty ? '记录查询' : tool.query}'
                                '${tool.elderId == null ? '' : ' · 老人 #${tool.elderId}'}'
                                '${tool.taskId == null ? '' : ' · 任务 ${tool.taskId}'}'
                                '　${tool.records} 条',
                                style: const TextStyle(fontSize: 9.5, height: 1.5, color: LinanColors.faint),
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
    if (label.isEmpty) return const SizedBox.shrink();
    final icon = type == 'task'
        ? Icons.checklist
        : type == 'incident'
            ? Icons.report_outlined
            : type == 'workflow'
                ? Icons.account_tree_outlined
                : Icons.person_outline;
    return InkWell(
      onTap: () => _openCitation(c, type),
      borderRadius: BorderRadius.circular(5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: LinanColors.surfaceAlt,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: LinanColors.borderSoft),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: LinanColors.primary),
            const SizedBox(width: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 9.5, color: LinanColors.primaryDeep)),
            ),
          ],
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
        title: const Text('依据详情', style: TextStyle(fontSize: 15)),
        content: SingleChildScrollView(
          child: Text(
            c.entries.map((e) => '${e.key}: ${e.value}').join('\n'),
            style: const TextStyle(fontSize: 11, height: 1.7),
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
          return const Padding(
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
            Row(
              children: [
                LevelPill(t.level),
                const SizedBox(width: 8),
                StatePill(t.state),
                if (t.requiredSkill.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Tag(skillName(t.requiredSkill)),
                ],
                const Spacer(),
                if (t.overdue) const Tag('已超时', color: LinanColors.danger),
              ],
            ),
            const SizedBox(height: 12),
            KeyValue('老人', '${t.elderName} · 档案 #${t.elderId}'),
            KeyValue('任务', t.title),
            KeyValue('负责人', t.staffName.isEmpty ? '待派单' : t.staffName),
            KeyValue('截止', t.due == null ? '不设截止时间' : formatStamp(t.due)),
            KeyValue('建议', t.advice.isEmpty ? '暂无建议' : t.advice),
            const SizedBox(height: 10),
            const Text(
              '可前往「任务中心」按权限跟进或提交处置结果。',
              style: TextStyle(fontSize: 10, height: 1.6, color: LinanColors.faint),
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
          return const Padding(
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
            Row(
              children: [
                LevelPill(e.level),
                const SizedBox(width: 8),
                if (e.dataUnknown) const Tag('数据缺失 = 未知', color: LinanColors.warm),
              ],
            ),
            const SizedBox(height: 12),
            KeyValue('姓名', e.name),
            KeyValue('年龄 / 楼栋', '${e.age} 岁 · ${e.building}'),
            KeyValue('数据来源', e.origin),
            KeyValue('历史基线', '${e.historyDays} 天 · ${e.baselineReady ? '可用于个性化判断' : '学习中，暂不生成成熟基线'}'),
            KeyValue('未关闭事件', '${e.incidentCount} 条'),
            const SizedBox(height: 10),
            const Text(
              '可前往「老人档案」查看完整详情与最近上报。',
              style: TextStyle(fontSize: 10, height: 1.6, color: LinanColors.faint),
            ),
          ],
        );
      },
    );
  }
}
