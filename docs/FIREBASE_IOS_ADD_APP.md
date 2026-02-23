# Firebase에 iOS 앱(com.idosquare.feelog) 추가하기

현재 프로젝트 번들 ID는 **com.idosquare.feelog**인데, Firebase에는 **com.example.voicetales**로 등록된 iOS 앱만 있어 Apple 로그인 등이 동작하지 않을 수 있습니다. 아래 순서대로 진행하세요.

---

## 1. Firebase Console에서 iOS 앱 추가

1. [Firebase Console](https://console.firebase.google.com/) 접속 후 **feelog** 프로젝트 선택
2. **프로젝트 설정**(휴지통 옆 톱니바퀴) 클릭
3. **일반** 탭에서 아래로 내려가 **내 앱** 영역 확인
4. **앱 추가** → **iOS(iOS+)** 선택
5. **Apple 번들 ID**에 아래를 **그대로** 입력:
   ```
   com.idosquare.feelog
   ```
6. 앱 닉네임(예: Feelog iOS), App Store ID는 선택 사항
7. **앱 등록** 클릭

---

## 2. GoogleService-Info.plist 다운로드 및 배치

1. 등록 직후 나오는 **GoogleService-Info.plist 다운로드** 버튼 클릭
2. 다운로드한 파일을 프로젝트의 **ios/Runner/** 폴더에 복사  
   (경로: `feelog/ios/Runner/GoogleService-Info.plist`)
3. Xcode에서 Runner 타깃에 해당 파일이 포함되어 있는지 확인 (보통 자동으로 추가됨)

---

## 3. FlutterFire로 firebase_options 갱신

터미널에서 프로젝트 루트(`feelog`)로 이동한 뒤:

**방법 A – 전역 설치 후 실행 (권장)**

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

**방법 B – 프로젝트에서 실행**

```bash
dart run flutterfire_cli:flutterfire configure
```

- iOS 플랫폼이 나오면 **com.idosquare.feelog** 번들 ID를 가진 앱을 선택
- 완료되면 `lib/firebase_options.dart`가 새 iOS 앱 설정으로 갱신됩니다

> ⚠️ `dart run flutterfire_cli:configure`는 사용하지 마세요. `configure`가 아니라 `flutterfire configure`입니다.

---

## 4. Apple 로그인 사용 시 추가 확인

- **Authentication** → **Sign-in method** → **Apple** 사용 설정
- **Firebase Console** 프로젝트 설정 → **내 앱**에서 방금 추가한 iOS 앱(com.idosquare.feelog)이 보이면 정상입니다.

이후 앱을 다시 빌드해서 실행해 보세요.
