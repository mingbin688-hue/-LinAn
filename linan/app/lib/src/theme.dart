import 'package:flutter/material.dart';

/// 邻安视觉基调：暖白纸面、鼠尾草绿、低饱和风险色。
class LinanColors {
  static const bg = Color(0xFFF4F6F2);
  static const surface = Color(0xFFFDFEFB);
  static const surfaceAlt = Color(0xFFF8FAF4);
  static const border = Color(0xFFE1E7DC);
  static const borderSoft = Color(0xFFEDF0E7);
  static const primary = Color(0xFF206B58);
  static const primaryDeep = Color(0xFF15523F);
  static const primarySoft = Color(0xFFE9F0E8);
  static const text = Color(0xFF273D35);
  static const muted = Color(0xFF7E8D83);
  static const faint = Color(0xFF9BA78F);
  static const green = Color(0xFF559C7C);
  static const amber = Color(0xFFC99D52);
  static const warm = Color(0xFFAC7550);
  static const danger = Color(0xFFBA5E4C);
  static const blueSoft = Color(0xFFE7EEF2);
}

class LinanTheme {
  static ThemeData build() {
    final scheme = ColorScheme.fromSeed(
      seedColor: LinanColors.primary,
      primary: LinanColors.primary,
      surface: LinanColors.surface,
      error: LinanColors.danger,
      brightness: Brightness.light,
    ).copyWith(
      onSurface: LinanColors.text,
      outline: LinanColors.border,
      secondary: LinanColors.green,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: LinanColors.bg,
      splashFactory: InkSparkle.splashFactory,
      fontFamilyFallback: const [
        'Microsoft YaHei',
        'PingFang SC',
        'Noto Sans SC',
        'Noto Sans CJK SC',
        'WenQuanYi Micro Hei',
      ],
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        displaySmall: const TextStyle(fontSize: 30, fontWeight: FontWeight.w600, color: LinanColors.text, height: 1.35),
        headlineMedium: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: LinanColors.text, height: 1.4),
        headlineSmall: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: LinanColors.text, height: 1.45),
        titleLarge: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: LinanColors.text),
        titleMedium: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: LinanColors.text),
        titleSmall: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: LinanColors.text),
        bodyLarge: const TextStyle(fontSize: 14, color: LinanColors.text, height: 1.7),
        bodyMedium: const TextStyle(fontSize: 12.5, color: LinanColors.text, height: 1.7),
        bodySmall: const TextStyle(fontSize: 11, color: LinanColors.muted, height: 1.65),
        labelLarge: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
        labelSmall: const TextStyle(fontSize: 9.5, letterSpacing: .6),
      ),
      dividerTheme: const DividerThemeData(color: LinanColors.borderSoft, thickness: 1, space: 1),
      cardTheme: CardThemeData(
        elevation: 0,
        color: LinanColors.surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: LinanColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: LinanColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: LinanColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: LinanColors.primary, width: 1.4),
        ),
        hintStyle: const TextStyle(color: LinanColors.faint, fontSize: 12),
        labelStyle: const TextStyle(color: LinanColors.muted, fontSize: 12),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: LinanColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 38),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: LinanColors.primary,
          minimumSize: const Size(0, 38),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          side: const BorderSide(color: LinanColors.border),
          textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: LinanColors.primary,
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          minimumSize: const Size(0, 32),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: LinanColors.primaryDeep,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 12.5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: LinanColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerColor: LinanColors.borderSoft,
      tooltipTheme: const TooltipThemeData(waitDuration: Duration(milliseconds: 400)),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(LinanColors.border),
        radius: const Radius.circular(8),
      ),
    );
  }
}

/// 风险等级配色（-1 平稳、0 未知、1 关注、2 优先、3 紧急）。
class LevelStyle {
  final Color bg;
  final Color fg;
  const LevelStyle(this.bg, this.fg);

  static const Map<int, LevelStyle> _styles = {
    -1: LevelStyle(Color(0xFFE9F0E4), Color(0xFF638165)),
    0: LevelStyle(Color(0xFFEAF0EF), Color(0xFF798E86)),
    1: LevelStyle(Color(0xFFEDF0DC), Color(0xFF939455)),
    2: LevelStyle(Color(0xFFF4F0DD), Color(0xFFAA9148)),
    3: LevelStyle(Color(0xFFF8ECE5), Color(0xFFB16B4C)),
  };

  static LevelStyle of(int level) => _styles[level] ?? _styles[0]!;
}
