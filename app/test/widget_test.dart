import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:linan_app/src/app_state.dart';
import 'package:linan_app/src/screens/login.dart';
import 'package:linan_app/src/theme.dart';

void main() {
  testWidgets('登录页渲染演示身份与服务器设置', (WidgetTester tester) async {
    final state = AppState();
    await tester.pumpWidget(
      MaterialApp(
        theme: LinanTheme.build(),
        home: LoginScreen(state: state),
      ),
    );
    await tester.pump();

    expect(find.text('登录邻安'), findsOneWidget);
    expect(find.text('进入守护台'), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);
    expect(find.text('admin'), findsWidgets);
  });
}
