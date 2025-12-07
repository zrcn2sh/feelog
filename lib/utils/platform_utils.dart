import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

/// 플랫폼 유틸리티
class PlatformUtils {
  /// 웹 플랫폼인지 확인
  static bool get isWeb => kIsWeb;

  /// 모바일 앱인지 확인 (안드로이드 또는 iOS)
  static bool get isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// 안드로이드인지 확인
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;

  /// iOS인지 확인
  static bool get isIOS => !kIsWeb && Platform.isIOS;
}

