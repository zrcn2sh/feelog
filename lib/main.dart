import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io' show Platform;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'firebase_options.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'pages/settings_page.dart';
import 'services/auth_service.dart';
import 'services/ai_service.dart';
import 'config/app_secret.dart';
import 'config/app_theme.dart';
import 'config/app_locale.dart';
import 'config/app_version.dart';
import 'config/app_font.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // 초기화 전부를 await 하면 네이티브 스플래시(흰 화면+아이콘)만 보이는 시간이 길어질 수 있음.
  // 즉시 runApp 해 Flutter 첫 프레임(로딩)을 그린 뒤 비동기로 Firebase 등을 마친다.
  runApp(const FeelogBootstrap());
}

/// 스플래시에서 멈춘 것처럼 보이지 않도록, 최소 UI를 먼저 띄운 뒤 초기화한다.
class FeelogBootstrap extends StatefulWidget {
  const FeelogBootstrap({super.key});

  @override
  State<FeelogBootstrap> createState() => _FeelogBootstrapState();
}

class _FeelogBootstrapState extends State<FeelogBootstrap> {
  AppTheme? _appTheme;
  AppLocale? _appLocale;
  AppFont? _appFont;
  Object? _initError;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  String _userFacingInitError(Object e) {
    if (kDebugMode) return e.toString();
    return '앱을 시작할 수 없습니다. 인터넷 연결을 확인한 뒤 다시 시도해 주세요.';
  }

  Future<void> _bootstrap() async {
    try {
      // 기기에서는 rootBundle 에셋만 읽힘. pubspec에 .env가 없으면 파일 없음 →
      // 예외만 삼키면 clean() 직후 미초기화 상태라 AppSecret에서 NotInitializedError 남.
      await dotenv.load(fileName: '.env', isOptional: true);
      if (kDebugMode && dotenv.env.isEmpty) {
        print(
            'ℹ️ .env가 에셋에 없거나 비어 있습니다. pubspec assets에 .env를 넣거나 --dart-define을 사용합니다.',
        );
      }

      if (kDebugMode) {
        print(
            '🔍 플랫폼: ${kIsWeb ? "웹" : (Platform.isAndroid ? "안드로이드" : "iOS")}');
      }

      await AppVersion.init();

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(const Duration(seconds: 45));

      if (AppSecret.geminiApiKey.isNotEmpty) {
        AIService.setApiKey(AppSecret.geminiApiKey);
      } else if (kDebugMode) {
        print('⚠️ GEMINI_API_KEY가 없어 AI 기능이 비활성화됩니다.');
      }

      final themePreference = await AppTheme.loadThemePreference();
      final appTheme = AppTheme(initialPreference: themePreference);

      final localeCode = await AppLocale.loadLocaleCode();
      final appLocale = AppLocale(initialCode: localeCode);

      final fontFamily = await AppFont.loadFontFamily();
      final appFont = AppFont(initialFamily: fontFamily);

      if (!kIsWeb) {
        try {
          await MobileAds.instance
              .initialize()
              .timeout(const Duration(seconds: 15));
        } on TimeoutException {
          if (kDebugMode) {
            print('⚠️ MobileAds 초기화 타임아웃(15초). 앱은 계속 실행됩니다.');
          }
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ MobileAds 초기화 실패: $e');
          }
        }
      }

      if (kDebugMode) {
        print('ℹ️ Hive 초기화는 사용자 로그인 후 HomePage에서 수행됩니다.');
      }

      if (!mounted) return;
      setState(() {
        _appTheme = appTheme;
        _appLocale = appLocale;
        _appFont = appFont;
        _initError = null;
      });
    } on TimeoutException catch (e) {
      if (!mounted) return;
      setState(() => _initError = e);
    } catch (e) {
      if (!mounted) return;
      setState(() => _initError = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initError != null) {
      final msg = _userFacingInitError(_initError!);
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(msg, textAlign: TextAlign.center),
            ),
          ),
        ),
      );
    }

    final appTheme = _appTheme;
    final appLocale = _appLocale;
    final appFont = _appFont;
    if (appTheme == null || appLocale == null || appFont == null) {
      return const MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: CircularProgressIndicator(
              color: AppColors.primary,
            ),
          ),
        ),
      );
    }

    return AppFontScope(
      notifier: appFont,
      child: AppThemeScope(
        notifier: appTheme,
        child: AppLocaleScope(
          notifier: appLocale,
          child: MyApp(theme: appTheme, appFont: appFont),
        ),
      ),
    );
  }
}

// 앱 테마 색상 정의 (아이콘 보라색 기반)
class AppColors {
  static const Color primary = Color(0xFF8B5CF6); // 보라색 (#8B5CF6)
  static const Color primaryLight = Color(0xFFA78BFA); // 밝은 보라색
  static const Color primaryDark = Color(0xFF7C3AED); // 어두운 보라색
  static const Color secondary = Color(0xFFF3F4F6); // 연한 회색
  static const Color accent = Color(0xFFEC4899); // 핑크 액센트
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, required this.theme, required this.appFont});

  final AppTheme theme;
  final AppFont appFont;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    widget.theme.addListener(_onThemeChanged);
    widget.appFont.addListener(_onThemeChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.theme.removeListener(_onThemeChanged);
    widget.appFont.removeListener(_onThemeChanged);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    widget.theme.handlePlatformBrightnessChanged();
  }

  void _onThemeChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final appLocale = AppLocaleScope.of(context);
    return CupertinoApp(
      debugShowCheckedModeBanner: false,
      title: 'Feelog',
      locale: appLocale.locale,
      theme: CupertinoThemeData(
        primaryColor: AppColors.primary,
        brightness: widget.theme.brightness,
        textTheme: CupertinoTextThemeData(
          primaryColor: widget.theme.brightness == Brightness.dark
              ? CupertinoColors.white
              : CupertinoColors.label,
          textStyle: appFontText(
            context,
            color: widget.theme.brightness == Brightness.dark
                ? CupertinoColors.white
                : CupertinoColors.label,
            fontSize: 18,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/home': (context) => const HomePage(),
        '/settings': (context) => const SettingsPage(),
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
    _setupAuthListener();
  }

  void _setupAuthListener() {
    // Firebase Auth 상태 변화를 실시간으로 감지
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (mounted) {
        setState(() {
          _isLoggedIn = user != null;
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _checkAuthStatus() async {
    try {
      final isLoggedIn = _authService.isLoggedIn();
      setState(() {
        _isLoggedIn = isLoggedIn;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return _isLoggedIn ? const HomePage() : const LoginPage();
  }
}
