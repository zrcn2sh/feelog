import 'app_locale.dart';

/// 메인(홈) 페이지 문구 (한국어 / English)
class HomeStrings {
  const HomeStrings({
    required this.ok,
    required this.cancel,
    required this.delete,
    required this.close,
    required this.exit,
    required this.alert,
    required this.userInfo,
    required this.user,
    required this.withdrawConfirmTitle,
    required this.withdrawConfirmMessage,
    required this.withdraw,
    required this.withdrawFailed,
    required this.logoutFailed,
    required this.debugDiaryListTitle,
    required this.noDiarySaved,
    required this.checkConsole,
    required this.webHiveNotice,
    required this.debugTotalTitle,
    required this.todayDiary,
    required this.diaryPlaceholder,
    required this.save,
    required this.edit,
    required this.enterDiaryPrompt,
    required this.saveSuccess,
    required this.diarySaved,
    required this.saveFailed,
    required this.saveErrorMessage,
    required this.editSuccess,
    required this.diaryUpdated,
    required this.editFailed,
    required this.editErrorMessage,
    required this.deleteDiaryTitle,
    required this.deleteDiaryConfirm,
    required this.deleteSuccess,
    required this.diaryDeleted,
    required this.deleteFailed,
    required this.deleteErrorMessage,
    required this.weekdaysSunFirst,
    required this.weekdaysMonFirst,
    required this.today,
    required this.analyzingDiary,
    required this.adLoadFailed,
    required this.noDataForAnalysis,
    required this.period6MonthTitle,
    required this.period1YearTitle,
    required this.analyzingPeriodWait,
    required this.pleaseWait,
    required this.errorTitle,
    required this.loadDataFailed,
    required this.noEntryOnThisDay,
  });

  final String ok;
  final String cancel;
  final String delete;
  final String close;
  final String exit;
  final String alert;
  final String userInfo;
  final String user;
  final String withdrawConfirmTitle;
  final String withdrawConfirmMessage;
  final String withdraw;
  final String withdrawFailed;
  final String logoutFailed;
  final String debugDiaryListTitle;
  final String noDiarySaved;
  final String checkConsole;
  final String webHiveNotice;
  final String debugTotalTitle;
  final String todayDiary;
  final String diaryPlaceholder;
  final String save;
  final String edit;
  final String enterDiaryPrompt;
  final String saveSuccess;
  final String diarySaved;
  final String saveFailed;
  final String saveErrorMessage;
  final String editSuccess;
  final String diaryUpdated;
  final String editFailed;
  final String editErrorMessage;
  final String deleteDiaryTitle;
  final String deleteDiaryConfirm;
  final String deleteSuccess;
  final String diaryDeleted;
  final String deleteFailed;
  final String deleteErrorMessage;
  final List<String> weekdaysSunFirst;
  final List<String> weekdaysMonFirst;
  final String today;
  final String analyzingDiary;
  final String adLoadFailed;
  final String noDataForAnalysis;
  final String period6MonthTitle;
  final String period1YearTitle;
  final String analyzingPeriodWait;
  final String pleaseWait;
  final String errorTitle;
  final String loadDataFailed;
  final String noEntryOnThisDay;

  bool get _isKo => identical(this, ko);
  /// SD 모달 제목 (같은 날의 추억)
  String sameDayMemoriesTitle(int month, int day) =>
      _isKo ? '$month월 $day일의 추억' : 'Memories on ${_enMonthsShort[month - 1]} $day';

  String diaryCount(int n) => _isKo ? '총 $n개의 일기' : '$n diaries';
  String andMore(int n) => _isKo ? '... 외 $n개' : '... +$n more';
  String diaryEntryLine(String date, int chars) =>
      _isKo ? '• $date (${chars}자)' : '• $date ($chars chars)';
  String noDiaryInYear(int year) =>
      _isKo ? '$year년에 작성한 일기가 없습니다.' : 'No diaries in $year.';
  String formatDate(int year, int month, int day, String weekday) =>
      _isKo ? '$year년 $month월 $day일 ($weekday)' : '$month/$day/$year ($weekday)';
  /// 캘린더 헤더용 년·월 표시 (예: 2026년 2월 / February 2026)
  String formatYearMonth(int year, int month) =>
      _isKo ? '$year년 $month월' : '${_enMonths[month - 1]} $year';
  String formatYear(int year) => _isKo ? '$year년' : '$year';
  String formatMonth(int month) => _isKo ? '$month월' : _enMonths[month - 1];
  /// 차트 등 좁은 공간용 월 약자 (1월 / Jan, Feb, ...)
  String formatMonthShort(int month) => _isKo ? '$month월' : _enMonthsShort[month - 1];
  String get yearMonthSelectTitle => _isKo ? '년월 선택' : 'Select year & month';
  /// 사용자 정보 > 월별 일기 작성 수 차트 제목
  String monthlyDiaryChartTitle(int year) =>
      _isKo ? '$year년 월별 일기 작성 수' : 'Diaries per month, $year';
  String debugTotalCount(int n) => _isKo ? '총 일기 수: ${n}개' : 'Total diaries: $n';

  static const List<String> _enMonths = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static const List<String> _enMonthsShort = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static const HomeStrings ko = HomeStrings(
    ok: '확인',
    cancel: '취소',
    delete: '삭제',
    close: '닫기',
    exit: '나가기',
    alert: '알림',
    userInfo: '사용자 정보',
    user: '사용자',
    withdrawConfirmTitle: '계정 탈퇴',
    withdrawConfirmMessage:
        '정말 탈퇴하시겠습니까?\n모든 일기 데이터가 삭제되며 복구할 수 없습니다.',
    withdraw: '탈퇴',
    withdrawFailed: '탈퇴 실패',
    logoutFailed: '로그아웃 실패',
    debugDiaryListTitle: '일기 날짜 목록:',
    noDiarySaved: '저장된 일기가 없습니다.',
    checkConsole: '※ 상세 정보는 콘솔 로그를 확인하세요.',
    webHiveNotice: '웹에서는 Hive를 사용하지 않습니다.',
    debugTotalTitle: '총 일기 수:',
    todayDiary: '오늘의 일기',
    diaryPlaceholder: '일기를 입력하세요',
    save: '저장하기',
    edit: '수정하기',
    enterDiaryPrompt: '일기를 입력해주세요.',
    saveSuccess: '저장 완료',
    diarySaved: '일기가 저장되었습니다.',
    saveFailed: '저장 실패',
    saveErrorMessage: '일기 저장 중 오류가 발생했습니다.',
    editSuccess: '수정 완료',
    diaryUpdated: '일기가 수정되었습니다.',
    editFailed: '수정 실패',
    editErrorMessage: '일기 수정 중 오류가 발생했습니다.',
    deleteDiaryTitle: '일기 삭제',
    deleteDiaryConfirm: '정말 이 일기를 삭제하시겠습니까?',
    deleteSuccess: '삭제 완료',
    diaryDeleted: '일기가 삭제되었습니다.',
    deleteFailed: '삭제 실패',
    deleteErrorMessage: '일기 삭제 중 오류가 발생했습니다.',
    weekdaysSunFirst: ['일', '월', '화', '수', '목', '금', '토'],
    weekdaysMonFirst: ['월', '화', '수', '목', '금', '토', '일'],
    today: '오늘',
    analyzingDiary: '일기 분석 중',
    adLoadFailed: '광고를 불러올 수 없습니다',
    noDataForAnalysis: '분석할 데이터가 없습니다.',
    period6MonthTitle: '지난 6개월 감정',
    period1YearTitle: '지난 1년 감정',
    analyzingPeriodWait: 'AI 일기 분석 중...',
    pleaseWait: '잠시만 기다려주세요',
    errorTitle: '오류',
    loadDataFailed: '데이터를 불러올 수 없습니다.',
    noEntryOnThisDay: '아직 이날 기록이 없네요',
  );

  static const HomeStrings en = HomeStrings(
    ok: 'OK',
    cancel: 'Cancel',
    delete: 'Delete',
    close: 'Close',
    exit: 'Exit',
    alert: 'Notice',
    userInfo: 'User info',
    user: 'User',
    withdrawConfirmTitle: 'Delete account',
    withdrawConfirmMessage:
        'Are you sure? All diary data will be deleted and cannot be recovered.',
    withdraw: 'Delete',
    withdrawFailed: 'Delete failed',
    logoutFailed: 'Logout failed',
    debugDiaryListTitle: 'Diary dates:',
    noDiarySaved: 'No diaries saved.',
    checkConsole: 'See console for details.',
    webHiveNotice: 'Hive is not used on web.',
    debugTotalTitle: 'Total diaries:',
    todayDiary: "Today's diary",
    diaryPlaceholder: 'Enter your diary',
    save: 'Save',
    edit: 'Edit',
    enterDiaryPrompt: 'Please enter your diary.',
    saveSuccess: 'Saved',
    diarySaved: 'Diary saved.',
    saveFailed: 'Save failed',
    saveErrorMessage: 'An error occurred while saving.',
    editSuccess: 'Updated',
    diaryUpdated: 'Diary updated.',
    editFailed: 'Update failed',
    editErrorMessage: 'An error occurred while updating.',
    deleteDiaryTitle: 'Delete diary',
    deleteDiaryConfirm: 'Are you sure you want to delete this diary?',
    deleteSuccess: 'Deleted',
    diaryDeleted: 'Diary deleted.',
    deleteFailed: 'Delete failed',
    deleteErrorMessage: 'An error occurred while deleting.',
    weekdaysSunFirst: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'],
    weekdaysMonFirst: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
    today: 'Today',
    analyzingDiary: 'Analyzing diary',
    adLoadFailed: 'Unable to load ad',
    noDataForAnalysis: 'No data to analyze.',
    period6MonthTitle: 'Last 6 months mood',
    period1YearTitle: 'Last 1 year mood',
    analyzingPeriodWait: 'Analyzing diary...',
    pleaseWait: 'Please wait',
    errorTitle: 'Error',
    loadDataFailed: 'Unable to load data.',
    noEntryOnThisDay: 'No diary on this day yet',
  );

  static HomeStrings forLocale(AppLocaleCode code) {
    return code == AppLocaleCode.en ? en : ko;
  }
}
