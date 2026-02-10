# Receipt Ledger

## 아키텍처

### OCR 처리
- Gemini Vision API를 통한 영수증 이미지 분석
- `SllmService` → OCR 서버 (FastAPI + Gemini) 에 요청
- `ReceiptData.fromOcrResponse` : 다양한 키 이름을 지원하여 JSON 파싱

### 주요 구조
- `main.dart` : `ProviderScope` + `MaterialApp` + 탭 네비게이션
- `receipt_screen.dart` : 영수증 촬영/선택 → OCR → 거래 저장
- `sync_service.dart` : 서버와 데이터 동기화
- `receipt.dart` : `ReceiptData`, `ReceiptItem` 모델

### 점검 사항
- **에러 처리**: `parseReceiptFromBytes` 에서 `try-catch` 로 에러를 다시 던짐
- **테스트**: `test` 폴더에 `widget_test.dart` 존재
