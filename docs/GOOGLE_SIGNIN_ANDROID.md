# Android Google 로그인 설정 (ApiException: 10 해결)

Google 로그인 시 `ApiException: 10` (DEVELOPER_ERROR)이 나오면 **패키지 com.idosquare.feelogdiary** 에 대한 **SHA-1**(및 Play 배포 시 **Play 앱 서명 키**의 SHA)이 Firebase에 등록되지 않은 경우입니다.

## 1. 디버그 키스토어 SHA-1 (현재 프로젝트)

```
SHA-1: D7:FF:21:75:E3:58:F5:84:02:06:6B:EE:E8:DC:4D:9F:FD:6F:C8:91
```

(소문자로 입력해도 됨: `d7ff2175e358f58402066beee8dc4d9ffd6fc891`)

## 2. Firebase Console에 SHA-1 등록 (필수)

1. [Firebase Console](https://console.firebase.google.com) → 프로젝트 **feelog-997bc** 선택  
2. **프로젝트 설정** (톱니바퀴) → **내 앱**  
3. **Android** 앱 중 **패키지 이름이 com.idosquare.feelogdiary 인 앱** 선택  
   - 없으면 **앱 추가** → **Android** → 패키지 이름 `com.idosquare.feelogdiary` 입력 후 앱 등록  
4. 해당 앱에서 **SHA 인증서 지문 추가** (또는 "지문 추가") 클릭  
5. **SHA-1** 란에 아래 값 입력 후 저장  
   `D7:FF:21:75:E3:58:F5:84:02:06:6B:EE:E8:DC:4D:9F:FD:6F:C8:91`  
6. **google-services.json** 다시 다운로드  
   - 같은 화면에서 **google-services.json** 다운로드 후  
   - 프로젝트의 `android/app/google-services.json` 을 **덮어쓰기**  
7. 앱 완전 종료 후 다시 실행하고 Google 로그인 재시도  

**주의:** 예전 패키지(`com.idosquare.feelog` 등)가 아니라 **com.idosquare.feelogdiary** Android 앱에 SHA-1/256을 추가해야 합니다. **Play 스토어 배포 빌드**에는 Play Console → 앱 무결성에 표시된 **앱 서명 키** 지문 등록이 필수입니다.

## 3. 적용된 코드 설정

- **Web Client ID** (`app_secret.dart`): Firebase용 웹 클라이언트 ID 사용 중 (`client_type 3`).
- Android에서는 `serverClientId`로 위 Web Client ID를 사용해 Firebase Auth와 연동합니다.

---

**릴리스 빌드** 시에는 **릴리스 키스토어의 SHA-1**도 동일하게 Firebase에 추가해야 합니다.
