import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 앱 버전 정보 (버전은 pubspec.yaml의 version과 동기화됨)
class AppVersion {
  /// 현재 버전 (앱 시작 시 init()에서 pubspec.yaml 기준으로 설정, 실패 시 fallbackVersion)
  static String version = fallbackVersion;

  /// 플러그인 미지원 환경(웹 디버그 등)에서 사용할 폴백 버전
  static const String fallbackVersion = '1.2.4';

  /// 개발자명
  static const String developer = 'Nat-dwi @idosquare';

  /// pubspec.yaml의 version을 읽어와 설정. main()에서 앱 시작 시 한 번 호출.
  /// MissingPluginException 등으로 실패하면 fallbackVersion 유지.
  static Future<void> init() async {
    try {
      final info = await PackageInfo.fromPlatform();
      version = info.version;
    } on MissingPluginException catch (_) {
      version = fallbackVersion;
    } on PlatformException catch (_) {
      version = fallbackVersion;
    } catch (_) {
      version = fallbackVersion;
    }
  }
}
