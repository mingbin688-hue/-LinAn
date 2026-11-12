import 'package:flutter/material.dart';

import '../labels.dart';
import '../theme.dart';

/// 圆角图标底板，用于列表行、卡片标题与统计块。
class IconTile extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final double size;
  final double iconSize;

  const IconTile(this.icon, {super.key, this.color, this.size = 32, this.iconSize = 17});

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? LinanColors.primary;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: LinanColors.tint(color, .13),
        borderRadius: BorderRadius.circular(size * .3),
      ),
      child: Icon(icon, size: iconSize, color: color),
    );
  }
}

/// iOS 大标题页头：图标、标题、说明与右侧操作。
class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? accent;
  final List<Widget> actions;
  final EdgeInsetsGeometry padding;

  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.accent,
    this.actions = const [],
    this.padding = const EdgeInsets.fromLTRB(24, 26, 24, 16),
  });

  @override
  Widget build(BuildContext context) {
    final accent = this.accent ?? LinanColors.primary;
    final heading = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: LinanColors.tint(accent, .13),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, size: 23, color: accent),
          ),
          SizedBox(width: 13),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 27, fontWeight: FontWeight.w700, color: LinanColors.text, height: 1.2, letterSpacing: -.6)),
              if (subtitle != null) ...[
                SizedBox(height: 3),
                Text(subtitle!,
                    style: TextStyle(fontSize: 12.5, color: LinanColors.muted, height: 1.45)),
              ],
            ],
          ),
        ),
      ],
    );

    if (actions.isEmpty) {
      return Padding(padding: padding, child: heading);
    }
    return Padding(
      padding: padding,
      child: LayoutBuilder(builder: (context, c) {
        if (c.maxWidth >= 760) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: heading),
              const SizedBox(width: 14),
              Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: actions),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            heading,
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: actions),
          ],
        );
      }),
    );
  }
}

class LevelPill extends StatelessWidget {
  final int level;
  final bool compact;
  const LevelPill(this.level, {super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final style = LevelStyle.of(level);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 2.5 : 3.5),
      decoration: BoxDecoration(color: style.bg, borderRadius: BorderRadius.circular(LinanColors.rPill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (level >= 2 && !compact) ...[
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 5),
              decoration: BoxDecoration(color: style.fg, shape: BoxShape.circle),
            ),
          ],
          Text(
            levelName(level),
            style: TextStyle(color: style.fg, fontSize: compact ? 11 : 11.5, fontWeight: FontWeight.w600, height: 1.2),
          ),
        ],
      ),
    );
  }
}

class StatePill extends StatelessWidget {
  final String state;
  final bool compact;
  const StatePill(this.state, {super.key, this.compact = false});

  static (Color, Color) _colorsFor(String state) {
    switch (state) {
      case 'pending':
        return (LinanColors.stateNeutralBg, LinanColors.stateNeutralFg);
      case 'dispatched':
        return (LinanColors.stateBlueBg, LinanColors.stateBlueFg);
      case 'accepted':
        return (LinanColors.stateGreenBg, LinanColors.stateGreenFg);
      case 'processing':
        return (LinanColors.stateAmberBg, LinanColors.stateAmberFg);
      case 'review':
        return (LinanColors.statePurpleBg, LinanColors.statePurpleFg);
      case 'closed':
        return (LinanColors.stateGreenBg, LinanColors.stateGreenFg);
      default:
        return (LinanColors.surfaceAlt, LinanColors.muted);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _colorsFor(state);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 9, vertical: compact ? 2.5 : 3.5),
      decoration: BoxDecoration(color: colors.$1, borderRadius: BorderRadius.circular(LinanColors.rPill)),
      child: Text(
        stateName(state),
        style: TextStyle(color: colors.$2, fontSize: compact ? 11 : 11.5, fontWeight: FontWeight.w600, height: 1.2),
      ),
    );
  }
}

class Tag extends StatelessWidget {
  final String text;
  final Color? color;
  final IconData? icon;
  const Tag(this.text, {super.key, this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    final base = color ?? LinanColors.muted;
    // 胶囊底色是强调色的 10% 浅染；文字必须换成同色系的深色前景，
    // 否则系统绿/橙在浅底上只有 2–3:1，11pt 文本不可读。
    final c = _tagForeground(base);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: LinanColors.tint(base, .1),
        borderRadius: BorderRadius.circular(LinanColors.rPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: c),
            const SizedBox(width: 4),
          ],
          Text(text, style: TextStyle(fontSize: 11, color: c, height: 1.25, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  static Color _tagForeground(Color c) {
    if (c == LinanColors.green) return LinanColors.greenText;
    if (c == LinanColors.amber || c == LinanColors.warm) return LinanColors.amberText;
    if (c == LinanColors.danger) return LinanColors.dangerText;
    if (c == LinanColors.primary) return LinanColors.primaryText;
    if (c == LinanColors.teal) return LinanColors.tealText;
    if (c == LinanColors.purple) return LinanColors.purpleText;
    if (c == LinanColors.indigo) return LinanColors.indigoText;
    if (c == LinanColors.pink) return LinanColors.pinkText;
    if (c == LinanColors.faint || c == LinanColors.muted) return LinanColors.grayText;
    return c;
  }
}

/// iOS 分组卡片：可选图标标题、副标题、右侧操作与纯白圆角容器。
class SectionCard extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final BoxBorder? border;
  final Gradient? gradient;

  const SectionCard({
    super.key,
    this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(18, 17, 18, 18),
    this.color,
    this.border,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? LinanColors.surface) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(LinanColors.rCard),
        border: gradient == null ? border : null,
      ),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: EdgeInsets.only(bottom: 13),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    IconTile(icon!, size: 30, iconSize: 16),
                    SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title!,
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600, color: LinanColors.text, height: 1.3, letterSpacing: -.2)),
                        if (subtitle != null)
                          Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Text(subtitle!,
                                style: TextStyle(fontSize: 11.5, color: LinanColors.muted, height: 1.45)),
                          ),
                      ],
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
          child,
        ],
      ),
    );
  }
}

/// iOS 设置式列表行：左侧图标底板、标题与说明、右侧值与箭头。
class ListRow extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;
  final bool showDivider;
  final EdgeInsetsGeometry padding;

  const ListRow({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.showChevron = false,
    this.showDivider = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
  });

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: padding,
      child: Row(
        children: [
          if (leading != null) ...[leading!, SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: LinanColors.text, height: 1.35)),
                if (subtitle != null) ...[
                  SizedBox(height: 2),
                  Text(subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: LinanColors.muted, height: 1.45)),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[SizedBox(width: 10), trailing!],
          if (showChevron) ...[
            SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 19, color: LinanColors.faint),
          ],
        ],
      ),
    );
    final content = onTap == null
        ? row
        : InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12), child: row);
    if (!showDivider) return content;
    return Column(
      children: [
        content,
        const Divider(height: .6, indent: 56, endIndent: 14),
      ],
    );
  }
}

class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final String? note;
  final Color? accent;
  final IconData? icon;
  final VoidCallback? onTap;

  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.unit = '',
    this.note,
    this.accent,
    this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = this.accent ?? LinanColors.primary;
    return Material(
      color: LinanColors.surface,
      borderRadius: BorderRadius.circular(LinanColors.rCard),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(17, 15, 17, 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: LinanColors.muted, fontWeight: FontWeight.w500)),
                  ),
                  if (icon != null) IconTile(icon!, size: 26, iconSize: 15, color: accent),
                ],
              ),
              SizedBox(height: 9),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(value,
                      style: TextStyle(
                          fontSize: 29, fontWeight: FontWeight.w700, color: LinanColors.text, height: 1.08, letterSpacing: -.7)),
                  if (unit.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(left: 3),
                      child: Text(unit, style: TextStyle(fontSize: 11.5, color: LinanColors.muted, fontWeight: FontWeight.w500)),
                    ),
                ],
              ),
              if (note != null) ...[
                SizedBox(height: 6),
                Text(note!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.8, color: LinanColors.faint, height: 1.45)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 横向分段控件，接近 iOS UISegmentedControl。
class SegmentedControl extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;
  final bool enabled;

  const SegmentedControl({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(color: LinanColors.fill, borderRadius: BorderRadius.circular(10)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++)
              GestureDetector(
                onTap: enabled ? () => onChanged(i) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: i == selected
                        ? (LinanColors.brightness == Brightness.dark
                            ? LinanColors.fillStrong
                            : LinanColors.surface)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(7.5),
                    boxShadow: i == selected && LinanColors.brightness == Brightness.light
                        ? [BoxShadow(color: Colors.black.withValues(alpha: .09), blurRadius: 5, offset: const Offset(0, 1))]
                        : null,
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: i == selected ? FontWeight.w600 : FontWeight.w500,
                      color: i == selected ? LinanColors.text : LinanColors.muted,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class EmptyHint extends StatelessWidget {
  final String text;
  final IconData icon;
  const EmptyHint(this.text, {super.key, this.icon = Icons.inbox_outlined});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: LinanColors.surfaceAlt, shape: BoxShape.circle),
              child: Icon(icon, size: 21, color: LinanColors.faint),
            ),
            SizedBox(height: 9),
            Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: LinanColors.faint)),
          ],
        ),
      ),
    );
  }
}

class KeyValue extends StatelessWidget {
  final String label;
  final String value;
  final Widget? trailing;
  const KeyValue(this.label, this.value, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 7.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 98,
              child: Text(label, style: TextStyle(fontSize: 12, color: LinanColors.muted, height: 1.5))),
          Expanded(
            child: Text(value.isEmpty ? '—' : value,
                style: TextStyle(fontSize: 12.5, color: LinanColors.text, height: 1.55)),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class Dot extends StatelessWidget {
  final Color color;
  final double size;
  const Dot(this.color, {super.key, this.size = 6});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

class BtnLabel extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color? color;
  const BtnLabel(this.text, {super.key, this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? LinanColors.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 15, color: color), const SizedBox(width: 5)],
        Text(text, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600, letterSpacing: -.1)),
      ],
    );
  }
}

/// iOS 表单页（form sheet）：宽屏居中圆角卡片，窄屏底部上滑。
Future<void> showSideSheet(
  BuildContext context, {
  required String title,
  String? subtitle,
  required Widget child,
  List<Widget> actions = const [],
}) {
  final size = MediaQuery.sizeOf(context);
  final wide = size.width >= 720;
  final height = wide ? size.height * .82 : size.height * .93;
  final width = wide ? 640.0 : size.width;

  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: title,
    barrierColor: Colors.black.withValues(alpha: .3),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (ctx, animation, secondary) {
      final sheet = ClipRRect(
        borderRadius: BorderRadius.vertical(top: Radius.circular(wide ? 22 : 22), bottom: Radius.circular(wide ? 22 : 0)),
        child: Material(
          color: LinanColors.bg,
          child: SizedBox(
            width: width,
            height: height,
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 8),
                  Center(
                    child: Container(
                      width: 36,
                      height: 5,
                      decoration: BoxDecoration(
                        color: LinanColors.fillStrong,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(22, 14, 14, 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 19, fontWeight: FontWeight.w700, color: LinanColors.text, letterSpacing: -.3)),
                              if (subtitle != null)
                                Padding(
                                  padding: EdgeInsets.only(top: 3),
                                  child: Text(subtitle,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 12, color: LinanColors.muted, height: 1.45)),
                                ),
                            ],
                          ),
                        ),
                        ...actions,
                        Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: LinanColors.fill, shape: BoxShape.circle),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            tooltip: '关闭',
                            onPressed: () => Navigator.of(ctx).pop(),
                            icon: Icon(Icons.close_rounded, size: 17, color: LinanColors.muted),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: .6),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                      child: child,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      if (wide) return Center(child: sheet);
      return Align(alignment: Alignment.bottomCenter, child: sheet);
    },
    transitionBuilder: (ctx, animation, secondary, dialog) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
      if (wide) {
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(scale: Tween(begin: .96, end: 1.0).animate(curved), child: dialog),
        );
      }
      return SlideTransition(position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(curved), child: dialog);
    },
  );
}

/// iOS 警告框：圆角、语义色按钮。
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  String confirmText = '确认',
  String cancelText = '取消',
  bool danger = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      title: Text(title),
      content: Text(body),
      actionsPadding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          style: TextButton.styleFrom(foregroundColor: LinanColors.primary),
          child: Text(cancelText),
        ),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: LinanColors.danger) : null,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmText),
        ),
      ],
    ),
  );
  return result == true;
}
