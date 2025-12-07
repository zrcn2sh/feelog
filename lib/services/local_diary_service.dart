import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:hive_flutter/hive_flutter.dart';
import '../models/diary_entry.dart';

class LocalDiaryService {
  static const String _diaryBoxPrefix = 'diaries_';
  static const String _analysisBoxPrefix = 'period_analysis_';
  static Box<Map>? _diaryBox; // Map 형식으로 저장 (TypeAdapter 불필요)
  static Box? _analysisBox;
  static bool _initialized = false;
  static String? _currentUserId; // 현재 사용자 ID
  static bool _hiveFlutterInitialized = false; // Hive.initFlutter() 호출 여부

  /// Hive 초기화 (모바일 앱에서만 사용)
  /// [userId] 현재 로그인한 사용자 ID (필수)
  static Future<void> initialize({String? userId}) async {
    // 플랫폼 감지 (웹이 아니고 Android 또는 iOS인 경우만)
    final bool isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);

    if (!isMobile) {
      print('🌐 웹 환경 또는 모바일이 아님 - Hive 초기화 스킵');
      print('   kIsWeb: $kIsWeb');
      if (!kIsWeb) {
        try {
          print('   Platform.isAndroid: ${Platform.isAndroid}');
          print('   Platform.isIOS: ${Platform.isIOS}');
        } catch (e) {
          print('   Platform 정보 가져오기 실패: $e');
        }
      }
      return;
    }

    if (userId == null || userId.isEmpty) {
      print('⚠️ 사용자 ID가 없어서 Hive 초기화를 스킵합니다.');
      return;
    }

    // 같은 사용자로 이미 초기화된 경우 스킵
    if (_initialized && _currentUserId == userId) {
      print('✅ Hive 이미 초기화됨 (사용자: $userId)');
      return;
    }

    // 다른 사용자로 전환하는 경우 기존 Box 닫기
    if (_initialized && _currentUserId != userId) {
      print('🔄 사용자 변경 감지: $_currentUserId → $userId');
      await close();
    }

    try {
      print('═══════════════════════════════════════');
      print('🔧 Hive 초기화 시작');
      print('🌐 kIsWeb: $kIsWeb');
      print('📱 Platform: ${Platform.isAndroid ? "안드로이드" : "iOS"}');

      // Hive 초기화 (한 번만 호출)
      if (!_hiveFlutterInitialized) {
        await Hive.initFlutter();
        _hiveFlutterInitialized = true;
        print('✅ Hive.initFlutter() 완료');
      } else {
        print('✅ Hive.initFlutter() 이미 초기화됨 - 스킵');
      }

      // TypeAdapter 없이 Map 형식으로 저장하므로 등록 불필요
      print('ℹ️ Map 형식으로 저장하므로 TypeAdapter 등록 불필요');

      // 사용자별 Box 이름 생성
      final diaryBoxName = '$_diaryBoxPrefix$userId';
      final analysisBoxName = '$_analysisBoxPrefix$userId';

      // Box 열기 (Map 형식)
      print('📦 Box 열기 시도...');
      print('   - 사용자 ID: $userId');
      print('   - 일기 Box: $diaryBoxName (Map 형식)');
      print('   - 분석 Box: $analysisBoxName');

      try {
        _diaryBox = await Hive.openBox<Map>(diaryBoxName);
        print('✅ 일기 Box 열기 완료');
      } catch (e) {
        print('❌ 일기 Box 열기 실패: $e');
        // 기존 Box가 손상되었을 수 있므로 삭제 후 재시도
        print('🔄 기존 Box 삭제 후 재시도...');
        try {
          await Hive.deleteBoxFromDisk(diaryBoxName);
          print('✅ 기존 Box 삭제 완료');
          _diaryBox = await Hive.openBox<Map>(diaryBoxName);
          print('✅ 일기 Box 재생성 완료');
        } catch (e2) {
          print('❌ Box 재생성 실패: $e2');
          rethrow;
        }
      }

      try {
        _analysisBox = await Hive.openBox(analysisBoxName);
        print('✅ 분석 Box 열기 완료');
      } catch (e) {
        print('❌ 분석 Box 열기 실패: $e');
        // 기존 Box가 손상되었을 수 있으므로 삭제 후 재시도
        print('🔄 기존 Box 삭제 후 재시도...');
        try {
          await Hive.deleteBoxFromDisk(analysisBoxName);
          print('✅ 기존 Box 삭제 완료');
          _analysisBox = await Hive.openBox(analysisBoxName);
          print('✅ 분석 Box 재생성 완료');
        } catch (e2) {
          print('❌ Box 재생성 실패: $e2');
          // 분석 Box는 필수가 아니므로 경고만 표시
          print('⚠️ 분석 Box 생성 실패했지만 계속 진행합니다.');
        }
      }

      _currentUserId = userId;
      _initialized = true;
      print('✅ Hive 초기화 완료 (사용자: $userId)');
      print('═══════════════════════════════════════');
    } catch (e, stackTrace) {
      print('❌ Hive 초기화 실패: $e');
      print('스택 트레이스: $stackTrace');
      _initialized = false;
      _diaryBox = null;
      _analysisBox = null;
      rethrow;
    }
  }

  /// 일기 저장
  static Future<void> saveDiary(String dateStr, DiaryEntry entry) async {
    print('═══════════════════════════════════════');
    print('💾 LocalDiaryService.saveDiary 호출');
    print('📅 날짜: $dateStr');
    print('🌐 kIsWeb: $kIsWeb');
    print('✅ _initialized: $_initialized');
    print('📦 _diaryBox: ${_diaryBox != null ? "존재" : "null"}');

    if (kIsWeb) {
      throw Exception('웹에서는 Hive를 사용할 수 없습니다.');
    }

    if (!_initialized) {
      print('⚠️ Hive가 초기화되지 않았습니다. 자동 초기화 시도...');
      try {
        await initialize();
        print('✅ 자동 초기화 완료');
      } catch (e) {
        print('❌ 자동 초기화 실패: $e');
        throw Exception('로컬 저장소가 초기화되지 않았습니다. Hive 초기화를 먼저 실행하세요.');
      }
    }

    if (_diaryBox == null) {
      print('❌ _diaryBox가 null입니다.');
      throw Exception('일기 저장소 Box가 열리지 않았습니다.');
    }

    try {
      print('📝 DiaryEntry를 Map으로 변환하여 저장 시도...');
      print('   - date: ${entry.date}');
      print('   - content 길이: ${entry.content.length}자');
      print(
          '   - moodAnalysisData: ${entry.moodAnalysisData != null ? "있음" : "없음"}');

      // DiaryEntry를 Map으로 변환하여 저장
      final mapData = entry.toHiveMap();
      await _diaryBox!.put(dateStr, mapData);
      print('✅ Hive Box에 저장 완료 (Map 형식)');

      // 저장 확인
      final saved = _diaryBox!.get(dateStr);
      if (saved != null) {
        print('✅ 저장 확인 성공');
      } else {
        print('⚠️ 저장 확인 실패 - 저장된 데이터를 찾을 수 없습니다');
      }
    } catch (e, stackTrace) {
      print('❌ Hive 저장 중 오류 발생: $e');
      print('스택 트레이스: $stackTrace');
      rethrow;
    }
    print('═══════════════════════════════════════');
  }

  /// 일기 로드
  static DiaryEntry? loadDiary(String dateStr) {
    if (kIsWeb) {
      return null;
    }

    if (!_initialized) {
      print('⚠️ Hive가 초기화되지 않았습니다. loadDiary는 null 반환');
      return null;
    }

    if (_diaryBox == null) {
      print('⚠️ _diaryBox가 null입니다. loadDiary는 null 반환');
      return null;
    }

    final mapData = _diaryBox!.get(dateStr);
    if (mapData == null) {
      return null;
    }

    try {
      // Map에서 DiaryEntry로 변환 (안전한 타입 변환)
      // Hive에서 가져온 Map은 _Map<dynamic, dynamic> 타입일 수 있으므로 cast 사용
      final safeMap = (mapData).cast<String, dynamic>();
      return DiaryEntry.fromHiveMap(safeMap);
    } catch (e, stackTrace) {
      print('❌ 일기 로드 중 오류: $e');
      print('스택 트레이스: $stackTrace');
      print('mapData 타입: ${mapData.runtimeType}');
      return null;
    }
  }

  /// 모든 일기 날짜 가져오기
  static Set<String> getAllDiaryDates() {
    if (kIsWeb || !_initialized || _diaryBox == null) {
      return {};
    }

    return _diaryBox!.keys.cast<String>().toSet();
  }

  /// 날짜별 주요 감정 가져오기
  static Map<String, String> getDiaryMainEmotions() {
    if (kIsWeb || !_initialized || _diaryBox == null) {
      return {};
    }

    final emotions = <String, String>{};
    for (final key in _diaryBox!.keys) {
      try {
        final mapData = _diaryBox!.get(key);
        if (mapData != null) {
          final safeMap = (mapData).cast<String, dynamic>();
          final entry = DiaryEntry.fromHiveMap(safeMap);
          if (entry.moodAnalysis != null &&
              entry.moodAnalysis!.emotions.isNotEmpty) {
            emotions[key as String] = entry.moodAnalysis!.emotions[0];
          }
        }
      } catch (e) {
        print('⚠️ 감정 로드 오류 ($key): $e');
      }
    }
    return emotions;
  }

  /// 일기 삭제
  static Future<void> deleteDiary(String dateStr) async {
    if (kIsWeb || !_initialized || _diaryBox == null) {
      throw Exception('로컬 저장소가 초기화되지 않았습니다.');
    }

    await _diaryBox!.delete(dateStr);
    print('✅ 일기 삭제 완료: $dateStr');
  }

  /// 기간별 일기 조회
  static List<DiaryEntry> getDiariesByDateRange(
      DateTime startDate, DateTime endDate) {
    if (kIsWeb || !_initialized || _diaryBox == null) {
      return [];
    }

    final entries = <DiaryEntry>[];
    for (final key in _diaryBox!.keys) {
      try {
        final mapData = _diaryBox!.get(key);
        if (mapData != null) {
          final safeMap = (mapData).cast<String, dynamic>();
          final entry = DiaryEntry.fromHiveMap(safeMap);
          if (entry.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
              entry.date.isBefore(endDate.add(const Duration(days: 1)))) {
            entries.add(entry);
          }
        }
      } catch (e) {
        print('⚠️ 일기 로드 오류 ($key): $e');
      }
    }
    entries.sort((a, b) => a.date.compareTo(b.date));
    return entries;
  }

  /// 같은 월/일의 일기 조회
  static List<DiaryEntry> getDiariesByMonthDay(int month, int day) {
    if (kIsWeb || !_initialized || _diaryBox == null) {
      return [];
    }

    final entries = <DiaryEntry>[];
    for (final key in _diaryBox!.keys) {
      try {
        final mapData = _diaryBox!.get(key);
        if (mapData != null) {
          final safeMap = (mapData).cast<String, dynamic>();
          final entry = DiaryEntry.fromHiveMap(safeMap);
          if (entry.date.month == month && entry.date.day == day) {
            entries.add(entry);
          }
        }
      } catch (e) {
        print('⚠️ 일기 로드 오류 ($key): $e');
      }
    }
    entries.sort((a, b) => a.date.year.compareTo(b.date.year));
    return entries;
  }

  /// 기간별 분석 결과 저장
  static Future<void> savePeriodAnalysis(
      String periodKey, Map<String, dynamic> analysisData) async {
    if (kIsWeb || !_initialized || _analysisBox == null) {
      throw Exception('로컬 저장소가 초기화되지 않았습니다.');
    }

    await _analysisBox!.put(periodKey, analysisData);
  }

  /// 기간별 분석 결과 로드
  static Map<String, dynamic>? loadPeriodAnalysis(String periodKey) {
    if (kIsWeb || !_initialized || _analysisBox == null) {
      return null;
    }

    return _analysisBox!.get(periodKey) as Map<String, dynamic>?;
  }

  /// Box 닫기
  static Future<void> close() async {
    if (kIsWeb) return;

    await _diaryBox?.close();
    await _analysisBox?.close();
    _initialized = false;
  }
}
