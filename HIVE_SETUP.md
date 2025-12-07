# Hive 설정 가이드

## 1. 패키지 설치

터미널에서 다음 명령어 실행:

```bash
flutter pub get
```

## 2. 코드 생성

Hive TypeAdapter를 생성하기 위해 build_runner 실행:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

또는 watch 모드로 실행 (파일 변경 시 자동 재생성):

```bash
flutter pub run build_runner watch --delete-conflicting-outputs
```

## 3. 생성된 파일 확인

`lib/models/diary_entry.g.dart` 파일이 생성되었는지 확인하세요.

## 4. LocalDiaryService 활성화

`lib/services/local_diary_service.dart` 파일에서 다음 주석을 해제:

```dart
if (!Hive.isAdapterRegistered(0)) {
  Hive.registerAdapter(DiaryEntryAdapter());
}
```

## 5. 테스트

앱을 실행하여 모바일 앱에서 로컬 저장이 정상 작동하는지 확인하세요.

## 주의사항

- 웹에서는 Hive가 작동하지 않으므로 Firebase를 사용합니다.
- 모바일 앱(Android/iOS)에서만 Hive가 활성화됩니다.
- `kIsWeb` 플래그로 플랫폼을 감지합니다.

