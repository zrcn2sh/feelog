import 'app_locale.dart';

/// 온보딩 모달 문구 (한국어 / English)
class OnboardingStrings {
  const OnboardingStrings({
    required this.welcomeTitle,
    required this.welcomeDesc,
    required this.chip6mDesc,
    required this.chip1yDesc,
    required this.chipSdDesc,
    required this.dataNoticeTitle,
    required this.dataNoticeBody,
    required this.startButton,
    required this.languageLabel,
    required this.languageOptionKo,
    required this.languageOptionEn,
  });

  final String welcomeTitle;
  final String welcomeDesc;
  final String chip6mDesc;
  final String chip1yDesc;
  final String chipSdDesc;
  final String dataNoticeTitle;
  final String dataNoticeBody;
  final String startButton;
  final String languageLabel;
  final String languageOptionKo;
  final String languageOptionEn;

  static const OnboardingStrings ko = OnboardingStrings(
    welcomeTitle: 'Feelog에 오신 것을 환영해요',
    welcomeDesc:
        '이 앱에서는 오늘 하루의 일기를 작성하고,\nAI가 감정을 분석해 드려요.\n일기를 쓰고 저장해 보세요.',
    chip6mDesc: '최근 6개월 감정 요약을 한눈에 볼 수 있어요.',
    chip1yDesc: '최근 1년 감정 요약을 볼 수 있어요.',
    chipSdDesc: '같은 일자의 과거 일기(추억)를 볼 수 있어요.',
    dataNoticeTitle: '※ 일기 데이터 안내',
    dataNoticeBody:
        '· 일기 데이터는 이 기기(휴대폰)에만 저장\n· 앱·데이터 삭제 시에 저장된 일기는 복구 불가',
    startButton: '시작하기',
    languageLabel: '언어',
    languageOptionKo: '한국어',
    languageOptionEn: 'English',
  );

  static const OnboardingStrings en = OnboardingStrings(
    welcomeTitle: 'Welcome to Feelog',
    welcomeDesc:
        'Write your daily diary and get AI emotion analysis.\nPick a date and save your diary.',
    chip6mDesc: 'View your 6-month emotion summary at a glance.',
    chip1yDesc: 'View your 1-year emotion summary.',
    chipSdDesc: 'View past diaries on the same date (memories).',
    dataNoticeTitle: 'Diary data notice',
    dataNoticeBody:
        '· Diary data is stored only on this device\n· Deleted data cannot be recovered',
    startButton: 'Get started',
    languageLabel: 'Language',
    languageOptionKo: 'Korean',
    languageOptionEn: 'English',
  );

  static OnboardingStrings forLocale(AppLocaleCode code) {
    return code == AppLocaleCode.en ? en : ko;
  }
}
