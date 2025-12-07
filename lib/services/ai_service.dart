import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';

class MoodAnalysisResult {
  final List<String> emotions; // 감지된 감정 목록 (최대 3개, 순서대로)
  final String advice;
  final Map<String, double> moodWeights; // 감정별 가중치

  MoodAnalysisResult({
    required this.emotions,
    required this.advice,
    required this.moodWeights,
  });

  factory MoodAnalysisResult.fromJson(Map<String, dynamic> json) {
    return MoodAnalysisResult(
      emotions: List<String>.from(json['emotions'] as List),
      advice: json['advice'] as String,
      moodWeights: Map<String, double>.from(json['moodWeights'] as Map),
    );
  }
}

class AIService {
  static GenerativeModel? _model;
  static bool _initialized = false;
  static String? _apiKey;

  /// API 키 설정 및 모델 초기화
  static void setApiKey(String apiKey) {
    _apiKey = apiKey;
    _initialized = false; // API 키 변경 시 재초기화 필요
  }

  /// 모델 초기화 (voicetales 방식과 동일)
  static Future<void> _ensureInitialized() async {
    if (_initialized && _model != null) return;
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('API 키가 설정되지 않았습니다.');
    }

    // 지원되는 모델 목록 (우선순위 순) - voicetales와 동일
    List<String> supportedModels = [
      'gemini-2.5-flash-lite', // 기본 모델 - 빠르고 효율적
      'gemini-2.5-flash', // 대체 모델 - 더 높은 성능
      'gemini-pro', // 백업 모델 - 안정성
    ];

    for (String modelName in supportedModels) {
      try {
        print('🔵 AI 모델 시도: $modelName');

        // GenerationConfig 설정
        final config = GenerationConfig(
          temperature: 0.7,
          topK: modelName.contains('2.5') ? 64 : 40,
          topP: 0.95,
          maxOutputTokens: 8192,
        );

        _model = GenerativeModel(
          model: modelName,
          apiKey: _apiKey!,
          generationConfig: config,
        );

        // 모델 테스트를 위한 간단한 요청
        await _model!.generateContent([Content.text('test')]);

        _initialized = true;
        print('✅ AI Service 초기화 완료 (모델: $modelName)');
        return;
      } catch (e) {
        print('⚠️ 모델 $modelName 초기화 실패: $e');
        continue;
      }
    }

    throw Exception('지원되는 AI 모델을 찾을 수 없습니다. API 키를 확인해주세요.');
  }

  /// 기간별 감정 변화를 분석하여 조언 제공
  Future<String> analyzeMoodPeriod(Map<String, String> emotionMap) async {
    try {
      await _ensureInitialized();
      if (_model == null) {
        return '감정 분석 데이터가 부족합니다.';
      }

      final prompt = _buildPeriodAnalysisPrompt(emotionMap);
      print('🔵 기간별 감정 분석 API 호출 시작...');

      final response = await _model!.generateContent([Content.text(prompt)]);

      if (response.text != null && response.text!.isNotEmpty) {
        String advice = response.text!;
        print('✅ 기간별 분석 조언 받음');
        return advice.trim();
      } else {
        return '데이터를 분석할 수 없습니다.';
      }
    } catch (e) {
      print('❌ 기간별 분석 중 오류: $e');
      return '분석 중 문제가 발생했습니다.';
    }
  }

  /// 일기를 분석하여 감정 상태를 파악
  Future<MoodAnalysisResult?> analyzeDiary(String diaryContent) async {
    try {
      await _ensureInitialized();
      if (_model == null) {
        print('⚠️ API 키가 설정되지 않았습니다. setApiKey()를 먼저 호출하세요.');
        return _getDefaultAnalysis();
      }

      final prompt = _buildPrompt(diaryContent);
      print('🔵 Gemini API 호출 시작...');

      final response = await _model!.generateContent([Content.text(prompt)]);

      if (response.text == null || response.text!.isEmpty) {
        print('⚠️ 응답이 비어있습니다');
        return _getDefaultAnalysis();
      }

      final generatedText = response.text!;
      print(
          '✅ AI 응답 받음: ${generatedText.substring(0, generatedText.length > 100 ? 100 : generatedText.length)}...');

      // JSON 파싱 시도
      try {
        final jsonMatch =
            RegExp(r'\{.*\}', dotAll: true).firstMatch(generatedText);
        if (jsonMatch != null) {
          final jsonStr = jsonMatch.group(0)!;
          final resultJson = jsonDecode(jsonStr) as Map<String, dynamic>;
          print('✅ JSON 파싱 성공');
          return MoodAnalysisResult.fromJson(resultJson);
        }
      } catch (e) {
        print('⚠️ JSON 파싱 실패: $e');
      }

      // 파싱 실패 시 텍스트 분석 반환
      print('📝 텍스트 기반 분석으로 전환');
      return _parseTextResponse(generatedText);
    } catch (e, stackTrace) {
      print('❌ AI 분석 중 오류 발생: $e');
      print('스택 트레이스: $stackTrace');
      return _getDefaultAnalysis();
    }
  }

  /// 기간별 감정 변화 분석 프롬프트 작성
  String _buildPeriodAnalysisPrompt(Map<String, String> emotionMap) {
    // 감정을 사분면별로 분류
    Map<String, List<String>> quadrantEmotions = {
      '노란색 (1분면)': [], // 높은 에너지 + 높은 쾌적함
      '빨간색 (2분면)': [], // 높은 에너지 + 낮은 쾌적함
      '파란색 (3분면)': [], // 낮은 에너지 + 낮은 쾌적함
      '녹색 (4분면)': [], // 낮은 에너지 + 높은 쾌적함
    };

    emotionMap.forEach((date, emotion) {
      // 사분면 판단 (간단한 감정 키워드 기반)
      if (['행복한', '희망찬', '신나는', '긍정적인', '활발한', '동기부여된', '자랑스러운']
          .contains(emotion)) {
        quadrantEmotions['노란색 (1분면)']!.add('$date: $emotion');
      } else if (['화난', '걱정', '불안한', '스트레스', '초조한'].contains(emotion)) {
        quadrantEmotions['빨간색 (2분면)']!.add('$date: $emotion');
      } else if (['슬픈', '우울한', '실망', '피곤한', '좌절한'].contains(emotion)) {
        quadrantEmotions['파란색 (3분면)']!.add('$date: $emotion');
      } else if (['평온한', '편안한', '만족', '감사', '차분한'].contains(emotion)) {
        quadrantEmotions['녹색 (4분면)']!.add('$date: $emotion');
      }
    });

    return '''
당신은 심리상담 전문가입니다. 사용자의 기간별 감정 변화를 분석하여 조언을 제공해주세요.

[분석 데이터]
총 일기 작성일: ${emotionMap.length}일

사분면별 감정 분포:
1. 노란색 사분면 (높은 에너지 + 높은 쾌적함): ${quadrantEmotions['노란색 (1분면)']!.length}건
   ${quadrantEmotions['노란색 (1분면)']!.isNotEmpty ? quadrantEmotions['노란색 (1분면)']!.take(3).join(', ') : '없음'}

2. 빨간색 사분면 (높은 에너지 + 낮은 쾌적함): ${quadrantEmotions['빨간색 (2분면)']!.length}건
   ${quadrantEmotions['빨간색 (2분면)']!.isNotEmpty ? quadrantEmotions['빨간색 (2분면)']!.take(3).join(', ') : '없음'}

3. 파란색 사분면 (낮은 에너지 + 낮은 쾌적함): ${quadrantEmotions['파란색 (3분면)']!.length}건
   ${quadrantEmotions['파란색 (3분면)']!.isNotEmpty ? quadrantEmotions['파란색 (3분면)']!.take(3).join(', ') : '없음'}

4. 녹색 사분면 (낮은 에너지 + 높은 쾌적함): ${quadrantEmotions['녹색 (4분면)']!.length}건
   ${quadrantEmotions['녹색 (4분면)']!.isNotEmpty ? quadrantEmotions['녹색 (4분면)']!.take(3).join(', ') : '없음'}

[분석 지침]
1. 1분면(노란색)과 4분면(녹색)의 비율이 높으면 긍정적 감정이 많은 것으로 보이며, 축하와 격려 조언
2. 2분면(빨간색)이나 3분면(파란색)의 비율이 높으면 스트레스나 우울감이 많은 것으로 보이며, 휴식과 자기돌봄 조언
3. 1,4분면에서 2,3분면으로 감정이 변화한 경우, 최근 좋지 않은 일이 있었는지 물어보고 지지 조언
4. 반대로 2,3분면에서 1,4분면으로 개선된 경우, 긍정적 변화를 칭찬하고 격려
5. 특정 사분면에 지속적으로 머물러 있다면, 삶의 균형을 위한 조언

[출력 형식]
심리상담사 입장에서 따뜻하고 친근한 어조로, 150자 내외의 한국어 조언을 작성해주세요.
단순한 위로가 아닌, 구체적이고 건설적인 조언을 제시해주세요.

예시:
"이 기간 동안 긍정적인 감정이 많았네요! 활기찬 에너지를 유지하고 계시는 것 같아요. 하지만 가끔씩 쌓인 피로를 풀 수 있는 여유 시간을 갖는 것도 중요해요. 연속으로 긍정적인 감정을 느끼는 것은 좋지만, 휴식은 에너지를 충전하는 필수 과정이에요."
''';
  }

  /// Marc Brackett의 Mood Meter 기반 프롬프트 작성
  String _buildPrompt(String diaryContent) {
    return '''
당신은 감정 분석 전문 AI입니다. Marc Brackett의 Mood Meter 이론을 기반으로 사용자의 일기 내용을 분석해주세요.

[Mood Meter - 감정 및 색상]
사용 가능한 감정 목록 (정확히 이 단어들만 사용):

빨강 계열:
1. 격분한, 격노한, 화가 치밀어 오른, 불안한, 불쾌한 (진빨강)
2. 공황에 빠진, 몸시 화가 난, 겁먹은, 우려하는, 골치 아픈 (빨강)
3. 스트레스 받는, 좌절한, 화난, 근심하는, 염려하는 (오렌지레드)
4. 초조한, 신경이 날카로운, 짜증나는, 마음이 불편한 (진오렌지)
5. 충격받은, 망연자실한, 안정부절못하는, 거슬리는, 언짢은 (오렌지)

노랑 계열:
6. 놀란, 들뜬, 기운이 넘치는, 만족스러운, 유쾌한 (연노랑)
7. 긍정적인, 쾌활한, 활발한, 행복한, 기쁜 (노랑)
8. 흥겨운, 동기 부여된, 흥분한, 집중하는 (노랑-주황)
9. 아주 신나는, 영감을 받은, 낙관적인, 재미있는 (진주황)
10. 황홀한, 의기양양한, 열광하는, 짜릿한, 더없이 행복한 (노랑-오렌지)

초록 계열:
11. 속 편한, 평온한, 여유로운, 한가로운, 나른한 (연연두)
12. 태평한, 안전한, 차분한, 생각에 잠긴, 흐뭇한 (연두)
13. 자족하는, 편안한, 평화로운, 고요한 (초록-연두)
14. 다정한, 감사하는, 축복받은, 편한 (연초록)
15. 충만한, 감동적인, 안정적인, 근심 걱정 없는, 안온한 (초록)

파랑 계열:
16. 역겨운 (진파랑)
17. 침울한, 사무룩한 (파랑)
18. 실망스러운, 낙담한 (중간파랑)
19. 의욕 없는, 슬픈 (청색)
20. 냉담한, 지루한, 기죽은, 피곤한, 지친, 우울한, 소외된, 쓸쓸한, 비관적인, 의기소침한, 절망한, 비참한, 가망 없는, 고독한, 뚱한, 기진맥진한, 소모된, 진이 빠진 (연청색)

일기 내용:
"$diaryContent"

다음 JSON 형식으로 응답해주세요:
{
  "emotions": ["감정1", "감정2", "감정3"],
  "moodWeights": {
    "감정1": 0.0~1.0 사이의 숫자,
    "감정2": 0.0~1.0 사이의 숫자,
    "감정3": 0.0~1.0 사이의 숫자
  },
  "advice": "심리상담사 입장에서 100자 내외로 가볍고 따뜻한 조언 (한국어로)"
}

규칙:
1. 위 목록에 있는 감정 단어만 정확히 사용 (절대 변형하거나 새로운 단어 생성 금지)
2. 감정 3개를 선택하여 배열로 제공
3. moodWeights는 각 감정의 가중치 (합은 1.0)
4. advice는 감정을 인정하고 희망적이고 건설적인 조언을 한국어로 작성
5. JSON 형식만 반환
''';
  }

  /// 텍스트 응답을 파싱 (JSON 파싱 실패 시)
  MoodAnalysisResult _parseTextResponse(String text) {
    // 간단한 키워드 기반 분석 - Mood Meter 구조로 변환
    final highEnergyKeywords = [
      '행복',
      '기쁨',
      '좋',
      '감사',
      '즐거',
      '희망',
      '성공',
      '사랑',
      '만족',
      '화',
      '걱정',
      '불안',
      '스트레스'
    ];
    final pleasantKeywords = [
      '행복',
      '기쁨',
      '좋',
      '감사',
      '즐거',
      '희망',
      '성공',
      '사랑',
      '만족'
    ];
    final unpleasantKeywords = [
      '슬',
      '우울',
      '화',
      '걱정',
      '불안',
      '힘들',
      '어렵',
      '스트레스',
      '실망'
    ];

    int highEnergyCount = 0;
    int pleasantCount = 0;
    int unpleasantCount = 0;

    for (final keyword in highEnergyKeywords) {
      if (text.contains(keyword)) highEnergyCount++;
    }
    for (final keyword in pleasantKeywords) {
      if (text.contains(keyword)) pleasantCount++;
    }
    for (final keyword in unpleasantKeywords) {
      if (text.contains(keyword)) unpleasantCount++;
    }

    // 감정 결정 (Mood Meter 정식 용어만 사용)
    List<String> emotions;
    Map<String, double> moodWeights;

    if (pleasantCount > unpleasantCount && highEnergyCount > 0) {
      emotions = ['행복한', '긍정적인', '활발한'];
      moodWeights = {'행복한': 0.5, '긍정적인': 0.3, '활발한': 0.2};
    } else if (pleasantCount <= unpleasantCount && highEnergyCount > 0) {
      emotions = ['불안한', '스트레스 받는', '초조한'];
      moodWeights = {'불안한': 0.5, '스트레스 받는': 0.3, '초조한': 0.2};
    } else if (pleasantCount <= unpleasantCount && highEnergyCount == 0) {
      emotions = ['슬픈', '우울한', '피곤한'];
      moodWeights = {'슬픈': 0.5, '우울한': 0.3, '피곤한': 0.2};
    } else {
      emotions = ['평온한', '편안한', '충만한'];
      moodWeights = {'평온한': 0.5, '편안한': 0.3, '충만한': 0.2};
    }

    return MoodAnalysisResult(
      emotions: emotions,
      advice: '오늘 하루도 수고하셨어요. 작은 감정의 변화도 소중합니다. 내일을 위해 충분히 휴식하세요.',
      moodWeights: moodWeights,
    );
  }

  /// 기본 분석 결과 반환 (API 호출 실패 시)
  MoodAnalysisResult _getDefaultAnalysis() {
    return MoodAnalysisResult(
      emotions: ['평온한', '편안한', '충만한'],
      advice: '오늘 하루는 어떠셨나요? 작은 감정의 변화도 소중합니다. 내일을 위해 충분히 휴식하세요.',
      moodWeights: {
        '평온한': 0.4,
        '편안한': 0.3,
        '충만한': 0.3,
      },
    );
  }
}
