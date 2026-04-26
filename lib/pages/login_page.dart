import 'package:flutter/cupertino.dart';
import '../services/auth_service.dart';
import '../main.dart';
import '../config/app_font.dart';
import '../config/app_version.dart';
import '../config/app_locale.dart';
import '../config/login_strings.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userCredential = await _authService.signInWithGoogle();
      if (userCredential != null && userCredential.user != null) {
        await _authService.recordLoginHistory(userCredential.user!, loginMethod: 'google');
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      }
    } catch (e) {
      if (mounted) _showLoginError('$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithApple() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userCredential = await _authService.signInWithApple();
      if (userCredential != null && userCredential.user != null) {
        await _authService.recordLoginHistory(userCredential.user!, loginMethod: 'apple');
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      }
    } catch (e) {
      if (mounted) _showLoginError('$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showLoginError(String message) {
    final s = LoginStrings.forLocale(AppLocaleScope.of(context).code);
    showCupertinoDialog(
      context: context,
      builder: (BuildContext ctx) => CupertinoAlertDialog(
        title: Text(s.loginFailed),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: Text(s.ok),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = LoginStrings.forLocale(AppLocaleScope.of(context).code);
    // 앱 테마 밝기 사용 (설정에서 다크 모드 선택 시 반영)
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final textColor = isDark ? CupertinoColors.white : CupertinoColors.label;
    final secondaryTextColor = isDark
        ? CupertinoColors.white
        : CupertinoColors.secondaryLabel;
    final tertiaryTextColor = isDark
        ? CupertinoColors.white.withOpacity(0.85)
        : CupertinoColors.tertiaryLabel;

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemBackground,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 앱 로고
              Center(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: SizedBox(
                      width: 120,
                      height: 120,
                      child: Image.asset(
                        'assets/images/icon.png',
                        fit: BoxFit.cover,
                        width: 120,
                        height: 120,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 120,
                            height: 120,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              CupertinoIcons.heart_fill,
                              size: 60,
                              color: CupertinoColors.white,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // 앱 제목
              Text(
                'Feelog',
                style: appFontText(context, 
                  fontSize: 37,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: 12),

              // 부제목
              Text(
                s.subtitle,
                textAlign: TextAlign.center,
                style: appFontText(context, 
                  fontSize: 18,
                  color: secondaryTextColor,
                  fontWeight: FontWeight.w400,
                ),
              ),

              const SizedBox(height: 80),

              // Google 로그인 버튼
              SizedBox(
                width: double.infinity,
                height: 56,
                child: CupertinoButton.filled(
                  onPressed: _isLoading ? null : _signInWithGoogle,
                  borderRadius: BorderRadius.circular(25),
                  child: _isLoading
                      ? const CupertinoActivityIndicator(
                          color: CupertinoColors.white,
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              CupertinoIcons.person_circle,
                              color: CupertinoColors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              s.continueWithGoogle,
                              style: appFontText(context, 
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                                color: CupertinoColors.white,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 12),

              // Apple 로그인 버튼 (Apple 가이드라인: 검정 배경)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: CupertinoButton(
                  onPressed: _isLoading ? null : _signInWithApple,
                  borderRadius: BorderRadius.circular(25),
                  color: CupertinoColors.black,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        CupertinoIcons.device_phone_portrait,
                        color: CupertinoColors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        s.continueWithApple,
                        style: appFontText(context, 
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                          color: CupertinoColors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // 약관 동의 텍스트
              Text(
                s.termsNotice,
                textAlign: TextAlign.center,
                style: appFontText(context, 
                  fontSize: 14,
                  color: secondaryTextColor,
                  fontWeight: FontWeight.w400,
                ),
              ),

              const Spacer(),

              // 버전 정보
              Column(
                children: [
                  Text(
                    'v${AppVersion.fullVersion}',
                    style: appFontText(context, 
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: secondaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'by ${AppVersion.developer}',
                    style: appFontText(context, 
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: tertiaryTextColor,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
