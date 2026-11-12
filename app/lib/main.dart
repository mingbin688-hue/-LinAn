import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'src/app_state.dart';
import 'src/screens/login.dart';
import 'src/screens/shell.dart';
import 'src/theme.dart';

void main() {
  runApp(const LinanApp());
}

class LinanApp extends StatefulWidget {
  const LinanApp({super.key});

  @override
  State<LinanApp> createState() => _LinanAppState();
}

class _LinanAppState extends State<LinanApp> with WidgetsBindingObserver {
  final AppState _state = AppState();
  late Brightness _brightness = _initialBrightness();

  /// 跟随系统外观；`LINAN_APPEARANCE=dark|light` 仅用于验收截图，不在界面暴露开关。
  static Brightness _initialBrightness() {
    final override = Platform.environment['LINAN_APPEARANCE'];
    if (override == 'dark') return Brightness.dark;
    if (override == 'light') return Brightness.light;
    return WidgetsBinding.instance.platformDispatcher.platformBrightness;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _state.boot();
  }

  @override
  void didChangePlatformBrightness() {
    setState(() => _brightness = _initialBrightness());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    LinanColors.apply(_brightness);
    return MaterialApp(
      title: '邻安 · 社区守护',
      debugShowCheckedModeBanner: false,
      theme: LinanTheme.build(brightness: _brightness),
      scaffoldMessengerKey: messengerKey,
      home: ListenableBuilder(
        listenable: _state,
        builder: (context, _) {
          if (_state.booting) return _Splash();
          if (_state.user == null) return LoginScreen(state: _state);
          return ShellScreen(state: _state);
        },
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: LinanColors.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: const Text('安', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w600)),
            ),
            SizedBox(height: 18),
            Text('邻安', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: LinanColors.text)),
            SizedBox(height: 6),
            Text('正在连接社区守护服务…', style: TextStyle(fontSize: 11.5, color: LinanColors.muted)),
            const SizedBox(height: 20),
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: LinanColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
