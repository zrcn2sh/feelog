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
    final emotions = List<String>.from(json['emotions'] as List);
    final moodWeights = Map<String, double>.from(json['moodWeights'] as Map);
    // 비율이 높은 순으로 정렬 → 가장 높은 감정(색상)이 제일 왼쪽에 표시되도록
    emotions.sort((a, b) => (moodWeights[b] ?? 0).compareTo(moodWeights[a] ?? 0));
    return MoodAnalysisResult(
      emotions: emotions,
      advice: json['advice'] as String,
      moodWeights: moodWeights,
    );
  }
}

class AIService {
  static GenerativeModel? _model;
  static bool _initialized = false;
  static String? _apiKey;

  /// 마지막 호출이 API 실패로 기본값(폴백)을 반환했는지
  static bool lastCallUsedFallback = false;

  /// API 키가 실제로 설정되었는지 (플레이스홀더/빈 값 제외)
  static bool get isApiKeyConfigured =>
      _apiKey != null &&
      _apiKey!.trim().isNotEmpty &&
      !_apiKey!.contains('YOUR_GEMINI_API_KEY_HERE');

  /// API 키 설정 및 모델 초기화
  static void setApiKey(String apiKey) {
    // API 키에서 공백 및 줄바꿈 제거
    final trimmedKey = apiKey.trim();

    // API 키 유효성 검사
    if (trimmedKey.isEmpty) {
      print('⚠️ API 키가 비어있습니다.');
      _apiKey = null; // 명시적으로 null 설정
      _initialized = false;
      return;
    }

    if (!trimmedKey.startsWith('AIza')) {
      print(
          '⚠️ API 키 형식이 올바르지 않습니다. (시작: ${trimmedKey.substring(0, trimmedKey.length > 10 ? 10 : trimmedKey.length)})');
      // 경고만 하고 계속 진행 (일부 유효한 키도 있을 수 있음)
    }

    _apiKey = trimmedKey;
    _initialized = false; // API 키 변경 시 재초기화 필요
    print('✅ API 키 설정 완료 (길이: ${_apiKey!.length})');
  }

  /// 모델 초기화
  static Future<void> _ensureInitialized() async {
    if (_initialized && _model != null) return;
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('API 키가 설정되지 않았습니다.');
    }

    // 지원되는 모델 목록 (우선순위 순)
    // Google Generative AI SDK에서 사용 가능한 모델들
    List<String> supportedModels = [
      'gemini-2.0-flash', // 최신 빠른 모델 (권장)
      'gemini-pro', // 안정적인 모델 (백업)
      'gemini-1.5-pro', // 고성능 모델 (백업)
    ];

    for (String modelName in supportedModels) {
      try {
        print('🔵 AI 모델 시도: $modelName');

        // GenerationConfig 설정
        final config = GenerationConfig(
          temperature: 0.7,
          topK: (modelName.contains('1.5') || modelName.contains('2.0'))
              ? 64
              : 40,
          topP: 0.95,
          maxOutputTokens: 8192,
        );

        _model = GenerativeModel(
          model: modelName,
          apiKey: _apiKey!,
          generationConfig: config,
        );

        // 모델 초기화만 수행 (테스트 요청 제거 - 실제 사용 시점에 검증)
        _initialized = true;
        print('✅ AI Service 초기화 완료 (모델: $modelName)');
        return;
      } catch (e) {
        print('⚠️ 모델 $modelName 초기화 실패: $e');
        _initialized = false;
        _model = null;
        continue;
      }
    }

    throw Exception('지원되는 AI 모델을 찾을 수 없습니다. API 키를 확인해주세요.');
  }

  /// 기간별 감정 변화를 분석하여 조언 제공
  /// [languageCode] 'ko' | 'en' - 조언 반환 언어
  Future<String> analyzeMoodPeriod(Map<String, String> emotionMap,
      {String languageCode = 'ko'}) async {
    lastCallUsedFallback = false;
    final isEn = languageCode == 'en';
    try {
      await _ensureInitialized();
      if (_model == null) {
        lastCallUsedFallback = true;
        return isEn
            ? 'Not enough data for analysis. (Check AI API key.)'
            : '감정 분석 데이터가 부족합니다. (AI API 키를 확인해 주세요.)';
      }

      final prompt = _buildPeriodAnalysisPrompt(emotionMap, languageCode);
      print('🔵 기간별 감정 분석 API 호출 시작... (lang: $languageCode)');

      final response = await _model!.generateContent([Content.text(prompt)]);

      if (response.text != null && response.text!.isNotEmpty) {
        String advice = response.text!;
        print('✅ 기간별 분석 조언 받음');
        return advice.trim();
      } else {
        lastCallUsedFallback = true;
        return isEn ? 'Unable to analyze data.' : '데이터를 분석할 수 없습니다.';
      }
    } catch (e) {
      print('❌ 기간별 분석 중 오류: $e');
      lastCallUsedFallback = true;
      return isEn
          ? 'Analysis failed. (Check API key and network.)'
          : '분석 중 문제가 발생했습니다. (API 키 및 네트워크를 확인해 주세요.)';
    }
  }

  /// 일기를 분석하여 감정 상태를 파악
  /// [languageCode] 'ko' | 'en' - 감정 라벨과 조언을 반환할 언어
  Future<MoodAnalysisResult?> analyzeDiary(String diaryContent,
      {String languageCode = 'ko'}) async {
    lastCallUsedFallback = false;
    try {
      await _ensureInitialized();

      if (_model == null) {
        print('⚠️ API 키가 설정되지 않았습니다. setApiKey()를 먼저 호출하세요.');
        lastCallUsedFallback = true;
        return _getDefaultAnalysis(languageCode);
      }

      final prompt = _buildPrompt(diaryContent, languageCode);
      print('🔵 Gemini API 호출 시작... (lang: $languageCode)');

      // API 호출 시도 (실패 시 다른 모델로 재시도)
      try {
        final response = await _model!.generateContent([Content.text(prompt)]);
        return _processResponse(response, languageCode);
      } catch (e) {
        print('⚠️ API 호출 실패, 다른 모델로 재시도: $e');
        // 모델 초기화 상태 리셋
        _initialized = false;
        _model = null;

        // 다른 모델로 재시도
        await _ensureInitialized();
        if (_model == null) {
          print('⚠️ 모든 모델 초기화 실패');
          lastCallUsedFallback = true;
          return _getDefaultAnalysis(languageCode);
        }

        final response = await _model!.generateContent([Content.text(prompt)]);
        return _processResponse(response, languageCode);
      }
    } catch (e, stackTrace) {
      print('❌ AI 분석 중 오류 발생: $e');
      print('스택 트레이스: $stackTrace');
      lastCallUsedFallback = true;
      return _getDefaultAnalysis(languageCode);
    }
  }

  /// API 응답 처리
  MoodAnalysisResult _processResponse(
      GenerateContentResponse response, String languageCode) {
    if (response.text == null || response.text!.isEmpty) {
      print('⚠️ 응답이 비어있습니다');
      return _getDefaultAnalysis(languageCode);
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
    return _parseTextResponse(generatedText, languageCode);
  }

  /// 기간별 감정 변화 분석 프롬프트 작성 (한/영 지원)
  String _buildPeriodAnalysisPrompt(Map<String, String> emotionMap, String languageCode) {
    final isEn = languageCode == 'en';
    // 감정을 사분면별로 분류 (한국어 + 영어 라벨 모두 처리)
    final q1 = <String>[]; // 노란색: 높은 에너지 + 높은 쾌적함
    final q2 = <String>[]; // 빨간색: 높은 에너지 + 낮은 쾌적함
    final q3 = <String>[]; // 파란색: 낮은 에너지 + 낮은 쾌적함
    final q4 = <String>[]; // 녹색: 낮은 에너지 + 높은 쾌적함
    const q1Keywords = [
      '행복한', '희망찬', '신나는', '긍정적인', '활발한', '동기부여된', '동기 부여된', '자랑스러운',
      'Happy', 'Hopeful', 'Excited', 'Content', 'Joyful', 'Proud', 'Grateful', 'Optimistic',
    ];
    const q2Keywords = [
      '화난', '걱정', '불안한', '스트레스', '초조한', '스트레스 받는',
      'Angry', 'Anxious', 'Stressed', 'Worried', 'Nervous', 'Frustrated', 'Irritated',
    ];
    const q3Keywords = [
      '슬픈', '우울한', '실망', '피곤한', '좌절한',
      'Sad', 'Depressed', 'Tired', 'Down', 'Disappointed', 'Lonely', 'Hopeless',
    ];
    const q4Keywords = [
      '평온한', '편안한', '만족', '감사', '차분한', '충만한',
      'Calm', 'Peaceful', 'Relaxed', 'Serene', 'Satisfied', 'Thankful', 'Comfortable',
    ];

    emotionMap.forEach((date, emotion) {
      if (q1Keywords.any((k) => emotion.contains(k))) {
        q1.add('$date: $emotion');
      } else if (q2Keywords.any((k) => emotion.contains(k))) {
        q2.add('$date: $emotion');
      } else if (q3Keywords.any((k) => emotion.contains(k))) {
        q3.add('$date: $emotion');
      } else if (q4Keywords.any((k) => emotion.contains(k))) {
        q4.add('$date: $emotion');
      }
    });

    final noneStr = isEn ? 'none' : '없음';
    if (isEn) {
      return '''
You are a counseling expert. Analyze the user's mood over this period and give advice. Respond in English only.

[Data]
Total diary days: ${emotionMap.length}

Quadrant distribution (Mood Meter):
1. Yellow (high energy, pleasant): ${q1.length} entries
   ${q1.isNotEmpty ? q1.take(3).join(', ') : noneStr}
2. Red (high energy, unpleasant): ${q2.length} entries
   ${q2.isNotEmpty ? q2.take(3).join(', ') : noneStr}
3. Blue (low energy, unpleasant): ${q3.length} entries
   ${q3.isNotEmpty ? q3.take(3).join(', ') : noneStr}
4. Green (low energy, pleasant): ${q4.length} entries
   ${q4.isNotEmpty ? q4.take(3).join(', ') : noneStr}

[Guidelines]
1. More yellow/green: positive period → congratulate and encourage.
2. More red/blue: stress or low mood → suggest rest and self-care.
3. Shift from 1,4 to 2,3: acknowledge and offer support.
4. Shift from 2,3 to 1,4: praise improvement.
5. Stuck in one quadrant: suggest balance.

[Output]
Write warm, friendly advice in English only, about 150 characters. Be specific and constructive, not just comforting.
''';
    }

    return '''
당신은 심리상담 전문가입니다. 사용자의 기간별 감정 변화를 분석하여 조언을 제공해주세요.

[분석 데이터]
총 일기 작성일: ${emotionMap.length}일

사분면별 감정 분포:
1. 노란색 사분면 (높은 에너지 + 높은 쾌적함): ${q1.length}건
   ${q1.isNotEmpty ? q1.take(3).join(', ') : noneStr}

2. 빨간색 사분면 (높은 에너지 + 낮은 쾌적함): ${q2.length}건
   ${q2.isNotEmpty ? q2.take(3).join(', ') : noneStr}

3. 파란색 사분면 (낮은 에너지 + 낮은 쾌적함): ${q3.length}건
   ${q3.isNotEmpty ? q3.take(3).join(', ') : noneStr}

4. 녹색 사분면 (낮은 에너지 + 높은 쾌적함): ${q4.length}건
   ${q4.isNotEmpty ? q4.take(3).join(', ') : noneStr}

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

  /// Marc Brackett의 Mood Meter 기반 프롬프트 작성 (선택 언어에 따라 감정·조언 언어 지정)
  String _buildPrompt(String diaryContent, String languageCode) {
    final isEn = languageCode == 'en';
    if (isEn) {
      return _buildPromptEn(diaryContent);
    }
    return _buildPromptKo(diaryContent);
  }

  String _buildPromptKo(String diaryContent) {
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

  String _buildPromptEn(String diaryContent) {
    return '''
You are an emotion analysis AI. Analyze the user's diary based on Marc Brackett's Mood Meter and respond in English only.

[Mood Meter - Emotions and colors]
Use ONLY these emotion words (no variations):

Red / high energy, unpleasant:
Enraged, Anxious, Stressed, Frustrated, Angry, Worried, Nervous, Irritated, Overwhelmed

Yellow / high energy, pleasant:
Excited, Happy, Joyful, Content, Proud, Grateful, Amused, Hopeful, Optimistic

Green / low energy, pleasant:
Calm, Peaceful, Relaxed, Serene, Satisfied, Thankful, Comfortable, At ease

Blue / low energy, unpleasant:
Sad, Depressed, Disappointed, Bored, Tired, Lonely, Hopeless, Down, Exhausted

Diary content:
"$diaryContent"

Respond with this JSON only:
{
  "emotions": ["emotion1", "emotion2", "emotion3"],
  "moodWeights": {
    "emotion1": number between 0.0 and 1.0,
    "emotion2": number between 0.0 and 1.0,
    "emotion3": number between 0.0 and 1.0
  },
  "advice": "Brief, warm advice in English (about 100 characters) as a counselor, acknowledging their feelings."
}

Rules:
1. Use ONLY the emotion words from the list above.
2. Pick exactly 3 emotions and provide moodWeights (sum = 1.0).
3. Write advice in English only.
4. Return valid JSON only.
''';
  }

  /// 텍스트 응답을 파싱 (JSON 파싱 실패 시) - [languageCode]에 따라 반환 언어 결정
  MoodAnalysisResult _parseTextResponse(String text, String languageCode) {
    final isEn = languageCode == 'en';
    // 키워드: 한글/영어 공통으로 검사 (일기 내용이 어떤 언어일 수 있음)
    final highEnergyKeywords = isEn
        ? ['happy', 'joy', 'good', 'love', 'excited', 'hope', 'success']
        : ['행복', '기쁨', '좋', '감사', '즐거', '희망', '성공', '사랑', '만족', '화', '걱정', '불안', '스트레스'];
    final pleasantKeywords = isEn
        ? ['happy', 'joy', 'good', 'love', 'grateful', 'hope', 'success']
        : ['행복', '기쁨', '좋', '감사', '즐거', '희망', '성공', '사랑', '만족'];
    final unpleasantKeywords = isEn
        ? ['sad', 'angry', 'worried', 'tired', 'stress', 'disappointed']
        : ['슬', '우울', '화', '걱정', '불안', '힘들', '어렵', '스트레스', '실망'];

    int highEnergyCount = 0;
    int pleasantCount = 0;
    int unpleasantCount = 0;
    final lower = text.toLowerCase();

    for (final keyword in highEnergyKeywords) {
      if (lower.contains(keyword.toLowerCase())) highEnergyCount++;
    }
    for (final keyword in pleasantKeywords) {
      if (lower.contains(keyword.toLowerCase())) pleasantCount++;
    }
    for (final keyword in unpleasantKeywords) {
      if (lower.contains(keyword.toLowerCase())) unpleasantCount++;
    }

    if (isEn) {
      List<String> emotions;
      Map<String, double> moodWeights;
      if (pleasantCount > unpleasantCount && highEnergyCount > 0) {
        emotions = ['Happy', 'Content', 'Hopeful'];
        moodWeights = {'Happy': 0.5, 'Content': 0.3, 'Hopeful': 0.2};
      } else if (pleasantCount <= unpleasantCount && highEnergyCount > 0) {
        emotions = ['Anxious', 'Stressed', 'Worried'];
        moodWeights = {'Anxious': 0.5, 'Stressed': 0.3, 'Worried': 0.2};
      } else if (pleasantCount <= unpleasantCount && highEnergyCount == 0) {
        emotions = ['Sad', 'Tired', 'Down'];
        moodWeights = {'Sad': 0.5, 'Tired': 0.3, 'Down': 0.2};
      } else {
        emotions = ['Calm', 'Peaceful', 'Relaxed'];
        moodWeights = {'Calm': 0.5, 'Peaceful': 0.3, 'Relaxed': 0.2};
      }
      return MoodAnalysisResult(
        emotions: emotions,
        advice: 'Your feelings matter. Take time to rest and be kind to yourself.',
        moodWeights: moodWeights,
      );
    }

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

  /// 기본 분석 결과 반환 (API 호출 실패 시) - [languageCode]에 따라 반환 언어 결정
  MoodAnalysisResult _getDefaultAnalysis(String languageCode) {
    final isEn = languageCode == 'en';
    if (isEn) {
      return MoodAnalysisResult(
        emotions: ['Calm', 'Peaceful', 'Relaxed'],
        advice: 'How was your day? Small changes in mood matter. Get some rest for tomorrow.',
        moodWeights: {'Calm': 0.4, 'Peaceful': 0.3, 'Relaxed': 0.3},
      );
    }
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
