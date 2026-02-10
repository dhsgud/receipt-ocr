# 📋 관리자 설정 체크리스트

> 마지막 업데이트: 2026-02-10

---

## 🔴 반드시 설정 (Critical)

### 1. RevenueCat API 키 (프로덕션 교체)
- **파일**: `lib/core/entitlements.dart` (11번 줄)
- **이전**: `test_XrYkyXGIFqIDKMEuoLJElJcLUPb` ← 테스트 키
- **현재**: `goog_cmNZaYwgXEHhVCWWixvBbyGNIVI` ← Google Play 프로덕션 키
- [x] 완료 (2026-02-10)

### 2. Android 릴리즈 서명 키 (Keystore)
- **파일**: `android/app/build.gradle.kts` (37번 줄)
- **현재**: `signingConfig = signingConfigs.getByName("debug")` ← 디버그 키 사용 중
- **할 일**:
  - 릴리즈용 keystore 파일 생성
  - `key.properties` 파일 생성 (storePassword, keyPassword, keyAlias, storeFile)
  - `build.gradle.kts`에 릴리즈 서명 설정 추가
- [ ] 완료

### 3. AdMob 리워드 광고 ID 통일
- **문제**: `entitlements.dart`의 리워드 광고 ID가 아직 테스트 ID
  - `entitlements.dart:137` → `ca-app-pub-1570373945115921/5269593106` (실제 ID로 변경됨)
  - `ad_service.dart:12` → `ca-app-pub-1570373945115921/5269593106` (실제)
- **완료**: 두 파일 모두 실제 ID로 통일됨
- [x] 완료 (2026-02-10)

---

## 🟡 확인 필요 (Important)

### 4. 동기화/OCR 서버 URL (하드코딩)
현재 3곳에 IP가 하드코딩되어 있음:

| 파일 | 줄 | 현재 값 |
|------|-----|---------|
| `lib/core/constants/app_constants.dart` | 7 | `http://183.96.3.137:9999` |
| `lib/shared/providers/app_providers.dart` | 130 | `http://183.96.3.137:9999` |
| `lib/data/services/sllm_service.dart` | 28 | `http://183.96.3.137:9999` |

- **할 일**: 프로덕션 서버 주소로 변경 또는 환경별 설정 분리 검토
- [ ] 완료

### 6. CORS 설정 (보안)
- **파일**: `sync_server/ocr_server.py` (44번 줄)
- **현재**: `allow_origins=["*"]` ← 모든 출처 허용
- **할 일**: 프로덕션에서는 앱 도메인만 허용하도록 변경 권장
- [ ] 완료

### 7. iOS 광고 ID (테스트 → 실제)
- **파일**: `lib/data/services/ad_service.dart`
  - iOS 배너: `ca-app-pub-3940256099942544/2934735716` ← 테스트
  - iOS 리워드: `ca-app-pub-3940256099942544/1712485313` ← 테스트
- **할 일**: iOS 출시 시 실제 AdMob 광고 ID로 교체
- [ ] 완료

### 8. AdMob 테스트 디바이스 관리
- **파일**: `lib/data/services/ad_service.dart` (93번 줄)
- **현재**: `F84A7F5F2A7EBC7EDD9709EA35F339F2`
- **완료**: `bool.fromEnvironment('dart.vm.product')`를 사용하여 릴리즈 빌드에서 자동 비활성화되도록 수정함
- [x] 완료 (2026-02-10)

---

## 🟢 선택 사항 (Optional)

### 9. RevenueCat 상품 ID 확인
- **파일**: `lib/core/entitlements.dart`
- `basic_monthly`, `basic_yearly`, `lifetime`이 Google Play(receipt_ledger) / App Store에 동일하게 등록되었는지 확인
- **완료**: RevenueCat 대시보드에서 `receipt_ledger` 앱 생성 및 상품 매핑 완료
- [x] 완료 (2026-02-10)

### 10. 앱 버전 업데이트
- **파일**: `pubspec.yaml` (5번 줄)
- **현재**: `1.0.0+1`
- **할 일**: 출시 버전에 맞게 업데이트
- [ ] 완료

### 11. 서버 HTTPS 설정
- **현재**: HTTP 사용 중
- **할 일**: 프로덕션 환경에서 HTTPS + 리버스 프록시(nginx 등) 적용 권장
- [ ] 완료

### 12. 데이터베이스 백업
- **파일**: `sync_server/sync_data.db` (SQLite)
- **할 일**: 주기적 백업 스크립트 또는 크론잡 구성
- [ ] 완료

---

## 📁 관련 파일 요약

| 파일 | 주요 설정 항목 |
|------|---------------|
| `sync_server/.env` | API 키 (Gemini ✅, OpenAI, Anthropic 등) |
| `lib/core/entitlements.dart` | RevenueCat 키, AdMob ID, 구독/쿼터 설정 |
| `lib/core/constants/app_constants.dart` | 서버 URL, 앱 정보 |
| `lib/data/services/ad_service.dart` | 플랫폼별 광고 ID, 테스트 디바이스 |
| `android/app/build.gradle.kts` | 서명 설정, 앱 ID |
| `android/app/src/main/AndroidManifest.xml` | AdMob App ID ✅ |
