import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import '../config/app_theme.dart';
import '../config/app_locale.dart';
import '../config/app_font.dart';
import '../config/settings_strings.dart';
import '../main.dart';
import '../services/backup_restore_stub.dart'
    if (dart.library.io) '../services/backup_restore_io.dart' as backup;

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, this.onWithdraw});

  static final Uri _webHelpUri = Uri.parse(
    'https://help.idosquare.co.kr/feelog-diary',
  );

  /// 계정 탈퇴 시 호출 (홈에서 설정 진입 시에만 전달되어 설정 하단에 표시)
  final VoidCallback? onWithdraw;

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeScope.of(context);
    final appFont = AppFontScope.of(context);
    final appLocale = AppLocaleScope.of(context);
    final s = SettingsStrings.forLocale(appLocale.code);
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final titleColor = isDark
        ? CupertinoColors.white
        : CupertinoColors.label.resolveFrom(context);
    final rowTextColor = isDark
        ? CupertinoColors.white
        : CupertinoColors.label.resolveFrom(context);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          s.title,
          style: appFontText(context, 
            fontSize: 19,
            fontWeight: FontWeight.w600,
            color: titleColor,
          ),
        ),
        backgroundColor: CupertinoColors.systemBackground,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF8F4FF), Color(0xFFEFE6FF)],
              ),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: const Color(0xFFE8DFFA), width: 1),
            ),
            child: const Icon(
              CupertinoIcons.back,
              size: 18,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            _languageRow(context, rowTextColor, s),
            const SizedBox(height: 12),
            _buttonRow(
              context,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Text(
                    s.displayMode,
                    style: appFontText(context, fontSize: 17, color: rowTextColor),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CupertinoSlidingSegmentedControl<ThemePreference>(
                      groupValue: theme.preference,
                      thumbColor: CupertinoColors.tertiarySystemFill
                          .resolveFrom(context),
                      children: {
                        ThemePreference.system: _segmentPadding(
                          Text(s.auto,
                              style: appFontText(context, 
                                  fontSize: 13, color: rowTextColor)),
                        ),
                        ThemePreference.light: _segmentPadding(
                          Text(s.light,
                              style: appFontText(context, 
                                  fontSize: 13, color: rowTextColor)),
                        ),
                        ThemePreference.dark: _segmentPadding(
                          Text(s.dark,
                              style: appFontText(context, 
                                  fontSize: 13, color: rowTextColor)),
                        ),
                      },
                      onValueChanged: (v) {
                        if (v != null) theme.setThemePreference(v);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buttonRow(
              context,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Text(
                    s.font,
                    style: appFontText(context, fontSize: 17, color: rowTextColor),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CupertinoSlidingSegmentedControl<AppFontFamily>(
                      groupValue: appFont.family,
                      thumbColor: CupertinoColors.tertiarySystemFill
                          .resolveFrom(context),
                      children: {
                        AppFontFamily.gaegu: _segmentPadding(
                          Text(
                            s.fontOptionCurrent,
                            style: appFontText(context,
                                fontSize: 13, color: rowTextColor),
                          ),
                        ),
                        AppFontFamily.notoSans: _segmentPadding(
                          Text(
                            s.fontOptionNotoSans,
                            style: appFontText(context,
                                fontSize: 13, color: rowTextColor),
                          ),
                        ),
                      },
                      onValueChanged: (v) {
                        if (v != null) appFont.setFamily(v);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buttonRow(
              context,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.dataTransfer,
                    style: appFontText(context, 
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: rowTextColor),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: CupertinoButton(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          onPressed: kIsWeb
                              ? null
                              : () => backup.exportBackup(context),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(CupertinoIcons.square_arrow_up,
                                  size: 20, color: CupertinoColors.activeBlue),
                              const SizedBox(width: 6),
                              Text(
                                s.exportBackup,
                                style: appFontText(context, 
                                    fontSize: 15,
                                    color: CupertinoColors.activeBlue),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: CupertinoButton(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          onPressed: kIsWeb
                              ? null
                              : () => backup.importBackup(context),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(CupertinoIcons.square_arrow_down,
                                  size: 20, color: CupertinoColors.activeBlue),
                              const SizedBox(width: 6),
                              Text(
                                s.importBackup,
                                style: appFontText(context, 
                                    fontSize: 15,
                                    color: CupertinoColors.activeBlue),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    s.backupDescription,
                    style: appFontText(context, 
                      fontSize: 13,
                      color:
                          CupertinoColors.secondaryLabel.resolveFrom(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _openWebHelp(context),
              child: _buttonRow(
                context,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    const Icon(
                      CupertinoIcons.globe,
                      size: 20,
                      color: CupertinoColors.activeBlue,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.webHelp,
                        style: appFontText(context,
                            fontSize: 17, color: rowTextColor),
                      ),
                    ),
                    const Icon(
                      CupertinoIcons.chevron_forward,
                      size: 16,
                      color: CupertinoColors.systemGrey2,
                    ),
                  ],
                ),
              ),
            ),
            if (onWithdraw != null) ...[
              const SizedBox(height: 12),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: onWithdraw,
                child: _buttonRow(
                  context,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Center(
                    child: Text(
                      s.deleteAccount,
                      style: appFontText(context, 
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                        color: CupertinoColors.destructiveRed,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openWebHelp(BuildContext context) async {
    final ok = await launchUrl(
      _webHelpUri,
      mode: LaunchMode.externalApplication,
    );
    if (!ok && context.mounted) {
      await showCupertinoDialog<void>(
        context: context,
        builder: (context) {
          return CupertinoAlertDialog(
            title: const Text('안내'),
            content: const Text('도움말 페이지를 열 수 없습니다.'),
            actions: [
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('확인'),
              ),
            ],
          );
        },
      );
    }
  }
}

Widget _languageRow(
    BuildContext context, Color rowTextColor, SettingsStrings s) {
  final appLocale = AppLocaleScope.of(context);
  return _buttonRow(
    context,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Row(
      children: [
        Text(
          s.language,
          style: appFontText(context, fontSize: 17, color: rowTextColor),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: CupertinoSlidingSegmentedControl<AppLocaleCode>(
            groupValue: appLocale.code,
            thumbColor:
                CupertinoColors.tertiarySystemFill.resolveFrom(context),
            children: {
              AppLocaleCode.ko: _segmentPadding(
                Text(
                  s.languageOptionKo,
                  style: appFontText(context, 
                      fontSize: 13, color: rowTextColor),
                ),
              ),
              AppLocaleCode.en: _segmentPadding(
                Text(
                  s.languageOptionEn,
                  style: appFontText(context, 
                      fontSize: 13, color: rowTextColor),
                ),
              ),
            },
            onValueChanged: (v) {
              if (v != null) appLocale.setLocaleCode(v);
            },
          ),
        ),
      ],
    ),
  );
}

Widget _buttonRow(BuildContext context,
    {required EdgeInsets padding, required Widget child}) {
  final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
  return Container(
    width: double.infinity,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? const [Color(0xFF26262E), Color(0xFF1E1E24)]
            : const [CupertinoColors.white, Color(0xFFF6F2FF)],
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: isDark ? const Color(0xFF33333C) : const Color(0xFFE8E3F6),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: isDark
              ? CupertinoColors.black.withValues(alpha: 0.22)
              : const Color(0x1F000000),
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    padding: padding,
    child: child,
  );
}

Padding _segmentPadding(Widget child) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
    child: child,
  );
}
