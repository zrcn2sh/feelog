import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kDebugMode) {
    print('🔍 플랫폼: ${kIsWeb ? "웹" : (Platform.isAndroid ? "안드로이드" : "iOS")}');
  }

  // 앱 버전 로드 (pubspec.yaml의 version 사용)
  await AppVersion.init();

  // Firebase 초기화
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // AI 서비스 초기화 (Gemini API 키 설정)
  AIService.setApiKey(AppSecret.geminiApiKey);

  // 테마 설정 로드 (시스템 따르기 | 라이트 | 다크)
  final themePreference = await AppTheme.loadThemePreference();
  final appTheme = AppTheme(initialPreference: themePreference);

  // 언어 설정 로드 (한국어 / English)
  final localeCode = await AppLocale.loadLocaleCode();
  final appLocale = AppLocale(initialCode: localeCode);

  // AdMob 초기화 (모바일만)
  if (!kIsWeb) {
    await MobileAds.instance.initialize();
  }

  if (kDebugMode) {
    print('ℹ️ Hive 초기화는 사용자 로그인 후 HomePage에서 수행됩니다.');
  }

  runApp(AppThemeScope(
    notifier: appTheme,
    child: AppLocaleScope(
      notifier: appLocale,
      child: MyApp(theme: appTheme),
    ),
  ));
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
  const MyApp({super.key, required this.theme});

  final AppTheme theme;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    widget.theme.addListener(_onThemeChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.theme.removeListener(_onThemeChanged);
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
          textStyle: GoogleFonts.gaegu(
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
