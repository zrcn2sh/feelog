import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _keyDarkMode = 'feelog_dark_mode';
const String _keyThemePreference = 'feelog_theme_preference';

/// 테마 선택: 시스템 설정 따르기 | 라이트 | 다크
enum ThemePreference {
  system,
  light,
  dark,
}

extension ThemePreferenceExtension on ThemePreference {
  String get value => name;
  static ThemePreference fromString(String? s) {
    switch (s) {
      case 'light':
        return ThemePreference.light;
      case 'dark':
        return ThemePreference.dark;
      default:
        return ThemePreference.system;
    }
  }
}

/// 앱 테마(다크 모드) 상태 관리 및 저장
/// Android·iOS 모두 디바이스 설정은 [PlatformDispatcher.instance.platformBrightness]로 동일하게 반영합니다.
class AppTheme extends ChangeNotifier {
  AppTheme({ThemePreference initialPreference = ThemePreference.system})
      : _preference = initialPreference {
    _brightness = _resolveBrightness();
  }

  /// 시스템 밝기가 바뀌었을 때 호출 (MyApp에서 WidgetsBindingObserver로 호출)
  void handlePlatformBrightnessChanged() {
    if (_preference != ThemePreference.system) return;
    _brightness = PlatformDispatcher.instance.platformBrightness;
    notifyListeners();
  }

  ThemePreference _preference;
  late Brightness _brightness;

  ThemePreference get preference => _preference;

  /// 실제 적용 중인 밝기 (시스템 따르기면 디바이스 설정, 아니면 선택한 값)
  Brightness get brightness => _brightness;

  bool get isDarkMode => _brightness == Brightness.dark;

  bool get isFollowingSystem => _preference == ThemePreference.system;

  Brightness _resolveBrightness() {
    if (_preference == ThemePreference.system) {
      return PlatformDispatcher.instance.platformBrightness;
    }
    return _preference == ThemePreference.dark ? Brightness.dark : Brightness.light;
  }

  /// 테마 선택 변경 (시스템 | 라이트 | 다크)
  Future<void> setThemePreference(ThemePreference value) async {
    if (_preference == value) return;
    _preference = value;
    _brightness = _resolveBrightness();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemePreference, value.value);
    notifyListeners();
  }

  /// 이전 버전 호환: 다크 모드 on/off만 설정
  Future<void> setDarkMode(bool value) async {
    await setThemePreference(value ? ThemePreference.dark : ThemePreference.light);
  }

  /// 저장된 테마 설정 로드 (시스템 | 라이트 | 다크). 구버전 bool 저장값은 자동 마이그레이션.
  static Future<ThemePreference> loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_keyThemePreference);
    if (saved != null) return ThemePreferenceExtension.fromString(saved);
    // 구버전: feelog_dark_mode (bool)
    final legacy = prefs.getBool(_keyDarkMode);
    if (legacy != null) {
      final migrated = legacy ? ThemePreference.dark : ThemePreference.light;
      await prefs.setString(_keyThemePreference, migrated.value);
      return migrated;
    }
    return ThemePreference.system;
  }

  /// @deprecated 구버전 호환용. [loadThemePreference] 사용 권장.
  static Future<bool> loadDarkMode() async {
    final p = await loadThemePreference();
    if (p == ThemePreference.system) {
      return PlatformDispatcher.instance.platformBrightness == Brightness.dark;
    }
    return p == ThemePreference.dark;
  }
}

/// 트리 하위에서 [AppTheme] 접근용
class AppThemeScope extends InheritedNotifier<AppTheme> {
  const AppThemeScope({
    super.key,
    required AppTheme notifier,
    required super.child,
  }) : super(notifier: notifier);

  static AppTheme of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppThemeScope>();
    assert(scope != null, 'AppThemeScope not found. Wrap with AppThemeScope.');
    return scope!.notifier!;
  }
}
