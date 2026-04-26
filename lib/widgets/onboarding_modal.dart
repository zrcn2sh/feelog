import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, Colors, Color;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_locale.dart';
import '../config/app_font.dart';
import '../config/onboarding_strings.dart';
import '../main.dart';

/// 첫 로그인 시 한 번만 보여주는 설명 모달.
/// [onComplete]에서 SharedPreferences에 '본 적 있음' 저장 후 호출.
class OnboardingModal extends StatelessWidget {
  const OnboardingModal({
    super.key,
    required this.onComplete,
  });

  final VoidCallback onComplete;

  static const String _prefKey = 'feelog_onboarding_seen';

  /// 이미 온보딩을 본 적 있는지 확인 (사용자별로 저장하려면 [userId] 전달).
  static Future<bool> hasSeenOnboarding({String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = userId != null ? '${_prefKey}_$userId' : _prefKey;
    return prefs.getBool(key) ?? false;
  }

  /// 온보딩을 완료했음으로 저장 (같은 [userId]로 호출해야 함).
  static Future<void> markOnboardingSeen({String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = userId != null ? '${_prefKey}_$userId' : _prefKey;
    await prefs.setBool(key, true);
  }

  /// 홈의 6M/1Y/SD 버튼과 같은 둥근 버튼 + 설명 한 줄
  static Widget _buildChipRow(
      BuildContext context, String label, String description) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? const [Color(0xFF2A2A33), Color(0xFF21212A)]
                    : const [Color(0xFFF8F3FF), Color(0xFFEEE5FF)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? const Color(0xFF3A3A45) : const Color(0xFFE6DBFA),
                width: 1,
              ),
            ),
            child: Text(
              label,
              style: appFontText(context, 
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              description,
              style: appFontText(context, 
                fontSize: 15,
                height: 1.35,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 모달이 열릴 때 키보드가 남아 있으면 '시작하기'가 가려지므로 한 번 더 내림
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusManager.instance.primaryFocus?.unfocus();
      if (context.mounted) FocusScope.of(context).unfocus();
    });
    final size = MediaQuery.sizeOf(context);
    final maxWidth = size.width - 48; // 좌우 24 패딩
    final appLocale = AppLocaleScope.of(context);
    final s = OnboardingStrings.forLocale(appLocale.code);
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final secondaryColor = CupertinoColors.secondaryLabel.resolveFrom(context);

    return Material(
      color: Colors.transparent,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: size.height * 0.75,
            ),
            child: SizedBox(
              width: double.infinity,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: CupertinoTheme.brightnessOf(context) == Brightness.dark
                        ? const [Color(0xFF24242B), Color(0xFF19191F)]
                        : const [CupertinoColors.white, Color(0xFFF5F1FF)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: CupertinoTheme.brightnessOf(context) == Brightness.dark
                        ? const Color(0xFF31313A)
                        : const Color(0xFFEAE4F7),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: CupertinoColors.black.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          CupertinoSlidingSegmentedControl<AppLocaleCode>(
                            groupValue: appLocale.code,
                            thumbColor: CupertinoColors.tertiarySystemFill
                                .resolveFrom(context),
                            children: {
                              AppLocaleCode.ko: _segmentPaddingSmall(
                                Text(
                                  'KOR',
                                  style: appFontText(context, 
                                    fontSize: 11,
                                    color: labelColor,
                                  ),
                                ),
                              ),
                              AppLocaleCode.en: _segmentPaddingSmall(
                                Text(
                                  'ENG',
                                  style: appFontText(context, 
                                    fontSize: 11,
                                    color: labelColor,
                                  ),
                                ),
                              ),
                            },
                            onValueChanged: (v) {
                              if (v != null) appLocale.setLocaleCode(v);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Icon(
                        CupertinoIcons.heart_fill,
                        size: 48,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        s.welcomeTitle,
                        style: appFontText(context, 
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                          color: labelColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        s.welcomeDesc,
                        style: appFontText(context, 
                          fontSize: 17,
                          height: 1.4,
                          color: secondaryColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      _buildChipRow(context, '6M', s.chip6mDesc),
                      _buildChipRow(context, '1Y', s.chip1yDesc),
                      _buildChipRow(context, 'SD', s.chipSdDesc),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors:
                                CupertinoTheme.brightnessOf(context) == Brightness.dark
                                    ? const [Color(0xFF2A2A31), Color(0xFF222229)]
                                    : const [Color(0xFFF8F4FF), Color(0xFFF0E9FF)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: CupertinoTheme.brightnessOf(context) == Brightness.dark
                                ? const Color(0xFF373741)
                                : const Color(0xFFE7DDFC),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.dataNoticeTitle,
                              style: appFontText(context, 
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: labelColor,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              s.dataNoticeBody,
                              style: appFontText(context, 
                                fontSize: 14,
                                height: 1.45,
                                color: secondaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: CupertinoButton(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                          onPressed: () => onComplete(),
                          child: Text(
                            s.startButton,
                            style: appFontText(context, 
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: CupertinoColors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Padding _segmentPaddingSmall(Widget child) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 6),
    child: child,
  );
}
