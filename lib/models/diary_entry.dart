import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/ai_service.dart';

// build_runner 실행 후 주석 해제 필요
// part 'diary_entry.g.dart';

@HiveType(typeId: 0)
class DiaryEntry extends HiveObject {
  @HiveField(0)
  DateTime date;

  @HiveField(1)
  String content;

  @HiveField(2)
  Map<String, dynamic>? moodAnalysisData; // MoodAnalysisResult를 Map으로 저장

  @HiveField(3)
  DateTime createdAt;

  @HiveField(4)
  DateTime updatedAt;

  DiaryEntry({
    required this.date,
    required this.content,
    MoodAnalysisResult? moodAnalysis,
    required this.createdAt,
    required this.updatedAt,
  }) : moodAnalysisData = moodAnalysis != null
            ? {
                'emotions': moodAnalysis.emotions,
                'advice': moodAnalysis.advice,
                'moodWeights': moodAnalysis.moodWeights,
              }
            : null;

  // MoodAnalysisResult getter
  MoodAnalysisResult? get moodAnalysis {
    if (moodAnalysisData == null) return null;
    return MoodAnalysisResult.fromJson(moodAnalysisData!);
  }

  // Firestore 데이터에서 변환
  factory DiaryEntry.fromFirestore(Map<String, dynamic> data, String dateStr) {
    final date = (data['date'] as Timestamp).toDate();
    MoodAnalysisResult? moodAnalysis;
    
    if (data['moodAnalysis'] != null) {
      final moodData = data['moodAnalysis'] as Map<String, dynamic>;
      moodAnalysis = MoodAnalysisResult.fromJson(moodData);
    }

    return DiaryEntry(
      date: date,
      content: data['content'] ?? '',
      moodAnalysis: moodAnalysis,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Hive에서 직접 생성 (Map 데이터 사용)
  factory DiaryEntry.fromMap({
    required DateTime date,
    required String content,
    Map<String, dynamic>? moodAnalysisData,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    final entry = DiaryEntry(
      date: date,
      content: content,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
    entry.moodAnalysisData = moodAnalysisData;
    return entry;
  }

  // Firestore 형식으로 변환
  Map<String, dynamic> toFirestore() {
    return {
      'date': Timestamp.fromDate(date),
      'content': content,
      'moodAnalysis': moodAnalysis != null
          ? {
              'emotions': moodAnalysis!.emotions,
              'moodWeights': moodAnalysis!.moodWeights,
              'advice': moodAnalysis!.advice,
            }
          : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // Hive Map 형식으로 변환 (TypeAdapter 없이 사용)
  Map<String, dynamic> toHiveMap() {
    return {
      'date': date.toIso8601String(),
      'content': content,
      'moodAnalysisData': moodAnalysisData,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // Hive Map에서 DiaryEntry 생성
  factory DiaryEntry.fromHiveMap(Map<String, dynamic> map) {
    // 중첩된 Map도 안전하게 변환
    Map<String, dynamic>? moodAnalysisData;
    if (map['moodAnalysisData'] != null) {
      // _Map<dynamic, dynamic> 타입도 처리 가능하도록 변환
      final rawData = map['moodAnalysisData'];
      if (rawData is Map) {
        moodAnalysisData = rawData.cast<String, dynamic>();
      } else if (rawData is Map<String, dynamic>) {
        moodAnalysisData = rawData;
      }
    }
    
    return DiaryEntry(
      date: DateTime.parse(map['date'] as String),
      content: map['content'] as String,
      moodAnalysis: moodAnalysisData != null
          ? MoodAnalysisResult.fromJson(moodAnalysisData)
          : null,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}

