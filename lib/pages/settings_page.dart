import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import '../config/app_theme.dart';
import '../services/backup_restore_stub.dart'
    if (dart.library.io) '../services/backup_restore_io.dart' as backup;

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, this.onWithdraw});

  /// 계정 탈퇴 시 호출 (홈에서 설정 진입 시에만 전달되어 설정 하단에 표시)
  final VoidCallback? onWithdraw;

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeScope.of(context);
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
          '설정',
          style: GoogleFonts.gaegu(
            fontSize: 19,
            fontWeight: FontWeight.w600,
            color: titleColor,
          ),
        ),
        backgroundColor: CupertinoColors.systemBackground,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Icon(CupertinoIcons.back),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            _buttonRow(
              context,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Text(
                    '화면 모드',
                    style: GoogleFonts.gaegu(fontSize: 17, color: rowTextColor),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CupertinoSlidingSegmentedControl<ThemePreference>(
                      groupValue: theme.preference,
                      thumbColor: CupertinoColors.tertiarySystemFill
                          .resolveFrom(context),
                      children: {
                        ThemePreference.system: _segmentPadding(
                          Text('자동',
                              style: GoogleFonts.gaegu(
                                  fontSize: 13, color: rowTextColor)),
                        ),
                        ThemePreference.light: _segmentPadding(
                          Text('라이트',
                              style: GoogleFonts.gaegu(
                                  fontSize: 13, color: rowTextColor)),
                        ),
                        ThemePreference.dark: _segmentPadding(
                          Text('다크',
                              style: GoogleFonts.gaegu(
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '데이터 옮기기',
                    style: GoogleFonts.gaegu(
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
                              Icon(CupertinoIcons.square_arrow_up,
                                  size: 20, color: CupertinoColors.activeBlue),
                              const SizedBox(width: 6),
                              Text(
                                '백업하여 내보내기',
                                style: GoogleFonts.gaegu(
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
                              Icon(CupertinoIcons.square_arrow_down,
                                  size: 20, color: CupertinoColors.activeBlue),
                              const SizedBox(width: 6),
                              Text(
                                '백업에서 가져오기',
                                style: GoogleFonts.gaegu(
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
                    '폰을 바꿀 때 백업 파일을 저장(이메일, 드라이브)해 두었다가, 새 기기에서 같은 계정으로 로그인한 뒤 가져오기하면 일기를 옮길 수 있습니다.',
                    style: GoogleFonts.gaegu(
                      fontSize: 13,
                      color:
                          CupertinoColors.secondaryLabel.resolveFrom(context),
                    ),
                  ),
                ],
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
                      '계정 탈퇴',
                      style: GoogleFonts.gaegu(
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
}

Widget _buttonRow(BuildContext context,
    {required EdgeInsets padding, required Widget child}) {
  return Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: CupertinoColors.secondarySystemFill.resolveFrom(context),
      borderRadius: BorderRadius.circular(12),
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
