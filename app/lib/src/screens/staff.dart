import 'package:flutter/material.dart';

import '../app_state.dart';
import '../labels.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

class StaffPage extends StatelessWidget {
  final AppState state;
  const StaffPage({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final admin = state.user?.isAdmin == true;
    final rows = admin ? state.staff : state.staff.where((s) => s.id == state.user?.staffId).toList();
    final onDuty = rows.where((p) => p.onDuty).length;
    final busy = rows.where((p) => p.busy).length;

    return LayoutBuilder(
      builder: (context, shell) {
        final side = shell.maxWidth > 1228 ? (shell.maxWidth - 1180) / 2 : 24.0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: admin ? '照护人员' : '我的值班状态',
              subtitle: admin
                  ? '在岗 $onDuty / ${rows.length} 人 · 执行中 $busy 人'
                  : '你只能查看和维护自己的值班状态；任务范围也仅限本人。',
              icon: Icons.groups_2_outlined,
              accent: LinanColors.teal,
              padding: EdgeInsets.fromLTRB(side, 22, side, 14),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(side, 0, side, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _infoBanner(admin),
                    const SizedBox(height: 14),
                    if (rows.isEmpty)
                      const EmptyHint('没有人员记录', icon: Icons.person_search_outlined)
                    else
                      LayoutBuilder(
                        builder: (context, c) {
                          final cols = c.maxWidth >= 1080 ? 3 : (c.maxWidth >= 720 ? 2 : 1);
                          const gap = 14.0;
                          final width = (c.maxWidth - gap * (cols - 1)) / cols;
                          return Wrap(
                            spacing: gap,
                            runSpacing: gap,
                            children: [
                              for (final p in rows)
                                SizedBox(
                                  width: width,
                                  child: _StaffCard(
                                    key: ValueKey(p.id),
                                    state: state,
                                    staff: p,
                                    editable: admin || p.id == state.user?.staffId,
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
          ],
        );
      },
    );
  }

  Widget _infoBanner(bool admin) => Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: LinanColors.primarySoft.withValues(alpha: .7),
          borderRadius: BorderRadius.circular(LinanColors.rControl),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(Icons.info_outline_rounded, size: 15, color: LinanColors.primary),
            ),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                admin
                    ? '派单会同时校验技能、值班、可用性、楼栋与单任务容量；人员版本变化后，旧推荐会失效。'
                    : '你只能查看和维护自己的值班状态；任务范围也仅限本人。',
                style: TextStyle(fontSize: 11.5, color: LinanColors.primaryDeep, height: 1.6),
              ),
            ),
          ],
        ),
      );
}

class _StaffCard extends StatelessWidget {
  final AppState state;
  final Staff staff;
  final bool editable;

  const _StaffCard({super.key, required this.state, required this.staff, required this.editable});

  @override
  Widget build(BuildContext context) {
    final mine = staff.id == state.user?.staffId;
    final used = staff.busy ? 1 : 0;
    final trackColor = staff.busy
        ? LinanColors.amber
        : staff.onDuty && staff.available
            ? LinanColors.green
            : LinanColors.faint;

    return SectionCard(
      padding: EdgeInsets.fromLTRB(18, 15, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => _openDetail(context),
            borderRadius: BorderRadius.circular(LinanColors.rControl),
            child: Row(
              children: [
                _avatar(staff),
                SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(staff.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600, color: LinanColors.text, letterSpacing: -.2)),
                      SizedBox(height: 2),
                      Text('人员 #${staff.id} · ${staff.location} 号楼',
                          style: TextStyle(fontSize: 11, color: LinanColors.muted)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Tag(
                      staff.busy ? '执行中' : (staff.onDuty ? (staff.available ? '可接单' : '值班中') : '未值班'),
                      color: staff.busy
                          ? LinanColors.amber
                          : staff.onDuty
                              ? (staff.available ? LinanColors.green : LinanColors.primary)
                              : LinanColors.muted,
                    ),
                    SizedBox(height: 4),
                    Icon(Icons.chevron_right_rounded, size: 18, color: LinanColors.faint),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 11),
          if (staff.skills.isEmpty)
            Text('暂未登记技能', style: TextStyle(fontSize: 11, color: LinanColors.faint))
          else
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                for (final skill in staff.skills)
                  Tag(skillName(skill), color: LinanColors.primary, icon: Icons.verified_outlined),
              ],
            ),
          SizedBox(height: 12),
          Row(
            children: [
              Text('当前任务', style: TextStyle(fontSize: 11.5, color: LinanColors.muted)),
              SizedBox(width: 8),
              Text('$used / 1',
                  style: TextStyle(fontSize: 11.5, color: trackColor, fontWeight: FontWeight.w600)),
              Spacer(),
              Text(staff.onDuty ? '值班中' : '未值班',
                  style: TextStyle(fontSize: 11.5, color: LinanColors.faint)),
            ],
          ),
          SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Container(
              height: 4,
              color: LinanColors.fill,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: used / 1,
                child: ColoredBox(color: trackColor),
              ),
            ),
          ),
          Divider(height: 22),
          _StaffControls(state: state, staff: staff, editable: editable),
          Divider(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  staff.activeTask == null ? '当前没有未关闭任务' : '执行中任务 #${staff.activeTask}',
                  style: TextStyle(fontSize: 11.5, color: LinanColors.muted),
                ),
              ),
              if (staff.activeTask != null)
                TextButton(
                  onPressed: () => state.selectPage('tasks'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 30),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  child: Text('查看'),
                ),
            ],
          ),
          if (mine)
            Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('这是你自己的服务身份；切换状态会立即影响可派单性。',
                  style: TextStyle(fontSize: 11, color: LinanColors.faint, height: 1.5)),
            ),
        ],
      ),
    );
  }

  Widget _avatar(Staff staff) => Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: LinanColors.primarySoft,
          shape: BoxShape.circle,
          border: Border.all(color: LinanColors.primary.withValues(alpha: .14)),
        ),
        child: Text(
          staff.name.isEmpty ? '?' : staff.name.characters.first,
          style: TextStyle(fontSize: 16, color: LinanColors.primaryText, fontWeight: FontWeight.w600),
        ),
      );

  Future<void> _openDetail(BuildContext context) async {
    await showSideSheet(
      context,
      title: '${staff.name} · 人员 #${staff.id}',
      subtitle: '${staff.location} 号楼 · ${staff.onDuty ? '值班中' : '未值班'}',
      child: _StaffDetail(state: state, staffId: staff.id, editable: editable),
    );
  }
}

/// 值班 / 接单 / 楼栋三个可编辑项；卡片和详情侧滑各自持有一份，读取同一个 AppState。
class _StaffControls extends StatefulWidget {
  final AppState state;
  final Staff staff;
  final bool editable;

  const _StaffControls({required this.state, required this.staff, required this.editable});

  @override
  State<_StaffControls> createState() => _StaffControlsState();
}

class _StaffControlsState extends State<_StaffControls> {
  /// 请求进行中：禁用开关与下拉，避免重复 PUT。
  bool _saving = false;

  /// 乐观状态；null 表示跟随服务端返回的对象。
  bool? _onDuty;
  bool? _available;
  int? _location;

  bool get _duty => _onDuty ?? widget.staff.onDuty;
  bool get _accepting => _available ?? widget.staff.available;
  int get _building => _location ?? widget.staff.location;

  @override
  void didUpdateWidget(covariant _StaffControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 服务端数据发生变化（轮询、他人修改）时以服务端为准。
    final changed = widget.staff.onDuty != oldWidget.staff.onDuty ||
        widget.staff.available != oldWidget.staff.available ||
        widget.staff.location != oldWidget.staff.location;
    if (!_saving && changed) {
      _onDuty = null;
      _available = null;
      _location = null;
    }
  }

  /// 后端 WorkerUpdate 要求 on_duty / available / location 三字段齐全，
  /// 因此每次都从当前人员对象合并出完整载荷后整体提交。
  Future<void> _save({bool? onDuty, bool? available, int? location}) async {
    if (_saving) return;
    final nextDuty = onDuty ?? _duty;
    final nextAccepting = available ?? _accepting;
    final nextBuilding = location ?? _building;
    final unchanged = nextDuty == widget.staff.onDuty &&
        nextAccepting == widget.staff.available &&
        nextBuilding == widget.staff.location;
    if (unchanged) return;

    setState(() {
      _saving = true;
      _onDuty = nextDuty;
      _available = nextAccepting;
      _location = nextBuilding;
    });

    var ok = false;
    try {
      ok = await widget.state.updateStaff(
        widget.staff.id,
        onDuty: nextDuty,
        available: nextAccepting,
        location: nextBuilding,
      );
    } on Object {
      // updateStaff 约定不抛异常；这里兜底，避免异常导致开关永久禁用。
      ok = false;
    }

    if (!mounted) return;
    setState(() {
      _saving = false;
      if (!ok) {
        // 失败回滚到服务端状态，控件恢复可操作以便重试。
        _onDuty = null;
        _available = null;
        _location = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final editable = widget.editable;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _line(
          '值班状态',
          editable
              ? Switch(
                  value: _duty,
                  onChanged: _saving ? null : (v) => _save(onDuty: v),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )
              : _readOnly(_duty ? '值班中' : '未值班'),
        ),
        _line(
          '接受新任务',
          editable
              ? Switch(
                  value: _accepting,
                  onChanged: _saving || !_duty ? null : (v) => _save(available: v),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )
              : _readOnly(_accepting ? '可接单' : '暂停'),
        ),
        _line(
          '负责楼栋',
          editable
              ? DropdownButton<int>(
                  value: _building,
                  isDense: true,
                  underline: SizedBox.shrink(),
                  borderRadius: BorderRadius.circular(LinanColors.rControl),
                  style: TextStyle(fontSize: 12.5, color: LinanColors.text, fontWeight: FontWeight.w500),
                  items: [
                    for (var i = 1; i <= 5; i++)
                      DropdownMenuItem(value: i, child: Text('$i 号楼', style: const TextStyle(fontSize: 12.5))),
                  ],
                  onChanged: _saving
                      ? null
                      : (v) {
                          if (v != null) _save(location: v);
                        },
                )
              : _readOnly('$_building 号楼'),
        ),
      ],
    );
  }

  Widget _readOnly(String text) => Text(text, style: TextStyle(fontSize: 12.5, color: LinanColors.text));

  Widget _line(String label, Widget control) => Padding(
        padding: EdgeInsets.symmetric(vertical: 1),
        child: Row(
          children: [
            SizedBox(
              width: 88,
              child: Text(label, style: TextStyle(fontSize: 12.5, color: LinanColors.muted)),
            ),
            Expanded(child: Align(alignment: Alignment.centerLeft, child: control)),
            if (_saving)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.6)),
              ),
          ],
        ),
      );
}

/// 人员详情侧滑：与卡片共用 AppState，打开期间跟随状态刷新。
class _StaffDetail extends StatefulWidget {
  final AppState state;
  final int staffId;
  final bool editable;

  const _StaffDetail({required this.state, required this.staffId, required this.editable});

  @override
  State<_StaffDetail> createState() => _StaffDetailState();
}

class _StaffDetailState extends State<_StaffDetail> {
  @override
  void initState() {
    super.initState();
    widget.state.addListener(_sync);
  }

  @override
  void dispose() {
    widget.state.removeListener(_sync);
    super.dispose();
  }

  void _sync() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final staff = widget.state.staffById(widget.staffId);
    if (staff == null) return EmptyHint('人员记录已不存在', icon: Icons.person_off_outlined);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          padding: EdgeInsets.fromLTRB(18, 16, 18, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: LinanColors.primarySoft, shape: BoxShape.circle),
                    child: Text(
                      staff.name.isEmpty ? '?' : staff.name.characters.first,
                      style: TextStyle(fontSize: 18, color: LinanColors.primaryText, fontWeight: FontWeight.w600),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(staff.name,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: LinanColors.text)),
                        SizedBox(height: 3),
                        Text('人员 #${staff.id} · ${staff.location} 号楼',
                            style: TextStyle(fontSize: 11.5, color: LinanColors.muted)),
                      ],
                    ),
                  ),
                  Tag(
                    staff.busy ? '执行中' : (staff.onDuty ? (staff.available ? '可接单' : '值班中') : '未值班'),
                    color: staff.busy
                        ? LinanColors.amber
                        : staff.onDuty
                            ? (staff.available ? LinanColors.green : LinanColors.primary)
                            : LinanColors.muted,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              KeyValue('技能', staff.skills.isEmpty ? '未登记' : staff.skills.map(skillName).join('、')),
              KeyValue('值班状态', staff.onDuty ? '值班中' : '未值班'),
              KeyValue('接单状态', staff.available ? '接受新任务' : '暂停接单'),
              KeyValue('负责楼栋', '${staff.location} 号楼'),
              KeyValue('当前任务', staff.activeTask == null ? '空闲' : '任务 #${staff.activeTask}'),
              KeyValue('人员版本', '${staff.version}'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: '可派单状态',
          subtitle: '切换后会立即影响后续派单与人员推荐。',
          icon: Icons.tune_rounded,
          child: _StaffControls(state: widget.state, staff: staff, editable: widget.editable),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: '派单校验',
          icon: Icons.rule_rounded,
          child: Text(
            '系统会同时校验技能、值班、可用性与单任务容量；本次调整会更新人员版本，旧的派单建议随即失效，需要重新计算。',
            style: TextStyle(fontSize: 12, height: 1.7, color: LinanColors.muted),
          ),
        ),
      ],
    );
  }
}
