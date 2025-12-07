import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
    ],
  );

  // Google 로그인 (Firebase Auth와 연동)
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // 플랫폼 감지 디버깅
      final bool isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
      print('═══════════════════════════════════════');
      print('🔐 Google 로그인 시작');
      print('   kIsWeb: $kIsWeb');
      if (!kIsWeb) {
        print('   Platform.isAndroid: ${Platform.isAndroid}');
        print('   Platform.isIOS: ${Platform.isIOS}');
      }
      print(
          '   플랫폼 타입: ${kIsWeb ? "웹" : (isMobile ? (Platform.isAndroid ? "안드로이드" : "iOS") : "기타")}');
      print('═══════════════════════════════════════');

      // 웹용 Google Sign-In 설정 (웹에서만 clientId 명시)
      // 모바일 앱에서는 google-services.json의 clientId를 자동으로 사용
      final GoogleSignIn googleSignIn = kIsWeb
          ? GoogleSignIn(
              clientId:
                  '913437887294-n7867hr9d8aomfeu54r00veso3l3dl72.apps.googleusercontent.com',
              scopes: ['email', 'profile'],
            )
          : _googleSignIn;

      print(
          '✅ GoogleSignIn 인스턴스 생성 완료 (${kIsWeb ? "웹 - clientId 명시" : "모바일 - google-services.json 사용"})');

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        return null; // 로그인 취소
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      if (userCredential.user != null) {
        await _updateUserProfile(userCredential.user!);
        await _saveUserInfo(userCredential.user!);
      }

      return userCredential;
    } catch (error) {
      throw Exception('Google 로그인 실패: $error');
    }
  }

  // 로그아웃
  Future<void> signOut() async {
    try {
      // 웹용 Google Sign-In 설정 (웹에서만 clientId 명시)
      // 모바일 앱에서는 google-services.json의 clientId를 자동으로 사용
      final GoogleSignIn googleSignIn = kIsWeb
          ? GoogleSignIn(
              clientId:
                  '913437887294-n7867hr9d8aomfeu54r00veso3l3dl72.apps.googleusercontent.com',
              scopes: ['email', 'profile'],
            )
          : _googleSignIn;

      await _auth.signOut();
      await googleSignIn.signOut();
      await _clearUserInfo();
    } catch (error) {
      throw Exception('로그아웃 실패: $error');
    }
  }

  // 현재 로그인된 사용자 정보 가져오기
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // 로그인 상태 확인
  bool isLoggedIn() {
    return _auth.currentUser != null;
  }

  // 사용자 프로필 정보 업데이트 (Firestore)
  Future<void> _updateUserProfile(User user) async {
    try {
      final userRef = _firestore.collection('users').doc(user.uid);

      final docSnapshot = await userRef.get();

      if (docSnapshot.exists) {
        // 기존 사용자 - 마지막 로그인 시간만 업데이트
        await userRef.update({
          'lastLoginAt': FieldValue.serverTimestamp(),
        });
        print('기존 사용자 로그인 시간 업데이트 완료');
      } else {
        // 신규 사용자 - 전체 프로필 생성
        await userRef.set({
          'uid': user.uid,
          'email': user.email,
          'displayName': user.displayName ?? '익명',
          'photoURL': user.photoURL,
          'userType': 'user',
          'totalCreatedStories': 0,
          'totalGeneratedCovers': 0,
          'totalDeletedStories': 0,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLoginAt': FieldValue.serverTimestamp(),
        });
        print('신규 사용자 프로필 생성 완료');
      }
    } catch (e) {
      print('사용자 프로필 업데이트 오류: $e');
    }
  }

  // 사용자 정보 로컬 저장
  Future<void> _saveUserInfo(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', user.uid);
    await prefs.setString('user_email', user.email ?? '');
    await prefs.setString('user_name', user.displayName ?? '');
    await prefs.setString('user_photo', user.photoURL ?? '');
  }

  // 사용자 정보 로컬에서 삭제
  Future<void> _clearUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('user_email');
    await prefs.remove('user_name');
    await prefs.remove('user_photo');
  }

  // 저장된 사용자 정보 가져오기
  Future<Map<String, String?>> getSavedUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'id': prefs.getString('user_id'),
      'email': prefs.getString('user_email'),
      'name': prefs.getString('user_name'),
      'photo': prefs.getString('user_photo'),
    };
  }

  // Firebase Auth에서 사용자 정보를 가져와서 SharedPreferences에 저장
  Future<void> saveUserInfoFromFirebase(User user) async {
    await _saveUserInfo(user);
  }

  // 로그인 이력을 Firestore에 기록
  Future<void> recordLoginHistory(User user) async {
    try {
      await _firestore.collection('loginHistory').add({
        'userId': user.uid,
        'email': user.email,
        'displayName': user.displayName,
        'loginTime': FieldValue.serverTimestamp(),
        'loginMethod': 'google',
      });
      print('로그인 이력이 기록되었습니다.');
    } catch (e) {
      print('로그인 이력 기록 오류: $e');
    }
  }

  // 사용자 통계 업데이트
  Future<void> updateUserStats(String actionType) async {
    try {
      final user = getCurrentUser();
      if (user == null) return;

      final userRef = _firestore.collection('users').doc(user.uid);
      final docSnapshot = await userRef.get();

      if (docSnapshot.exists) {
        final currentData = docSnapshot.data()!;
        final currentCreated = currentData['totalCreatedStories'] ?? 0;
        final currentDeleted = currentData['totalDeletedStories'] ?? 0;
        final currentCovers = currentData['totalGeneratedCovers'] ?? 0;

        Map<String, dynamic> updateData = {};

        if (actionType == 'created') {
          updateData['totalCreatedStories'] = currentCreated + 1;
        } else if (actionType == 'deleted') {
          updateData['totalDeletedStories'] = currentDeleted + 1;
        } else if (actionType == 'cover') {
          updateData['totalGeneratedCovers'] = currentCovers + 1;
        }

        await userRef.update(updateData);
      }
      print('사용자 통계 업데이트 완료: $actionType');
    } catch (e) {
      print('사용자 통계 업데이트 오류: $e');
    }
  }
}
