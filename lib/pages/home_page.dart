import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/auth_service.dart';
import '../services/ai_service.dart';
import '../services/local_diary_service.dart';
import '../models/diary_entry.dart';
import '../main.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AuthService _authService = AuthService();
  final AIService _aiService = AIService();
  User? _currentUser;
  Map<String, String?> _userInfo = {};
  final TextEditingController _diaryController = TextEditingController();
  final FocusNode _diaryFocusNode = FocusNode();
  DateTime _selectedDate = DateTime.now();
  bool _isCalendarExpanded = false;
  DateTime _displayMonth = DateTime.now();
  Set<String> _diaryDates = {}; // 일기가 있는 날짜들
  final Map<String, String> _diaryMainEmotions = {}; // 날짜별 주요 감정 (첫 번째 감정)
  String _savedDiaryContent = ''; // 선택된 날짜의 저장된 일기 내용
  MoodAnalysisResult? _currentMoodAnalysis; // 현재 일기의 감정 분석 결과
  bool _isAnalyzing = false; // AI 분석 중인지 여부
  bool _hasExistingDiary = false; // 선택된 날짜에 일기가 있는지 여부
  bool _isEditingMode = false; // 수정 모드인지 여부

  @override
  void initState() {
    super.initState();
    _initializeApp();

    // 키보드 포커스 리스너
    _diaryFocusNode.addListener(() {
      if (_diaryFocusNode.hasFocus && _isCalendarExpanded) {
        // 키보드가 올라오고 달력이 열려있으면 달력을 닫음
        setState(() {
          _isCalendarExpanded = false;
        });
      }
    });
  }

  /// 앱 초기화 (순차 실행)
  Future<void> _initializeApp() async {
    // 1. 사용자 정보 로드
    await _loadUserInfo();

    // 2. 사용자 정보 로드 후 HIVE 초기화
    await _initializeHiveForUser();

    // 3. 일기 데이터 로드
    await _loadDiaryDates();
    await _loadDiaryForDate(_selectedDate);
  }

  /// 사용자별 Hive 초기화
  Future<void> _initializeHiveForUser() async {
    if (kIsWeb) return; // 웹에서는 Hive 사용 안 함

    final user = _authService.getCurrentUser();
    if (user == null) {
      print('⚠️ 사용자가 로그인하지 않아 Hive 초기화를 스킵합니다.');
      return;
    }

    try {
      print('🔧 사용자별 Hive 초기화 시작 (사용자: ${user.uid})');
      await LocalDiaryService.initialize(userId: user.uid);
      print('✅ 사용자별 Hive 초기화 완료');
    } catch (e) {
      print('❌ Hive 초기화 실패: $e');
      // 초기화 실패해도 앱은 계속 실행
    }
  }

  // 일기가 있는 날짜들을 로드
  Future<void> _loadDiaryDates() async {
    final user = _authService.getCurrentUser();
    if (user == null) return;

    try {
      print('═══════════════════════════════════════');
      print('📅 일기 날짜 목록 로드 시작');
      print('🌐 kIsWeb 값: $kIsWeb');
      print('📱 플랫폼: ${kIsWeb ? "웹 (Firebase 사용)" : "모바일 (Hive 사용)"}');

      if (kIsWeb) {
        // 웹: Firebase 사용
        print('🌐 Firebase에서 일기 날짜 목록 로드 중...');
        final snapshot = await FirebaseFirestore.instance
            .collection('diaries')
            .doc(user.uid)
            .collection('entries')
            .get();

        print('📄 Firebase 문서 수: ${snapshot.docs.length}');

        setState(() {
          _diaryDates = snapshot.docs.map((doc) => doc.id).toSet();

          // 날짜별 주요 감정 추출
          _diaryMainEmotions.clear();
          for (final doc in snapshot.docs) {
            final data = doc.data();
            if (data['moodAnalysis'] != null) {
              final moodData = data['moodAnalysis'] as Map<String, dynamic>;
              final emotions = moodData['emotions'] as List;
              if (emotions.isNotEmpty) {
                _diaryMainEmotions[doc.id] = emotions[0] as String;
              }
            }
          }
        });
        print('✅ Firebase에서 ${_diaryDates.length}개 날짜 로드 완료');
      } else {
        // 모바일: Hive 사용
        print('📱 Hive에서 일기 날짜 목록 로드 중...');

        // Hive 초기화 확인을 위해 잠시 대기
        await Future.delayed(const Duration(milliseconds: 100));

        final dates = LocalDiaryService.getAllDiaryDates();
        final emotions = LocalDiaryService.getDiaryMainEmotions();

        print('📦 Hive에서 가져온 날짜 수: ${dates.length}');
        if (dates.isEmpty) {
          print('⚠️ Hive에서 날짜가 비어있습니다. Hive 초기화 상태를 확인하세요.');
        } else {
          print('📦 Hive 날짜 목록: ${dates.toList()..sort()}');
        }

        setState(() {
          _diaryDates = dates;
          _diaryMainEmotions.clear();
          _diaryMainEmotions.addAll(emotions);
        });
        print('✅ Hive에서 ${_diaryDates.length}개 날짜 로드 완료');
      }
      print('═══════════════════════════════════════');
    } catch (e) {
      print('❌ 일기 날짜 로드 오류: $e');
      print('스택 트레이스: ${StackTrace.current}');
    }
  }

  // 특정 날짜의 일기 내용을 로드
  Future<void> _loadDiaryForDate(DateTime date) async {
    final user = _authService.getCurrentUser();
    if (user == null) return;

    try {
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      print('═══════════════════════════════════════');
      print('📅 일기 로드 시작: $dateStr');
      print('🌐 kIsWeb 값: $kIsWeb');
      print('📱 플랫폼: ${kIsWeb ? "웹" : "모바일"}');

      if (kIsWeb) {
        // 웹: Firebase 사용
        final doc = await FirebaseFirestore.instance
            .collection('diaries')
            .doc(user.uid)
            .collection('entries')
            .doc(dateStr)
            .get();

        print('📄 문서 존재: ${doc.exists}');

        setState(() {
          if (doc.exists) {
            final data = doc.data();
            _savedDiaryContent = data?['content'] ?? '';
            _diaryController.text = _savedDiaryContent;
            _hasExistingDiary = true;
            _isEditingMode = false;

            // 저장된 감정 분석 결과 로드
            if (data?['moodAnalysis'] != null) {
              final moodData = data!['moodAnalysis'] as Map<String, dynamic>;
              print('🎭 감정 분석 데이터 로드: ${moodData['emotions']}');
              _currentMoodAnalysis = MoodAnalysisResult(
                emotions: List<String>.from(moodData['emotions'] as List),
                advice: moodData['advice'] as String,
                moodWeights:
                    Map<String, double>.from(moodData['moodWeights'] as Map),
              );
            } else {
              print('⚠️ 감정 분석 데이터 없음');
              _currentMoodAnalysis = null;
            }
          } else {
            _savedDiaryContent = '';
            _diaryController.clear();
            _currentMoodAnalysis = null;
            _hasExistingDiary = false;
            _isEditingMode = false;
          }
        });
      } else {
        // 모바일: Hive 사용
        print('📱 모바일 환경 - Hive에서 일기 로드 시도: $dateStr');

        // Hive 초기화 확인을 위해 잠시 대기
        await Future.delayed(const Duration(milliseconds: 100));

        final entry = LocalDiaryService.loadDiary(dateStr);
        print('📦 Hive 로드 결과: ${entry != null ? "일기 발견" : "일기 없음"}');

        setState(() {
          if (entry != null) {
            _savedDiaryContent = entry.content;
            _diaryController.text = _savedDiaryContent;
            _hasExistingDiary = true;
            _isEditingMode = false;
            _currentMoodAnalysis = entry.moodAnalysis;
            print('✅ 일기 로드 완료 (Hive) - 내용 길이: ${entry.content.length}자');
            if (entry.moodAnalysis != null) {
              print('🎭 감정 분석 데이터 로드: ${entry.moodAnalysis!.emotions}');
            }
          } else {
            _savedDiaryContent = '';
            _diaryController.clear();
            _currentMoodAnalysis = null;
            _hasExistingDiary = false;
            _isEditingMode = false;
            print('⚠️ 일기 없음 (Hive) - $dateStr');
          }
        });
      }

      // 일기가 없으면 자동으로 포커스
      if (!_hasExistingDiary) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _diaryFocusNode.requestFocus();
        });
      }
    } catch (e) {
      print('❌ 일기 로드 오류: $e');
    }
  }

  @override
  void dispose() {
    _diaryController.dispose();
    _diaryFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    _currentUser = _authService.getCurrentUser();
    if (_currentUser != null) {
      // SharedPreferences에서 정보 가져오기
      final savedUserInfo = await _authService.getSavedUserInfo();

      // SharedPreferences에 정보가 없거나 비어있으면 Firebase Auth에서 가져오기
      if (savedUserInfo['name'] == null || savedUserInfo['name']!.isEmpty) {
        setState(() {
          _userInfo = {
            'id': _currentUser!.uid,
            'email': _currentUser!.email ?? '',
            'name': _currentUser!.displayName ?? '사용자',
            'photo': _currentUser!.photoURL ?? '',
          };
        });
        // Firebase Auth 정보를 SharedPreferences에 저장
        await _authService.saveUserInfoFromFirebase(_currentUser!);
      } else {
        setState(() {
          _userInfo = savedUserInfo;
        });
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await _authService.signOut();
      // AuthWrapper의 authStateChanges 리스너가 자동으로 로그인 페이지로 전환
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (BuildContext context) => CupertinoAlertDialog(
            title: const Text('로그아웃 실패'),
            content: Text('$e'),
            actions: [
              CupertinoDialogAction(
                child: const Text('확인'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    }
  }

  void _showUserInfo() {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: Text(
          '사용자 정보',
          style: GoogleFonts.gaegu(
            fontSize: 19,
            fontWeight: FontWeight.w600,
          ),
        ),
        message: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.1),
              ),
              child:
                  _userInfo['photo'] != null && _userInfo['photo']!.isNotEmpty
                      ? ClipOval(
                          child: Image.network(
                            _userInfo['photo']!,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                CupertinoIcons.person_fill,
                                size: 40,
                                color: AppColors.primary,
                              );
                            },
                          ),
                        )
                      : const Icon(
                          CupertinoIcons.person_fill,
                          size: 40,
                          color: AppColors.primary,
                        ),
            ),
            const SizedBox(height: 12),
            Text(
              _userInfo['name'] ?? '사용자',
              style: GoogleFonts.gaegu(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.label,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _userInfo['email'] ?? '',
              style: GoogleFonts.gaegu(
                fontSize: 17,
                color: CupertinoColors.secondaryLabel,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        CupertinoIcons.book_fill,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '총 ${_diaryDates.length}개의 일기',
                        style: GoogleFonts.gaegu(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => _showMonthlyDiaryChart(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      CupertinoIcons.chart_bar,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
        actions: [
          CupertinoActionSheetAction(
            child: Text(
              '닫기',
              style: GoogleFonts.gaegu(
                fontSize: 19,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  // Hive 데이터 확인 및 표시
  void _showHiveDataDebug() {
    if (kIsWeb) {
      showCupertinoDialog(
        context: context,
        builder: (BuildContext context) => CupertinoAlertDialog(
          title: Text(
            '알림',
            style: GoogleFonts.gaegu(
              fontSize: 19,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            '웹에서는 Hive를 사용하지 않습니다.',
            style: GoogleFonts.gaegu(
              fontSize: 17,
            ),
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('확인'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
      return;
    }

    // Hive 데이터 읽기
    final dates = LocalDiaryService.getAllDiaryDates();
    final emotions = LocalDiaryService.getDiaryMainEmotions();

    // 콘솔에 상세 정보 출력
    print('═══════════════════════════════════════');
    print('📦 Hive 데이터 확인');
    print('═══════════════════════════════════════');
    print('📅 총 일기 수: ${dates.length}');
    print('📅 일기 날짜 목록:');
    for (final date in dates.toList()..sort()) {
      final entry = LocalDiaryService.loadDiary(date);
      if (entry != null) {
        print('  - $date: ${entry.content.length}자');
        if (entry.moodAnalysis != null) {
          print('    감정: ${entry.moodAnalysis!.emotions.join(", ")}');
        }
      }
    }
    print('🎭 주요 감정 맵: $emotions');
    print('═══════════════════════════════════════');

    // 화면에 요약 정보 표시
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: Text(
          'Hive 데이터 확인',
          style: GoogleFonts.gaegu(
            fontSize: 19,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '총 일기 수: ${dates.length}개',
                style: GoogleFonts.gaegu(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              if (dates.isNotEmpty) ...[
                Text(
                  '일기 날짜 목록:',
                  style: GoogleFonts.gaegu(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ...() {
                  final sortedDates = dates.toList()..sort();
                  return sortedDates.take(10).map<Widget>((date) {
                    final entry = LocalDiaryService.loadDiary(date);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '• $date (${entry?.content.length ?? 0}자)',
                        style: GoogleFonts.gaegu(
                          fontSize: 14,
                          color: CupertinoColors.secondaryLabel,
                        ),
                      ),
                    );
                  }).toList();
                }(),
                if (dates.length > 10)
                  Text(
                    '... 외 ${dates.length - 10}개',
                    style: GoogleFonts.gaegu(
                      fontSize: 14,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
              ] else
                Text(
                  '저장된 일기가 없습니다.',
                  style: GoogleFonts.gaegu(
                    fontSize: 15,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                '※ 상세 정보는 콘솔 로그를 확인하세요.',
                style: GoogleFonts.gaegu(
                  fontSize: 12,
                  color: CupertinoColors.placeholderText,
                ),
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('확인'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  // 올해 월별 일기 수 계산
  Future<Map<int, int>> _getMonthlyDiaryCount() async {
    final user = _authService.getCurrentUser();
    if (user == null) {
      print('⚠️ 사용자가 로그인하지 않았습니다.');
      return {};
    }

    final now = DateTime.now();
    final currentYear = now.year;
    final monthlyCount = <int, int>{};

    // 1월부터 12월까지 초기화
    for (int month = 1; month <= 12; month++) {
      monthlyCount[month] = 0;
    }

    try {
      if (kIsWeb) {
        // 웹: Firebase 사용
        print('📊 Firebase에서 월별 일기 수 계산 시작 (올해: $currentYear)');
        final snapshot = await FirebaseFirestore.instance
            .collection('diaries')
            .doc(user.uid)
            .collection('entries')
            .get();

        print('📄 총 ${snapshot.docs.length}개의 일기 문서 발견');

        for (final doc in snapshot.docs) {
          final dateStr = doc.id;
          print('📅 날짜 문자열: $dateStr');
          final parts = dateStr.split('-');
          if (parts.length == 3) {
            final year = int.tryParse(parts[0]);
            final month = int.tryParse(parts[1]);
            print('   → 연도: $year, 월: $month');
            if (year == currentYear &&
                month != null &&
                month >= 1 &&
                month <= 12) {
              monthlyCount[month] = (monthlyCount[month] ?? 0) + 1;
              print('   ✅ $month월 카운트 증가: ${monthlyCount[month]}');
            } else {
              print('   ⚠️ 올해가 아니거나 유효하지 않은 월: $year/$month');
            }
          } else {
            print('   ⚠️ 날짜 형식이 올바르지 않음: $dateStr');
          }
        }
      } else {
        // 모바일: Hive 사용
        print('📊 Hive에서 월별 일기 수 계산 시작 (올해: $currentYear)');
        final dates = LocalDiaryService.getAllDiaryDates();
        print('📄 총 ${dates.length}개의 일기 날짜 발견');

        for (final dateStr in dates) {
          print('📅 날짜 문자열: $dateStr');
          final parts = dateStr.split('-');
          if (parts.length == 3) {
            final year = int.tryParse(parts[0]);
            final month = int.tryParse(parts[1]);
            print('   → 연도: $year, 월: $month');
            if (year == currentYear &&
                month != null &&
                month >= 1 &&
                month <= 12) {
              monthlyCount[month] = (monthlyCount[month] ?? 0) + 1;
              print('   ✅ $month월 카운트 증가: ${monthlyCount[month]}');
            } else {
              print('   ⚠️ 올해가 아니거나 유효하지 않은 월: $year/$month');
            }
          } else {
            print('   ⚠️ 날짜 형식이 올바르지 않음: $dateStr');
          }
        }
      }

      print('📊 최종 월별 카운트: $monthlyCount');
    } catch (e) {
      print('❌ 월별 일기 수 계산 오류: $e');
    }

    return monthlyCount;
  }

  // 월별 일기 수 그래프 표시
  Future<void> _showMonthlyDiaryChart() async {
    final monthlyCount = await _getMonthlyDiaryCount();
    print('📊 그래프 표시 - 월별 카운트: $monthlyCount');

    final maxCount = monthlyCount.values.isEmpty
        ? 1
        : monthlyCount.values.reduce((a, b) => a > b ? a : b);
    final totalCount = monthlyCount.values.isEmpty
        ? 0
        : monthlyCount.values.reduce((a, b) => a + b);

    print('📊 최대 카운트: $maxCount, 총 카운트: $totalCount');

    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Text(
            '${DateTime.now().year}년 월별 일기 작성 수',
            style: GoogleFonts.gaegu(
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          leading: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => Navigator.pop(context),
            child: const Icon(
              CupertinoIcons.back,
              color: AppColors.primary,
              size: 24,
            ),
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 그래프 영역
                Container(
                  height: 280,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey6,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(12, (index) {
                      final month = index + 1;
                      final count = monthlyCount[month] ?? 0;
                      // 사용 가능한 높이: 280 - 32(패딩) - 8(SizedBox) - 20(텍스트) = 220
                      const availableHeight = 220.0;
                      final height = maxCount > 0
                          ? (count / maxCount) * availableHeight
                          : 0.0;

                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // 바 차트
                              Container(
                                width: double.infinity,
                                height: height,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(4),
                                    topRight: Radius.circular(4),
                                  ),
                                ),
                                child: count > 0
                                    ? Center(
                                        child: Text(
                                          count.toString(),
                                          style: GoogleFonts.gaegu(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: CupertinoColors.white,
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(height: 8),
                              // 월 레이블
                              Text(
                                '$month월',
                                style: GoogleFonts.gaegu(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: CupertinoColors.secondaryLabel,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 24),
                // 총 일기 수 표시 또는 빈 데이터 메시지
                totalCount > 0
                    ? Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              CupertinoIcons.book_fill,
                              size: 20,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '총 $totalCount개의 일기',
                              style: GoogleFonts.gaegu(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemGrey6,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              CupertinoIcons.info,
                              size: 20,
                              color: CupertinoColors.secondaryLabel,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${DateTime.now().year}년에 작성한 일기가 없습니다.',
                              style: GoogleFonts.gaegu(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: CupertinoColors.secondaryLabel,
                              ),
                            ),
                          ],
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          'Feelog',
          style: GoogleFonts.gaegu(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: CupertinoColors.systemBackground,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 프로필 사진
            GestureDetector(
              onTap: _showUserInfo,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withOpacity(0.1),
                ),
                child:
                    _userInfo['photo'] != null && _userInfo['photo']!.isNotEmpty
                        ? ClipOval(
                            child: Image.network(
                              _userInfo['photo']!,
                              width: 32,
                              height: 32,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  CupertinoIcons.person_fill,
                                  size: 18,
                                  color: AppColors.primary,
                                );
                              },
                            ),
                          )
                        : const Icon(
                            CupertinoIcons.person_fill,
                            size: 18,
                            color: AppColors.primary,
                          ),
              ),
            ),
            const SizedBox(width: 8),
            // 로그아웃 버튼
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _signOut,
              child: const Icon(
                CupertinoIcons.square_arrow_right_fill,
                color: AppColors.primary,
                size: 20,
              ),
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // 상단 스크롤 가능한 컨텐츠
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 날짜 선택 카드
                    GestureDetector(
                      onTap: () async {
                        final wasExpanded = _isCalendarExpanded;
                        setState(() {
                          _isCalendarExpanded = !_isCalendarExpanded;
                        });
                        // 달력을 열 때 일기 날짜 목록 다시 로드 (Hive/Firebase 최신 데이터 반영)
                        if (!wasExpanded) {
                          await _loadDiaryDates();
                        } else {
                          // 달력을 닫을 때 현재 선택된 날짜의 일기 다시 로드
                          await _loadDiaryForDate(_selectedDate);
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemGrey6,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 12.0,
                          ),
                          child: Row(
                            children: [
                              // 왼쪽 화살표 (이전 날짜)
                              GestureDetector(
                                onTap: () async {
                                  setState(() {
                                    _selectedDate = DateTime(
                                      _selectedDate.year,
                                      _selectedDate.month,
                                      _selectedDate.day - 1,
                                    );
                                  });
                                  await _loadDiaryForDate(_selectedDate);
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  child: const Icon(
                                    CupertinoIcons.chevron_left,
                                    color: AppColors.primary,
                                    size: 18,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                CupertinoIcons.calendar,
                                color: AppColors.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _formatDate(_selectedDate),
                                  style: GoogleFonts.gaegu(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: CupertinoColors.label,
                                  ),
                                ),
                              ),
                              // 오른쪽 화살표 (다음 날짜)
                              GestureDetector(
                                onTap: () async {
                                  setState(() {
                                    _selectedDate = DateTime(
                                      _selectedDate.year,
                                      _selectedDate.month,
                                      _selectedDate.day + 1,
                                    );
                                  });
                                  await _loadDiaryForDate(_selectedDate);
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  child: const Icon(
                                    CupertinoIcons.chevron_right,
                                    color: AppColors.primary,
                                    size: 18,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                _isCalendarExpanded
                                    ? CupertinoIcons.chevron_up
                                    : CupertinoIcons.chevron_down,
                                color: CupertinoColors.placeholderText,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // 달력 뷰 (확장/축소)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: _isCalendarExpanded ? 250 : 0,
                      child: _isCalendarExpanded
                          ? Container(
                              margin: const EdgeInsets.only(top: 16),
                              decoration: BoxDecoration(
                                color: CupertinoColors.systemBackground,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: CupertinoColors.separator,
                                  width: 0.5,
                                ),
                              ),
                              child: _buildCalendar(),
                            )
                          : const SizedBox.shrink(),
                    ),

                    const SizedBox(height: 24),

                    // 일기 작성 제목
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '오늘의 일기',
                          style: GoogleFonts.gaegu(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: CupertinoColors.label,
                          ),
                        ),
                        Row(
                          children: [
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () => _show6MonthMood(),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '6M',
                                  style: GoogleFonts.gaegu(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: CupertinoColors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () => _show1YearMood(),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '1Y',
                                  style: GoogleFonts.gaegu(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: CupertinoColors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () => _showSameDayDiary(),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'SD',
                                  style: GoogleFonts.gaegu(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: CupertinoColors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // 일기 작성 영역 (동적 높이 조정)
                    GestureDetector(
                      onTap: () {
                        // 일기가 없거나 수정 모드일 때만 포커스
                        if (!_hasExistingDiary || _isEditingMode) {
                          _diaryFocusNode.requestFocus();
                        }
                      },
                      child: Container(
                        constraints: const BoxConstraints(
                          minHeight: 100, // 최소 높이
                        ),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemBackground,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: CupertinoColors.separator,
                            width: 0.5,
                          ),
                        ),
                        child: CupertinoScrollbar(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16.0),
                            child: CupertinoTextField(
                              controller: _diaryController,
                              focusNode: _diaryFocusNode,
                              minLines: _hasExistingDiary && !_isEditingMode
                                  ? null
                                  : 4,
                              maxLines: null,
                              enabled: !_hasExistingDiary ||
                                  _isEditingMode, // 일기가 없거나 수정 모드면 활성화
                              style: GoogleFonts.gaegu(
                                fontSize: 18,
                                fontWeight: FontWeight.w400,
                                color: (_hasExistingDiary && !_isEditingMode)
                                    ? CupertinoColors.secondaryLabel
                                    : CupertinoColors.label,
                                height: 1.5,
                              ),
                              decoration: const BoxDecoration(),
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // AI 분석 결과 표시
                    if (_currentMoodAnalysis != null)
                      _buildMoodChart(_currentMoodAnalysis!),

                    if (_currentMoodAnalysis != null)
                      const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // 하단 고정 버튼 영역
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: const BoxDecoration(
                color: CupertinoColors.systemBackground,
                border: Border(
                  top: BorderSide(
                    color: CupertinoColors.separator,
                    width: 0.5,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: !_hasExistingDiary
                    ? // 일기가 없으면 저장하기
                    SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: CupertinoButton.filled(
                          onPressed: _isAnalyzing ? null : _saveDiary,
                          borderRadius: BorderRadius.circular(25),
                          child: _isAnalyzing
                              ? const CupertinoActivityIndicator(
                                  color: CupertinoColors.white)
                              : Text(
                                  '저장하기',
                                  style: GoogleFonts.gaegu(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w600,
                                    color: CupertinoColors.white,
                                  ),
                                ),
                        ),
                      )
                    : // 일기가 있으면 수정하기와 삭제하기
                    Row(
                        children: [
                          // 수정하기 버튼
                          Expanded(
                            child: CupertinoButton.filled(
                              onPressed: _isAnalyzing
                                  ? null
                                  : _isEditingMode
                                      ? _saveUpdatedDiary
                                      : _startEditing,
                              borderRadius: BorderRadius.circular(25),
                              child: _isAnalyzing
                                  ? const CupertinoActivityIndicator(
                                      color: CupertinoColors.white)
                                  : Text(
                                      _isEditingMode ? '저장하기' : '수정하기',
                                      style: GoogleFonts.gaegu(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w600,
                                        color: CupertinoColors.white,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // 삭제하기 버튼 (아이콘만)
                          CupertinoButton(
                            onPressed: _isAnalyzing ? null : _deleteDiary,
                            padding: EdgeInsets.zero,
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: CupertinoColors.destructiveRed,
                                borderRadius: BorderRadius.circular(25),
                              ),
                              child: const Icon(
                                CupertinoIcons.trash,
                                color: CupertinoColors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveDiary() async {
    if (_diaryController.text.trim().isEmpty) {
      showCupertinoDialog(
        context: context,
        builder: (BuildContext context) => CupertinoAlertDialog(
          title: Text(
            '알림',
            style: GoogleFonts.gaegu(
              fontSize: 19,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            '일기를 입력해주세요.',
            style: GoogleFonts.gaegu(
              fontSize: 17,
            ),
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('확인'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
      return;
    }

    // Firestore에 일기 저장
    try {
      final user = _authService.getCurrentUser();
      if (user == null) {
        throw Exception('로그인이 필요합니다.');
      }

      // 날짜를 문자열로 변환 (YYYY-MM-DD 형식)
      final dateStr =
          '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

      // AI 감정 분석 실행
      setState(() {
        _isAnalyzing = true;
      });

      final moodAnalysis = await _aiService.analyzeDiary(_diaryController.text);

      setState(() {
        _isAnalyzing = false;
        _currentMoodAnalysis = moodAnalysis;
      });

      // Firestore에 일기 및 감정 분석 결과 저장
      final diaryData = {
        'date': Timestamp.fromDate(DateTime(
            _selectedDate.year, _selectedDate.month, _selectedDate.day)),
        'content': _diaryController.text,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // AI 분석 결과 추가
      if (moodAnalysis != null) {
        diaryData['moodAnalysis'] = {
          'emotions': moodAnalysis.emotions,
          'moodWeights': moodAnalysis.moodWeights,
          'advice': moodAnalysis.advice,
        };
      }

      if (kIsWeb) {
        // 웹: Firebase에 저장
        print('🌐 웹 환경 - Firebase에 일기 저장: $dateStr');
        await FirebaseFirestore.instance
            .collection('diaries')
            .doc(user.uid)
            .collection('entries')
            .doc(dateStr)
            .set(diaryData);
        print('✅ Firebase 저장 완료');
      } else {
        // 모바일: Hive에 저장
        print('═══════════════════════════════════════');
        print('📱 모바일 환경 - Hive에 일기 저장 시작');
        print('📅 날짜: $dateStr');
        print('📝 내용 길이: ${_diaryController.text.length}자');
        print('🎭 감정 분석: ${moodAnalysis != null ? "있음" : "없음"}');

        try {
          final diaryEntry = DiaryEntry(
            date: DateTime(
                _selectedDate.year, _selectedDate.month, _selectedDate.day),
            content: _diaryController.text,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            moodAnalysis: moodAnalysis,
          );
          print('📦 DiaryEntry 객체 생성 완료');

          await LocalDiaryService.saveDiary(dateStr, diaryEntry);
          print('✅ Hive 저장 완료');

          // 저장 확인
          final savedEntry = LocalDiaryService.loadDiary(dateStr);
          if (savedEntry != null) {
            print('✅ 저장 확인 성공 - 내용: ${savedEntry.content.length}자');
          } else {
            print('⚠️ 저장 확인 실패 - 일기를 찾을 수 없습니다');
          }
        } catch (e, stackTrace) {
          print('❌ Hive 저장 오류: $e');
          print('스택 트레이스: $stackTrace');
          rethrow; // 에러를 상위로 전달
        }
        print('═══════════════════════════════════════');
      }

      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (BuildContext context) => CupertinoAlertDialog(
            title: Text(
              '저장 완료',
              style: GoogleFonts.gaegu(
                fontSize: 19,
                fontWeight: FontWeight.w600,
              ),
            ),
            content: Text(
              '일기가 저장되었습니다.',
              style: GoogleFonts.gaegu(
                fontSize: 17,
              ),
            ),
            actions: [
              CupertinoDialogAction(
                child: Text(
                  '확인',
                  style: GoogleFonts.gaegu(
                    fontSize: 17,
                  ),
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }

      // 저장 후 일기 날짜 목록 업데이트 및 현재 날짜 일기 다시 로드
      _loadDiaryDates();
      _loadDiaryForDate(_selectedDate);
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (BuildContext context) => CupertinoAlertDialog(
            title: Text(
              '저장 실패',
              style: GoogleFonts.gaegu(
                fontSize: 19,
                fontWeight: FontWeight.w600,
              ),
            ),
            content: Text(
              '일기 저장 중 오류가 발생했습니다.\n$e',
              style: GoogleFonts.gaegu(
                fontSize: 17,
              ),
            ),
            actions: [
              CupertinoDialogAction(
                child: Text(
                  '확인',
                  style: GoogleFonts.gaegu(
                    fontSize: 17,
                  ),
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    }
  }

  void _startEditing() {
    setState(() {
      _isEditingMode = true;
    });
  }

  Future<void> _saveUpdatedDiary() async {
    final user = _authService.getCurrentUser();
    if (user == null) {
      throw Exception('로그인이 필요합니다.');
    }

    // 날짜를 문자열로 변환 (YYYY-MM-DD 형식)
    final dateStr =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

    try {
      // AI 감정 분석 실행
      setState(() {
        _isAnalyzing = true;
      });

      final moodAnalysis = await _aiService.analyzeDiary(_diaryController.text);

      setState(() {
        _isAnalyzing = false;
        _currentMoodAnalysis = moodAnalysis;
        _isEditingMode = false;
      });

      if (kIsWeb) {
        // 웹: Firestore에 일기 및 감정 분석 결과 업데이트
        final diaryData = {
          'date': Timestamp.fromDate(DateTime(
              _selectedDate.year, _selectedDate.month, _selectedDate.day)),
          'content': _diaryController.text,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        // AI 분석 결과 추가
        if (moodAnalysis != null) {
          diaryData['moodAnalysis'] = {
            'emotions': moodAnalysis.emotions,
            'moodWeights': moodAnalysis.moodWeights,
            'advice': moodAnalysis.advice,
          };
        }

        print('🌐 웹 환경 - Firebase에 일기 업데이트: $dateStr');
        await FirebaseFirestore.instance
            .collection('diaries')
            .doc(user.uid)
            .collection('entries')
            .doc(dateStr)
            .update(diaryData);
        print('✅ Firebase 업데이트 완료');
      } else {
        // 모바일: Hive에 업데이트
        print('📱 모바일 환경 - Hive에 일기 업데이트: $dateStr');
        final existingEntry = LocalDiaryService.loadDiary(dateStr);
        final diaryEntry = DiaryEntry(
          date: DateTime(
              _selectedDate.year, _selectedDate.month, _selectedDate.day),
          content: _diaryController.text,
          createdAt: existingEntry?.createdAt ?? DateTime.now(),
          updatedAt: DateTime.now(),
          moodAnalysis: moodAnalysis,
        );
        await LocalDiaryService.saveDiary(dateStr, diaryEntry);
        print('✅ Hive 업데이트 완료');
      }

      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (BuildContext context) => CupertinoAlertDialog(
            title: Text(
              '수정 완료',
              style: GoogleFonts.gaegu(
                fontSize: 19,
                fontWeight: FontWeight.w600,
              ),
            ),
            content: Text(
              '일기가 수정되었습니다.',
              style: GoogleFonts.gaegu(
                fontSize: 17,
              ),
            ),
            actions: [
              CupertinoDialogAction(
                child: Text(
                  '확인',
                  style: GoogleFonts.gaegu(
                    fontSize: 17,
                  ),
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }

      // 수정 후 일기 날짜 목록 업데이트 및 현재 날짜 일기 다시 로드
      _loadDiaryDates();
      await _loadDiaryForDate(_selectedDate);
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _isEditingMode = false;
      });
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (BuildContext context) => CupertinoAlertDialog(
            title: Text(
              '수정 실패',
              style: GoogleFonts.gaegu(
                fontSize: 19,
                fontWeight: FontWeight.w600,
              ),
            ),
            content: Text(
              '일기 수정 중 오류가 발생했습니다.\n$e',
              style: GoogleFonts.gaegu(
                fontSize: 17,
              ),
            ),
            actions: [
              CupertinoDialogAction(
                child: Text(
                  '확인',
                  style: GoogleFonts.gaegu(
                    fontSize: 17,
                  ),
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _updateDiary() async {
    final user = _authService.getCurrentUser();
    if (user == null) {
      throw Exception('로그인이 필요합니다.');
    }

    // 날짜를 문자열로 변환 (YYYY-MM-DD 형식)
    final dateStr =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

    try {
      // AI 감정 분석 실행
      setState(() {
        _isAnalyzing = true;
      });

      final moodAnalysis = await _aiService.analyzeDiary(_diaryController.text);

      setState(() {
        _isAnalyzing = false;
        _currentMoodAnalysis = moodAnalysis;
      });

      // Firestore에 일기 및 감정 분석 결과 업데이트
      final diaryData = {
        'date': Timestamp.fromDate(DateTime(
            _selectedDate.year, _selectedDate.month, _selectedDate.day)),
        'content': _diaryController.text,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // AI 분석 결과 추가
      if (moodAnalysis != null) {
        diaryData['moodAnalysis'] = {
          'emotions': moodAnalysis.emotions,
          'moodWeights': moodAnalysis.moodWeights,
          'advice': moodAnalysis.advice,
        };
      }

      await FirebaseFirestore.instance
          .collection('diaries')
          .doc(user.uid)
          .collection('entries')
          .doc(dateStr)
          .update(diaryData);

      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (BuildContext context) => CupertinoAlertDialog(
            title: Text(
              '수정 완료',
              style: GoogleFonts.gaegu(
                fontSize: 19,
                fontWeight: FontWeight.w600,
              ),
            ),
            content: Text(
              '일기가 수정되었습니다.',
              style: GoogleFonts.gaegu(
                fontSize: 17,
              ),
            ),
            actions: [
              CupertinoDialogAction(
                child: Text(
                  '확인',
                  style: GoogleFonts.gaegu(
                    fontSize: 17,
                  ),
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }

      // 수정 후 일기 날짜 목록 업데이트 및 현재 날짜 일기 다시 로드
      _loadDiaryDates();
      await _loadDiaryForDate(_selectedDate);
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (BuildContext context) => CupertinoAlertDialog(
            title: Text(
              '수정 실패',
              style: GoogleFonts.gaegu(
                fontSize: 19,
                fontWeight: FontWeight.w600,
              ),
            ),
            content: Text(
              '일기 수정 중 오류가 발생했습니다.\n$e',
              style: GoogleFonts.gaegu(
                fontSize: 17,
              ),
            ),
            actions: [
              CupertinoDialogAction(
                child: Text(
                  '확인',
                  style: GoogleFonts.gaegu(
                    fontSize: 17,
                  ),
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _deleteDiary() async {
    final user = _authService.getCurrentUser();
    if (user == null) return;

    // 삭제 확인 다이얼로그
    final confirmed = await showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: Text(
          '일기 삭제',
          style: GoogleFonts.gaegu(
            fontSize: 19,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          '정말 이 일기를 삭제하시겠습니까?',
          style: GoogleFonts.gaegu(
            fontSize: 17,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: Text(
              '취소',
              style: GoogleFonts.gaegu(
                fontSize: 17,
                color: CupertinoColors.destructiveRed,
              ),
            ),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            child: Text(
              '삭제',
              style: GoogleFonts.gaegu(
                fontSize: 17,
                color: AppColors.primary,
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // 날짜를 문자열로 변환 (YYYY-MM-DD 형식)
    final dateStr =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

    try {
      if (kIsWeb) {
        // 웹: Firebase에서 삭제
        print('🌐 웹 환경 - Firebase에서 일기 삭제: $dateStr');
        await FirebaseFirestore.instance
            .collection('diaries')
            .doc(user.uid)
            .collection('entries')
            .doc(dateStr)
            .delete();
        print('✅ Firebase 삭제 완료');
      } else {
        // 모바일: Hive에서 삭제
        print('📱 모바일 환경 - Hive에서 일기 삭제: $dateStr');
        await LocalDiaryService.deleteDiary(dateStr);
        print('✅ Hive 삭제 완료');
      }

      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (BuildContext context) => CupertinoAlertDialog(
            title: Text(
              '삭제 완료',
              style: GoogleFonts.gaegu(
                fontSize: 19,
                fontWeight: FontWeight.w600,
              ),
            ),
            content: Text(
              '일기가 삭제되었습니다.',
              style: GoogleFonts.gaegu(
                fontSize: 17,
              ),
            ),
            actions: [
              CupertinoDialogAction(
                child: Text(
                  '확인',
                  style: GoogleFonts.gaegu(
                    fontSize: 17,
                  ),
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }

      // 삭제 후 일기 내용 초기화
      setState(() {
        _diaryController.clear();
        _currentMoodAnalysis = null;
        _hasExistingDiary = false;
        _savedDiaryContent = '';
      });

      // 일기 날짜 목록 업데이트
      _loadDiaryDates();
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (BuildContext context) => CupertinoAlertDialog(
            title: Text(
              '삭제 실패',
              style: GoogleFonts.gaegu(
                fontSize: 19,
                fontWeight: FontWeight.w600,
              ),
            ),
            content: Text(
              '일기 삭제 중 오류가 발생했습니다.\n$e',
              style: GoogleFonts.gaegu(
                fontSize: 17,
              ),
            ),
            actions: [
              CupertinoDialogAction(
                child: Text(
                  '확인',
                  style: GoogleFonts.gaegu(
                    fontSize: 17,
                  ),
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    }
  }

  Widget _buildCalendar() {
    final firstDay = DateTime(_displayMonth.year, _displayMonth.month, 1);
    final lastDay = DateTime(_displayMonth.year, _displayMonth.month + 1, 0);
    final firstWeekday = firstDay.weekday;
    final totalDays = lastDay.day;
    final today = DateTime.now();

    final weekdays = ['일', '월', '화', '수', '목', '금', '토'];
    final weeks = <List<DateTime>>[];

    List<DateTime> week = [];

    // 첫 주 앞 빈칸
    // Dart의 weekday: Monday=1(월), Tuesday=2(화), ..., Sunday=7(일)
    // 달력 인덱스: Sunday=0, Monday=1, Tuesday=2, ..., Saturday=6
    // 변환: Monday(1) -> 1, Tuesday(2) -> 2, ..., Saturday(6) -> 6, Sunday(7) -> 0
    // 달력은 일요일부터 시작하므로 수요일(weekday=3)은 인덱스 3에 위치
    // 앞에 빈칸 0, 1, 2 → 총 3개 빈칸 필요
    int calendarIndex = (firstWeekday == 7) ? 6 : firstWeekday;

    for (int i = 0; i < calendarIndex; i++) {
      week.add(DateTime(0));
    }

    // 실제 날짜들
    for (int day = 1; day <= totalDays; day++) {
      week.add(DateTime(_displayMonth.year, _displayMonth.month, day));
      if (week.length == 7) {
        weeks.add(week);
        week = [];
      }
    }

    // 마지막 주 뒤 빈칸
    if (week.isNotEmpty) {
      while (week.length < 7) {
        week.add(DateTime(0));
      }
      weeks.add(week);
    }

    return Padding(
      padding:
          const EdgeInsets.only(left: 16.0, right: 16.0, top: 8.0, bottom: 4.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 월/년 네비게이션
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () async {
                      setState(() {
                        _displayMonth = DateTime(
                            _displayMonth.year, _displayMonth.month - 1);
                      });
                      // 월 변경 시 일기 날짜 목록 다시 로드
                      await _loadDiaryDates();
                    },
                    child: const Icon(CupertinoIcons.chevron_left, size: 20),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () async {
                      final now = DateTime.now();
                      setState(() {
                        _displayMonth = DateTime(now.year, now.month);
                        _selectedDate = DateTime(now.year, now.month, now.day);
                      });
                      // 오늘 버튼 클릭 시 일기 날짜 목록 다시 로드
                      await _loadDiaryDates();
                      await _loadDiaryForDate(_selectedDate);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '오늘',
                        style: GoogleFonts.gaegu(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  _showYearMonthPicker();
                },
                child: Text(
                  '${_displayMonth.year}년 ${_displayMonth.month}월',
                  style: GoogleFonts.gaegu(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.label,
                  ),
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () async {
                  setState(() {
                    _displayMonth =
                        DateTime(_displayMonth.year, _displayMonth.month + 1);
                  });
                  // 월 변경 시 일기 날짜 목록 다시 로드
                  await _loadDiaryDates();
                },
                child: const Icon(CupertinoIcons.chevron_right, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // 요일 헤더
          Row(
            children: weekdays.map((day) {
              return Expanded(
                child: Text(
                  day,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.gaegu(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
          // 달력 그리드
          Flexible(
            child: Column(
              children: weeks.asMap().entries.map((entry) {
                final week = entry.value;
                return Flexible(
                  child: Padding(
                    padding: EdgeInsets.only(
                        bottom: entry.key < weeks.length - 1 ? 4.0 : 0.0),
                    child: Row(
                      children: week.map((date) {
                        if (date.year == 0) {
                          return const Expanded(child: SizedBox());
                        }

                        final isSelected = date.year == _selectedDate.year &&
                            date.month == _selectedDate.month &&
                            date.day == _selectedDate.day;

                        final isToday = date.year == today.year &&
                            date.month == today.month &&
                            date.day == today.day;

                        final isPast = date.isBefore(
                            DateTime(today.year, today.month, today.day));

                        // 날짜를 YYYY-MM-DD 형식으로 변환
                        final dateStr =
                            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                        final hasDiary = _diaryDates.contains(dateStr);
                        final mainEmotion = _diaryMainEmotions[dateStr];
                        final moodColor = mainEmotion != null
                            ? _getEmotionColor(mainEmotion)
                            : null;

                        return Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              setState(() {
                                _selectedDate = date;
                              });
                              await _loadDiaryForDate(date);
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 1, vertical: 1),
                              padding: const EdgeInsets.only(
                                  top: 2, bottom: 8, left: 8, right: 8),
                              decoration: BoxDecoration(
                                color: moodColor != null
                                    ? moodColor.withOpacity(0.3)
                                    : hasDiary && !isToday
                                        ? AppColors.primary.withOpacity(0.15)
                                        : isToday
                                            ? AppColors.primary.withOpacity(0.1)
                                            : Colors.transparent,
                                border: isSelected
                                    ? Border.all(
                                        color: Colors.red,
                                        width: 2.0,
                                      )
                                    : null,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${date.day}',
                                style: GoogleFonts.gaegu(
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: isPast
                                      ? CupertinoColors.secondaryLabel
                                      : CupertinoColors.label,
                                ),
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.visible,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    // DateTime.weekday: Monday=1, Tuesday=2, ..., Sunday=7
    // weekdays 배열을 달력과 동일하게 일요일부터 시작
    final weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    // weekday가 1(월)일 때 인덱스 0, weekday가 7(일)일 때 인덱스 6
    // Monday=1 -> index 0, Tuesday=2 -> index 1, ..., Sunday=7 -> index 6
    return '${date.year}년 ${date.month}월 ${date.day}일 (${weekdays[date.weekday - 1]})';
  }

  /// 감정 이름으로 색상 가져오기
  Color _getEmotionColor(String emotion) {
    final emotionColors = {
      // 진빨강 (#D32F2F)
      '격분한': const Color(0xFFD32F2F),
      '격노한': const Color(0xFFD32F2F),
      '화가 치밀어 오른': const Color(0xFFD32F2F),
      '불안한': const Color(0xFFD32F2F),
      '불쾌한': const Color(0xFFD32F2F),

      // 빨강 (#E53935)
      '공황에 빠진': const Color(0xFFE53935),
      '몸시 화가 난': const Color(0xFFE53935),
      '겁먹은': const Color(0xFFE53935),
      '우려하는': const Color(0xFFE53935),
      '골치 아픈': const Color(0xFFE53935),

      // 오렌지레드 (#EF5350)
      '스트레스 받는': const Color(0xFFEF5350),
      '좌절한': const Color(0xFFEF5350),
      '화난': const Color(0xFFEF5350),
      '근심하는': const Color(0xFFEF5350),
      '염려하는': const Color(0xFFEF5350),

      // 진오렌지 (#FF5722)
      '초조한': const Color(0xFFFF5722),
      '신경이 날카로운': const Color(0xFFFF5722),
      '짜증나는': const Color(0xFFFF5722),
      '마음이 불편한': const Color(0xFFFF5722),

      // 오렌지 (#FF9800)
      '충격받은': const Color(0xFFFF9800),
      '망연자실한': const Color(0xFFFF9800),
      '안정부절못하는': const Color(0xFFFF9800),
      '거슬리는': const Color(0xFFFF9800),
      '언짢은': const Color(0xFFFF9800),

      // 연노랑 (#FFF176)
      '놀란': const Color(0xFFFFF176),
      '들뜬': const Color(0xFFFFF176),
      '기운이 넘치는': const Color(0xFFFFF176),
      '만족스러운': const Color(0xFFFFF176),
      '유쾌한': const Color(0xFFFFF176),

      // 노랑 (#FFEB3B)
      '긍정적인': const Color(0xFFFFEB3B),
      '쾌활한': const Color(0xFFFFEB3B),
      '활발한': const Color(0xFFFFEB3B),
      '행복한': const Color(0xFFFFEB3B),
      '기쁜': const Color(0xFFFFEB3B),

      // 노랑-주황 (#FFD54F)
      '흥겨운': const Color(0xFFFFD54F),
      '동기 부여된': const Color(0xFFFFD54F),
      '흥분한': const Color(0xFFFFD54F),
      '집중하는': const Color(0xFFFFD54F),

      // 진주황 (#FFCC02)
      '아주 신나는': const Color(0xFFFFCC02),
      '영감을 받은': const Color(0xFFFFCC02),
      '낙관적인': const Color(0xFFFFCC02),
      '재미있는': const Color(0xFFFFCC02),

      // 노랑-오렌지 (#FFB300)
      '황홀한': const Color(0xFFFFB300),
      '의기양양한': const Color(0xFFFFB300),
      '열광하는': const Color(0xFFFFB300),
      '짜릿한': const Color(0xFFFFB300),
      '더없이 행복한': const Color(0xFFFFB300),

      // 연연두 (#C5E1A5)
      '속 편한': const Color(0xFFC5E1A5),
      '평온한': const Color(0xFFC5E1A5),
      '여유로운': const Color(0xFFC5E1A5),
      '한가로운': const Color(0xFFC5E1A5),
      '나른한': const Color(0xFFC5E1A5),

      // 연두 (#A5D6A7)
      '태평한': const Color(0xFFA5D6A7),
      '안전한': const Color(0xFFA5D6A7),
      '차분한': const Color(0xFFA5D6A7),
      '생각에 잠긴': const Color(0xFFA5D6A7),
      '흐뭇한': const Color(0xFFA5D6A7),

      // 초록-연두 (#81C784)
      '자족하는': const Color(0xFF81C784),
      '편안한': const Color(0xFF81C784),
      '평화로운': const Color(0xFF81C784),
      '고요한': const Color(0xFF81C784),

      // 연초록 (#66BB6A)
      '다정한': const Color(0xFF66BB6A),
      '감사하는': const Color(0xFF66BB6A),
      '축복받은': const Color(0xFF66BB6A),
      '편한': const Color(0xFF66BB6A),

      // 초록 (#4CAF50)
      '충만한': const Color(0xFF4CAF50),
      '감동적인': const Color(0xFF4CAF50),
      '안정적인': const Color(0xFF4CAF50),
      '근심 걱정 없는': const Color(0xFF4CAF50),
      '안온한': const Color(0xFF4CAF50),

      // 진파랑 (#1A237E)
      '역겨운': const Color(0xFF1A237E),

      // 파랑 (#283593)
      '침울한': const Color(0xFF283593),
      '사무룩한': const Color(0xFF283593),

      // 중간파랑 (#3F51B5)
      '실망스러운': const Color(0xFF3F51B5),
      '낙담한': const Color(0xFF3F51B5),

      // 청색 (#5C6BC0)
      '의욕 없는': const Color(0xFF5C6BC0),
      '슬픈': const Color(0xFF5C6BC0),

      // 연청색 (#7986CB)
      '냉담한': const Color(0xFF7986CB),
      '지루한': const Color(0xFF7986CB),
      '기죽은': const Color(0xFF7986CB),
      '피곤한': const Color(0xFF7986CB),
      '지친': const Color(0xFF7986CB),
      '우울한': const Color(0xFF7986CB),
      '소외된': const Color(0xFF7986CB),
      '쓸쓸한': const Color(0xFF7986CB),
      '비관적인': const Color(0xFF7986CB),
      '의기소침한': const Color(0xFF7986CB),
      '절망한': const Color(0xFF7986CB),
      '비참한': const Color(0xFF7986CB),
      '가망 없는': const Color(0xFF7986CB),
      '고독한': const Color(0xFF7986CB),
      '뚱한': const Color(0xFF7986CB),
      '기진맥진한': const Color(0xFF7986CB),
      '소모된': const Color(0xFF7986CB),
      '진이 빠진': const Color(0xFF7986CB),
    };

    return emotionColors[emotion] ?? CupertinoColors.systemGrey;
  }

  /// AI 분석 결과를 Mood Meter로 표시 (상위 3개 감정)
  Widget _buildMoodChart(MoodAnalysisResult analysis) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 감정 레이블
          Row(
            children: analysis.emotions.asMap().entries.map((entry) {
              final emotion = entry.value;
              final value = analysis.moodWeights[emotion] ?? 0.0;
              final color = _getEmotionColor(emotion);

              return Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        emotion,
                        style: GoogleFonts.gaegu(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.label,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          // 전체 가로 바 (100% 구성)
          Container(
            height: 28,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: analysis.emotions.asMap().entries.map((entry) {
                final emotion = entry.value;
                final value = analysis.moodWeights[emotion] ?? 0.0;
                final color = _getEmotionColor(emotion);

                return Flexible(
                  flex: (value * 100).round(),
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.only(
                        topLeft: entry.key == 0
                            ? const Radius.circular(14)
                            : Radius.zero,
                        bottomLeft: entry.key == 0
                            ? const Radius.circular(14)
                            : Radius.zero,
                        topRight: entry.key == analysis.emotions.length - 1
                            ? const Radius.circular(14)
                            : Radius.zero,
                        bottomRight: entry.key == analysis.emotions.length - 1
                            ? const Radius.circular(14)
                            : Radius.zero,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${(value * 100).toStringAsFixed(0)}%',
                        style: GoogleFonts.gaegu(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.black,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          // AI 조언
          Text(
            analysis.advice,
            style: GoogleFonts.gaegu(
              fontSize: 16,
              color: CupertinoColors.label,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // 6개월 감정 화면 표시
  Future<void> _show6MonthMood() async {
    final user = _authService.getCurrentUser();
    if (user == null) return;

    // 모바일 환경에서 HIVE가 초기화되지 않았으면 초기화
    if (!kIsWeb) {
      try {
        await _initializeHiveForUser();
      } catch (e) {
        print('⚠️ HIVE 초기화 실패: $e');
        if (!mounted) return;
        showCupertinoDialog(
          context: context,
          builder: (BuildContext context) => CupertinoAlertDialog(
            title: Text(
              '오류',
              style: GoogleFonts.gaegu(fontSize: 17),
            ),
            content: Text(
              '데이터를 불러올 수 없습니다.',
              style: GoogleFonts.gaegu(fontSize: 15),
            ),
            actions: [
              CupertinoDialogAction(
                child: const Text('확인'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
        return;
      }
    }

    // 6개월 전 날짜부터 오늘까지의 데이터 가져오기
    final today = DateTime.now();
    final sixMonthsAgo = DateTime(today.year, today.month - 6, today.day);
    final periodKey =
        '${sixMonthsAgo.year}-${sixMonthsAgo.month.toString().padLeft(2, '0')}-${today.year}-${today.month.toString().padLeft(2, '0')}';

    try {
      String aiAdvice = '분석할 데이터가 없습니다.';
      bool needsReanalysis = false;
      List<DiaryEntry> entries = [];
      Map<String, dynamic>? analysisData;
      DateTime? analysisCreatedAt;

      if (kIsWeb) {
        // 웹: Firebase 사용
        // 기존 분석 결과 확인
        final analysisDoc = await FirebaseFirestore.instance
            .collection('diaries')
            .doc(user.uid)
            .collection('period_analysis')
            .doc('6M_$periodKey')
            .get();

        // 해당 기간의 일기 데이터 가져오기
        final entriesSnapshot = await FirebaseFirestore.instance
            .collection('diaries')
            .doc(user.uid)
            .collection('entries')
            .where('date',
                isGreaterThanOrEqualTo: Timestamp.fromDate(sixMonthsAgo))
            .orderBy('date', descending: false)
            .get();

        // DiaryEntry 리스트로 변환
        entries = entriesSnapshot.docs.map((doc) {
          final data = doc.data();
          return DiaryEntry.fromFirestore(data, doc.id);
        }).toList();

        if (analysisDoc.exists) {
          analysisData = analysisDoc.data();
          analysisCreatedAt = analysisData?['createdAt'] != null
              ? (analysisData!['createdAt'] as Timestamp).toDate()
              : null;
        }
      } else {
        // 모바일: Hive 사용
        // 기존 분석 결과 확인
        final savedAnalysis =
            LocalDiaryService.loadPeriodAnalysis('6M_$periodKey');
        if (savedAnalysis != null) {
          analysisData = savedAnalysis;
          analysisCreatedAt = savedAnalysis['createdAt'] != null
              ? DateTime.parse(savedAnalysis['createdAt'] as String)
              : null;
        }

        // 해당 기간의 일기 데이터 가져오기
        entries = LocalDiaryService.getDiariesByDateRange(sixMonthsAgo, today);
      }

      if (analysisData != null) {
        // 기존 분석 결과가 있는 경우, 신규/수정된 일기 확인
        if (analysisCreatedAt != null) {
          // 분석 결과 생성일 이후에 등록/수정된 일기가 있는지 확인
          for (final entry in entries) {
            // updatedAt 또는 createdAt이 분석 결과 생성일보다 늦으면 재분석 필요
            if (entry.updatedAt.isAfter(analysisCreatedAt)) {
              needsReanalysis = true;
              print(
                  '🔄 신규 수정된 일기 발견 (updatedAt: ${entry.updatedAt} > analysisCreatedAt: $analysisCreatedAt)');
              break;
            } else if (entry.createdAt.isAfter(analysisCreatedAt)) {
              needsReanalysis = true;
              print(
                  '🔄 신규 등록된 일기 발견 (createdAt: ${entry.createdAt} > analysisCreatedAt: $analysisCreatedAt)');
              break;
            }
          }
        } else {
          // createdAt이 없으면 재분석
          needsReanalysis = true;
        }

        if (!needsReanalysis) {
          // 기존 데이터 사용
          aiAdvice = analysisData['advice'] ?? '분석할 데이터가 없습니다.';
          print('✅ 기존 분석 결과 사용 (재분석 불필요)');
        }
      } else {
        // 기존 분석 결과가 없으면 분석 필요
        needsReanalysis = true;
      }

      if (needsReanalysis) {
        // AI 분석 필요
        print('🔄 AI 재분석 시작...');

        // 로딩 다이얼로그 표시
        if (!mounted) return;
        showCupertinoDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) => CupertinoAlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CupertinoActivityIndicator(
                  radius: 20,
                ),
                const SizedBox(height: 16),
                Text(
                  'AI 일기 분석 중...',
                  style: GoogleFonts.gaegu(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '잠시만 기다려주세요',
                  style: GoogleFonts.gaegu(
                    fontSize: 14,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
              ],
            ),
          ),
        );

        try {
          // 날짜별 감정 색상 매핑 및 감정 정보 수집
          final Map<String, String> emotionMap = {};

          for (final entry in entries) {
            final dateStr =
                '${entry.date.year}-${entry.date.month.toString().padLeft(2, '0')}-${entry.date.day.toString().padLeft(2, '0')}';

            if (entry.moodAnalysis != null &&
                entry.moodAnalysis!.emotions.isNotEmpty) {
              emotionMap[dateStr] = entry.moodAnalysis!.emotions[0];
            }
          }

          // AI 기간별 분석 실행
          if (emotionMap.isNotEmpty) {
            aiAdvice = await _aiService.analyzeMoodPeriod(emotionMap);

            // 분석 결과 저장 (플랫폼에 따라)
            if (kIsWeb) {
              // 웹: Firebase에 저장
              await FirebaseFirestore.instance
                  .collection('diaries')
                  .doc(user.uid)
                  .collection('period_analysis')
                  .doc('6M_$periodKey')
                  .set({
                'period': '6M',
                'startDate': Timestamp.fromDate(sixMonthsAgo),
                'endDate': Timestamp.fromDate(today),
                'advice': aiAdvice,
                'createdAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              });
            } else {
              // 모바일: Hive에 저장
              await LocalDiaryService.savePeriodAnalysis('6M_$periodKey', {
                'period': '6M',
                'startDate': sixMonthsAgo.toIso8601String(),
                'endDate': today.toIso8601String(),
                'advice': aiAdvice,
                'createdAt': DateTime.now().toIso8601String(),
                'updatedAt': DateTime.now().toIso8601String(),
              });
            }
            print('✅ AI 재분석 완료 및 저장');
          } else {
            aiAdvice = '분석할 데이터가 없습니다.';
          }
        } finally {
          // 로딩 다이얼로그 닫기
          if (mounted) {
            Navigator.of(context).pop();
          }
        }
      }

      if (!mounted) return;

      // 무드 맵 생성 (그리드 표시용)
      final Map<String, Color> moodMap = {};
      for (final entry in entries) {
        final dateStr =
            '${entry.date.year}-${entry.date.month.toString().padLeft(2, '0')}-${entry.date.day.toString().padLeft(2, '0')}';

        if (entry.moodAnalysis != null &&
            entry.moodAnalysis!.emotions.isNotEmpty) {
          moodMap[dateStr] = _getEmotionColor(entry.moodAnalysis!.emotions[0]);
        }
      }

      if (!mounted) return;

      // 새 화면 표시
      showCupertinoModalPopup(
        context: context,
        builder: (BuildContext context) => CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
            middle: Text(
              '지난 6개월 감정',
              style: GoogleFonts.gaegu(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            leading: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.pop(context),
              child: const Icon(
                CupertinoIcons.back,
                color: AppColors.primary,
                size: 24,
              ),
            ),
          ),
          child: SafeArea(
            child: CupertinoScrollbar(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _build6MonthMoodGrid(moodMap, context),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey6,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _cleanAiAdvice(aiAdvice),
                        style: GoogleFonts.gaegu(
                          fontSize: 15,
                          color: CupertinoColors.label,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showCupertinoDialog(
        context: context,
        builder: (BuildContext context) => CupertinoAlertDialog(
          title: Text(
            '오류',
            style: GoogleFonts.gaegu(fontSize: 17),
          ),
          content: Text(
            '데이터를 불러올 수 없습니다.',
            style: GoogleFonts.gaegu(fontSize: 15),
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('확인'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    }
  }

  // 6개월 감정 그리드 표시
  Widget _build6MonthMoodGrid(
      Map<String, Color> moodMap, BuildContext popupContext) {
    final today = DateTime.now();
    final sixMonthsAgo = DateTime(today.year, today.month - 5, 1);

    // 월별로 그룹화된 데이터 생성
    final months = <Map<String, dynamic>>[];
    DateTime currentMonth = DateTime(sixMonthsAgo.year, sixMonthsAgo.month, 1);

    // 월별 데이터 생성 (오늘 달도 전체 표시)
    while (currentMonth.isBefore(today) ||
        (currentMonth.year == today.year &&
            currentMonth.month == today.month)) {
      final monthDays = <DateTime>[];
      final firstDay = DateTime(currentMonth.year, currentMonth.month, 1);
      final lastDay = DateTime(currentMonth.year, currentMonth.month + 1, 0);

      for (int i = 1; i <= lastDay.day; i++) {
        final day = DateTime(currentMonth.year, currentMonth.month, i);
        // 모든 날짜 포함 (미래 날짜도 표시)
        monthDays.add(day);
      }

      months.add({
        'year': currentMonth.year,
        'month': currentMonth.month,
        'days': monthDays,
      });

      currentMonth = DateTime(currentMonth.year, currentMonth.month + 1, 1);
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: months.length,
      itemBuilder: (context, monthIndex) {
        final monthData = months[monthIndex];
        final year = monthData['year'] as int;
        final month = monthData['month'] as int;
        final days = monthData['days'] as List<DateTime>;

        // 1달 = 2줄, 1줄 = 16개
        final rows = <List<DateTime>>[];
        for (int i = 0; i < days.length; i += 16) {
          rows.add(
              days.sublist(i, i + 16 > days.length ? days.length : i + 16));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...rows.asMap().entries.map((rowEntry) {
              final rowIndex = rowEntry.key;
              final row = rowEntry.value;
              final firstDate = row.first;
              final yearShort = (firstDate.year % 100).toString();
              final monthStr = firstDate.month.toString();
              final isFirstRow = rowIndex == 0;

              return Padding(
                padding: EdgeInsets.only(
                  bottom: 2,
                  top: isFirstRow && monthIndex > 0 ? 12 : 0,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 65,
                      child: isFirstRow
                          ? Text(
                              "'$yearShort년 $monthStr월",
                              style: GoogleFonts.gaegu(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: CupertinoColors.label,
                              ),
                              overflow: TextOverflow.visible,
                            )
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        children: List.generate(16, (index) {
                          if (index < row.length) {
                            final date = row[index];
                            final dateStr =
                                '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                            final color = moodMap[dateStr];

                            return Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  // 팝업 닫기
                                  Navigator.pop(popupContext);
                                  // 해당 날짜로 이동
                                  setState(() {
                                    _selectedDate = date;
                                    _displayMonth =
                                        DateTime(date.year, date.month);
                                  });
                                  await _loadDiaryForDate(date);
                                },
                                child: Container(
                                  height: 20,
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 1),
                                  decoration: BoxDecoration(
                                    color: color ?? CupertinoColors.systemGrey5,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            );
                          } else {
                            return Expanded(
                              child: Container(
                                height: 20,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 1),
                              ),
                            );
                          }
                        }),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }

  // 1년 무드 화면 표시
  Future<void> _show1YearMood() async {
    final user = _authService.getCurrentUser();
    if (user == null) return;

    // 모바일 환경에서 HIVE가 초기화되지 않았으면 초기화
    if (!kIsWeb) {
      try {
        await _initializeHiveForUser();
      } catch (e) {
        print('⚠️ HIVE 초기화 실패: $e');
        if (!mounted) return;
        showCupertinoDialog(
          context: context,
          builder: (BuildContext context) => CupertinoAlertDialog(
            title: Text(
              '오류',
              style: GoogleFonts.gaegu(fontSize: 17),
            ),
            content: Text(
              '데이터를 불러올 수 없습니다.',
              style: GoogleFonts.gaegu(fontSize: 15),
            ),
            actions: [
              CupertinoDialogAction(
                child: const Text('확인'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
        return;
      }
    }

    // 1년 전 날짜부터 오늘까지의 데이터 가져오기
    final today = DateTime.now();
    final oneYearAgo = DateTime(today.year, today.month - 11, 1);
    final periodKey =
        '${oneYearAgo.year}-${oneYearAgo.month.toString().padLeft(2, '0')}-${today.year}-${today.month.toString().padLeft(2, '0')}';

    try {
      String aiAdvice = '분석할 데이터가 없습니다.';
      bool needsReanalysis = false;
      List<DiaryEntry> entries = [];
      Map<String, dynamic>? analysisData;
      DateTime? analysisCreatedAt;

      if (kIsWeb) {
        // 웹: Firebase 사용
        // 기존 분석 결과 확인
        final analysisDoc = await FirebaseFirestore.instance
            .collection('diaries')
            .doc(user.uid)
            .collection('period_analysis')
            .doc('1Y_$periodKey')
            .get();

        // 해당 기간의 일기 데이터 가져오기
        final entriesSnapshot = await FirebaseFirestore.instance
            .collection('diaries')
            .doc(user.uid)
            .collection('entries')
            .where('date',
                isGreaterThanOrEqualTo: Timestamp.fromDate(oneYearAgo))
            .orderBy('date', descending: false)
            .get();

        // DiaryEntry 리스트로 변환
        entries = entriesSnapshot.docs.map((doc) {
          final data = doc.data();
          return DiaryEntry.fromFirestore(data, doc.id);
        }).toList();

        if (analysisDoc.exists) {
          analysisData = analysisDoc.data();
          analysisCreatedAt = analysisData?['createdAt'] != null
              ? (analysisData!['createdAt'] as Timestamp).toDate()
              : null;
        }
      } else {
        // 모바일: Hive 사용
        // 기존 분석 결과 확인
        final savedAnalysis =
            LocalDiaryService.loadPeriodAnalysis('1Y_$periodKey');
        if (savedAnalysis != null) {
          analysisData = savedAnalysis;
          analysisCreatedAt = savedAnalysis['createdAt'] != null
              ? DateTime.parse(savedAnalysis['createdAt'] as String)
              : null;
        }

        // 해당 기간의 일기 데이터 가져오기
        entries = LocalDiaryService.getDiariesByDateRange(oneYearAgo, today);
      }

      if (analysisData != null) {
        // 기존 분석 결과가 있는 경우, 신규/수정된 일기 확인
        if (analysisCreatedAt != null) {
          // 분석 결과 생성일 이후에 등록/수정된 일기가 있는지 확인
          for (final entry in entries) {
            // updatedAt 또는 createdAt이 분석 결과 생성일보다 늦으면 재분석 필요
            if (entry.updatedAt.isAfter(analysisCreatedAt)) {
              needsReanalysis = true;
              print(
                  '🔄 신규 수정된 일기 발견 (updatedAt: ${entry.updatedAt} > analysisCreatedAt: $analysisCreatedAt)');
              break;
            } else if (entry.createdAt.isAfter(analysisCreatedAt)) {
              needsReanalysis = true;
              print(
                  '🔄 신규 등록된 일기 발견 (createdAt: ${entry.createdAt} > analysisCreatedAt: $analysisCreatedAt)');
              break;
            }
          }
        } else {
          // createdAt이 없으면 재분석
          needsReanalysis = true;
        }

        if (!needsReanalysis) {
          // 기존 데이터 사용
          aiAdvice = analysisData['advice'] ?? '분석할 데이터가 없습니다.';
          print('✅ 기존 분석 결과 사용 (재분석 불필요)');
        }
      } else {
        // 기존 분석 결과가 없으면 분석 필요
        needsReanalysis = true;
      }

      if (needsReanalysis) {
        // AI 분석 필요
        print('🔄 AI 재분석 시작...');

        // 로딩 다이얼로그 표시
        if (!mounted) return;
        showCupertinoDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) => CupertinoAlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CupertinoActivityIndicator(
                  radius: 20,
                ),
                const SizedBox(height: 16),
                Text(
                  'AI 일기 분석 중...',
                  style: GoogleFonts.gaegu(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '잠시만 기다려주세요',
                  style: GoogleFonts.gaegu(
                    fontSize: 14,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
              ],
            ),
          ),
        );

        try {
          // 날짜별 감정 색상 매핑 및 감정 정보 수집
          final Map<String, String> emotionMap = {};

          for (final entry in entries) {
            final dateStr =
                '${entry.date.year}-${entry.date.month.toString().padLeft(2, '0')}-${entry.date.day.toString().padLeft(2, '0')}';

            if (entry.moodAnalysis != null &&
                entry.moodAnalysis!.emotions.isNotEmpty) {
              emotionMap[dateStr] = entry.moodAnalysis!.emotions[0];
            }
          }

          // AI 기간별 분석 실행
          if (emotionMap.isNotEmpty) {
            aiAdvice = await _aiService.analyzeMoodPeriod(emotionMap);

            // 분석 결과 저장 (플랫폼에 따라)
            if (kIsWeb) {
              // 웹: Firebase에 저장
              await FirebaseFirestore.instance
                  .collection('diaries')
                  .doc(user.uid)
                  .collection('period_analysis')
                  .doc('1Y_$periodKey')
                  .set({
                'period': '1Y',
                'startDate': Timestamp.fromDate(oneYearAgo),
                'endDate': Timestamp.fromDate(today),
                'advice': aiAdvice,
                'createdAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              });
            } else {
              // 모바일: Hive에 저장
              await LocalDiaryService.savePeriodAnalysis('1Y_$periodKey', {
                'period': '1Y',
                'startDate': oneYearAgo.toIso8601String(),
                'endDate': today.toIso8601String(),
                'advice': aiAdvice,
                'createdAt': DateTime.now().toIso8601String(),
                'updatedAt': DateTime.now().toIso8601String(),
              });
            }
            print('✅ AI 재분석 완료 및 저장');
          } else {
            aiAdvice = '분석할 데이터가 없습니다.';
          }
        } finally {
          // 로딩 다이얼로그 닫기
          if (mounted) {
            Navigator.of(context).pop();
          }
        }
      }

      if (!mounted) return;

      // 무드 맵 생성 (그리드 표시용)
      final Map<String, Color> moodMap = {};
      for (final entry in entries) {
        final dateStr =
            '${entry.date.year}-${entry.date.month.toString().padLeft(2, '0')}-${entry.date.day.toString().padLeft(2, '0')}';

        if (entry.moodAnalysis != null &&
            entry.moodAnalysis!.emotions.isNotEmpty) {
          moodMap[dateStr] = _getEmotionColor(entry.moodAnalysis!.emotions[0]);
        }
      }

      if (!mounted) return;

      // 새 화면 표시
      showCupertinoModalPopup(
        context: context,
        builder: (BuildContext context) => CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
            middle: Text(
              '지난 1년 감정',
              style: GoogleFonts.gaegu(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            leading: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.pop(context),
              child: const Icon(
                CupertinoIcons.back,
                color: AppColors.primary,
                size: 24,
              ),
            ),
          ),
          child: SafeArea(
            child: CupertinoScrollbar(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _build1YearMoodGrid(moodMap, context),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey6,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _cleanAiAdvice(aiAdvice),
                        style: GoogleFonts.gaegu(
                          fontSize: 15,
                          color: CupertinoColors.label,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showCupertinoDialog(
        context: context,
        builder: (BuildContext context) => CupertinoAlertDialog(
          title: Text(
            '오류',
            style: GoogleFonts.gaegu(fontSize: 17),
          ),
          content: Text(
            '데이터를 불러올 수 없습니다.',
            style: GoogleFonts.gaegu(fontSize: 15),
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('확인'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    }
  }

  // 1년 감정 그리드 표시
  Widget _build1YearMoodGrid(
      Map<String, Color> moodMap, BuildContext popupContext) {
    final today = DateTime.now();
    final oneYearAgo = DateTime(today.year, today.month - 11, 1);

    // 월별로 그룹화된 데이터 생성
    final months = <Map<String, dynamic>>[];
    DateTime currentMonth = DateTime(oneYearAgo.year, oneYearAgo.month, 1);

    // 월별 데이터 생성 (오늘 달도 전체 표시)
    while (currentMonth.isBefore(today) ||
        (currentMonth.year == today.year &&
            currentMonth.month == today.month)) {
      final monthDays = <DateTime>[];
      final firstDay = DateTime(currentMonth.year, currentMonth.month, 1);
      final lastDay = DateTime(currentMonth.year, currentMonth.month + 1, 0);

      for (int i = 1; i <= lastDay.day; i++) {
        final day = DateTime(currentMonth.year, currentMonth.month, i);
        // 모든 날짜 포함 (미래 날짜도 표시)
        monthDays.add(day);
      }

      months.add({
        'year': currentMonth.year,
        'month': currentMonth.month,
        'days': monthDays,
      });

      currentMonth = DateTime(currentMonth.year, currentMonth.month + 1, 1);
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: months.length,
      itemBuilder: (context, monthIndex) {
        final monthData = months[monthIndex];
        final year = monthData['year'] as int;
        final month = monthData['month'] as int;
        final days = monthData['days'] as List<DateTime>;

        // 1달 = 2줄, 1줄 = 16개
        final rows = <List<DateTime>>[];
        for (int i = 0; i < days.length; i += 16) {
          rows.add(
              days.sublist(i, i + 16 > days.length ? days.length : i + 16));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...rows.asMap().entries.map((rowEntry) {
              final rowIndex = rowEntry.key;
              final row = rowEntry.value;
              final firstDate = row.first;
              final yearShort = (firstDate.year % 100).toString();
              final monthStr = firstDate.month.toString();
              final isFirstRow = rowIndex == 0;

              return Padding(
                padding: EdgeInsets.only(
                  bottom: 2,
                  top: isFirstRow && monthIndex > 0 ? 12 : 0,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 65,
                      child: isFirstRow
                          ? Text(
                              "'$yearShort년 $monthStr월",
                              style: GoogleFonts.gaegu(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: CupertinoColors.label,
                              ),
                              overflow: TextOverflow.visible,
                            )
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        children: List.generate(16, (index) {
                          if (index < row.length) {
                            final date = row[index];
                            final dateStr =
                                '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                            final color = moodMap[dateStr];

                            return Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  // 팝업 닫기
                                  Navigator.pop(popupContext);
                                  // 해당 날짜로 이동
                                  setState(() {
                                    _selectedDate = date;
                                    _displayMonth =
                                        DateTime(date.year, date.month);
                                  });
                                  await _loadDiaryForDate(date);
                                },
                                child: Container(
                                  height: 20,
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 1),
                                  decoration: BoxDecoration(
                                    color: color ?? CupertinoColors.systemGrey5,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            );
                          } else {
                            return Expanded(
                              child: Container(
                                height: 20,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 1),
                              ),
                            );
                          }
                        }),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }

  /// 같은 날의 다른 년도 일기 표시
  Future<void> _showSameDayDiary() async {
    final user = _authService.getCurrentUser();
    if (user == null) return;

    try {
      // 현재 선택된 날짜의 월/일만 추출
      final currentMonth = _selectedDate.month;
      final currentDay = _selectedDate.day;

      // 같은 월/일의 일기 찾기
      List<DiaryEntry> sameDayEntriesList = [];

      if (kIsWeb) {
        // 웹: Firebase 사용
        final snapshot = await FirebaseFirestore.instance
            .collection('diaries')
            .doc(user.uid)
            .collection('entries')
            .get();

        final allEntries = snapshot.docs.map((doc) {
          final data = doc.data();
          return DiaryEntry.fromFirestore(data, doc.id);
        }).toList();

        // 같은 월/일 필터링
        sameDayEntriesList = allEntries
            .where((entry) =>
                entry.date.month == currentMonth &&
                entry.date.day == currentDay)
            .toList();
      } else {
        // 모바일: Hive 사용 (효율적인 메서드 사용)
        sameDayEntriesList =
            LocalDiaryService.getDiariesByMonthDay(currentMonth, currentDay);
        print('📦 Hive에서 같은 날짜 일기 ${sameDayEntriesList.length}개 발견');
      }

      final sameDayEntries = <Map<String, dynamic>>[];
      for (final entry in sameDayEntriesList) {
        sameDayEntries.add({
          'year': entry.date.year,
          'date': entry.date,
          'content': entry.content,
          'moodAnalysis': entry.moodAnalysis != null
              ? {
                  'emotions': entry.moodAnalysis!.emotions,
                  'moodWeights': entry.moodAnalysis!.moodWeights,
                  'advice': entry.moodAnalysis!.advice,
                }
              : null,
        });
      }

      // 년도순 정렬 (과거 → 최신, 과거 일기가 상단에 표시)
      sameDayEntries
          .sort((a, b) => (a['year'] as int).compareTo(b['year'] as int));

      if (!mounted) return;

      // 새 화면 표시
      showCupertinoModalPopup(
        context: context,
        builder: (BuildContext context) => CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
            middle: Text(
              '$currentMonth월 $currentDay일의 추억',
              style: GoogleFonts.gaegu(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            leading: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.pop(context),
              child: const Icon(
                CupertinoIcons.back,
                color: AppColors.primary,
                size: 24,
              ),
            ),
          ),
          child: SafeArea(
            child: sameDayEntries.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          CupertinoIcons.calendar,
                          size: 60,
                          color: CupertinoColors.systemGrey3,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '아직 이날 기록이 없네요',
                          style: GoogleFonts.gaegu(
                            fontSize: 16,
                            color: CupertinoColors.secondaryLabel,
                          ),
                        ),
                      ],
                    ),
                  )
                : CupertinoScrollbar(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: sameDayEntries.length,
                      itemBuilder: (context, index) {
                        final entry = sameDayEntries[index];
                        final year = entry['year'] as int;
                        final content = entry['content'] as String;
                        final moodAnalysis =
                            entry['moodAnalysis'] as Map<String, dynamic>?;

                        // 감정 색상 가져오기
                        Color? emotionColor;
                        if (moodAnalysis != null) {
                          final emotions = moodAnalysis['emotions'] as List?;
                          if (emotions != null && emotions.isNotEmpty) {
                            final mainEmotion = emotions[0] as String;
                            emotionColor = _getEmotionColor(mainEmotion);
                          }
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: emotionColor != null
                                ? emotionColor.withOpacity(0.3)
                                : CupertinoColors.systemGrey6,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$year년',
                                style: GoogleFonts.gaegu(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                content,
                                style: GoogleFonts.gaegu(
                                  fontSize: 15,
                                  color: CupertinoColors.label,
                                  height: 1.5,
                                ),
                              ),
                              if (moodAnalysis != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: CupertinoColors.white,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        CupertinoIcons.heart_fill,
                                        size: 20,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _cleanAiAdvice(
                                              moodAnalysis['advice'] ?? ''),
                                          style: GoogleFonts.gaegu(
                                            fontSize: 13,
                                            color: CupertinoColors.label,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showCupertinoDialog(
        context: context,
        builder: (BuildContext context) => CupertinoAlertDialog(
          title: Text(
            '오류',
            style: GoogleFonts.gaegu(fontSize: 17),
          ),
          content: Text(
            '데이터를 불러올 수 없습니다.',
            style: GoogleFonts.gaegu(fontSize: 15),
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('확인'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    }
  }

  /// 년월 선택 피커 표시
  void _showYearMonthPicker() {
    final int currentYear = _displayMonth.year;
    final int currentMonth = _displayMonth.month;

    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => Container(
        height: 300,
        color: CupertinoColors.systemBackground,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              // 타이틀 바
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: CupertinoColors.systemGrey6,
                  border: Border(
                    bottom: BorderSide(
                      color: CupertinoColors.separator,
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        '취소',
                        style: GoogleFonts.gaegu(
                          fontSize: 16,
                          color: CupertinoColors.destructiveRed,
                        ),
                      ),
                    ),
                    Text(
                      '년월 선택',
                      style: GoogleFonts.gaegu(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () async {
                        // 선택한 년월로 업데이트
                        // _displayMonth는 이미 년도/월 선택 시 업데이트됨
                        setState(() {
                          // 선택한 년월의 유효한 날짜로 설정
                          final lastDayOfMonth = DateTime(_displayMonth.year,
                                  _displayMonth.month + 1, 0)
                              .day;
                          final day = _selectedDate.day > lastDayOfMonth
                              ? lastDayOfMonth
                              : _selectedDate.day;
                          _selectedDate = DateTime(
                              _displayMonth.year, _displayMonth.month, day);
                        });
                        // 년/월 변경 시 일기 날짜 목록 다시 로드
                        await _loadDiaryDates();
                        await _loadDiaryForDate(_selectedDate);
                        Navigator.pop(context);
                      },
                      child: Text(
                        '확인',
                        style: GoogleFonts.gaegu(
                          fontSize: 16,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // 스크롤 선택 영역
              Expanded(
                child: Row(
                  children: [
                    // 년도 선택
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: FixedExtentScrollController(
                          initialItem: currentYear - 2000,
                        ),
                        itemExtent: 44.0,
                        children: List.generate(30, (index) {
                          final year = 2000 + index;
                          final isSelected = year == currentYear;
                          return Center(
                            child: Text(
                              '$year년',
                              style: GoogleFonts.gaegu(
                                fontSize: isSelected ? 18 : 16,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: isSelected
                                    ? AppColors.primary
                                    : CupertinoColors.label,
                              ),
                            ),
                          );
                        }),
                        onSelectedItemChanged: (int index) {
                          final year = 2000 + index;
                          setState(() {
                            // 현재 선택된 월(_displayMonth.month)을 사용
                            _displayMonth = DateTime(year, _displayMonth.month);
                          });
                        },
                      ),
                    ),
                    // 월 선택
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: FixedExtentScrollController(
                          initialItem: currentMonth - 1,
                        ),
                        itemExtent: 44.0,
                        children: List.generate(12, (index) {
                          final month = index + 1;
                          final isSelected = month == currentMonth;
                          return Center(
                            child: Text(
                              '$month월',
                              style: GoogleFonts.gaegu(
                                fontSize: isSelected ? 18 : 16,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: isSelected
                                    ? AppColors.primary
                                    : CupertinoColors.label,
                              ),
                            ),
                          );
                        }),
                        onSelectedItemChanged: (int index) {
                          final month = index + 1;
                          setState(() {
                            // 현재 선택된 년도(_displayMonth.year)를 사용
                            _displayMonth = DateTime(_displayMonth.year, month);
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// AI 조언에서 정체성 문구 제거
  String _cleanAiAdvice(String advice) {
    // AI, 심리상담사, 상담사 등의 정체성 언급 제거
    String cleaned = advice
        .replaceAll(RegExp(r'심리상담사(?:\s+입장에서)?'), '')
        .replaceAll(RegExp(r'상담사(?:\s+입장에서)?'), '')
        .replaceAll(RegExp(r'AI(?:\s+입장에서)?'), '')
        .replaceAll(RegExp(r'인공지능(?:\s+입장에서)?'), '')
        .replaceAll(RegExp(r'전문가(?:\s+입장에서)?'), '')
        .trim();

    // 연속된 공백 정리
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');

    // 문장 시작 부분의 불필요한 구두점 제거
    cleaned = cleaned.replaceAll(RegExp(r'^[,\\.\\s]+'), '');

    return cleaned;
  }
}
