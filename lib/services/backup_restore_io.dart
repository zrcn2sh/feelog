import 'dart:convert';
import 'dart:io' show File;
import 'dart:math' show Random;
import 'dart:typed_data' show Uint8List;
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'local_diary_service.dart';

const String _encMagic = 'FEELOG_ENC_V1\n';

Future<void> exportBackup(BuildContext context) async {
  try {
    final data = LocalDiaryService.exportAllData();
    final diaries = data['diaries'] as Map? ?? {};
    final periodAnalysis = data['periodAnalysis'] as Map? ?? {};
    if (diaries.isEmpty && periodAnalysis.isEmpty) {
      if (context.mounted) {
        _showDialog(context, '백업', '내보낼 일기 데이터가 없습니다.');
      }
      return;
    }
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);

    // 암호 설정 (선택)
    final password = await _showPasswordDialog(
      context,
      title: '백업 암호 설정',
      message: '암호를 입력하면 백업 파일이 암호화됩니다.\n비워두면 암호 없이 저장됩니다.',
      hint: '암호 (선택)',
      confirmLabel: '저장',
      optional: true,
    );
    if (!context.mounted) return;

    List<int> bytesToWrite;
    String fileName;
    if (password != null && password.isNotEmpty) {
      bytesToWrite = utf8.encode(_encMagic + _encrypt(jsonStr, password));
      fileName = 'feelog_backup_${_dateSuffix()}.json';
    } else {
      bytesToWrite = utf8.encode(jsonStr);
      fileName = 'feelog_backup_${_dateSuffix()}.json';
    }

    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/$fileName';
    final file = File(path);
    await file.writeAsBytes(bytesToWrite);

    await Share.shareXFiles([XFile(path)], text: 'Feelog 일기 백업');
    if (context.mounted) {
      _showDialog(
        context,
        '백업 완료',
        '일기 ${diaries.length}건, 기간 분석 ${periodAnalysis.length}건을 내보냈습니다.'
            '${password != null && password.isNotEmpty ? '\n(암호로 보호됨)' : ''}',
      );
    }
  } catch (e) {
    if (context.mounted) {
      _showDialog(context, '오류', '백업 중 오류: $e');
    }
  }
}

Future<void> importBackup(BuildContext context) async {
  try {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final platformFile = result.files.single;
    final path = platformFile.path;
    if (path == null || path.isEmpty) {
      if (context.mounted) _showDialog(context, '오류', '파일 경로를 읽을 수 없습니다.');
      return;
    }

    final bytes = await File(path).readAsBytes();
    String jsonStr;
    if (bytes.length >= _encMagic.length &&
        utf8.decode(bytes.sublist(0, _encMagic.length)) == _encMagic) {
      final password = await _showPasswordDialog(
        context,
        title: '백업 암호 입력',
        message: '이 백업 파일은 암호로 보호되어 있습니다.',
        hint: '암호',
        confirmLabel: '확인',
        optional: false,
      );
      if (!context.mounted) return;
      if (password == null || password.isEmpty) {
        if (context.mounted) _showDialog(context, '취소', '암호를 입력해야 가져올 수 있습니다.');
        return;
      }
      try {
        jsonStr = _decrypt(utf8.decode(bytes.sublist(_encMagic.length)), password);
      } catch (_) {
        if (context.mounted) _showDialog(context, '오류', '암호가 맞지 않거나 파일이 손상되었습니다.');
        return;
      }
    } else {
      jsonStr = utf8.decode(bytes);
    }

    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    await LocalDiaryService.importAllData(data);
    final diaries = data['diaries'] as Map? ?? {};
    final periodAnalysis = data['periodAnalysis'] as Map? ?? {};
    if (context.mounted) {
      _showDialog(
        context,
        '가져오기 완료',
        '일기 ${diaries.length}건, 기간 분석 ${periodAnalysis.length}건을 가져왔습니다. 홈으로 돌아가면 반영됩니다.',
      );
    }
  } catch (e) {
    if (context.mounted) {
      _showDialog(context, '오류', '가져오기 중 오류: $e');
    }
  }
}

String _dateSuffix() {
  final now = DateTime.now();
  return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
      '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
}

/// AES-256-CBC: salt(16) + iv(16) + cipher. key/iv from SHA256(salt+password), SHA256(password+salt).
String _encrypt(String plain, String password) {
  final salt = List<int>.generate(16, (_) => Random.secure().nextInt(256));
  final keyBytes = _deriveKey(salt, password);
  final ivBytes = _deriveIv(salt, password);
  final key = enc.Key(Uint8List.fromList(keyBytes));
  final iv = enc.IV(Uint8List.fromList(ivBytes));
  final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
  final encrypted = encrypter.encrypt(plain, iv: iv);
  final combined = [...salt, ...ivBytes, ...encrypted.bytes];
  return base64Encode(combined);
}

String _decrypt(String base64Cipher, String password) {
  final combined = base64Decode(base64Cipher);
  if (combined.length < 16 + 16) throw Exception('invalid payload');
  final salt = combined.sublist(0, 16);
  final ivBytes = combined.sublist(16, 32);
  final cipherBytes = combined.sublist(32).toList();
  final keyBytes = _deriveKey(salt, password);
  final key = enc.Key(Uint8List.fromList(keyBytes));
  final iv = enc.IV(Uint8List.fromList(ivBytes));
  final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
  final encrypted = enc.Encrypted(Uint8List.fromList(cipherBytes));
  return encrypter.decrypt(encrypted, iv: iv);
}

List<int> _deriveKey(List<int> salt, String password) {
  final h = sha256.convert([...salt, ...utf8.encode(password)]);
  return h.bytes.toList();
}

List<int> _deriveIv(List<int> salt, String password) {
  final h = sha256.convert([...utf8.encode(password), ...salt]);
  return h.bytes.sublist(0, 16).toList();
}

Future<String?> _showPasswordDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String hint,
  required String confirmLabel,
  required bool optional,
}) async {
  final controller = TextEditingController();
  final result = await showCupertinoDialog<String?>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(title, style: GoogleFonts.gaegu(fontSize: 18)),
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: GoogleFonts.gaegu(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: controller,
              placeholder: hint,
              obscureText: true,
              style: GoogleFonts.gaegu(fontSize: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6.resolveFrom(ctx),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (optional)
          CupertinoDialogAction(
            child: const Text('건너뛰기'),
            onPressed: () => Navigator.pop(ctx, ''),
          ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result;
}

void _showDialog(BuildContext context, String title, String content) {
  showCupertinoDialog(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(title, style: GoogleFonts.gaegu(fontSize: 18)),
      content: Text(content, style: GoogleFonts.gaegu(fontSize: 16)),
      actions: [
        CupertinoDialogAction(child: const Text('확인'), onPressed: () => Navigator.pop(ctx)),
      ],
    ),
  );
}
