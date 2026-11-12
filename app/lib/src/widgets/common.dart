import 'package:flutter/material.dart';

import '../labels.dart';
import '../theme.dart';

class LevelPill extends StatelessWidget {
  final int level;
  final bool compact;
  const LevelPill(this.level, {super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final style = LevelStyle.of(level);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 9, vertical: compact ? 2 : 3),
      decoration: BoxDecoration(color: style.bg, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (level >= 2 && !compact)
            Container(
              width: 5,
              height: 5,
              margin: const EdgeInsets.only(right: 5),
              decoration: BoxDecoration(color: style.fg, shape: BoxShape.circle),
            ),
          Text(
            levelName(level),
            style: TextStyle(color: style.fg, fontSize: compact ? 10 : 11, fontWeight: FontWeight.w600, height: 1.2),
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

  static const Map<String, (Color, Color)> _colors = {
    'pending': (Color(0xFFF0EFE8), Color(0xFF8A8776)),
    'dispatched': (Color(0xFFE8EFF2), Color(0xFF5F7F8C)),
    'accepted': (Color(0xFFEDF0DE), Color(0xFF8B8F4F)),
    'processing': (Color(0xFFF4EEDD), Color(0xFFA8873F)),
    'review': (Color(0xFFF1EBE3), Color(0xFF9B7853)),
    'closed': (Color(0xFFE8F0E8), Color(0xFF5F8768)),
  };

  @override
  Widget build(BuildContext context) {
    final colors = _colors[state] ?? (LinanColors.surfaceAlt, LinanColors.muted);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: compact ? 2 : 3),
      decoration: BoxDecoration(color: colors.$1, borderRadius: BorderRadius.circular(6)),
      child: Text(
        stateName(state),
        style: TextStyle(color: colors.$2, fontSize: compact ? 10 : 11, fontWeight: FontWeight.w600, height: 1.2),
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
    final c = color ?? LinanColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        border: Border.all(color: c.withValues(alpha: .25)),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: c),
            const SizedBox(width: 4),
          ],
          Text(text, style: TextStyle(fontSize: 10, color: c, height: 1.3)),
        ],
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  final String? title;
  final String? subtitle;
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
    this.trailing,
    required this.child,
    this.padding = const EdgeInsets.all(18),
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
        borderRadius: BorderRadius.circular(12),
        border: gradient == null ? (border ?? Border.all(color: LinanColors.border)) : null,
      ),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title!, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 13.5)),
                        if (subtitle != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(subtitle!, style: const TextStyle(fontSize: 10.5, color: LinanColors.muted, height: 1.5)),
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

class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final String? note;
  final Color accent;
  final VoidCallback? onTap;

  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.unit = '',
    this.note,
    this.accent = LinanColors.primary,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 13),
        decoration: BoxDecoration(
          color: LinanColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: LinanColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 5, height: 5, decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: LinanColors.muted)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: LinanColors.text, height: 1.1)),
                if (unit.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 3),
                    child: Text(unit, style: const TextStyle(fontSize: 10.5, color: LinanColors.muted)),
                  ),
              ],
            ),
            if (note != null) ...[
              const SizedBox(height: 4),
              Text(note!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: LinanColors.faint)),
            ],
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
      padding: const EdgeInsets.symmetric(vertical: 26),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 26, color: LinanColors.border),
            const SizedBox(height: 8),
            Text(text, style: const TextStyle(fontSize: 11.5, color: LinanColors.faint)),
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
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 92, child: Text(label, style: const TextStyle(fontSize: 11, color: LinanColors.muted))),
          Expanded(
            child: Text(value.isEmpty ? '—' : value, style: const TextStyle(fontSize: 12, color: LinanColors.text, height: 1.6)),
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
  final Color color;
  const BtnLabel(this.text, {super.key, this.icon, this.color = LinanColors.primary});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: color), const SizedBox(width: 5)],
          Text(text, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ],
      );
}

Future<void> showSideSheet(
  BuildContext context, {
  required String title,
  String? subtitle,
  required Widget child,
  List<Widget> actions = const [],
}) {
  final wide = MediaQuery.sizeOf(context).width >= 720;
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: title,
    barrierColor: Colors.black.withValues(alpha: .28),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (ctx, animation, secondary) {
      return Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: LinanColors.surface,
          child: SizedBox(
            width: wide ? 640 : MediaQuery.sizeOf(ctx).width,
            height: MediaQuery.sizeOf(ctx).height,
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 18, 14, 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(fontSize: 17)),
                              if (subtitle != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(subtitle, style: const TextStyle(fontSize: 11, color: LinanColors.muted)),
                                ),
                            ],
                          ),
                        ),
                        ...actions,
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close, size: 18),
                          color: LinanColors.muted,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
                      child: child,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (ctx, animation, secondary, child) {
      final tween = Tween(begin: const Offset(1, 0), end: Offset.zero)
          .chain(CurveTween(curve: Curves.easeOutCubic));
      return SlideTransition(position: animation.drive(tween), child: child);
    },
  );
}

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
      title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      content: Text(body, style: const TextStyle(fontSize: 12.5, height: 1.7)),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(cancelText)),
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
