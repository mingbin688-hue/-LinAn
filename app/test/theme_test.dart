import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linan_app/src/theme.dart';

void main() {
  test('浅色/深色外观切换调色板与主题亮度', () {
    LinanColors.apply(Brightness.dark);
    expect(LinanColors.brightness, Brightness.dark);
    expect(LinanColors.bg, const Color(0xFF0F0F11));
    expect(LinanColors.surface, const Color(0xFF1C1C1E));
    expect(LinanColors.text, const Color(0xFFF5F5F7));
    expect(LinanTheme.build(brightness: Brightness.dark).brightness, Brightness.dark);

    LinanColors.apply(Brightness.light);
    expect(LinanColors.brightness, Brightness.light);
    expect(LinanColors.bg, const Color(0xFFF2F2F7));
    expect(LinanColors.surface, const Color(0xFFFFFFFF));
    expect(LinanColors.text, const Color(0xFF1C1C1E));
    expect(LinanTheme.build().brightness, Brightness.light);
  });
}
