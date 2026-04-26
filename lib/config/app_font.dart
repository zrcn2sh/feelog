import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _keyAppFontFamily = 'feelog_app_font_family';

enum AppFontFamily {
  gaegu,
  notoSans,
}

extension AppFontFamilyExtension on AppFontFamily {
  String get value => name;

  static AppFontFamily fromString(String? value) {
    switch (value) {
      case 'notoSans':
        return AppFontFamily.notoSans;
      default:
        return AppFontFamily.gaegu;
    }
  }
}

class AppFont extends ChangeNotifier {
  AppFont({AppFontFamily initialFamily = AppFontFamily.gaegu})
      : _family = initialFamily;

  AppFontFamily _family;

  AppFontFamily get family => _family;

  Future<void> setFamily(AppFontFamily family) async {
    if (_family == family) return;
    _family = family;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAppFontFamily, family.value);
    notifyListeners();
  }

  TextStyle textStyle({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    double? height,
    Locale? locale,
    Paint? foreground,
    Paint? background,
    List<Shadow>? shadows,
    List<FontFeature>? fontFeatures,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
  }) {
    final adjustedFontSize =
        _family == AppFontFamily.notoSans && fontSize != null
            ? (fontSize - 1).clamp(1.0, double.infinity)
            : fontSize;

    final baseStyle = _family == AppFontFamily.notoSans
        ? GoogleFonts.notoSans(
            color: color,
            fontSize: adjustedFontSize,
            fontWeight: fontWeight,
            fontStyle: fontStyle,
            letterSpacing: letterSpacing,
            wordSpacing: wordSpacing,
            textBaseline: textBaseline,
            height: height,
            locale: locale,
            foreground: foreground,
            background: background,
            shadows: shadows,
            fontFeatures: fontFeatures,
            decoration: decoration,
            decorationColor: decorationColor,
            decorationStyle: decorationStyle,
            decorationThickness: decorationThickness,
          )
        : GoogleFonts.gaegu(
            color: color,
            fontSize: adjustedFontSize,
            fontWeight: fontWeight,
            fontStyle: fontStyle,
            letterSpacing: letterSpacing,
            wordSpacing: wordSpacing,
            textBaseline: textBaseline,
            height: height,
            locale: locale,
            foreground: foreground,
            background: background,
            shadows: shadows,
            fontFeatures: fontFeatures,
            decoration: decoration,
            decorationColor: decorationColor,
            decorationStyle: decorationStyle,
            decorationThickness: decorationThickness,
          );
    return baseStyle;
  }

  static Future<AppFontFamily> loadFontFamily() async {
    final prefs = await SharedPreferences.getInstance();
    return AppFontFamilyExtension.fromString(prefs.getString(_keyAppFontFamily));
  }
}

class AppFontScope extends InheritedNotifier<AppFont> {
  const AppFontScope({
    super.key,
    required AppFont notifier,
    required super.child,
  }) : super(notifier: notifier);

  static AppFont of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppFontScope>();
    assert(scope != null, 'AppFontScope not found. Wrap with AppFontScope.');
    return scope!.notifier!;
  }
}

TextStyle appFontText(
  BuildContext context, {
  Color? color,
  double? fontSize,
  FontWeight? fontWeight,
  FontStyle? fontStyle,
  double? letterSpacing,
  double? wordSpacing,
  TextBaseline? textBaseline,
  double? height,
  Locale? locale,
  Paint? foreground,
  Paint? background,
  List<Shadow>? shadows,
  List<FontFeature>? fontFeatures,
  TextDecoration? decoration,
  Color? decorationColor,
  TextDecorationStyle? decorationStyle,
  double? decorationThickness,
}) {
  return AppFontScope.of(context).textStyle(
    color: color,
    fontSize: fontSize,
    fontWeight: fontWeight,
    fontStyle: fontStyle,
    letterSpacing: letterSpacing,
    wordSpacing: wordSpacing,
    textBaseline: textBaseline,
    height: height,
    locale: locale,
    foreground: foreground,
    background: background,
    shadows: shadows,
    fontFeatures: fontFeatures,
    decoration: decoration,
    decorationColor: decorationColor,
    decorationStyle: decorationStyle,
    decorationThickness: decorationThickness,
  );
}
