import 'app_locale.dart';

/// 설정 화면 문구 (한국어 / English)
class SettingsStrings {
  const SettingsStrings({
    required this.title,
    required this.language,
    required this.displayMode,
    required this.auto,
    required this.light,
    required this.dark,
    required this.dataTransfer,
    required this.exportBackup,
    required this.importBackup,
    required this.backupDescription,
    required this.deleteAccount,
    required this.languageOptionKo,
    required this.languageOptionEn,
  });

  final String title;
  final String language;
  final String displayMode;
  final String auto;
  final String light;
  final String dark;
  final String dataTransfer;
  final String exportBackup;
  final String importBackup;
  final String backupDescription;
  final String deleteAccount;
  final String languageOptionKo;
  final String languageOptionEn;

  static const SettingsStrings ko = SettingsStrings(
    title: '설정',
    language: '언어',
    displayMode: '화면 모드',
    auto: '자동',
    light: '라이트',
    dark: '다크',
    dataTransfer: '데이터 옮기기',
    exportBackup: '백업하여 내보내기',
    importBackup: '백업에서 가져오기',
    backupDescription:
        '폰을 바꿀 때 백업 파일을 저장(이메일, 드라이브)해 두었다가, 새 기기에서 같은 계정으로 로그인한 뒤 가져오기하면 일기를 옮길 수 있습니다.',
    deleteAccount: '계정 탈퇴',
    languageOptionKo: '한국어',
    languageOptionEn: 'English',
  );

  static const SettingsStrings en = SettingsStrings(
    title: 'Settings',
    language: 'Language',
    displayMode: 'Display',
    auto: 'Auto',
    light: 'Light',
    dark: 'Dark',
    dataTransfer: 'Data transfer',
    exportBackup: 'Export backup',
    importBackup: 'Import backup',
    backupDescription:
        'When you get a new device, save a backup (email, drive), then sign in with the same account and import to move your diaries.',
    deleteAccount: 'Delete account',
    languageOptionKo: 'Korean',
    languageOptionEn: 'English',
  );

  static SettingsStrings forLocale(AppLocaleCode code) {
    return code == AppLocaleCode.en ? en : ko;
  }
}
