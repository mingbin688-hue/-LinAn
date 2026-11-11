import 'package:flutter/material.dart';

import '../api_client.dart';
import '../app_state.dart';
import '../labels.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/report_dialog.dart';

class EldersPage extends StatefulWidget {
  final AppState state;
  const EldersPage({super.key, required this.state});

  @override
  State<EldersPage> createState() => _EldersPageState();
}

class _EldersPageState extends State<EldersPage> {
  final _search = TextEditingController();
  int? _levelFilter;
  bool _onlyUnknown = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final rows = s.elders.where((e) {
      final key = _search.text.trim();
      if (key.isNotEmpty && !(e.name.contains(key) || e.building.contains(key))) return false;
      if (_levelFilter != null && e.level != _levelFilter) return false;
      if (_onlyUnknown && !e.dataUnknown) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.level.compareTo(a.level));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(24, 15, 24, 12),
          decoration: const BoxDecoration(
            color: LinanColors.surface,
            border: Border(bottom: BorderSide(color: LinanColors.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 250,
                    height: 34,
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        hintText: '搜索姓名或楼栋',
                        prefixIcon: const Icon(Icons.search, size: 15),
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () => setState(() => _search.clear()),
                                icon: const Icon(Icons.close, size: 13),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _filter('全部', null),
                          _filter('紧急', 3),
                          _filter('优先', 2),
                          _filter('关注', 1),
                          _filter('状态未知', 0),
                          _filter('平稳', -1),
                        ],
                      ),
                    ),
                  ),
                  if (s.user?.isAdmin == true) ...[
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: () => _openProfile(context, s),
                      icon: const Icon(Icons.add, size: 14),
                      label: const Text('新建档案'),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Text('共 ${rows.length} 位 · 排序：风险等级优先',
                      style: const TextStyle(fontSize: 10, color: LinanColors.faint)),
                  const SizedBox(width: 12),
                  FilterChip(
                    label: const Text('仅看数据未知', style: TextStyle(fontSize: 9.5)),
                    selected: _onlyUnknown,
                    onSelected: (v) => setState(() => _onlyUnknown = v),
                    visualDensity: VisualDensity.compact,
                    selectedColor: LinanColors.warm.withValues(alpha: .12),
                    checkmarkColor: LinanColors.warm,
                    side: const BorderSide(color: LinanColors.border),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: Scrollbar(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
              child: rows.isEmpty
                  ? const Padding(padding: EdgeInsets.only(top: 60), child: EmptyHint('没有匹配的老人档案'))
                  : LayoutBuilder(
                      builder: (context, c) {
                        final cols = c.maxWidth >= 1200 ? 4 : (c.maxWidth >= 860 ? 3 : (c.maxWidth >= 560 ? 2 : 1));
                        final gap = 12.0;
                        final width = (c.maxWidth - gap * (cols - 1)) / cols;
                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [
                            for (final e in rows)
                              SizedBox(width: width, child: _ElderCard(elder: e, onOpen: () => _openDetail(context, s, e))),
                          ],
                        );
                      },
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _filter(String label, int? level) {
    final selected = _levelFilter == level;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 10.5, color: selected ? LinanColors.primaryDeep : LinanColors.muted)),
        selected: selected,
        onSelected: (_) => setState(() => _levelFilter = level),
        visualDensity: VisualDensity.compact,
        selectedColor: LinanColors.primarySoft,
        backgroundColor: Colors.white,
        side: BorderSide(color: selected ? LinanColors.primary.withValues(alpha: .3) : LinanColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        showCheckmark: false,
      ),
    );
  }

  Future<void> _openDetail(BuildContext context, AppState s, Elder elder) async {
    await showSideSheet(
      context,
      title: elder.name,
      subtitle: '${elder.age} 岁 · ${elder.building} · 档案 #${elder.id}',
      actions: [
        TextButton.icon(
          onPressed: () => showReportDialog(context, s, elderId: elder.id),
          icon: const Icon(Icons.add_circle_outline, size: 14),
          label: const Text('上报信息'),
        ),
      ],
      child: _ElderDetail(state: s, elder: elder),
    );
  }

  Future<void> _openProfile(BuildContext context, AppState s, {Elder? elder}) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _ProfileDialog(state: s, elder: elder),
    );
  }
}

class _ElderCard extends StatelessWidget {
  final Elder elder;
  final VoidCallback onOpen;

  const _ElderCard({required this.elder, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: LinanColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(15, 14, 15, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: LinanColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  LevelPill(elder.level),
                  const SizedBox(width: 6),
                  if (elder.dataUnknown) const Tag('数据未知', color: LinanColors.warm),
                  const Spacer(),
                  Dot(elder.online ? LinanColors.green : LinanColors.border),
                  const SizedBox(width: 4),
                  Text(elder.online ? '在线' : '离线', style: const TextStyle(fontSize: 9, color: LinanColors.faint)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(elder.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: LinanColors.text)),
                  const SizedBox(width: 6),
                  Text('${elder.age} 岁', style: const TextStyle(fontSize: 10, color: LinanColors.faint)),
                ],
              ),
              const SizedBox(height: 3),
              Text('${elder.building} · ${elder.routine.isEmpty ? '作息未登记' : elder.routine}',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: LinanColors.muted)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                decoration: BoxDecoration(color: LinanColors.surfaceAlt, borderRadius: BorderRadius.circular(7)),
                child: Row(
                  children: [
                    _mini('15 分钟', '${elder.count15} 次'),
                    const SizedBox(width: 12),
                    _mini('静止', '${elder.gap} 分'),
                    const SizedBox(width: 12),
                    _mini('报平安', elder.lastCheckin == null ? '—' : formatClock(elder.lastCheckin)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                elder.evidence.isEmpty ? (elder.latestIncident ?? '暂无风险判断') : elder.evidence.first,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: LinanColors.muted, height: 1.55),
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Tag('事件 ${elder.incidentCount}', icon: Icons.report_problem_outlined),
                  const SizedBox(width: 6),
                  if (!elder.baselineReady) const Tag('学习中', color: LinanColors.amber),
                  const Spacer(),
                  Text(elder.events.isEmpty ? '查看详情' : '详情',
                      style: const TextStyle(fontSize: 10, color: LinanColors.primary, fontWeight: FontWeight.w600)),
                  const Icon(Icons.chevron_right, size: 14, color: LinanColors.primary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mini(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 8.5, color: LinanColors.faint)),
        const SizedBox(height: 1),
        Text(value, style: const TextStyle(fontSize: 10.5, color: LinanColors.text, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _ElderDetail extends StatefulWidget {
  final AppState state;
  final Elder elder;

  const _ElderDetail({required this.state, required this.elder});

  @override
  State<_ElderDetail> createState() => _ElderDetailState();
}

class _ElderDetailState extends State<_ElderDetail> {
  late Future<Elder> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.state.elderDetail(widget.elder.id);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Elder>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (snapshot.hasError) {
          return EmptyHint('加载详情失败：${snapshot.error}', icon: Icons.error_outline);
        }
        final e = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                LevelPill(e.level),
                const SizedBox(width: 8),
                if (e.dataUnknown) const Tag('数据缺失 = 未知', color: LinanColors.warm),
                const Spacer(),
                Text('档案版本 ${e.version.toStringAsFixed(0)}', style: const TextStyle(fontSize: 9.5, color: LinanColors.faint)),
              ],
            ),
            const SizedBox(height: 14),
            _blockTitle('基础档案'),
            SectionCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Column(
                children: [
                  KeyValue('年龄 / 楼栋', '${e.age} 岁 · ${e.building}'),
                  KeyValue('联系人', e.contact),
                  KeyValue('日常作息', e.routine),
                  KeyValue('计划报平安', '每天 ${e.checkinHour.toString().padLeft(2, '0')}:00 前后'),
                  KeyValue('数据来源', e.origin),
                  KeyValue('历史基线', '${e.historyDays} 天 · ${e.baselineReady ? '可用于个性化判断' : '学习中，暂不生成成熟基线'}'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _blockTitle('当前判断依据'),
            SectionCard(
              child: e.evidence.isEmpty
                  ? const Text('暂无可展示的异常证据。', style: TextStyle(fontSize: 11, color: LinanColors.muted))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final line in e.evidence)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 5),
                                  child: Dot(LinanColors.amber, size: 5),
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Text(line, style: const TextStyle(fontSize: 11, color: LinanColors.text, height: 1.6))),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 16),
            _blockTitle('最近上报'),
            if (e.events.isEmpty)
              SectionCard(child: const EmptyHint('还没有上报记录'))
            else
              Column(
                children: [
                  for (final ev in e.events.take(12))
                    Container(
                      margin: const EdgeInsets.only(bottom: 7),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: LinanColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: LinanColors.borderSoft),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: LinanColors.surfaceAlt, borderRadius: BorderRadius.circular(4)),
                            child: Text(kindName('${ev['kind'] ?? ''}'),
                                style: const TextStyle(fontSize: 9, color: LinanColors.muted)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _eventPayload(ev),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 10.5, color: LinanColors.text),
                            ),
                          ),
                          Text(formatStamp((ev['received_at'] as num?)?.toInt()),
                              style: const TextStyle(fontSize: 9, color: LinanColors.faint)),
                        ],
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 8),
            if (widget.state.user?.isAdmin == true)
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => _ProfileDialog(state: widget.state, elder: e),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: const Text('编辑档案'),
                ),
              ),
          ],
        );
      },
    );
  }

  String _eventPayload(Map<String, dynamic> ev) {
    final payload = ev['payload'];
    if (payload is! Map || payload.isEmpty) return kindName('${ev['kind'] ?? ''}');
    final parts = <String>[];
    for (final entry in payload.entries) {
      final v = entry.value;
      if (v is List) continue;
      parts.add('${entry.key}=$v');
    }
    return parts.isEmpty ? kindName('${ev['kind'] ?? ''}') : parts.join(' · ');
  }

  Widget _blockTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Text(text, style: const TextStyle(fontSize: 10, letterSpacing: .8, color: LinanColors.faint)),
      );
}

class _ProfileDialog extends StatefulWidget {
  final AppState state;
  final Elder? elder;

  const _ProfileDialog({required this.state, this.elder});

  @override
  State<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<_ProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _age;
  late final TextEditingController _building;
  late final TextEditingController _contact;
  late final TextEditingController _routine;
  late final TextEditingController _checkin;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.elder;
    _name = TextEditingController(text: e?.name ?? '');
    _age = TextEditingController(text: '${e?.age ?? 75}');
    _building = TextEditingController(text: e?.building ?? '3 号楼');
    _contact = TextEditingController(text: e?.contact ?? '');
    _routine = TextEditingController(text: e?.routine ?? '早睡早起，上午活动');
    _checkin = TextEditingController(text: '${e?.checkinHour ?? 9}');
  }

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _building.dispose();
    _contact.dispose();
    _routine.dispose();
    _checkin.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.state.saveElder({
        'name': _name.text.trim(),
        'age': int.parse(_age.text.trim()),
        'building': _building.text.trim(),
        'contact': _contact.text.trim(),
        'routine': _routine.text.trim(),
        'checkin_hour': int.parse(_checkin.text.trim()),
      }, id: widget.elder?.id);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(widget.elder == null ? '新建老人档案' : '编辑老人档案',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                const Text('档案只描述虚拟社区；历史不足时系统会显示学习中。',
                    style: TextStyle(fontSize: 10, color: LinanColors.muted)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(labelText: '姓名'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? '必填' : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _age,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: '年龄'),
                        validator: (v) {
                          final n = int.tryParse(v?.trim() ?? '');
                          if (n == null || n < 60 || n > 120) return '60–120';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _building,
                  decoration: const InputDecoration(labelText: '楼栋'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? '必填' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _contact,
                  decoration: const InputDecoration(labelText: '联系人 / 电话'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _routine,
                  decoration: const InputDecoration(labelText: '日常作息'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _checkin,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '计划报平安小时（0–23）'),
                  validator: (v) {
                    final n = int.tryParse(v?.trim() ?? '');
                    if (n == null || n < 0 || n > 23) return '0–23';
                    return null;
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(fontSize: 11, color: LinanColors.danger)),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: const Text('取消')),
                    const SizedBox(width: 6),
                    FilledButton(
                      onPressed: _saving ? null : _submit,
                      child: _saving
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.6, color: Colors.white))
                          : Text(widget.elder == null ? '创建档案' : '保存修改'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
