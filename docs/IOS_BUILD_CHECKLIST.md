# iOS(아이폰) 빌드 전 점검 사항

## 🔴 반드시 해결 후 빌드

### 1. GoogleService-Info.plist 없음
- **상태:** `ios/Runner/GoogleService-Info.plist` 파일이 프로젝트에 없음 (또는 .gitignore로 제외됨).
- **조치:**
  1. [Firebase 콘솔](https://console.firebase.google.com/) → 프로젝트 **feelog-997bc** 선택.
  2. 프로젝트 설정 → **내 앱** → **iOS 앱** (Bundle ID `com.example.voicetales` 또는 사용 중인 번들 ID) 선택.
  3. **GoogleService-Info.plist** 다운로드.
  4. 파일을 `feelog_app/ios/Runner/` 폴더에 복사.
- 이 파일이 없으면 Firebase 초기화/로그인 시 오류 또는 크래시 가능.

---

### 2. Info.plist – Google 로그인용 클라이언트 ID가 이전 프로젝트(voicetales) 것임
- **상태:** `ios/Runner/Info.plist`의 `GIDClientID`와 `CFBundleURLSchemes`가 **913437887294**(voicetales)용으로 설정됨. 현재 앱은 **feelog-997bc** 사용 중.
- **결과:** iOS에서 Google 로그인 시 `access_token audience is not for this project` 발생 가능.
- **조치:**
  1. **GoogleService-Info.plist**를 먼저 다운로드한 경우, 파일을 열어 `<key>CLIENT_ID</key>` 다음의 `<string>...</string>` 값이 iOS OAuth 클라이언트 ID입니다. 이 값을 Info.plist의 `GIDClientID`에 넣으면 됩니다.
  2. 또는 Firebase 콘솔 → feelog-997bc → 프로젝트 설정 → **내 앱** → **iOS 앱**에서 iOS 클라이언트 ID 확인.
  3. 또는 [Google Cloud Console](https://console.cloud.google.com/) → feelog-997bc 프로젝트 → **API 및 서비스** → **사용자 인증 정보** → **OAuth 2.0 클라이언트 ID** 중 **iOS** 타입의 클라이언트 ID 복사.
  4. `ios/Runner/Info.plist`에서:
     - `GIDClientID` 값을 위에서 복사한 **feelog-997bc iOS 클라이언트 ID**로 교체.
     - `CFBundleURLSchemes` 안의 URL 스킴을 교체: iOS 클라이언트 ID가 `539935166814-xxxxxxxxxx.apps.googleusercontent.com` 형태라면, 스킴은 `com.googleusercontent.apps.539935166814-xxxxxxxxxx` (하이픈 포함 전체)로 넣으면 됩니다.
  5. 저장 후 클린 빌드.

---

### 3. Bundle ID와 Firebase 등록 일치
- **현재:** Xcode `PRODUCT_BUNDLE_IDENTIFIER` = `com.example.voicetales`
- **확인:** Firebase feelog-997bc에 등록한 **iOS 앱의 번들 ID**가 `com.example.voicetales`와 **완전히 동일**한지 확인.
- **선택:** 앱 이름에 맞춰 `com.example.feelog_app` 등으로 바꾸려면, Xcode에서 Bundle ID 변경 후 Firebase에서도 동일한 번들 ID로 iOS 앱을 추가/등록하고, `firebase_options.dart`의 `iosBundleId`와 `GoogleService-Info.plist`를 새 앱 기준으로 다시 받아서 사용.

---

## 🟡 빌드/배포 전 확인 권장

### 4. 개발 팀 ID (DEVELOPMENT_TEAM)
- **현재:** `ios/Runner.xcodeproj/project.pbxproj`에 `DEVELOPMENT_TEAM = Z968VDYWB6` 설정됨.
- **확인:** 본인 Apple Developer 팀 ID가 `Z968VDYWB6`가 맞는지 확인. 다른 팀으로 서명하려면 Xcode에서 **Signing & Capabilities**에서 팀 변경하거나, pbxproj에서 `DEVELOPMENT_TEAM` 값 수정.

### 5. 서명(Signing)
- **현재:** Code Sign Style = Automatic, DEVELOPMENT_TEAM 설정됨.
- **확인:** 실제 기기/배포 시 Xcode에서 **Runner** 타깃 → **Signing & Capabilities**에서 올바른 팀과 프로비저닝 프로파일이 선택되는지 확인.

### 6. iOS 배포 타깃
- **현재:** `platform :ios, '13.0'` (Podfile), `IPHONEOS_DEPLOYMENT_TARGET = 13.0` (Xcode).  
- iOS 13 이상에서 동작. 필요 시 12 등으로 낮출 수 있으나, 사용 중인 플러그인 호환 여부 확인 필요.

---

## 🟢 참고 (이미 OK인 부분)

- **Podfile:** `platform :ios, '13.0'`, `use_frameworks!` 등 기본 설정 적절.
- **Info.plist:** 앱 이름(CFBundleDisplayName), 방향, Launch Storyboard 등 기본 항목 있음.
- **플랫폼 분기:** `kIsWeb` / `Platform.isIOS` 등으로 웹·iOS 분리되어 있어 iOS 빌드에 필요한 코드만 사용됨.
- **Firebase 옵션:** `lib/firebase_options.dart`의 iOS 항목은 이미 feelog-997bc 프로젝트용으로 설정됨 (GoogleService-Info.plist와 Info.plist만 feelog-997bc에 맞추면 됨).

---

## 빌드 전 한 번에 할 일 요약

1. **GoogleService-Info.plist** (feelog-997bc iOS 앱) → `ios/Runner/`에 추가.
2. **Info.plist**의 **GIDClientID**와 **CFBundleURLSchemes**를 feelog-997bc iOS OAuth 클라이언트 ID로 변경.
3. Firebase 콘솔에서 iOS 앱 번들 ID가 Xcode Bundle ID와 동일한지 확인.
4. 터미널에서:
   ```bash
   cd feelog_app
   flutter clean
   flutter pub get
   cd ios && pod install && cd ..
   flutter build ios
   ```
   또는 Xcode에서 **Runner** 스킴 선택 후 실제 기기 연결하여 Run.

이 체크리스트를 맞춘 뒤 빌드하면 iOS에서 Firebase 및 Google 로그인이 정상 동작할 가능성이 높습니다.
