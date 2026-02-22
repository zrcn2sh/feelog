# Firebase Google 인증 - SHA-1 지문 추가 방법

Android에서 Google 로그인이 동작하려면 앱 서명용 **SHA-1**(및 권장: SHA-256) 지문을 Firebase 프로젝트에 등록해야 합니다.

---

## ⚠️ "access_token audience is not for this project" / 로그인 실패 시

**원인:** 앱이 사용하는 **서명 키(SHA-1)** 와 **Firebase 프로젝트에 등록된 SHA-1**이 다르거나,  
다른 Firebase/Google 프로젝트용으로 발급된 토큰을 현재 프로젝트에서 쓰고 있을 때 발생합니다.

**Android에서 할 일:**

1. **Firebase 콘솔** → 프로젝트 **feelog-997bc** → 프로젝트 설정 → **Android 앱** (`com.example.feelog_app`) 선택.
2. **디지털 지문**에 아래 **SHA-1**이 반드시 등록되어 있는지 확인. 없으면 **지문 추가**로 넣기.
   - `D7:FF:21:75:E3:58:F5:84:02:06:6B:EE:E8:DC:4D:9F:FD:6F:C8:91`
3. **google-services.json** 다시 다운로드 후 `android/app/google-services.json` 에 덮어쓰기.
4. 앱 **클린 빌드** 후 재설치:  
   `flutter clean` → `flutter pub get` → `flutter run`

**웹에서 로그인할 때:** `auth_service.dart` 의 웹용 `clientId` 가 **feelog-997bc** 의 웹 클라이언트 ID인지 확인.  
(Firebase 콘솔 → 프로젝트 설정 → 내 앱 → 웹 앱 → SDK 설정 및 구성에서 확인 가능)

---

## 프로젝트 전용 디버그 키 (SHA-1 중복 방지)

이 프로젝트는 **전역** `~/.android/debug.keystore` 대신 **프로젝트 전용** `android/app/feelog_debug.keystore` 를 사용합니다.  
다른 앱/프로젝트와 SHA-1이 겹치지 않도록 하기 위함입니다.

- Keystore: `android/app/feelog_debug.keystore`
- 비밀번호: `android` / alias: `androiddebugkey`
- 팀원과 같은 SHA-1을 쓰려면 이 keystore 파일을 저장소에 포함하면 됩니다. (민감하게 다루고 싶으면 `.gitignore`에 추가)

---

## 현재 프로젝트 디버그 키 지문 (Firebase에 등록할 값)

아래 값을 Firebase 콘솔 → 프로젝트 설정 → Android 앱 → 디지털 지문에 등록하세요.

| 항목 | 값 |
|------|-----|
| **SHA-1** | `D7:FF:21:75:E3:58:F5:84:02:06:6B:EE:E8:DC:4D:9F:FD:6F:C8:91` |
| **SHA-256** | `DA:23:A2:4F:35:68:D6:2D:9E:5C:00:C7:84:91:E0:69:34:92:C3:06:20:E7:E8:27:19:53:1C:8D:61:7B:47:B3` |

> 나중에 **릴리스 전용 keystore**를 쓰면, 그 키의 SHA-1/SHA-256도 Firebase에 추가로 등록해야 합니다.

---

## 1. SHA-1 지문 확인하기

### 방법 A: Gradle로 확인 (권장)

프로젝트 루트(`feelog_app`)에서:

```powershell
cd android
.\gradlew signingReport
```

출력에서 **Variant: debug** / **Variant: release** 각각의  
`SHA1:` 줄을 복사합니다.  
**SHA-256**도 함께 등록하면 좋습니다.

### 방법 B: keytool로 확인

**이 프로젝트 디버그 키** (`android/app/feelog_debug.keystore`):

```powershell
keytool -list -v -keystore android\app\feelog_debug.keystore -alias androiddebugkey -storepass android -keypass android
```

(프로젝트 루트 `feelog_app` 에서 실행)

**전역 디버그 키 (다른 프로젝트용):**

```powershell
keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

**릴리스 키 (배포용):**

릴리스 keystore 파일이 있을 때:

```powershell
keytool -list -v -keystore "경로\your-release-key.jks" -alias your-key-alias
```

비밀번호 입력 후 출력에서 `SHA1:` 과 `SHA256:` 을 확인합니다.

---

## 2. Firebase 콘솔에 SHA-1 등록

1. **Firebase 콘솔** 접속  
   https://console.firebase.google.com/

2. 프로젝트 선택 (예: **feelog-997bc**).

3. **프로젝트 설정** (톱니바퀴) → **일반** 탭.

4. 아래로 내려가 **"내 앱"** 섹션에서 **Android 앱** (`com.example.feelog_app`) 선택.  
   (없으면 **앱 추가** → Android → 패키지 이름 `com.example.feelog_app` 로 등록 후 진행.)

5. **"디지털 지문"** 섹션에서 **"지문 추가"** 클릭.

6. 위에서 복사한 **SHA-1** 붙여넣기 → 저장.  
   (선택) **SHA-256**도 같은 방식으로 추가.

7. **google-services.json**  
   - Android 앱이 새로 추가되었거나 지문을 처음 넣었다면, **google-services.json**을 다시 다운로드해  
     `feelog_app/android/app/google-services.json` 에 덮어쓰기.

---

## 3. 등록해야 할 지문 정리

| 용도     | 키 저장소                    | 등록 시점                    |
|----------|-----------------------------|-----------------------------|
| 개발/테스트 | `~/.android/debug.keystore` | 디버그 빌드로 로그인 테스트 시 |
| 앱 배포  | 본인 릴리스 keystore (.jks) | Play Store 등 배포 전       |

- **디버그만** 쓸 때: 디버그 키의 SHA-1만 등록해도 됩니다.
- **출시 앱**도 Google 로그인 사용 시: **릴리스 키의 SHA-1**(및 SHA-256)을 반드시 추가해야 합니다.

---

## 4. 릴리스 키 만들기 (아직 없는 경우)

1. 키 저장소 생성:

```powershell
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

2. 생성된 `upload-keystore.jks` 의 SHA-1 확인:

```powershell
keytool -list -v -keystore upload-keystore.jks -alias upload
```

3. 이 SHA-1(및 SHA-256)을 Firebase **디지털 지문**에 추가.

4. `android/key.properties` 생성 및 `android/app/build.gradle` 에서 이 keystore로 release 서명하도록 설정하면, 실제 출시 빌드와 Firebase에 등록한 지문이 일치합니다.

---

## 5. 등록 후 확인

- 앱 삭제 후 재설치하거나, **로그아웃** 후 다시 Google 로그인.
- 여전히 실패하면:  
  - Firebase 콘솔의 SHA-1/ SHA-256 오타 여부,  
  - 올바른 Android 앱(같은 패키지명)에 등록했는지,  
  - **google-services.json** 최신 버전으로 교체했는지 확인.
