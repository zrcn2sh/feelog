import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:google_fonts/google_fonts.dart';
import '../config/app_locale.dart';
import '../config/home_strings.dart';
import '../main.dart';

/// 웹 빌드용 스텁 (광고 없이 "일기 분석 중"만 표시). 모바일에서는 analyzing_ad_dialog 사용.
class PreloadedBannerHolder {
  PreloadedBannerHolder._();
  static void preload() {}
  static void releaseAndPreloadNext() {}
  static Object? get ad => null;
  static bool get isReady => false;
  static ValueNotifier<bool>? get readyNotifier => null;
}

/// 웹에서는 preloadedAd/ready/notifier 무시 (광고 미표시).
class AnalyzingAdDialog extends StatelessWidget {
  const AnalyzingAdDialog({
    super.key,
    this.onAdDisplayed,
    this.preloadedAd,
    this.preloadedAdReady = false,
    this.preloadedReadyNotifier,
  });
  final VoidCallback? onAdDisplayed;
  final Object? preloadedAd;
  final bool preloadedAdReady;
  final ValueNotifier<bool>? preloadedReadyNotifier;

  @override
  Widget build(BuildContext context) {
    final s = HomeStrings.forLocale(AppLocaleScope.of(context).code);
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final textColor = isDark ? CupertinoColors.white : CupertinoColors.label.resolveFrom(context);
    final bgColor = isDark ? const Color(0xFF2C2C2E) : CupertinoColors.systemBackground.resolveFrom(context);

    return Center(
      child: Container(
        width: 320,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              s.analyzingDiary,
              style: GoogleFonts.gaegu(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: 20),
            const SizedBox(
              height: 50,
              child: Center(
                child: CupertinoActivityIndicator(color: AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
