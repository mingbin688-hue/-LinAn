import 'package:flutter/material.dart';

import '../api_client.dart';
import '../app_state.dart';
import '../labels.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/report_dialog.dart';

/// 老人档案：搜索、风险筛选与档案详情。
///
/// 外层 Shell 已提供侧栏、工具栏与背景，本页只负责内容区。
class EldersPage extends StatefulWidget {
  final AppState state;

  const EldersPage({super.key, required this.state});

  @override
  State<EldersPage> createState() => _EldersPageState();
}

class _EldersPageState extends State<EldersPage> {
  static const List<String> _segmentLabels = ['全部', '紧急', '优先', '关注', '状态未知', '平稳'];
  static const List<int?> _segmentLevels = [null, 3, 2, 1, 0, -1];

  final _search = TextEditingController();
  int? _levelFilter;
  bool _onlyUnknown = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Elder> _rows(AppState state) {
    final key = _search.text.trim();
    return state.elders.where((e) {
      if (key.isNotEmpty && !e.name.contains(key) && !e.building.contains(key)) {
        return false;
      }
      if (_levelFilter != null && e.level != _levelFilter) return false;
      if (_onlyUnknown && !e.dataUnknown) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.level.compareTo(a.level));
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final rows = _rows(state);
    final attention = state.elders.where((e) => e.level >= 2).length;
    final unknown = state.elders.where((e) => e.dataUnknown).length;
    final filtered = rows.length != state.elders.length;

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
                    title: '老人档案',
                    subtitle: '在册 ${state.elders.length} 位 · 需关注 $attention 位 · 数据未知 $unknown 位',
                    icon: Icons.elderly_rounded,
                    padding: const EdgeInsets.fromLTRB(0, 22, 0, 16),
                    actions: [
                      if (state.user?.isAdmin == true)
                        FilledButton.icon(
                          onPressed: () => _openProfileSheet(context, state),
                          icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                          label: const Text('新建档案'),
                        ),
                    ],
                  ),
                  _filterCard(rows),
                  const SizedBox(height: 14),
                  if (rows.isEmpty)
                    SectionCard(
                      child: EmptyHint(
                        filtered ? '没有匹配的老人档案，试试清空筛选条件' : '还没有老人档案',
                        icon: Icons.search_off_rounded,
                      ),
                    )
                  else
                    LayoutBuilder(
                      builder: (context, box) {
                        final cols = box.maxWidth >= 1120
                            ? 3
                            : box.maxWidth >= 720
                                ? 2
                                : 1;
                        const gap = 14.0;
                        final width = (box.maxWidth - gap * (cols - 1)) / cols;
                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [
                            for (final elder in rows)
                              SizedBox(
                                width: width,
                                child: _ElderCard(
                                  elder: elder,
                                  onOpen: () => _openDetail(context, state, elder),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _filterCard(List<Elder> rows) {
    final index = _segmentLevels.indexOf(_levelFilter);
    return SectionCard(
      padding: EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _searchField()),
              SizedBox(width: 10),
              _TogglePill(
                label: '仅看数据未知',
                icon: Icons.help_outline_rounded,
                color: LinanColors.warm,
                selected: _onlyUnknown,
                onTap: () => setState(() => _onlyUnknown = !_onlyUnknown),
              ),
            ],
          ),
          SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SegmentedControl(
                  labels: _segmentLabels,
                  selected: index < 0 ? 0 : index,
                  onChanged: (i) => setState(() => _levelFilter = _segmentLevels[i]),
                ),
              ),
              SizedBox(width: 12),
              Text(
                '${rows.length} 位',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: LinanColors.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _searchField() {
    return TextField(
      controller: _search,
      onChanged: (_) => setState(() {}),
      textInputAction: TextInputAction.search,
      style: TextStyle(fontSize: 13, color: LinanColors.text),
      decoration: InputDecoration(
        hintText: '搜索姓名或楼栋',
        isDense: true,
        prefixIcon: Icon(Icons.search_rounded, size: 17, color: LinanColors.faint),
        prefixIconConstraints: BoxConstraints(minWidth: 38, minHeight: 34),
        suffixIconConstraints: BoxConstraints(minWidth: 34, minHeight: 34),
        suffixIcon: _search.text.isEmpty
            ? null
            : IconButton(
                tooltip: '清空搜索',
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(_search.clear),
                icon: Icon(Icons.close_rounded, size: 15, color: LinanColors.faint),
              ),
      ),
    );
  }

  Future<void> _openDetail(BuildContext context, AppState state, Elder elder) {
    return showSideSheet(
      context,
      title: elder.name,
      subtitle: '${elder.age} 岁 · ${elder.building} · 档案 #${elder.id}',
      actions: [
        TextButton.icon(
          onPressed: () => showReportDialog(context, state, elderId: elder.id),
          icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
          label: const Text('上报信息'),
        ),
      ],
      child: _ElderDetail(state: state, elder: elder),
    );
  }
}

/// 打开新建 / 编辑档案表单（iOS form sheet）。
Future<void> _openProfileSheet(
  BuildContext context,
  AppState state, {
  Elder? elder,
  VoidCallback? onSaved,
}) {
  return showSideSheet(
    context,
    title: elder == null ? '新建老人档案' : '编辑老人档案',
    subtitle: '档案只描述虚拟社区；历史不足时系统会显示学习中。',
    child: _ProfileForm(state: state, elder: elder, onSaved: onSaved),
  );
}

/// 老人卡片：身份、风险与最近活动一屏可读。
class _ElderCard extends StatelessWidget {
  final Elder elder;
  final VoidCallback onOpen;

  const _ElderCard({required this.elder, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final style = LevelStyle.of(elder.level);
    final evidence = elder.evidence.isEmpty
        ? (elder.latestIncident ?? '暂无风险判断')
        : elder.evidence.first;

    return Material(
      color: LinanColors.surface,
      borderRadius: BorderRadius.circular(LinanColors.rCard),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 15, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Monogram(name: elder.name, color: style.fg),
                  SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                elder.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: LinanColors.text,
                                  height: 1.25,
                                ),
                              ),
                            ),
                            SizedBox(width: 6),
                            Text(
                              '${elder.age} 岁',
                              style: TextStyle(fontSize: 11.5, color: LinanColors.faint),
                            ),
                          ],
                        ),
                        SizedBox(height: 3),
                        Text(
                          '${elder.building} · ${elder.routine.isEmpty ? '作息未登记' : elder.routine}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: LinanColors.muted, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      LevelPill(elder.level),
                      SizedBox(height: 5),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Dot(elder.online ? LinanColors.green : LinanColors.border),
                          SizedBox(width: 4),
                          Text(
                            elder.online ? '在线' : '离线',
                            style: TextStyle(fontSize: 11.5, color: LinanColors.faint),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                decoration: BoxDecoration(
                  color: LinanColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(LinanColors.rControl),
                ),
                child: Row(
                  children: [
                    Expanded(child: _metric('15 分钟', '${elder.count15} 次')),
                    _MetricDivider(),
                    Expanded(child: _metric('静止', '${elder.gap} 分')),
                    _MetricDivider(),
                    Expanded(
                      child: _metric(
                        '报平安',
                        elder.lastCheckin == null ? '—' : formatClock(elder.lastCheckin),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 10),
              SizedBox(
                height: 35,
                child: Text(
                  evidence,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: LinanColors.muted, height: 1.5),
                ),
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      children: [
                        Tag('事件 ${elder.incidentCount}', icon: Icons.report_problem_outlined),
                        if (elder.dataUnknown) Tag('数据未知', color: LinanColors.warm),
                        if (!elder.baselineReady) Tag('学习中', color: LinanColors.amber),
                      ],
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    '详情',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: LinanColors.primary),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 16, color: LinanColors.primary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11.5, color: LinanColors.faint, height: 1.2),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: LinanColors.text,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 22,
      margin: const EdgeInsets.symmetric(horizontal: 9),
      color: LinanColors.borderSoft,
    );
  }
}

class _Monogram extends StatelessWidget {
  final String name;
  final Color color;

  const _Monogram({required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: LinanColors.tint(color, .13), shape: BoxShape.circle),
      child: Text(
        name.isEmpty ? '安' : name.characters.first,
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

/// 与分段控件同高的本地开关胶囊。
class _TogglePill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _TogglePill({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ink = selected ? color : LinanColors.muted;
    return Material(
      color: selected ? LinanColors.tint(color, .12) : LinanColors.surfaceAlt,
      borderRadius: BorderRadius.circular(LinanColors.rPill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(LinanColors.rPill),
        child: SizedBox(
          height: _height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 13, color: ink),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: ink),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static const double _height = 38;
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

  void _reload() {
    setState(() => _future = widget.state.elderDetail(widget.elder.id));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Elder>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 64),
            child: Center(
              child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          );
        }
        final error = snapshot.error;
        if (error != null) {
          final missing = error is ApiException && error.status == 404;
          return _InlineError(
            title: missing ? '档案不存在' : '加载详情失败',
            message: missing ? '该老人档案不存在或已被移除，请返回后刷新列表。' : '加载详情失败：$error',
            onRetry: _reload,
          );
        }
        final elder = snapshot.data;
        if (elder == null) {
          return _InlineError(
            title: '加载详情失败',
            message: '没有取到档案数据，请返回后刷新列表。',
            onRetry: _reload,
          );
        }
        return _content(elder);
      },
    );
  }

  Widget _content(Elder e) {
    final admin = widget.state.user?.isAdmin == true;
    final events = e.events.take(12).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            LevelPill(e.level),
            if (e.dataUnknown) Tag('数据缺失 = 未知', color: LinanColors.warm),
            if (!e.baselineReady) Tag('学习中', color: LinanColors.amber),
            Tag('档案版本 ${e.version.toStringAsFixed(0)}'),
          ],
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: '基础档案',
          icon: Icons.badge_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              KeyValue('年龄 / 楼栋', '${e.age} 岁 · ${e.building}'),
              KeyValue('联系人', e.contact.isEmpty ? '未登记' : e.contact),
              KeyValue('日常作息', e.routine.isEmpty ? '未登记' : e.routine),
              KeyValue('计划报平安', '每天 ${e.checkinHour.toString().padLeft(2, '0')}:00 前后'),
              KeyValue('数据来源', e.origin),
              KeyValue(
                '历史基线',
                '${e.historyDays} 天 · ${e.baselineReady ? '可用于个性化判断' : '学习中，暂不生成成熟基线'}',
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
        SectionCard(
          title: '当前判断依据',
          icon: Icons.insights_outlined,
          child: e.evidence.isEmpty
              ? EmptyHint('暂无可展示的异常证据。', icon: Icons.notes_rounded)
              : _BulletList(e.evidence),
        ),
        SizedBox(height: 12),
        SectionCard(
          title: '最近上报',
          icon: Icons.history_rounded,
          subtitle: events.isEmpty ? null : '照护端上报的最近 ${events.length} 条记录',
          trailing: events.isEmpty ? null : Tag('${e.events.length} 条'),
          padding: EdgeInsets.fromLTRB(18, 17, 18, 8),
          child: events.isEmpty
              ? EmptyHint('还没有上报记录', icon: Icons.inbox_outlined)
              : Column(
                  children: [
                    for (var i = 0; i < events.length; i++)
                      ListRow(
                        leading: IconTile(
                          _eventIcon('${events[i]['kind'] ?? ''}'),
                          size: 30,
                          iconSize: 15,
                          color: LinanColors.teal,
                        ),
                        title: _eventPayload(events[i]),
                        subtitle: kindName('${events[i]['kind'] ?? ''}'),
                        trailing: Text(
                          formatStamp(events[i]['received_at'] as num?),
                          style: TextStyle(fontSize: 11, color: LinanColors.faint),
                        ),
                        showDivider: i != events.length - 1,
                        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 9),
                      ),
                  ],
                ),
        ),
        if (admin) ...[
          SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () =>
                  _openProfileSheet(context, widget.state, elder: e, onSaved: _reload),
              icon: Icon(Icons.edit_outlined, size: 16),
              label: Text('编辑档案'),
            ),
          ),
        ],
      ],
    );
  }
}

class _InlineError extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;

  const _InlineError({required this.title, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 15, 16, 16),
      decoration: BoxDecoration(
        color: LinanColors.tint(LinanColors.danger, .08),
        borderRadius: BorderRadius.circular(LinanColors.rCard),
        border: Border.all(color: LinanColors.tint(LinanColors.danger, .2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline_rounded, size: 17, color: LinanColors.danger),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: LinanColors.danger,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: TextStyle(fontSize: 12, height: 1.6, color: LinanColors.tint(LinanColors.danger, .95)),
          ),
          SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: Icon(Icons.refresh_rounded, size: 15),
            label: Text('重新加载'),
          ),
        ],
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

IconData _eventIcon(String kind) {
  switch (kind) {
    case 'safe':
      return Icons.verified_user_outlined;
    case 'sos':
      return Icons.emergency_outlined;
    case 'contact':
      return Icons.phone_in_talk_outlined;
    case 'away':
      return Icons.directions_walk_rounded;
    case 'home':
      return Icons.home_outlined;
    case 'rest':
      return Icons.bedtime_outlined;
    case 'need_help':
      return Icons.volunteer_activism_outlined;
    case 'unreachable':
      return Icons.phone_disabled_outlined;
    case 'missed_checkin':
      return Icons.schedule_rounded;
    case 'activity':
      return Icons.directions_run_rounded;
    case 'data_offline':
      return Icons.sensors_off_outlined;
    case 'data_online':
      return Icons.sensors_rounded;
    default:
      return Icons.receipt_long_outlined;
  }
}

String _eventPayload(Map<String, dynamic> ev) {
  final kind = kindName('${ev['kind'] ?? ''}');
  final payload = ev['payload'];
  if (payload is! Map || payload.isEmpty) return kind;
  final parts = <String>[];
  for (final entry in payload.entries) {
    final value = entry.value;
    if (value is List) continue;
    parts.add('${entry.key}=$value');
  }
  return parts.isEmpty ? kind : parts.join(' · ');
}

/// 新建 / 编辑档案表单；保存逻辑与原对话框一致。
class _ProfileForm extends StatefulWidget {
  final AppState state;
  final Elder? elder;
  final VoidCallback? onSaved;

  const _ProfileForm({required this.state, this.elder, this.onSaved});

  @override
  State<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<_ProfileForm> {
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
    final elder = widget.elder;
    _name = TextEditingController(text: elder?.name ?? '');
    _age = TextEditingController(text: '${elder?.age ?? 75}');
    _building = TextEditingController(text: elder?.building ?? '3 号楼');
    _contact = TextEditingController(text: elder?.contact ?? '');
    _routine = TextEditingController(text: elder?.routine ?? '早睡早起，上午活动');
    _checkin = TextEditingController(text: '${elder?.checkinHour ?? 9}');
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
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.state.saveElder(
        {
          'name': _name.text.trim(),
          'age': int.parse(_age.text.trim()),
          'building': _building.text.trim(),
          'contact': _contact.text.trim(),
          'routine': _routine.text.trim(),
          'checkin_hour': int.parse(_checkin.text.trim()),
        },
        id: widget.elder?.id,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSaved?.call();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _field(_name, '姓名', mustFill: true)),
              SizedBox(width: 10),
              Expanded(flex: 2, child: _field(_age, '年龄', validator: _ageValidator)),
            ],
          ),
          SizedBox(height: 12),
          _field(_building, '楼栋', mustFill: true),
          SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _field(_contact, '联系人 / 电话')),
              SizedBox(width: 10),
              Expanded(flex: 2, child: _field(_checkin, '报平安小时（0–23）', validator: _checkinValidator)),
            ],
          ),
          SizedBox(height: 12),
          _field(_routine, '日常作息', maxLines: 2),
          if (_error != null) ...[
            SizedBox(height: 14),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: LinanColors.tint(LinanColors.danger, .08),
                borderRadius: BorderRadius.circular(LinanColors.rControl),
                border: Border.all(color: LinanColors.tint(LinanColors.danger, .2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline_rounded, size: 15, color: LinanColors.danger),
                  SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(fontSize: 12, height: 1.5, color: LinanColors.danger),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              const SizedBox(width: 6),
              FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(widget.elder == null ? '创建档案' : '保存修改'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool mustFill = false,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      enabled: !_saving,
      style: TextStyle(fontSize: 13, color: LinanColors.text),
      decoration: InputDecoration(labelText: label, isDense: true),
      validator: validator ??
          (mustFill
              ? (value) => (value == null || value.trim().isEmpty) ? '必填' : null
              : null),
    );
  }

  static String? _ageValidator(String? value) {
    final age = int.tryParse((value ?? '').trim());
    if (age == null || age < 60 || age > 120) return '60–120';
    return null;
  }

  static String? _checkinValidator(String? value) {
    final hour = int.tryParse((value ?? '').trim());
    if (hour == null || hour < 0 || hour > 23) return '0–23';
    return null;
  }
}
