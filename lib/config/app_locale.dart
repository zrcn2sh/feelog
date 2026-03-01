import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _keyLocale = 'feelog_locale';

/// 지원 언어: 한국어(ko), English(en)
enum AppLocaleCode {
  ko('ko'),
  en('en');

  const AppLocaleCode(this.code);
  final String code;

  static AppLocaleCode fromCode(String? code) {
    switch (code) {
      case 'en':
        return AppLocaleCode.en;
      default:
        return AppLocaleCode.ko;
    }
  }
}

/// 앱 언어 상태 관리 및 저장
class AppLocale extends ChangeNotifier {
  AppLocale({String? initialCode})
      : _code = AppLocaleCode.fromCode(initialCode ?? null);

  AppLocaleCode _code;

  AppLocaleCode get code => _code;

  Locale get locale => Locale(_code.code);

  /// 언어 변경 (한국어 / English)
  Future<void> setLocaleCode(AppLocaleCode value) async {
    if (_code == value) return;
    _code = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLocale, value.code);
    notifyListeners();
  }

  /// 저장된 언어 설정 로드
  static Future<String?> loadLocaleCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLocale);
  }
}

/// 트리 하위에서 [AppLocale] 접근용
class AppLocaleScope extends InheritedNotifier<AppLocale> {
  const AppLocaleScope({
    super.key,
    required AppLocale notifier,
    required super.child,
  }) : super(notifier: notifier);

  static AppLocale of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppLocaleScope>();
    assert(scope != null, 'AppLocaleScope not found. Wrap with AppLocaleScope.');
    return scope!.notifier!;
  }
}
