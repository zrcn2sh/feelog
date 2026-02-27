import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';

/// 웹 빌드용 스텁 (광고 없이 "일기 분석 중"만 표시). 모바일에서는 analyzing_ad_dialog_io 사용.
class AnalyzingAdDialog extends StatelessWidget {
  const AnalyzingAdDialog({super.key});

  @override
  Widget build(BuildContext context) {
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
              '일기 분석 중',
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
