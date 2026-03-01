/// AdMob 실제 광고 단위 ID 설정
///
/// ⚠️ 구분: 앱 ID(Application ID) ≠ 광고 단위 ID(Ad Unit ID)
/// - 앱 ID: ca-app-pub-XXXX~YYYY (물결 ~) → Info.plist / AndroidManifest 에 이미 설정됨
/// - 광고 단위 ID: ca-app-pub-XXXX/YYYY (슬래시 /) → 아래에 배너용으로 설정
///
/// 1. [AdMob 콘솔](https://admob.google.com) → 앱 → 광고 단위 → 배너
/// 2. iOS용 배너, Android용 배너 각각의 "광고 단위 ID" 전체를 복사 (슬래시 / 포함)
/// 3. 아래 값을 해당 ID로 교체. 0000000000 은 반드시 AdMob에서 발급한 숫자로 바꿔야 광고가 표시됩니다.
class AdConfig {
  /// iOS 배너 광고 단위 ID (형식: ca-app-pub-발행자ID/광고단위ID, 슬래시 사용)
  static const String bannerAdUnitIdIos =
      'ca-app-pub-7887828015262915/3728212467';

  /// Android 배너 광고 단위 ID (형식: ca-app-pub-발행자ID/광고단위ID)
  static const String bannerAdUnitIdAndroid =
      'ca-app-pub-7887828015262915/3728212467';
}
