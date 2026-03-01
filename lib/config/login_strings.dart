import 'app_locale.dart';

/// 로그인 페이지 문구 (한국어 / English)
class LoginStrings {
  const LoginStrings({
    required this.subtitle,
    required this.continueWithGoogle,
    required this.continueWithApple,
    required this.termsNotice,
    required this.loginFailed,
    required this.ok,
  });

  final String subtitle;
  final String continueWithGoogle;
  final String continueWithApple;
  final String termsNotice;
  final String loginFailed;
  final String ok;

  static const LoginStrings ko = LoginStrings(
    subtitle: '당신의 감정을 기록하고 관리하세요',
    continueWithGoogle: 'Google로 계속하기',
    continueWithApple: 'Apple로 계속하기',
    termsNotice: '로그인하면 서비스 이용약관 및 개인정보처리방침에\n동의하는 것으로 간주됩니다.',
    loginFailed: '로그인 실패',
    ok: '확인',
  );

  static const LoginStrings en = LoginStrings(
    subtitle: 'Record and manage your emotions',
    continueWithGoogle: 'Continue with Google',
    continueWithApple: 'Continue with Apple',
    termsNotice: 'By signing in, you agree to the Terms of Service\nand Privacy Policy.',
    loginFailed: 'Sign in failed',
    ok: 'OK',
  );

  static LoginStrings forLocale(AppLocaleCode code) {
    return code == AppLocaleCode.en ? en : ko;
  }
}
