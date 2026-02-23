import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

import '../config/app_secret.dart';
import 'local_diary_service.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Android: serverClientId 필요(Firebase가 idToken 검증용). 웹: clientId 필요.
  static GoogleSignIn _googleSignInForPlatform() {
    if (kIsWeb) {
      return GoogleSignIn(
        clientId: AppSecret.googleWebClientId,
        scopes: ['email', 'profile'],
      );
    }
    if (Platform.isAndroid) {
      return GoogleSignIn(
        serverClientId: AppSecret.googleWebClientId,
        scopes: ['email', 'profile'],
      );
    }
    return GoogleSignIn(scopes: ['email', 'profile']);
  }

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

      final GoogleSignIn googleSignIn = _googleSignInForPlatform();

      print(
          '✅ GoogleSignIn 인스턴스 생성 완료 (${kIsWeb ? "웹" : Platform.isAndroid ? "Android(serverClientId)" : "iOS"})');

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

  /// Apple 로그인용 nonce 생성 (재전송 공격 방지)
  static String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  static String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Android용 Apple 로그인 웹 옵션 (Service ID는 Apple Developer에서 생성 후 Firebase Console에 등록)
  static const String _appleServiceId = 'com.idosquare.feelog.service';
  static Uri get _appleRedirectUri =>
      Uri.parse('https://feelog-997bc.firebaseapp.com/__/auth/handler');

  /// Apple 로그인 (Firebase Auth 연동). iOS 13+, Android(선택), 웹은 별도 설정 필요.
  Future<UserCredential?> signInWithApple() async {
    try {
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      // Android에서는 webAuthenticationOptions 필수 (Service ID + Firebase redirect URI)
      final webOptions = (!kIsWeb && Platform.isAndroid)
          ? WebAuthenticationOptions(
              clientId: _appleServiceId,
              redirectUri: _appleRedirectUri,
            )
          : null;

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
        webAuthenticationOptions: webOptions,
      );

      final idToken = appleCredential.identityToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception(
          'Apple 로그인 응답이 올바르지 않습니다. '
          '다시 시도하거나, Apple Developer / Firebase의 Apple 로그인 설정을 확인해 주세요.',
        );
      }

      // Firebase가 Apple 토큰 검증 시 idToken + rawNonce + authorizationCode(accessToken) 사용
      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: idToken.trim(),
        rawNonce: rawNonce.trim(),
        accessToken: appleCredential.authorizationCode?.trim() ?? '',
      );

      final userCredential = await _auth.signInWithCredential(oauthCredential);
      final user = userCredential.user;

      if (user != null) {
        // Apple은 최초 1회만 fullName/email 전달. 없으면 기존 Firebase 프로필 유지
        final name = appleCredential.givenName != null || appleCredential.familyName != null
            ? '${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}'.trim()
            : null;
        if (name != null && name.isNotEmpty && user.displayName == null) {
          await user.updateDisplayName(name);
        }
        if (appleCredential.email != null &&
            appleCredential.email!.isNotEmpty &&
            user.email == null) {
          // email은 updateEmail 시 재인증 필요할 수 있어 프로필만 업데이트
        }
        await _updateUserProfile(user);
        await _saveUserInfo(user);
      }

      return userCredential;
    } on SignInWithAppleAuthorizationException catch (e) {
      // 사용자 취소 또는 Apple 측 권한 오류
      print('❌ Apple 로그인 AuthorizationException: code=${e.code}, message=${e.message}');
      if (e.code == AuthorizationErrorCode.canceled) {
        return null; // 취소는 실패가 아니므로 null 반환 (로그인 화면 유지)
      }
      // iOS에서 자주 나오는 코드: unknown(1000), failed(1001), invalidResponse(1002), notHandled(1003)
      if (!kIsWeb && Platform.isIOS) {
        throw Exception(
          'Apple 로그인에 실패했어요. '
          'Apple Developer에서 App ID(com.idosquare.feelog)에 "Sign in with Apple"이 켜져 있는지, '
          'Xcode에서 Runner → Signing & Capabilities에 Sign in with Apple이 추가되어 있는지 확인해 주세요.',
        );
      }
      throw Exception('Apple 로그인 실패: ${e.message}');
    } on SignInWithAppleNotSupportedException catch (_) {
      throw Exception('이 기기에서는 Apple 로그인을 사용할 수 없습니다.');
    } catch (error, stackTrace) {
      final msg = error.toString().toLowerCase();
      print('❌ Apple 로그인 오류: $error');
      print('스택: $stackTrace');
      if (!kIsWeb && Platform.isIOS) {
        // iOS 전용: 설정/권한 문제 안내
        if (msg.contains('1000') || msg.contains('1001') || msg.contains('not handled') || msg.contains('failed')) {
          throw Exception(
            'Apple 로그인이 처리되지 않았어요. '
            'Apple Developer → Identifiers → App ID(com.idosquare.feelog)에서 Sign in with Apple 사용 설정, '
            'Xcode에서 프로젝트에 동일 Capability 추가 후 프로비저닝 프로필을 다시 받아보세요.',
          );
        }
      }
      if (!kIsWeb && Platform.isAndroid) {
        // Apple 페이지에서 "invalid_client" → Service ID 미등록 또는 설정 오류
        if (msg.contains('invalid_client') || msg.contains('invalid client')) {
          throw Exception(
            'Apple 로그인 "Invalid client" 오류입니다. '
            'Apple Developer에서 Services IDs로 이동해, '
            'Identifier가 com.idosquare.feelog.service 인 Service ID를 만들고 '
            'Sign In with Apple을 켠 뒤 Return URL을 등록해 주세요. (자세한 내용은 docs/APPLE_SIGNIN_ANDROID.md 참고)',
          );
        }
        // 웹 인증 옵션 누락 (코드 오류 시)
        if (msg.contains('webauthenticationoptions') && msg.contains('must be provided')) {
          throw Exception('Apple 로그인 설정 오류입니다. 앱을 업데이트해 주세요.');
        }
        // redirect / clientId / 설정 관련 오류
        if (msg.contains('redirect') || msg.contains('clientid') || msg.contains('invalid') || msg.contains('configuration')) {
          throw Exception(
            'Apple 로그인 설정 오류입니다. '
            'Apple Developer에서 Service ID(com.idosquare.feelog.service)와 '
            'Return URL(https://feelog-997bc.firebaseapp.com/__/auth/handler)을 확인해 주세요.',
          );
        }
      }
      throw Exception('Apple 로그인 실패: $error');
    }
  }

  // 로그아웃
  Future<void> signOut() async {
    try {
      final GoogleSignIn googleSignIn = _googleSignInForPlatform();

      await _auth.signOut();
      await googleSignIn.signOut();
      await _clearUserInfo();
    } catch (error) {
      throw Exception('로그아웃 실패: $error');
    }
  }

  /// 계정 탈퇴: Firestore·로컬 데이터 삭제 후 Firebase Auth 계정 삭제
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('로그인된 사용자가 없습니다.');

    final uid = user.uid;

    try {
      // 1. Firestore 일기 subcollection 삭제 (diaries/{uid}/entries)
      final entriesRef = _firestore.collection('diaries').doc(uid).collection('entries');
      var batch = _firestore.batch();
      var count = 0;
      final snap = await entriesRef.get();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
        count++;
        if (count >= 500) {
          await batch.commit();
          batch = _firestore.batch();
          count = 0;
        }
      }
      if (count > 0) await batch.commit();

      // 2. Firestore 사용자 문서 삭제
      await _firestore.collection('users').doc(uid).delete();

      // 3. 모바일: Hive 사용자 데이터 삭제
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        await LocalDiaryService.deleteUserData(uid);
      }

      // 4. Firebase Auth 계정 삭제
      await user.delete();

      // 5. 로컬 저장 정보 삭제 및 로그아웃
      await _clearUserInfo();
      try {
        final googleSignIn = _googleSignInForPlatform();
        await googleSignIn.signOut();
      } catch (_) {}
      await _auth.signOut();
    } catch (e) {
      throw Exception('계정 탈퇴에 실패했습니다. $e');
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
  Future<void> recordLoginHistory(User user, {String loginMethod = 'google'}) async {
    try {
      await _firestore.collection('loginHistory').add({
        'userId': user.uid,
        'email': user.email,
        'displayName': user.displayName,
        'loginTime': FieldValue.serverTimestamp(),
        'loginMethod': loginMethod,
      });
      print('로그인 이력이 기록되었습니다. ($loginMethod)');
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
