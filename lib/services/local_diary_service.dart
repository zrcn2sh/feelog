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
        // Box가 이미 열려있는지 확인
        if (_diaryBox != null && _diaryBox!.isOpen) {
          print('📦 일기 Box가 이미 열려있음: $diaryBoxName');
          print('📊 현재 Box 키 개수: ${_diaryBox!.length}');
          print('✅ 기존 Box 재사용 (새로 열지 않음)');
        } else {
          // Box가 이미 존재하는지 확인
          final boxExists = await Hive.boxExists(diaryBoxName);
          if (boxExists) {
            print('📦 기존 Box 발견: $diaryBoxName');
            _diaryBox = await Hive.openBox<Map>(diaryBoxName);
            final keyCount = _diaryBox!.length;
            print('📊 기존 Box 키 개수: $keyCount');
            if (keyCount > 0) {
              print('📝 기존 데이터가 있습니다. 데이터 보존 중...');
            }
            print('✅ 기존 일기 Box 열기 완료 (데이터 보존)');
          } else {
            print('📦 새 Box 생성: $diaryBoxName');
            _diaryBox = await Hive.openBox<Map>(diaryBoxName);
            print('✅ 새 일기 Box 생성 완료');
          }
        }
      } catch (e) {
        print('❌ 일기 Box 열기 실패: $e');
        // 기존 Box가 손상되었을 수 있므로 삭제 후 재시도
        // Box가 실제로 손상되었는지 확인 (특정 오류만 재시도)
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('corrupt') || errorStr.contains('invalid') || errorStr.contains('lock')) {
          print('⚠️ Box 손상 감지 (corrupt/invalid/lock), 삭제 후 재시도...');
          try {
            if (await Hive.boxExists(diaryBoxName)) {
              await Hive.deleteBoxFromDisk(diaryBoxName);
              print('✅ 손상된 Box 삭제 완료');
            }
            _diaryBox = await Hive.openBox<Map>(diaryBoxName);
            print('✅ 일기 Box 재생성 완료');
          } catch (e2) {
            print('❌ Box 재생성 실패: $e2');
            rethrow;
          }
        } else {
          // 일반적인 오류는 그대로 전파 (데이터 삭제 방지)
          print('⚠️ 예상치 못한 오류로 Box 열기 실패. 데이터를 보존하기 위해 오류를 그대로 전파합니다.');
          rethrow;
        }
      }

      try {
        // Box가 이미 열려있는지 확인
        if (_analysisBox != null && _analysisBox!.isOpen) {
          print('📦 분석 Box가 이미 열려있음: $analysisBoxName');
          print('✅ 기존 분석 Box 재사용 (새로 열지 않음)');
        } else {
          // Box가 이미 존재하는지 확인
          final analysisBoxExists = await Hive.boxExists(analysisBoxName);
          if (analysisBoxExists) {
            print('📦 기존 분석 Box 발견: $analysisBoxName');
            _analysisBox = await Hive.openBox(analysisBoxName);
            print('✅ 기존 분석 Box 열기 완료 (데이터 보존)');
          } else {
            print('📦 새 분석 Box 생성: $analysisBoxName');
            _analysisBox = await Hive.openBox(analysisBoxName);
            print('✅ 새 분석 Box 생성 완료');
          }
        }
      } catch (e) {
        print('❌ 분석 Box 열기 실패: $e');
        // 분석 Box는 필수가 아니므로 손상된 경우에만 삭제 후 재시도
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('corrupt') || errorStr.contains('invalid')) {
          print('⚠️ 분석 Box 손상 감지, 삭제 후 재시도...');
          try {
            if (await Hive.boxExists(analysisBoxName)) {
              await Hive.deleteBoxFromDisk(analysisBoxName);
              print('✅ 손상된 분석 Box 삭제 완료');
            }
            _analysisBox = await Hive.openBox(analysisBoxName);
            print('✅ 분석 Box 재생성 완료');
          } catch (e2) {
            print('❌ 분석 Box 재생성 실패: $e2');
            // 분석 Box는 필수가 아니므로 경고만 표시하고 계속 진행
            print('⚠️ 분석 Box 생성 실패했지만 계속 진행합니다.');
          }
        } else {
          // 일반적인 오류는 경고만 표시 (분석 Box는 필수 아님)
          print('⚠️ 분석 Box 열기 실패했지만 계속 진행합니다.');
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
    print('═══════════════════════════════════════');
    print('📖 일기 로드 시작: $dateStr');
    
    if (kIsWeb) {
      print('⚠️ 웹 환경 - null 반환');
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

    print('📦 Box에서 데이터 조회 중...');
    print('📊 Box의 총 키 개수: ${_diaryBox!.length}');
    
    // 실제 키들을 확인 (타입 포함)
    final allRawKeys = _diaryBox!.keys.toList();
    print('📋 Box의 모든 키 (원본): $allRawKeys');
    print('📋 Box의 모든 키 (String 변환): ${allRawKeys.map((k) => k.toString()).toList()}');
    print('🔍 찾고자 하는 키: "$dateStr" (타입: String)');
    
    // 먼저 정확한 키로 조회
    var mapData = _diaryBox!.get(dateStr);
    
    // 정확한 키로 찾지 못한 경우, 모든 키와 비교
    if (mapData == null) {
      print('⚠️ 정확한 키로 찾지 못함. 모든 키와 비교 중...');
      for (final key in allRawKeys) {
        final keyStr = key.toString();
        print('   - 비교: "$keyStr" (타입: ${key.runtimeType}) vs "$dateStr"');
        if (keyStr == dateStr || key.toString() == dateStr) {
          print('   ✅ 일치하는 키 발견: $key');
          mapData = _diaryBox!.get(key);
          break;
        }
      }
    }
    if (mapData == null) {
      print('⚠️ 해당 날짜($dateStr)의 데이터를 찾을 수 없습니다.');
      print('═══════════════════════════════════════');
      return null;
    }

    print('✅ 데이터 발견: $dateStr');
    print('📦 mapData 타입: ${mapData.runtimeType}');
    print('📦 mapData 내용: $mapData');

    try {
      // Map에서 DiaryEntry로 변환 (안전한 타입 변환)
      // Hive에서 가져온 Map은 _Map<dynamic, dynamic> 타입일 수 있으므로 cast 사용
      final safeMap = (mapData).cast<String, dynamic>();
      print('✅ Map 변환 완료');
      
      final entry = DiaryEntry.fromHiveMap(safeMap);
      print('✅ DiaryEntry 생성 완료');
      print('   - date: ${entry.date}');
      print('   - content 길이: ${entry.content.length}자');
      print('   - moodAnalysis: ${entry.moodAnalysis != null ? "있음" : "없음"}');
      print('═══════════════════════════════════════');
      return entry;
    } catch (e, stackTrace) {
      print('❌ 일기 로드 중 오류: $e');
      print('스택 트레이스: $stackTrace');
      print('mapData 타입: ${mapData.runtimeType}');
      print('mapData 내용: $mapData');
      print('═══════════════════════════════════════');
      return null;
    }
  }

  /// Hive 초기화 상태 확인
  static bool isInitialized() {
    return _initialized && _diaryBox != null;
  }

  /// 현재 초기화된 사용자 ID 반환
  static String? getCurrentUserId() {
    return _currentUserId;
  }

  /// 특정 사용자로 초기화되어 있는지 확인
  static bool isInitializedForUser(String userId) {
    return _initialized && _currentUserId == userId && _diaryBox != null;
  }

  /// 모든 일기 날짜 가져오기 (실제 데이터가 있는 키만 반환)
  static Set<String> getAllDiaryDates() {
    print('📅 getAllDiaryDates 호출');
    print('   - kIsWeb: $kIsWeb');
    print('   - _initialized: $_initialized');
    print('   - _diaryBox: ${_diaryBox != null ? "존재" : "null"}');
    
    if (kIsWeb || !_initialized || _diaryBox == null) {
      print('⚠️ 조건 불만족 - 빈 Set 반환');
      return {};
    }

    // 모든 키를 가져와서 실제로 데이터가 있는지 확인
    // 먼저 키 타입 확인 (cast 전에 원본 키 확인)
    final rawKeys = _diaryBox!.keys.toList();
    print('📦 Box의 모든 키 (원본): ${rawKeys.length}개');
    print('   - 원본 키 타입: ${rawKeys.isNotEmpty ? rawKeys[0].runtimeType : "없음"}');
    print('   - 원본 키 목록: $rawKeys');
    
    final allKeys = rawKeys.map((k) => k.toString()).toList();
    print('📦 Box의 모든 키 (String 변환): ${allKeys.length}개');
    print('   - 키 목록: $allKeys');
    
    final validKeys = <String>[];
    // rawKeys와 allKeys를 함께 순회 (원본 키로 데이터 조회, String 키로 반환)
    for (int i = 0; i < rawKeys.length; i++) {
      final rawKey = rawKeys[i];
      final keyStr = allKeys[i];
      try {
        // 원본 키로 데이터 조회
        final mapData = _diaryBox!.get(rawKey);
        if (mapData != null) {
          try {
            // 실제로 DiaryEntry로 변환 가능한지 확인
            final safeMap = mapData.cast<String, dynamic>();
            // 간단한 유효성 검사: 필수 필드가 있는지 확인
            if (safeMap.containsKey('content') && safeMap.containsKey('date')) {
              validKeys.add(keyStr);
              print('✅ 키 "$keyStr" 유효 (원본 타입: ${rawKey.runtimeType})');
            } else {
              print('⚠️ 키 "$keyStr"에 필수 필드가 없습니다: ${safeMap.keys}');
            }
          } catch (e) {
            print('⚠️ 키 "$keyStr"의 데이터가 Map이 아니거나 변환 실패: $e (타입: ${mapData.runtimeType})');
          }
        } else {
          print('⚠️ 키 "$keyStr"의 데이터가 null입니다');
        }
      } catch (e) {
        print('⚠️ 키 "$keyStr" 처리 중 오류: $e');
      }
    }
    
    final result = validKeys.toSet();
    print('✅ 유효한 날짜 목록 반환: ${result.length}개 (전체 ${allKeys.length}개 중)');
    print('   - 유효한 날짜들: ${result.toList()..sort()}');
    return result;
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
    print('═══════════════════════════════════════');
    print('📅 기간별 일기 조회 시작');
    print('   - 시작 날짜: $startDate');
    print('   - 종료 날짜: $endDate');
    print('   - kIsWeb: $kIsWeb');
    print('   - _initialized: $_initialized');
    print('   - _diaryBox: ${_diaryBox != null ? "존재" : "null"}');
    
    if (kIsWeb || !_initialized || _diaryBox == null) {
      print('⚠️ 조건 불만족 - 빈 리스트 반환');
      return [];
    }

    final entries = <DiaryEntry>[];
    final allKeys = _diaryBox!.keys.toList();
    print('📦 Box의 총 키 개수: ${allKeys.length}');
    
    for (final key in allKeys) {
      try {
        final mapData = _diaryBox!.get(key);
        if (mapData != null) {
          final safeMap = (mapData).cast<String, dynamic>();
          final entry = DiaryEntry.fromHiveMap(safeMap);
          
          // 날짜 범위 확인 (경계값 포함)
          // 날짜 부분만 비교 (시간 제거)
          final entryDateOnly = DateTime(entry.date.year, entry.date.month, entry.date.day);
          final startDateOnly = DateTime(startDate.year, startDate.month, startDate.day);
          final endDateOnly = DateTime(endDate.year, endDate.month, endDate.day);
          
          // startDate <= entryDate <= endDate
          final isAfterOrEqual = entryDateOnly.isAfter(startDateOnly) || 
              (entryDateOnly.year == startDateOnly.year && 
               entryDateOnly.month == startDateOnly.month && 
               entryDateOnly.day == startDateOnly.day);
          final isBeforeOrEqual = entryDateOnly.isBefore(endDateOnly) || 
              (entryDateOnly.year == endDateOnly.year && 
               entryDateOnly.month == endDateOnly.month && 
               entryDateOnly.day == endDateOnly.day);
          final isInRange = isAfterOrEqual && isBeforeOrEqual;
          
          if (isInRange) {
            entries.add(entry);
            print('   ✅ 포함: ${entry.date} (키: $key)');
          } else {
            print('   ❌ 제외: ${entry.date} (범위: $startDateOnly ~ $endDateOnly)');
          }
        }
      } catch (e, stackTrace) {
        print('⚠️ 일기 로드 오류 ($key): $e');
        print('스택 트레이스: $stackTrace');
      }
    }
    
    entries.sort((a, b) => a.date.compareTo(b.date));
    print('✅ 기간별 일기 조회 완료: ${entries.length}개');
    print('═══════════════════════════════════════');
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
    print('📊 기간별 분석 결과 로드: $periodKey');
    print('   - kIsWeb: $kIsWeb');
    print('   - _initialized: $_initialized');
    print('   - _analysisBox: ${_analysisBox != null ? "존재" : "null"}');
    
    if (kIsWeb || !_initialized || _analysisBox == null) {
      print('⚠️ 조건 불만족 - null 반환');
      return null;
    }

    try {
      final data = _analysisBox!.get(periodKey);
      if (data == null) {
        print('⚠️ 분석 결과 없음: $periodKey');
        return null;
      }
      
      // _Map<dynamic, dynamic> 타입 처리
      if (data is Map) {
        final result = data.cast<String, dynamic>();
        print('✅ 분석 결과 로드 완료: $periodKey');
        return result;
      } else if (data is Map<String, dynamic>) {
        print('✅ 분석 결과 로드 완료: $periodKey');
        return data;
      } else {
        print('⚠️ 예상치 못한 데이터 타입: ${data.runtimeType}');
        return null;
      }
    } catch (e, stackTrace) {
      print('❌ 분석 결과 로드 오류: $e');
      print('스택 트레이스: $stackTrace');
      return null;
    }
  }

  /// Box 닫기
  static Future<void> close() async {
    if (kIsWeb) return;

    await _diaryBox?.close();
    await _analysisBox?.close();
    _initialized = false;
  }
}
