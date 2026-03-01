import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Color;
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../config/ad_config.dart';
import '../config/app_locale.dart';
import '../config/home_strings.dart';
import '../main.dart';

/// 미리 로드한 배너를 보관·제공. 홈에서 preload 후 저장 모달에 전달해 즉시 표시.
class PreloadedBannerHolder {
  PreloadedBannerHolder._();

  static BannerAd? _ad;
  static bool _ready = false;
  static ValueNotifier<bool>? _readyNotifier;

  static BannerAd? get ad => _ad;
  static bool get isReady => _ready;
  static ValueNotifier<bool>? get readyNotifier => _readyNotifier;

  static String get _bannerAdUnitId {
    if (Platform.isIOS) return AdConfig.bannerAdUnitIdIos;
    return AdConfig.bannerAdUnitIdAndroid;
  }

  /// 저장 버튼 누르기 전에 호출해 배너를 미리 로드 (홈 initState 등)
  static void preload() {
    if (_ad != null) return; // 이미 로드 중이거나 완료
    _ready = false;
    _readyNotifier = ValueNotifier<bool>(false);
    _ad = BannerAd(
      adUnitId: _bannerAdUnitId,
      size: AdSize.mediumRectangle,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          _ready = true;
          _readyNotifier?.value = true;
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint(
            'PreloadedBannerHolder 실패: code=${error.code}, message=${error.message}',
          );
          ad.dispose();
          _ad = null;
          _ready = false;
          _readyNotifier?.value = true; // 실패해도 onAdDisplayed는 호출되도록
        },
      ),
    );
    _ad!.load();
  }

  /// 모달을 닫은 뒤 호출: 현재 배너 dispose 후 다음 배너 preload
  static void releaseAndPreloadNext() {
    _ad?.dispose();
    _ad = null;
    _ready = false;
    _readyNotifier = null;
    preload();
  }
}

/// 일기 저장 시 "일기 분석 중" 메시지 + 하단 AdMob 배너 모달
/// [onAdDisplayed] 광고 로드 완료 또는 로드 실패 시 한 번만 호출 (팝업 닫기 타이밍용)
/// [preloadedAd] / [preloadedAdReady] / [preloadedReadyNotifier]: 미리 로드한 배너 사용 시 전달
class AnalyzingAdDialog extends StatefulWidget {
  const AnalyzingAdDialog({
    super.key,
    this.onAdDisplayed,
    this.preloadedAd,
    this.preloadedAdReady = false,
    this.preloadedReadyNotifier,
  });

  final VoidCallback? onAdDisplayed;
  final BannerAd? preloadedAd;
  final bool preloadedAdReady;
  final ValueNotifier<bool>? preloadedReadyNotifier;

  @override
  State<AnalyzingAdDialog> createState() => _AnalyzingAdDialogState();
}

class _AnalyzingAdDialogState extends State<AnalyzingAdDialog> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  bool _adLoadFailed = false;
  /// 미리 로드된 광고를 쓰는 경우 dispose 시 배너를 dispose 하지 않음 (호출자가 처리)
  bool _ownsAd = true;
  bool _onAdDisplayedCalled = false;
  VoidCallback? _notifierListener;

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
    if (widget.preloadedAd != null) {
      _bannerAd = widget.preloadedAd;
      _isAdLoaded = widget.preloadedAdReady;
      _ownsAd = false;
      if (_isAdLoaded) _callOnAdDisplayedOnce();
      widget.preloadedReadyNotifier?.addListener(_onPreloadedReadyChanged);
      _notifierListener = _onPreloadedReadyChanged;
    } else {
      _loadAd();
    }
  }

  void _onPreloadedReadyChanged() {
    if (!mounted || _onAdDisplayedCalled) return;
    final ready = widget.preloadedReadyNotifier?.value ?? false;
    if (ready) {
      setState(() => _isAdLoaded = true);
      _callOnAdDisplayedOnce();
    }
  }

  void _callOnAdDisplayedOnce() {
    if (_onAdDisplayedCalled) return;
    _onAdDisplayedCalled = true;
    widget.onAdDisplayed?.call();
  }

  void _loadAd() {
    _bannerAd = BannerAd(
      adUnitId: _bannerAdUnitId,
      size: AdSize.mediumRectangle, // 300x250, 정사각형에 가까운 비율
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) {
            setState(() => _isAdLoaded = true);
            _callOnAdDisplayedOnce();
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint(
            'BannerAd 실패: code=${error.code}, domain=${error.domain}, message=${error.message}. '
            'adUnitId=$_bannerAdUnitId (lib/config/ad_config.dart에서 실제 광고 단위 ID로 교체 필요)',
          );
          ad.dispose();
          if (mounted) {
            setState(() {
              _adLoadFailed = true;
              _bannerAd = null;
            });
            _callOnAdDisplayedOnce();
          }
        },
      ),
    );
    _bannerAd!.load();
  }

  @override
  void dispose() {
    if (_notifierListener != null) {
      widget.preloadedReadyNotifier?.removeListener(_notifierListener!);
    }
    if (_ownsAd) _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = HomeStrings.forLocale(AppLocaleScope.of(context).code);
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
              s.analyzingDiary,
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
                            s.adLoadFailed,
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
