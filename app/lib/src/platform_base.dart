import 'package:flutter/foundation.dart';

/// 桌面端连本机 8765；Android 模拟器走 10.0.2.2。
String defaultApiBase() {
  if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:8765';
  return 'http://127.0.0.1:8765';
}
