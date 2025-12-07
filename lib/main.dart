import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'firebase_options.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'services/auth_service.dart';
import 'services/ai_service.dart';
import 'config/app_secret.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 플랫폼 감지 디버깅
  print('═══════════════════════════════════════');
  print('🔍 플랫폼 감지 정보');
  print('   kIsWeb: $kIsWeb');
  if (!kIsWeb) {
    try {
      print('   Platform.isAndroid: ${Platform.isAndroid}');
      print('   Platform.isIOS: ${Platform.isIOS}');
      print('   Platform.operatingSystem: ${Platform.operatingSystem}');
    } catch (e) {
      print('   Platform 정보 가져오기 실패: $e');
    }
  }
  print(
      '   플랫폼 타입: ${kIsWeb ? "웹" : (Platform.isAndroid ? "안드로이드" : (Platform.isIOS ? "iOS" : "기타"))}');
  print('═══════════════════════════════════════');

  // Firebase 초기화
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // AI 서비스 초기화 (Gemini API 키 설정)
  AIService.setApiKey(AppSecret.geminiApiKey);

  // Hive 초기화는 사용자 로그인 후에 수행 (main.dart에서는 스킵)
  // 사용자별 Box를 열기 위해 userId가 필요함
  print('ℹ️ Hive 초기화는 사용자 로그인 후 HomePage에서 수행됩니다.');

  runApp(const MyApp());
}

// 앱 테마 색상 정의 (아이콘 보라색 기반)
class AppColors {
  static const Color primary = Color(0xFF8B5CF6); // 보라색 (#8B5CF6)
  static const Color primaryLight = Color(0xFFA78BFA); // 밝은 보라색
  static const Color primaryDark = Color(0xFF7C3AED); // 어두운 보라색
  static const Color secondary = Color(0xFFF3F4F6); // 연한 회색
  static const Color accent = Color(0xFFEC4899); // 핑크 액센트
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'Feelog',
      theme: CupertinoThemeData(
        primaryColor: AppColors.primary,
        brightness: Brightness.light,
        textTheme: CupertinoTextThemeData(
          primaryColor: CupertinoColors.label,
          textStyle: GoogleFonts.gaegu(
            color: CupertinoColors.label,
            fontSize: 17,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/home': (context) => const HomePage(),
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
