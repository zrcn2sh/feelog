import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, Colors, Color;
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  /// 다크 모드: 어두운 회색 배경, 라이트 모드: 시스템 배경
  static Color _modalBackgroundColor(BuildContext context) {
    if (CupertinoTheme.brightnessOf(context) == Brightness.dark) {
      return const Color(0xFF2C2C2E);
    }
    return CupertinoColors.systemBackground.resolveFrom(context);
  }

  /// 홈의 6M/1Y/SD 버튼과 같은 둥근 버튼 + 설명 한 줄
  static Widget _buildChipRow(
      BuildContext context, String label, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: GoogleFonts.gaegu(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              description,
              style: GoogleFonts.gaegu(
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
      FocusScope.of(context).unfocus();
    });
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: _modalBackgroundColor(context),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: CupertinoColors.black.withOpacity(0.15),
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
                    const SizedBox(height: 8),
                    const Icon(
                      CupertinoIcons.heart_fill,
                      size: 48,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Feelog에 오신 것을 환영해요',
                      style: GoogleFonts.gaegu(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                        color: CupertinoColors.label.resolveFrom(context),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '이 앱에서는 오늘 하루의 일기를 작성하고,\nAI가 감정을 분석해 드려요.\n달력에서 날짜를 선택해 일기를 쓰고 저장해 보세요.',
                      style: GoogleFonts.gaegu(
                        fontSize: 17,
                        height: 1.4,
                        color: CupertinoColors.secondaryLabel.resolveFrom(context),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    _buildChipRow(
                      context,
                      '6M',
                      '최근 6개월 감정 요약을 한눈에 볼 수 있어요.',
                    ),
                    _buildChipRow(
                      context,
                      '1Y',
                      '최근 1년 감정 요약을 볼 수 있어요.',
                    ),
                    _buildChipRow(
                      context,
                      'SD',
                      '같은 일자의 과거 일기(추억)를 볼 수 있어요.',
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey5.resolveFrom(context),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '※ 일기 데이터 안내',
                            style: GoogleFonts.gaegu(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: CupertinoColors.label.resolveFrom(context),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '· 일기 데이터는 이 기기(휴대폰)에만 저장\n'
                            '· 앱·데이터 삭제 시에 저장된 일기는 복구 불가',
                            style: GoogleFonts.gaegu(
                              fontSize: 14,
                              height: 1.45,
                              color: CupertinoColors.secondaryLabel.resolveFrom(context),
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
                          '시작하기',
                          style: GoogleFonts.gaegu(
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
    );
  }
}
