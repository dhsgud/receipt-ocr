# Receipt Ledger - 프로젝트 현황 보고서

## 📊 구현 완료 항목

### ✅ 등급제 구독 시스템

| 구현 항목 | 상태 | 파일 |
|----------|------|------|
| 3-tier 등급 구조 (Free/Basic/Pro) | ✅ 완료 | `entitlements.dart` |
| 일일/월간 쿼터 시스템 | ✅ 완료 | `quota_service.dart` |
| 쿼터 자동 리셋 (일/월) | ✅ 완료 | `quota_service.dart` |
| Free 등급 10회 제한 | ✅ 완료 | `quota_service.dart` |
| 결제 필수 다이얼로그 | ✅ 완료 | `receipt_screen.dart` |

### ✅ Google AdMob 광고

| 구현 항목 | 상태 | 파일 |
|----------|------|------|
| AdMob 서비스 초기화 | ✅ 완료 | `ad_service.dart` |
| 배너 광고 위젯 | ✅ 완료 | `banner_ad_widget.dart` |
| 홈 화면 배너 | ✅ 완료 | `home_screen.dart` |
| 통계 화면 배너 | ✅ 완료 | `statistics_screen.dart` |
| 구독자 광고 제거 | ✅ 완료 | `banner_ad_widget.dart` |

### ✅ RevenueCat IAP

| 구현 항목 | 상태 | 파일 |
|----------|------|------|
| RevenueCat SDK 통합 | ✅ 완료 | `purchase_service.dart` |
| 등급별 Entitlement 처리 | ✅ 완료 | `purchase_service.dart` |
| Paywall UI | ✅ 완료 | `subscription_screen.dart` |
| 구매 복원 | ✅ 완료 | `purchase_service.dart` |

---

## ⚠️ 설정 필요 항목 (수동 작업)

### 1. RevenueCat 설정

| 작업 | 위치 | 상태 |
|------|------|------|
| RevenueCat 계정 생성 | https://app.revenuecat.com | ❌ 미완료 |
| `basic` Entitlement 생성 | RevenueCat 대시보드 | ❌ 미완료 |
| `pro` Entitlement 생성 | RevenueCat 대시보드 | ❌ 미완료 |
| App Store 상품 생성 | App Store Connect | ❌ 미완료 |
| Google Play 상품 생성 | Google Play Console | ❌ 미완료 |
| API 키 교체 | `lib/core/entitlements.dart` | ❌ 미완료 |

### 2. Google AdMob 설정

| 작업 | 위치 | 상태 |
|------|------|------|
| AdMob 계정 생성 | https://admob.google.com | ❌ 미완료 |
| Android 앱 등록 | AdMob 대시보드 | ❌ 미완료 |
| iOS 앱 등록 | AdMob 대시보드 | ❌ 미완료 |
| 배너 광고 단위 생성 | AdMob 대시보드 | ❌ 미완료 |
| Android App ID 추가 | `AndroidManifest.xml` | ❌ 미완료 |
| iOS App ID 추가 | `Info.plist` | ❌ 미완료 |
| 광고 ID 교체 | `lib/core/entitlements.dart` | ❌ 미완료 |

---

## 📁 생성된 파일 목록

### 새로 생성된 파일

```
lib/data/services/quota_service.dart     ← 쿼터 관리
lib/data/services/ad_service.dart        ← 광고 서비스
lib/shared/widgets/banner_ad_widget.dart ← 배너 광고 위젯
docs/SETUP_GUIDE.md                      ← 설정 가이드
```

### 수정된 파일

```
lib/core/entitlements.dart               ← 등급/쿼터/광고 설정
lib/data/services/purchase_service.dart  ← 등급 기반 구독
lib/app.dart                             ← 서비스 초기화
lib/features/home/home_screen.dart       ← 배너 광고 추가
lib/features/statistics/statistics_screen.dart ← 배너 광고 추가
lib/features/receipt/receipt_screen.dart ← 쿼터 제한 + 결제 다이얼로그
```

---

## 🔧 코드 수정 필요 위치

### `lib/core/entitlements.dart`

```dart
// 12번 줄 - RevenueCat API 키 교체
const String revenueCatApiKey = 'test_XrYkyXGIFqID...';
//                               ↓
const String revenueCatApiKey = 'appl_실제_API_키';

// 149-150번 줄 - AdMob 광고 ID 교체
static const String bannerAdUnitIdAndroid = 'ca-app-pub-XXXXX/XXXXX';
static const String bannerAdUnitIdIos = 'ca-app-pub-XXXXX/XXXXX';
```

### `android/app/src/main/AndroidManifest.xml`

```xml
<!-- <application> 태그 안에 추가 -->
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-XXXXX~XXXXX"/>
```

### `ios/Runner/Info.plist`

```xml
<!-- <dict> 태그 안에 추가 -->
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-XXXXX~XXXXX</string>
```

---

## 📋 다음 단계 체크리스트

1. [ ] RevenueCat 계정 생성 및 프로젝트 설정
2. [ ] RevenueCat에 `basic`, `pro` Entitlement 생성
3. [ ] App Store Connect에서 구독 상품 5개 생성
4. [ ] Google Play Console에서 구독 상품 5개 생성
5. [ ] RevenueCat API 키를 코드에 적용
6. [ ] AdMob 계정 생성 및 앱 등록
7. [ ] 배너 광고 단위 생성 (Android/iOS)
8. [ ] AndroidManifest.xml에 App ID 추가
9. [ ] Info.plist에 App ID 추가
10. [ ] 광고 ID를 코드에 적용
11. [ ] 실제 기기에서 테스트
12. [ ] 스토어 출시

---

## 📖 참고 문서

- [설정 가이드](file:///Users/jinhan/Desktop/receipt-ocr/receipt_ledger/docs/SETUP_GUIDE.md) - 상세 설정 방법
- RevenueCat 문서: https://docs.revenuecat.com
- AdMob 문서: https://developers.google.com/admob/flutter/quick-start
