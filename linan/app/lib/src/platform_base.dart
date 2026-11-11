import 'package:flutter/foundation.dart';

/// 网页端与后端同源部署；桌面/移动端默认连本机 8765。
String defaultApiBase() {
  if (kIsWeb) return '';
  if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:8765';
  return 'http://127.0.0.1:8765';
}

const String defaultBaseFallback = 'http://127.0.0.1:8765';
