import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// 邻安的双外观色板。浅色为默认，深色对应 iOS/macOS 深色系统语义色。
///
/// 所有颜色都通过 [LinanColors] 的静态 getter 暴露，页面无需感知当前外观；
/// 切换外观时由根组件重建整棵树。
class LinanPalette {
  final Brightness brightness;

  final Color bg;
  final Color bgTop;
  final Color bgBottom;
  final Color surface;
  final Color surfaceAlt;
  final Color fill;
  final Color fillStrong;
  final Color border;
  final Color borderSoft;
  final Color separator;
  final Color text;
  final Color muted;
  final Color faint;

  final Color primary;
  final Color primaryText;
  final Color primaryDeep;
  final Color primarySoft;
  final Color blueSoft;

  final Color green;
  final Color amber;
  final Color warm;
  final Color danger;
  final Color purple;
  final Color teal;
  final Color pink;
  final Color indigo;

  final Color greenText;
  final Color amberText;
  final Color dangerText;
  final Color purpleText;
  final Color tealText;
  final Color indigoText;
  final Color pinkText;
  final Color grayText;

  final Color brandTop;
  final Color brandDeep;
  final Color accent;

  final Color snackBg;
  final Color hover;
  final Color scrollThumb;

  final Color stateNeutralBg;
  final Color stateNeutralFg;
  final Color stateBlueBg;
  final Color stateBlueFg;
  final Color stateGreenBg;
  final Color stateGreenFg;
  final Color stateAmberBg;
  final Color stateAmberFg;
  final Color statePurpleBg;
  final Color statePurpleFg;
  final Color stateRedBg;
  final Color stateRedFg;

  final Color levelCalmBg;
  final Color levelCalmFg;
  final Color levelUnknownBg;
  final Color levelUnknownFg;
  final Color levelWatchBg;
  final Color levelWatchFg;
  final Color levelPriorityBg;
  final Color levelPriorityFg;
  final Color levelUrgentBg;
  final Color levelUrgentFg;

  const LinanPalette({
    required this.brightness,
    required this.bg,
    required this.bgTop,
    required this.bgBottom,
    required this.surface,
    required this.surfaceAlt,
    required this.fill,
    required this.fillStrong,
    required this.border,
    required this.borderSoft,
    required this.separator,
    required this.text,
    required this.muted,
    required this.faint,
    required this.primary,
    required this.primaryText,
    required this.primaryDeep,
    required this.primarySoft,
    required this.blueSoft,
    required this.green,
    required this.amber,
    required this.warm,
    required this.danger,
    required this.purple,
    required this.teal,
    required this.pink,
    required this.indigo,
    required this.greenText,
    required this.amberText,
    required this.dangerText,
    required this.purpleText,
    required this.tealText,
    required this.indigoText,
    required this.pinkText,
    required this.grayText,
    required this.brandTop,
    required this.brandDeep,
    required this.accent,
    required this.snackBg,
    required this.hover,
    required this.scrollThumb,
    required this.stateNeutralBg,
    required this.stateNeutralFg,
    required this.stateBlueBg,
    required this.stateBlueFg,
    required this.stateGreenBg,
    required this.stateGreenFg,
    required this.stateAmberBg,
    required this.stateAmberFg,
    required this.statePurpleBg,
    required this.statePurpleFg,
    required this.stateRedBg,
    required this.stateRedFg,
    required this.levelCalmBg,
    required this.levelCalmFg,
    required this.levelUnknownBg,
    required this.levelUnknownFg,
    required this.levelWatchBg,
    required this.levelWatchFg,
    required this.levelPriorityBg,
    required this.levelPriorityFg,
    required this.levelUrgentBg,
    required this.levelUrgentFg,
  });

  static const light = LinanPalette(
    brightness: Brightness.light,
    bg: Color(0xFFF2F2F7),
    bgTop: Color(0xFFFAFAFC),
    bgBottom: Color(0xFFE9EDF5),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF7F7FA),
    fill: Color(0xFFE9E9EF),
    fillStrong: Color(0xFFDEDEE6),
    border: Color(0xFFD8D8DE),
    borderSoft: Color(0xFFEAEAEF),
    separator: Color(0x2E3C3C43),
    text: Color(0xFF1C1C1E),
    muted: Color(0xFF5C5C63),
    faint: Color(0xFF696970),
    primary: Color(0xFF007AFF),
    primaryText: Color(0xFF0055C8),
    primaryDeep: Color(0xFF0055C8),
    primarySoft: Color(0xFFEAF2FF),
    blueSoft: Color(0xFFEAF2FF),
    green: Color(0xFF34C759),
    amber: Color(0xFFFF9500),
    warm: Color(0xFFFF9F0A),
    danger: Color(0xFFFF3B30),
    purple: Color(0xFFAF52DE),
    teal: Color(0xFF30B0C7),
    pink: Color(0xFFFF2D55),
    indigo: Color(0xFF5856D6),
    greenText: Color(0xFF1B6E30),
    amberText: Color(0xFF8A5600),
    dangerText: Color(0xFFC4001A),
    purpleText: Color(0xFF6B3FA0),
    tealText: Color(0xFF0B6E7D),
    indigoText: Color(0xFF3B3AA8),
    pinkText: Color(0xFFB8003B),
    grayText: Color(0xFF5C5C63),
    brandTop: Color(0xFF2E9BFF),
    brandDeep: Color(0xFF0050C7),
    accent: Color(0xFF64B5FF),
    snackBg: Color(0xF21C1C1E),
    hover: Color(0x09000000),
    scrollThumb: Color(0x33000000),
    stateNeutralBg: Color(0xFFEFEFF4),
    stateNeutralFg: Color(0xFF5C5C63),
    stateBlueBg: Color(0xFFEAF2FF),
    stateBlueFg: Color(0xFF0062C4),
    stateGreenBg: Color(0xFFEBF7F2),
    stateGreenFg: Color(0xFF16714F),
    stateAmberBg: Color(0xFFFFF3E3),
    stateAmberFg: Color(0xFF945000),
    statePurpleBg: Color(0xFFF3EEFB),
    statePurpleFg: Color(0xFF7A4BC2),
    stateRedBg: Color(0xFFFFE9E7),
    stateRedFg: Color(0xFFD70015),
    levelCalmBg: Color(0xFFE8F8EC),
    levelCalmFg: Color(0xFF1B6E30),
    levelUnknownBg: Color(0xFFEFEFF4),
    levelUnknownFg: Color(0xFF5C5C63),
    levelWatchBg: Color(0xFFFFF6DF),
    levelWatchFg: Color(0xFF8A5600),
    levelPriorityBg: Color(0xFFFFEEDD),
    levelPriorityFg: Color(0xFFA64F00),
    levelUrgentBg: Color(0xFFFFE9E7),
    levelUrgentFg: Color(0xFFC4001A),
  );

  static const dark = LinanPalette(
    brightness: Brightness.dark,
    bg: Color(0xFF0F0F11),
    bgTop: Color(0xFF17171A),
    bgBottom: Color(0xFF0A0A0C),
    surface: Color(0xFF1C1C1E),
    surfaceAlt: Color(0xFF242427),
    fill: Color(0xFF2C2C2E),
    fillStrong: Color(0xFF3A3A3C),
    border: Color(0xFF3A3A3C),
    borderSoft: Color(0xFF2C2C2E),
    separator: Color(0x2EFFFFFF),
    text: Color(0xFFF5F5F7),
    muted: Color(0xFFA1A1A6),
    faint: Color(0xFF8E8E93),
    primary: Color(0xFF0A84FF),
    primaryText: Color(0xFF6CB4FF),
    primaryDeep: Color(0xFF0A5BD6),
    primarySoft: Color(0xFF10263D),
    blueSoft: Color(0xFF10263D),
    green: Color(0xFF30D158),
    amber: Color(0xFFFF9F0A),
    warm: Color(0xFFFFB340),
    danger: Color(0xFFFF453A),
    purple: Color(0xFFBF5AF2),
    teal: Color(0xFF40C8E0),
    pink: Color(0xFFFF375F),
    indigo: Color(0xFF5E5CE6),
    greenText: Color(0xFF6FD68A),
    amberText: Color(0xFFFFC46B),
    dangerText: Color(0xFFFF8A80),
    purpleText: Color(0xFFD0A9FF),
    tealText: Color(0xFF7ADCEA),
    indigoText: Color(0xFFA5A3FF),
    pinkText: Color(0xFFFF8FA8),
    grayText: Color(0xFFA1A1A6),
    brandTop: Color(0xFF1F6FEB),
    brandDeep: Color(0xFF0A3D91),
    accent: Color(0xFF8FC7FF),
    snackBg: Color(0xF23A3A3C),
    hover: Color(0x14FFFFFF),
    scrollThumb: Color(0x40FFFFFF),
    stateNeutralBg: Color(0xFF2C2C2E),
    stateNeutralFg: Color(0xFFD1D1D6),
    stateBlueBg: Color(0xFF10263D),
    stateBlueFg: Color(0xFF6CB4FF),
    stateGreenBg: Color(0xFF14301F),
    stateGreenFg: Color(0xFF6FD68A),
    stateAmberBg: Color(0xFF33260F),
    stateAmberFg: Color(0xFFFFC46B),
    statePurpleBg: Color(0xFF2A1F3D),
    statePurpleFg: Color(0xFFD0A9FF),
    stateRedBg: Color(0xFF3A1715),
    stateRedFg: Color(0xFFFF8A80),
    levelCalmBg: Color(0xFF14301F),
    levelCalmFg: Color(0xFF6FD68A),
    levelUnknownBg: Color(0xFF2C2C2E),
    levelUnknownFg: Color(0xFFD1D1D6),
    levelWatchBg: Color(0xFF33260F),
    levelWatchFg: Color(0xFFFFC46B),
    levelPriorityBg: Color(0xFF3A2410),
    levelPriorityFg: Color(0xFFFFB066),
    levelUrgentBg: Color(0xFF3A1715),
    levelUrgentFg: Color(0xFFFF8A80),
  );
}

/// 邻安视觉基线：遵循 Apple Human Interface Guidelines 的系统色板。
///
/// 浅色分组背景 + 纯白卡片、系统蓝作为交互强调色、系统绿/橙/红表达状态；
/// 深色跟随系统外观，由 [apply] 在根组件重建前切换。
class LinanColors {
  static LinanPalette _palette = LinanPalette.light;

  static LinanPalette get palette => _palette;
  static Brightness get brightness => _palette.brightness;

  static void apply(Brightness brightness) {
    _palette = brightness == Brightness.dark ? LinanPalette.dark : LinanPalette.light;
  }

  // 背景与表面
  static Color get bg => _palette.bg;
  static Color get bgTop => _palette.bgTop;
  static Color get bgBottom => _palette.bgBottom;
  static Color get surface => _palette.surface;
  static Color get surfaceAlt => _palette.surfaceAlt;
  static Color get fill => _palette.fill;
  static Color get fillStrong => _palette.fillStrong;

  // 分隔线
  static Color get border => _palette.border;
  static Color get borderSoft => _palette.borderSoft;
  static Color get separator => _palette.separator;

  // 文本标签
  static Color get text => _palette.text;
  static Color get muted => _palette.muted;
  static Color get faint => _palette.faint;

  // 强调色
  static Color get primary => _palette.primary;
  static Color get primaryText => _palette.primaryText;
  static Color get primaryDeep => _palette.primaryDeep;
  static Color get primarySoft => _palette.primarySoft;
  static Color get blueSoft => _palette.blueSoft;
  static Color get green => _palette.green;
  static Color get amber => _palette.amber;
  static Color get warm => _palette.warm;
  static Color get danger => _palette.danger;
  static Color get purple => _palette.purple;
  static Color get teal => _palette.teal;
  static Color get pink => _palette.pink;
  static Color get indigo => _palette.indigo;

  // 语义文本色
  static Color get greenText => _palette.greenText;
  static Color get amberText => _palette.amberText;
  static Color get dangerText => _palette.dangerText;
  static Color get purpleText => _palette.purpleText;
  static Color get tealText => _palette.tealText;
  static Color get indigoText => _palette.indigoText;
  static Color get pinkText => _palette.pinkText;
  static Color get grayText => _palette.grayText;

  // 品牌与浮层
  static Color get brandTop => _palette.brandTop;
  static Color get brandDeep => _palette.brandDeep;
  static Color get accent => _palette.accent;
  static Color get snackBg => _palette.snackBg;
  static Color get hover => _palette.hover;
  static Color get scrollThumb => _palette.scrollThumb;

  // 状态胶囊
  static Color get stateNeutralBg => _palette.stateNeutralBg;
  static Color get stateNeutralFg => _palette.stateNeutralFg;
  static Color get stateBlueBg => _palette.stateBlueBg;
  static Color get stateBlueFg => _palette.stateBlueFg;
  static Color get stateGreenBg => _palette.stateGreenBg;
  static Color get stateGreenFg => _palette.stateGreenFg;
  static Color get stateAmberBg => _palette.stateAmberBg;
  static Color get stateAmberFg => _palette.stateAmberFg;
  static Color get statePurpleBg => _palette.statePurpleBg;
  static Color get statePurpleFg => _palette.statePurpleFg;
  static Color get stateRedBg => _palette.stateRedBg;
  static Color get stateRedFg => _palette.stateRedFg;

  // 圆角
  static const double rCard = 18;
  static const double rControl = 12;
  static const double rPill = 999;

  static Color tint(Color color, [double alpha = .12]) => color.withValues(alpha: alpha);
}

/// SF 风格字体栈：优先系统 SF，其次 Windows 上最接近的 Segoe UI Variable。
const List<String> _cjkFallback = [
  'PingFang SC',
  'Microsoft YaHei UI',
  'Microsoft YaHei',
  'Noto Sans SC',
  'Noto Sans CJK SC',
  'WenQuanYi Micro Hei',
];

class LinanTheme {
  static ThemeData build({Brightness brightness = Brightness.light}) {
    final p = brightness == Brightness.dark ? LinanPalette.dark : LinanPalette.light;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: p.primary,
      onPrimary: Colors.white,
      secondary: p.green,
      onSecondary: Colors.white,
      error: p.danger,
      onError: Colors.white,
      surface: p.surface,
      onSurface: p.text,
      surfaceContainerHighest: p.surfaceAlt,
      outline: p.border,
      outlineVariant: p.borderSoft,
      shadow: const Color(0x1A000000),
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.bg,
      canvasColor: p.bg,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: p.hover,
      focusColor: p.primary.withValues(alpha: .10),
      fontFamilyFallback: const ['SF Pro Text', 'SF Pro Display', 'Segoe UI Variable Text', ..._cjkFallback],
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
      }),
      visualDensity: VisualDensity.standard,
    );

    final text = base.textTheme.copyWith(
      displayLarge: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: p.text, height: 1.16, letterSpacing: -.8),
      displayMedium: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: p.text, height: 1.2, letterSpacing: -.6),
      displaySmall: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: p.text, height: 1.22, letterSpacing: -.4),
      headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: p.text, height: 1.26, letterSpacing: -.3),
      headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: p.text, height: 1.3),
      titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: p.text, height: 1.3),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: p.text, height: 1.35),
      titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.text, height: 1.35),
      bodyLarge: TextStyle(fontSize: 15, color: p.text, height: 1.55),
      bodyMedium: TextStyle(fontSize: 13.5, color: p.text, height: 1.55),
      bodySmall: TextStyle(fontSize: 12.5, color: p.muted, height: 1.5),
      labelLarge: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: -.1),
      labelMedium: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      labelSmall: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: .1),
    );

    return base.copyWith(
      textTheme: text,
      dividerTheme: DividerThemeData(color: p.separator, thickness: .6, space: .6),
      cardTheme: CardThemeData(
        elevation: 0,
        color: p.surface,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(LinanColors.rCard)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: p.surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(LinanColors.rControl), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(LinanColors.rControl), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LinanColors.rControl),
          borderSide: BorderSide(color: p.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LinanColors.rControl),
          borderSide: BorderSide(color: p.danger, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LinanColors.rControl),
          borderSide: BorderSide(color: p.danger, width: 1.6),
        ),
        hintStyle: TextStyle(color: p.faint, fontSize: 13),
        labelStyle: TextStyle(color: p.muted, fontSize: 13),
        prefixIconColor: p.muted,
        suffixIconColor: p.muted,
        floatingLabelStyle: TextStyle(color: p.primaryText, fontSize: 12, fontWeight: FontWeight.w500),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.primaryDeep,
          foregroundColor: Colors.white,
          disabledBackgroundColor: p.fillStrong,
          disabledForegroundColor: p.faint,
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: -.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.primaryText,
          backgroundColor: p.primarySoft,
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          side: BorderSide.none,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: -.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.primaryText,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: -.1),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          minimumSize: const Size(0, 36),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: p.primaryText,
          highlightColor: p.hover,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.primaryDeep,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.snackBg,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        actionTextColor: p.accent,
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 24,
        shadowColor: Colors.black.withValues(alpha: .18),
        titleTextStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: p.text),
        contentTextStyle: TextStyle(fontSize: 13, color: p.text, height: 1.55),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.bg,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: p.bg,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
        showDragHandle: true,
        dragHandleColor: p.fillStrong,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 18,
        shadowColor: Colors.black.withValues(alpha: .16),
        textStyle: TextStyle(fontSize: 13, color: p.text),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.muted,
        textColor: p.text,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        minLeadingWidth: 24,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surface,
        selectedColor: p.primarySoft,
        disabledColor: p.fill,
        labelStyle: TextStyle(fontSize: 12, color: p.text),
        secondaryLabelStyle: TextStyle(fontSize: 12, color: p.primaryText, fontWeight: FontWeight.w600),
        side: BorderSide.none,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) => Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? p.green : p.fill),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
        trackOutlineWidth: WidgetStateProperty.all(0),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: p.fill,
          foregroundColor: p.text,
          selectedBackgroundColor: p.surface,
          selectedForegroundColor: p.text,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.primary,
        linearTrackColor: p.fill,
        circularTrackColor: p.fill,
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 350),
        decoration: BoxDecoration(
          color: p.snackBg,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 11.5),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(p.scrollThumb),
        radius: const Radius.circular(8),
        thickness: const WidgetStatePropertyAll(5),
        crossAxisMargin: 2,
      ),
      dividerColor: p.separator,
      badgeTheme: BadgeThemeData(backgroundColor: p.danger, textColor: Colors.white),
      datePickerTheme: DatePickerThemeData(backgroundColor: p.surface),
      timePickerTheme: TimePickerThemeData(backgroundColor: p.surface),
    );
  }
}

/// 风险等级配色（-1 平稳、0 未知、1 关注、2 优先、3 紧急）。
class LevelStyle {
  final Color bg;
  final Color fg;
  const LevelStyle(this.bg, this.fg);

  static LevelStyle of(int level) {
    final p = LinanColors.palette;
    return switch (level) {
      -1 => LevelStyle(p.levelCalmBg, p.levelCalmFg),
      1 => LevelStyle(p.levelWatchBg, p.levelWatchFg),
      2 => LevelStyle(p.levelPriorityBg, p.levelPriorityFg),
      3 => LevelStyle(p.levelUrgentBg, p.levelUrgentFg),
      _ => LevelStyle(p.levelUnknownBg, p.levelUnknownFg),
    };
  }
}
