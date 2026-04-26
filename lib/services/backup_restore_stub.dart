import 'package:flutter/cupertino.dart';
import '../config/app_font.dart';

Future<void> exportBackup(BuildContext context) async {
  if (!context.mounted) return;
  showCupertinoDialog(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text('백업', style: appFontText(ctx, fontSize: 18)),
      content: Text(
        '백업은 앱(Android·iOS)에서만 사용할 수 있습니다.',
        style: appFontText(ctx, fontSize: 16),
      ),
      actions: [
        CupertinoDialogAction(child: const Text('확인'), onPressed: () => Navigator.pop(ctx)),
      ],
    ),
  );
}

Future<void> importBackup(BuildContext context) async {
  if (!context.mounted) return;
  showCupertinoDialog(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text('가져오기', style: appFontText(ctx, fontSize: 18)),
      content: Text(
        '가져오기는 앱(Android·iOS)에서만 사용할 수 있습니다.',
        style: appFontText(ctx, fontSize: 16),
      ),
      actions: [
        CupertinoDialogAction(child: const Text('확인'), onPressed: () => Navigator.pop(ctx)),
      ],
    ),
  );
}
