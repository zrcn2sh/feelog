import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Color;
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../config/ad_config.dart';
import '../main.dart';

/// 일기 저장 시 "일기 분석 중" 메시지 + 하단 AdMob 배너 모달
class AnalyzingAdDialog extends StatefulWidget {
  const AnalyzingAdDialog({super.key});

  @override
  State<AnalyzingAdDialog> createState() => _AnalyzingAdDialogState();
}

class _AnalyzingAdDialogState extends State<AnalyzingAdDialog> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  bool _adLoadFailed = false;

  /// 배너 광고 단위 ID (실제 ID는 lib/config/ad_config.dart 에서 설정)
  static String get _bannerAdUnitId {
    if (Platform.isIOS) {
      return AdConfig.bannerAdUnitIdIos;
    }
    return AdConfig.bannerAdUnitIdAndroid;
  }

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    _bannerAd = BannerAd(
      adUnitId: _bannerAdUnitId,
      size: AdSize.mediumRectangle, // 300x250, 정사각형에 가까운 비율
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _isAdLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          // 광고 미표시 원인 확인: Xcode/Android Studio 로그에서 이 메시지 확인
          debugPrint(
            'BannerAd 실패: code=${error.code}, domain=${error.domain}, message=${error.message}. '
            'adUnitId=$_bannerAdUnitId (lib/config/ad_config.dart에서 실제 광고 단위 ID로 교체 필요)',
          );
          ad.dispose();
          if (mounted) setState(() {
            _adLoadFailed = true;
            _bannerAd = null;
          });
        },
      ),
    );
    _bannerAd!.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final textColor = isDark ? CupertinoColors.white : CupertinoColors.label.resolveFrom(context);
    final bgColor = isDark ? const Color(0xFF2C2C2E) : CupertinoColors.systemBackground.resolveFrom(context);

    return Center(
      child: Container(
        width: 360,
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
            SizedBox(
              width: 300,
              height: 250,
              child: _isAdLoaded && _bannerAd != null
                  ? AdWidget(ad: _bannerAd!)
                  : _adLoadFailed
                      ? Center(
                          child: Text(
                            '광고를 불러올 수 없습니다',
                            style: GoogleFonts.gaegu(
                              fontSize: 13,
                              color: CupertinoColors.tertiaryLabel.resolveFrom(context),
                            ),
                          ),
                        )
                      : Container(
                          color: CupertinoColors.systemGrey5.resolveFrom(context),
                          alignment: Alignment.center,
                          child: const CupertinoActivityIndicator(color: AppColors.primary),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
