import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'src/app_state.dart';
import 'src/screens/login.dart';
import 'src/screens/shell.dart';
import 'src/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // 浏览器验收可在地址后加 ?semantics=1 打开语义树，便于自动化读取控件。
  if (Uri.base.queryParameters['semantics'] == '1') {
    SemanticsBinding.instance.ensureSemantics();
  }
  runApp(const LinanApp());
}

class LinanApp extends StatefulWidget {
  const LinanApp({super.key});

  @override
  State<LinanApp> createState() => _LinanAppState();
}

class _LinanAppState extends State<LinanApp> {
  final AppState _state = AppState();

  @override
  void initState() {
    super.initState();
    _state.boot();
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '邻安 · 社区守护',
      debugShowCheckedModeBanner: false,
      theme: LinanTheme.build(),
      scaffoldMessengerKey: messengerKey,
      home: ListenableBuilder(
        listenable: _state,
        builder: (context, _) {
          if (_state.booting) return const _Splash();
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
            const SizedBox(height: 18),
            const Text('邻安', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: LinanColors.text)),
            const SizedBox(height: 6),
            const Text('正在连接社区守护服务…', style: TextStyle(fontSize: 11.5, color: LinanColors.muted)),
            const SizedBox(height: 20),
            const SizedBox(
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
