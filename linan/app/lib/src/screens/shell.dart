import 'package:flutter/material.dart';

import '../app_state.dart';
import '../labels.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/report_dialog.dart';
import 'assistant.dart';
import 'care.dart';
import 'elders.dart';
import 'incidents.dart';
import 'lab.dart';
import 'overview.dart';
import 'staff.dart';
import 'tasks.dart';
import 'workflows.dart';

class ShellScreen extends StatefulWidget {
  final AppState state;
  const ShellScreen({super.key, required this.state});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  AppState get s => widget.state;

  List<Widget> _pages() {
    final role = s.user!.role;
    if (role == 'admin') {
      return [
        OverviewPage(state: s),
        EldersPage(state: s),
        IncidentsPage(state: s),
        TasksPage(state: s),
        StaffPage(state: s),
        AssistantPage(state: s),
        WorkflowsPage(state: s),
        LabPage(state: s),
      ];
    }
    if (role == 'staff') {
      return [
        TasksPage(state: s),
        EldersPage(state: s),
        StaffPage(state: s),
        AssistantPage(state: s),
      ];
    }
    return [
      CarePage(state: s),
      IncidentsPage(state: s),
      AssistantPage(state: s),
    ];
  }

  int get _index {
    final idx = s.navs.indexWhere((n) => n.key == s.page);
    return idx < 0 ? 0 : idx;
  }

  bool get _wide => MediaQuery.sizeOf(context).width >= 1000;

  void _select(String key) {
    s.selectPage(key);
    if (!_wide) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(
      children: [
        _TopBar(
          state: s,
          showMenu: !_wide,
          onMenu: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        Expanded(
          child: IndexedStack(
            index: _index,
            children: _pages(),
          ),
        ),
      ],
    );

    if (_wide) {
      return Scaffold(
        body: Row(
          children: [
            _Sidebar(state: s, onSelect: _select, onLogout: s.logout),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        width: 262,
        child: _Sidebar(state: s, onSelect: _select, onLogout: s.logout, drawer: true),
      ),
      body: body,
    );
  }
}

class _Sidebar extends StatelessWidget {
  final AppState state;
  final ValueChanged<String> onSelect;
  final VoidCallback onLogout;
  final bool drawer;

  const _Sidebar({
    required this.state,
    required this.onSelect,
    required this.onLogout,
    this.drawer = false,
  });

  @override
  Widget build(BuildContext context) {
    final user = state.user!;
    return Container(
      width: drawer ? null : 224,
      color: LinanColors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 14, 16),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(color: LinanColors.primary, borderRadius: BorderRadius.circular(9)),
                    alignment: Alignment.center,
                    child: const Text('安', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('邻安', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: LinanColors.text, height: 1.2)),
                      Text('社区守护', style: TextStyle(fontSize: 9.5, color: LinanColors.muted, letterSpacing: .5)),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: LinanColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: LinanColors.borderSoft),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.location_city_outlined, size: 13, color: LinanColors.green),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text('梧桐里社区 · 虚拟档案',
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10, color: LinanColors.muted)),
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 2, 20, 6),
              child: Text('守护台', style: TextStyle(fontSize: 9, letterSpacing: 1.2, color: LinanColors.faint)),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: [
                  for (final nav in state.navs)
                    _NavItem(
                      nav: nav,
                      selected: state.page == nav.key,
                      onTap: () => onSelect(nav.key),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: LinanColors.primarySoft,
                    child: Text(user.name.isEmpty ? '安' : user.name.characters.first,
                        style: const TextStyle(fontSize: 12, color: LinanColors.primary, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: LinanColors.text)),
                        Text(roleNames[user.role] ?? user.role,
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 9.5, color: LinanColors.muted)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '退出登录',
                    onPressed: onLogout,
                    icon: const Icon(Icons.logout, size: 16),
                    color: LinanColors.muted,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final NavDef nav;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({required this.nav, required this.selected, required this.onTap});

  static const Map<String, IconData> _icons = {
    'overview': Icons.space_dashboard_outlined,
    'elders': Icons.elderly,
    'incidents': Icons.report_problem_outlined,
    'tasks': Icons.assignment_outlined,
    'staff': Icons.groups_outlined,
    'assistant': Icons.forum_outlined,
    'workflows': Icons.account_tree_outlined,
    'lab': Icons.science_outlined,
    'care': Icons.volunteer_activism_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? LinanColors.primarySoft : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                Icon(
                  _icons[nav.key] ?? Icons.circle_outlined,
                  size: 16,
                  color: selected ? LinanColors.primary : LinanColors.muted,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    nav.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected ? LinanColors.primaryDeep : LinanColors.text,
                    ),
                  ),
                ),
                if (selected) Container(width: 4, height: 4, decoration: const BoxDecoration(color: LinanColors.primary, shape: BoxShape.circle)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final AppState state;
  final bool showMenu;
  final VoidCallback onMenu;

  const _TopBar({required this.state, required this.showMenu, required this.onMenu});

  @override
  Widget build(BuildContext context) {
    final user = state.user!;
    final width = MediaQuery.sizeOf(context).width;
    final showDate = width >= 780;
    final showReport = !state.isCareSide;

    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        color: LinanColors.surface,
        border: Border(bottom: BorderSide(color: LinanColors.border)),
      ),
      child: Row(
        children: [
          if (showMenu)
            IconButton(
              onPressed: onMenu,
              icon: const Icon(Icons.menu, size: 18),
              color: LinanColors.text,
            ),
          if (showMenu) const SizedBox(width: 4),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('邻安', style: TextStyle(fontSize: 10, color: LinanColors.faint)),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Text('/', style: TextStyle(fontSize: 10, color: LinanColors.border)),
                    ),
                    Text(navLabel(state.page),
                        style: const TextStyle(fontSize: 10, color: LinanColors.green, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  navLabel(state.page),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: LinanColors.text),
                ),
              ],
            ),
          ),
          if (showDate)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(formatToday(), style: const TextStyle(fontSize: 10.5, color: LinanColors.muted)),
            ),
          IconButton(
            tooltip: '刷新',
            onPressed: state.loading ? null : () => state.refresh(),
            icon: state.loading
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.6))
                : const Icon(Icons.refresh, size: 16),
            color: LinanColors.muted,
          ),
          if (showReport)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: OutlinedButton(
                onPressed: () => showReportDialog(context, state),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_circle_outline, size: 13),
                    SizedBox(width: 5),
                    Text('信息上报'),
                  ],
                ),
              ),
            ),
          IconButton(
            tooltip: '站内消息',
            onPressed: () => _showNotices(context, state),
            icon: Badge(
              isLabelVisible: state.notices.isNotEmpty,
              label: Text('${state.notices.length > 99 ? 99 : state.notices.length}'),
              backgroundColor: LinanColors.danger,
              child: const Icon(Icons.notifications_none, size: 17),
            ),
            color: LinanColors.muted,
          ),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            tooltip: '账号',
            offset: const Offset(0, 42),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            onSelected: (v) {
              if (v == 'logout') state.logout();
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: LinanColors.text)),
                    const SizedBox(height: 2),
                    Text('${user.username} · ${roleNames[user.role] ?? user.role}',
                        style: const TextStyle(fontSize: 10, color: LinanColors.muted)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'logout', child: Text('退出登录', style: TextStyle(fontSize: 12))),
            ],
            child: CircleAvatar(
              radius: 15,
              backgroundColor: LinanColors.primarySoft,
              child: Text(user.name.isEmpty ? '安' : user.name.characters.first,
                  style: const TextStyle(fontSize: 12, color: LinanColors.primary, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  void _showNotices(BuildContext context, AppState state) {
    showSideSheet(
      context,
      title: '站内消息',
      subtitle: '按角色过滤的最近通知，每 5 秒随状态刷新',
      child: state.notices.isEmpty
          ? const EmptyHint('暂时没有新消息')
          : Column(
              children: [
                for (final n in state.notices)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: LinanColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: LinanColors.borderSoft),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(n.title,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: LinanColors.text)),
                            ),
                            Text(formatStamp(n.created), style: const TextStyle(fontSize: 9.5, color: LinanColors.faint)),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(n.body, style: const TextStyle(fontSize: 11, color: LinanColors.muted, height: 1.6)),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
