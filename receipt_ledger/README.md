# 코드 리뷰

## 1. `main.dart`
- `WidgetsFlutterBinding.ensureInitialized()` 호출 후 바로 `runApp` 으로 앱 실행.
- `ProviderScope` 안에 `ReceiptLedgerApp()` 으로 Flutter‑Riverpod 사용.
- `MaterialApp`에서 `theme`과 `darkTheme`를 지정하고 `themeMode`를 `themeModeProvider` 값에 따라 전환.
- `MainNavigationScreen`에서 `IndexedStack` + `NavigationBar` 로 탭 전환 구현.
- `initState`에서 `addPostFrameCallback` 으로 `_performAutoSync`530라 전환.
- `MainNavigationScreen`에서 `IndexedStack` + `NavigationBar` 로 탭 전환 구현.
- `initState`에서 `addPostFrameCallback` 으로 `_performAutoSync` 와 `_initNotificationMonitoring` 실행.
- `dispose` 에 `_notificationService.dispose()` 호출.

## 2. `local_ocr_service.dart`
- `platform` import 로 `dart.library.io` 가 있을 때 `local_ocr_service_native.dart` 를 사용.
- `LocalOcrService` 클래스는 `platform.LocalOcrServiceImpl` 인스턴스를 생성.
- `initialize`, `parseReceiptFromBytes`, `dispose` 를 래핑.

## 3. `local_ocr_service_native.dart`
- `llama_cpp_dart` 를 이용해 Vision 모델 로딩.
- `initialize` : 파일 존재/크기 확인, `LlamaParent` 생성.
- `parseReceiptFromBytes` : 이미지를 base64 인코딩 후 ChatML 프롬프트를 전송.
- `_runInference` : 스트림을 수신해 JSON 문자열 완성 후 반환.
- `_parseJson` : 문자열에서 JSON 객체를 추출.
- `dispose` : 스트림 취소, isolate 종료.

## 4. `receipt.dart`
- `ReceiptData` 와 `ReceiptItem` 모델.
- `fromSllmResponse` : 다양한 키 이름을 지원.
- 날짜 파싱 로직이 두 가지 패턴을 시도.

## 5. 전반적인 점검 사항
- **파일 경로**: `main.dart` 에 `import 'app.dart'` 가 있는데 `app.dart` 경로가 `lib/app.dart` 이므로 문제 없음.
- **다중 호출**: `initState` 에서 `addPostFrameCallback` 으로 두 메서드 호출 – 비동기 실행 시 `await` 로 순차 처리 필요 여부 검토.
- **에러 처리**: `parseReceiptFromBytes` 에서 `try-catch` 로 에러를 다시 던짐. 호출 측911 호출**: `initState` 에서 `addPostFrameCallback` 으로 두 메서드 호출 – 비동기 실행 시 `await` 로 순차 처리 필요 여부 검토.
- **에러 처리**: `parseReceiptFromBytes` 에서 `try-catch` 로 에러를 다시 던짐. 호출 측에서 처리해야 함.
- **메모리**: `StreamSubscription` 이 `dispose` 에서 cancel되며 `LlamaParent` 도 stop.
- **테스트**: `test` 폴더에 `widget_test.dart` 가 존재하지만 실제 테스트 케이스가 적은 것 같음.
- **코드 정리**: `local_ocr_service_native.dart` 가 길어 가독성 좋게 파일 분할 가능.
- **상수 사용**: 모델/프로젝트 파일 경로 문자열이 하드코딩되어 있음.
- **비동기 로딩**: `isLoading` 플래그를 UI에서 보여줄 수 있도록 `riverpod` provider 로 노출하면 좋음.
