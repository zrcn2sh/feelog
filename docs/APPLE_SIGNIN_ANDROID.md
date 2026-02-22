# Android Apple 로그인 설정 및 오류

## "invalid_client" / "Invalid client" 오류

Apple 로그인 화면(appleid.apple.com)에서 **invalid_client**가 나오면, **Service ID가 Apple Developer에 없거나 설정이 잘못된 경우**입니다.

**해결:** 아래 "Apple Developer – Service ID" 절차대로 **Service ID를 새로 만들고**, Identifier를 **정확히** `com.idosquare.feelog.service`로 두고, **Sign In with Apple**을 켠 뒤 **Return URL**을 등록해야 합니다.

---

## 코드에서 처리한 오류

- **사용자 취소**: 로그인 실패 대화상자 없이 로그인 화면 유지 (`null` 반환)
- **미지원 기기** (`SignInWithAppleNotSupportedException`): "이 기기에서는 Apple 로그인을 사용할 수 없습니다." 안내
- **설정 오류** (redirect/clientId/invalid/configuration): Service ID와 Return URL 확인 안내 메시지

## Android에서 Apple 로그인이 동작하려면

Android는 **웹 기반** Apple 로그인을 사용하므로 아래 설정이 필요합니다.

### 1. Apple Developer – Service ID

1. [Apple Developer](https://developer.apple.com/account) → **Identifiers** → **Services IDs** → **+** 로 새로 만들기
2. **Description**: 예) `Feelog Android`
3. **Identifier**: `com.idosquare.feelog.service` (코드의 Service ID와 동일해야 함)
4. **Sign In with Apple** 활성화 → **Configure** 클릭
5. **Return URL**에 아래 주소 **정확히** 등록:
   ```
   https://feelog-997bc.firebaseapp.com/__/auth/handler
   ```
6. 저장

### 2. Firebase Console

1. **Authentication** → **Sign-in method** → **Apple** 사용 설정
2. **Android** 설정에서 **Service ID**: `com.idosquare.feelog.service` 입력
3. Apple Developer에서 발급한 **Team ID**, **Key ID**, **Private Key** 등록

### 3. Return URL 요약

| 항목 | 값 |
|------|-----|
| **Return URL** | `https://feelog-997bc.firebaseapp.com/__/auth/handler` |
| **Service ID** | `com.idosquare.feelog.service` |

Return URL은 반드시 위와 같아야 하며, Firebase 프로젝트 ID(`feelog-997bc`)가 포함됩니다.

---

## "Unable to process request due to missing initial state" 오류

Firebase 화면(`-997bc.firebaseapp.com`)에서 **missing initial state** 메시지가 나오는 경우입니다.

**원인**  
Android에서 Apple 로그인 시 **Chrome Custom Tab**(인앱 브라우저)을 사용하는데, Apple에서 Firebase로 리다이렉트될 때 **sessionStorage**가 비어 있거나 접근되지 않아, Firebase가 처음 저장해 둔 상태를 찾지 못할 때 발생합니다. (리다이렉트 기반 로그인에서 알려진 현상입니다.)

**해결 순서**

1. **Firebase 인증 도메인 확인**  
   [Firebase Console](https://console.firebase.google.com) → **Authentication** → **Settings** (설정) → **Authorized domains**  
   - `feelog-997bc.firebaseapp.com` 이 목록에 있는지 확인하고, 없으면 **도메인 추가**로 넣어 주세요.

2. **한두 번 다시 시도**  
   탭/저장소 상태에 따라 동작할 수 있으므로, Apple 로그인을 다시 시도해 보세요.

3. **기기/브라우저**  
   일부 Android 기기나 인앱 브라우저에서는 이 오류가 자주 날 수 있습니다. 가능하면 **다른 기기**나 **시크릿/일반 브라우저**에서 한 번 시도해 볼 수 있습니다.

4. **Apple 로그인은 iOS에서 사용**  
   Android에서는 웹 플로우 특성상 이 오류가 나는 경우가 있어, Apple 로그인은 **iOS**에서 주로 사용하는 방식으로 안내하는 것도 방법입니다.
