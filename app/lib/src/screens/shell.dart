import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
import 'settings.dart';
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
  AppState get s => widget.state;

  /// 宽屏侧栏可以收起，给表格和长表单让出空间（HIG：桌面侧栏应当可隐藏）。
  bool _sidebarOpen = true;
  static const _digitKeys = [
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
    LogicalKeyboardKey.digit6,
    LogicalKeyboardKey.digit7,
    LogicalKeyboardKey.digit8,
    LogicalKeyboardKey.digit9,
  ];

  void _toggleSidebar() => setState(() => _sidebarOpen = !_sidebarOpen);

  void _goIndex(int index) {
    final navs = s.navs;
    if (index < navs.length) s.selectPage(navs[index].key);
  }

  @override
  void initState() {
    super.initState();
    s.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    s.removeListener(_onStateChanged);
    super.dispose();
  }

  /// 会话失效或退出登录后，本页会被登录页替换；先关掉仍打开的详情弹窗/侧滑，
  /// 避免遮罩挡在登录页上。
  void _onStateChanged() {
    if (!mounted || s.user != null) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

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
        SettingsPage(state: s),
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

  void _select(String key) => s.selectPage(key);

  @override
  Widget build(BuildContext context) {
    final wide = _wide;
    final body = Column(
      children: [
        _Toolbar(
          state: s,
          wide: wide,
          sidebarOpen: _sidebarOpen,
          onToggleSidebar: _toggleSidebar,
        ),
        Expanded(
          child: IndexedStack(
            index: _index,
            children: _pages(),
          ),
        ),
      ],
    );

    final scaffold = Scaffold(
      backgroundColor: LinanColors.bg,
      body: Stack(
        children: [
          const _AuroraBackground(),
          if (wide)
            Row(
              children: [
                if (_sidebarOpen) _Sidebar(state: s, onSelect: _select),
                Expanded(child: body),
              ],
            )
          else
            body,
        ],
      ),
      bottomNavigationBar: wide ? null : _MobileTabBar(state: s, onSelect: _select),
    );

    // 桌面键盘可达：刷新、收起侧栏、直接跳转前九项。
    // 工具栏里没有菜单栏，快捷键是 Windows 下最接近 HIG 桌面惯例的入口。
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f5): () => s.refresh(),
        const SingleActivator(LogicalKeyboardKey.keyR, control: true): () => s.refresh(),
        const SingleActivator(LogicalKeyboardKey.keyB, control: true): _toggleSidebar,
        const SingleActivator(LogicalKeyboardKey.comma, control: true): () {
          if (s.user?.role == 'admin') s.selectPage('settings');
        },
        for (var i = 0; i < _digitKeys.length; i++)
          SingleActivator(_digitKeys[i], control: true): () => _goIndex(i),
      },
      child: Focus(autofocus: true, child: scaffold),
    );
  }
}

/// 背景的柔和光晕，模拟 iOS 的半透明材质层次。
class _AuroraBackground extends StatelessWidget {
  const _AuroraBackground();

  @override
  Widget build(BuildContext context) {
    // “提高对比度”时去掉装饰光晕，只留纯色背景。
    if (MediaQuery.maybeOf(context)?.highContrast ?? false) {
      return ColoredBox(color: LinanColors.bg);
    }
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [LinanColors.bgTop, LinanColors.bg, LinanColors.bgBottom],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -160,
              right: -120,
              child: _Blob(color: LinanColors.primary.withValues(alpha: .10), size: 420),
            ),
            Positioned(
              bottom: -180,
              left: -140,
              child: _Blob(color: LinanColors.green.withValues(alpha: .09), size: 400),
            ),
          ],
        ),
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final Color color;
  final double size;
  const _Blob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}

IconData navIcon(String key) {
  return switch (key) {
    'overview' => Icons.space_dashboard_rounded,
    'elders' => Icons.elderly_rounded,
    'incidents' => Icons.warning_amber_rounded,
    'tasks' => Icons.checklist_rounded,
    'staff' => Icons.groups_rounded,
    'assistant' => Icons.chat_bubble_rounded,
    'workflows' => Icons.account_tree_rounded,
    'lab' => Icons.science_rounded,
    'settings' => Icons.settings_rounded,
    'care' => Icons.favorite_rounded,
    _ => Icons.circle,
  };
}

class _Sidebar extends StatelessWidget {
  final AppState state;
  final ValueChanged<String> onSelect;

  const _Sidebar({required this.state, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final user = state.user!;
    final solid = MediaQuery.maybeOf(context)?.highContrast ?? false;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: solid ? 0 : 28, sigmaY: solid ? 0 : 28),
        child: Container(
          width: 246,
          decoration: BoxDecoration(
            color: solid ? LinanColors.surface : LinanColors.surface.withValues(alpha: .72),
            border: Border(right: BorderSide(color: LinanColors.separator, width: .6)),
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 16, 14),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [LinanColors.brandTop, LinanColors.primary, LinanColors.brandDeep],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: LinanColors.primary.withValues(alpha: .28),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.health_and_safety_rounded, size: 22, color: Colors.white),
                      ),
                      const SizedBox(width: 11),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('邻安',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w700, color: LinanColors.text, letterSpacing: -.3, height: 1.2)),
                          Text('社区守护',
                              style: TextStyle(fontSize: 11.5, color: LinanColors.muted, letterSpacing: .2)),
                        ],
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                    decoration: BoxDecoration(
                      color: LinanColors.surfaceAlt.withValues(alpha: .9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.location_city_rounded, size: 15, color: LinanColors.teal),
                        SizedBox(width: 7),
                        Expanded(
                          child: Text('梧桐里社区 · 虚拟档案',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: LinanColors.muted, fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(22, 0, 22, 6),
                  child: Text('守护台',
                      style: TextStyle(
                          fontSize: 11.5, letterSpacing: .8, color: LinanColors.faint, fontWeight: FontWeight.w600)),
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
                Divider(height: 1),
                Padding(
                  padding: EdgeInsets.fromLTRB(14, 10, 10, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [LinanColors.accent, LinanColors.primary],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Text(user.name.isEmpty ? '安' : user.name.characters.first,
                            style: TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600)),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12.5, fontWeight: FontWeight.w600, color: LinanColors.text)),
                            Text(roleNames[user.role] ?? user.role,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11.5, color: LinanColors.muted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: selected ? LinanColors.primaryDeep : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9.5),
            child: Row(
              children: [
                Icon(
                  navIcon(nav.key),
                  size: 19,
                  color: selected ? Colors.white : LinanColors.muted,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    nav.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected ? Colors.white : LinanColors.text,
                      letterSpacing: -.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  final AppState state;
  final bool wide;
  final bool sidebarOpen;
  final VoidCallback onToggleSidebar;
  const _Toolbar({
    required this.state,
    required this.wide,
    required this.sidebarOpen,
    required this.onToggleSidebar,
  });

  @override
  Widget build(BuildContext context) {
    final user = state.user!;
    final showReport = !state.isCareSide;
    final mode = state.agentsInfo['mode'] == 'llm';
    final solid = MediaQuery.maybeOf(context)?.highContrast ?? false;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: solid ? 0 : 24, sigmaY: solid ? 0 : 24),
        child: Container(
          height: 56,
          padding: EdgeInsets.symmetric(horizontal: wide ? 22 : 10),
          decoration: BoxDecoration(
            color: solid ? LinanColors.surface : LinanColors.surface.withValues(alpha: .7),
            border: Border(bottom: BorderSide(color: LinanColors.separator, width: .6)),
          ),
          child: Row(
            children: [
              if (!wide) ...[
                CircleAvatar(
                  radius: 15,
                  backgroundColor: LinanColors.primary,
                  child: Icon(Icons.health_and_safety_rounded, size: 16, color: Colors.white),
                ),
                SizedBox(width: 9),
              ],
              if (wide) ...[
                _ToolbarButton(
                  icon: sidebarOpen ? Icons.menu_open_rounded : Icons.menu_rounded,
                  tooltip: sidebarOpen ? '隐藏侧栏 (Ctrl+B)' : '显示侧栏 (Ctrl+B)',
                  loading: false,
                  onTap: onToggleSidebar,
                ),
                SizedBox(width: 10),
                Tag(
                  mode ? '模型解释' : '规则引擎',
                  color: mode ? LinanColors.teal : LinanColors.muted,
                  icon: mode ? Icons.auto_awesome : Icons.rule,
                ),
                SizedBox(width: 8),
                _ToolbarText(text: formatToday()),
              ] else
                Expanded(
                  child: Text(navLabel(state.page),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: LinanColors.text)),
                ),
              Spacer(),
              if (wide && !state.isCareSide)
                Padding(
                  padding: EdgeInsets.only(right: 10),
                  child: Text(user.name,
                      style: TextStyle(fontSize: 12, color: LinanColors.muted, fontWeight: FontWeight.w500)),
                ),
              _ToolbarButton(
                icon: state.loading ? null : Icons.refresh_rounded,
                tooltip: '刷新 (Ctrl+R)',
                loading: state.loading,
                onTap: () => state.refresh(),
                size: wide ? 34 : 40,
              ),
              if (showReport) ...[
                const SizedBox(width: 6),
                FilledButton.icon(
                  onPressed: () => showReportDialog(context, state),
                  icon: Icon(Icons.edit_note_rounded, size: 17),
                  label: Text('信息上报'),
                  style: FilledButton.styleFrom(minimumSize: Size(0, 36), padding: EdgeInsets.symmetric(horizontal: 13)),
                ),
              ],
              SizedBox(width: 6),
              _NotificationButton(state: state, size: wide ? 34 : 40),
              SizedBox(width: 2),
              PopupMenuButton<String>(
                tooltip: '账号',
                offset: Offset(0, 46),
                onSelected: (v) {
                  if (v == 'logout') state.logout();
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    enabled: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.name,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: LinanColors.text)),
                        SizedBox(height: 2),
                        Text('${user.username} · ${roleNames[user.role] ?? user.role}',
                            style: TextStyle(fontSize: 11, color: LinanColors.muted)),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.login_rounded, size: 16, color: LinanColors.muted),
                        SizedBox(width: 8),
                        Text('退出登录', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  width: wide ? 34 : 40,
                  height: wide ? 34 : 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [LinanColors.accent, LinanColors.primary],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Text(user.name.isEmpty ? '安' : user.name.characters.first,
                      style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolbarText extends StatelessWidget {
  final String text;
  const _ToolbarText({required this.text});

  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(fontSize: 11.5, color: LinanColors.muted, fontWeight: FontWeight.w500));
}

class _ToolbarButton extends StatelessWidget {
  final IconData? icon;
  final String tooltip;
  final bool loading;
  final VoidCallback onTap;
  final double size;

  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.loading,
    required this.onTap,
    this.size = 34,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: LinanColors.surfaceAlt, borderRadius: BorderRadius.circular(10)),
          child: loading
              ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 1.8))
              : Icon(icon, size: 18, color: LinanColors.muted),
        ),
      ),
    );
  }
}

class _NotificationButton extends StatelessWidget {
  final AppState state;
  final double size;
  const _NotificationButton({required this.state, this.size = 34});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '站内消息',
      child: InkWell(
        onTap: () => _showNotices(context, state),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: LinanColors.surfaceAlt, borderRadius: BorderRadius.circular(10)),
          child: Badge(
            isLabelVisible: state.notices.isNotEmpty,
            label: Text('${state.notices.length > 99 ? 99 : state.notices.length}'),
            backgroundColor: LinanColors.danger,
            child: Icon(Icons.notifications_none_rounded, size: 19, color: LinanColors.muted),
          ),
        ),
      ),
    );
  }

  static void _showNotices(BuildContext context, AppState state) {
    showSideSheet(
      context,
      title: '站内消息',
      subtitle: '按角色过滤的最近通知，每 5 秒随状态刷新',
      child: state.notices.isEmpty
          ? EmptyHint('暂时没有新消息', icon: Icons.notifications_none_rounded)
          : Column(
              children: [
                for (final n in state.notices)
                  Container(
                    margin: EdgeInsets.only(bottom: 10),
                    padding: EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: LinanColors.surface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconTile(Icons.notifications_rounded, color: LinanColors.primary, size: 30, iconSize: 16),
                        SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(n.title,
                                        style: TextStyle(
                                            fontSize: 12.5, fontWeight: FontWeight.w600, color: LinanColors.text)),
                                  ),
                                  Text(formatStamp(n.created),
                                      style: TextStyle(fontSize: 11, color: LinanColors.faint)),
                                ],
                              ),
                              SizedBox(height: 4),
                              Text(n.body, style: TextStyle(fontSize: 11.5, color: LinanColors.muted, height: 1.5)),
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
}

/// 紧凑窗口下的 iOS 底部标签栏；超过四项时以“更多”承载。
class _MobileTabBar extends StatelessWidget {
  final AppState state;
  final ValueChanged<String> onSelect;
  const _MobileTabBar({required this.state, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final navs = state.navs;
    final primary = navs.take(4).toList();
    final rest = navs.skip(4).toList();
    final currentInPrimary = primary.any((n) => n.key == state.page);
    final solid = MediaQuery.maybeOf(context)?.highContrast ?? false;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: solid ? 0 : 24, sigmaY: solid ? 0 : 24),
        child: Container(
          decoration: BoxDecoration(
            color: solid ? LinanColors.surface : LinanColors.surface.withValues(alpha: .88),
            border: Border(top: BorderSide(color: LinanColors.separator, width: .6)),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 58,
              child: Row(
                children: [
                  for (final nav in primary)
                    Expanded(
                      child: _TabItem(
                        icon: navIcon(nav.key),
                        label: nav.label,
                        selected: state.page == nav.key,
                        onTap: () => onSelect(nav.key),
                      ),
                    ),
                  if (rest.isNotEmpty)
                    Expanded(
                      child: _TabItem(
                        icon: Icons.more_horiz_rounded,
                        label: '更多',
                        selected: !currentInPrimary,
                        onTap: () => _showMore(context, rest),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showMore(BuildContext context, List<NavDef> rest) {
    showSideSheet(
      context,
      title: '更多',
      subtitle: '全部功能',
      child: Container(
        decoration: BoxDecoration(color: LinanColors.surface, borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var i = 0; i < rest.length; i++)
              ListRow(
                leading: IconTile(navIcon(rest[i].key), size: 30, iconSize: 16),
                title: rest[i].label,
                showChevron: true,
                showDivider: i != rest.length - 1,
                onTap: () {
                  Navigator.of(context).pop();
                  onSelect(rest[i].key);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabItem({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: selected ? LinanColors.primary : LinanColors.muted),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? LinanColors.primaryText : LinanColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}
