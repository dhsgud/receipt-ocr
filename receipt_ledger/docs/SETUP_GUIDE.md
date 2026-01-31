# AdMob 및 RevenueCat 설정 가이드

이 문서는 Receipt Ledger 앱의 인앱 결제 및 광고 시스템을 활성화하기 위한 상세 설정 가이드입니다.

---

## 📋 목차

1. [RevenueCat 설정](#1-revenuecat-설정)
2. [Google AdMob 설정](#2-google-admob-설정)
3. [Android 설정](#3-android-설정)
4. [iOS 설정](#4-ios-설정)
5. [코드 수정 필요 사항](#5-코드-수정-필요-사항)

---

## 1. RevenueCat 설정

### 1.1 RevenueCat 대시보드 설정

1. **계정 생성**: https://app.revenuecat.com 에서 계정 생성

2. **프로젝트 생성**:
   - "Create Project" 클릭
   - 프로젝트 이름: `Receipt Ledger`

3. **앱 추가**:
   - iOS: App Store Connect에서 앱 연결
   - Android: Google Play Console에서 앱 연결

4. **API 키 복사**:
   - Settings → API Keys
   - **Public API Key** 복사

### 1.2 Entitlement 생성

RevenueCat 대시보드에서 아래 2개의 Entitlement를 생성합니다:

| Entitlement ID | 설명 |
|----------------|------|
| `basic` | Basic 등급 (₩1,900/월) |
| `pro` | Pro 등급 (₩4,900/월) |

**생성 방법**:
1. Project → Entitlements → "+ New"
2. Identifier: `basic` 입력
3. 동일하게 `pro` 생성

### 1.3 상품 생성

각 스토어(App Store / Google Play)에서 아래 상품 ID로 구독 상품을 생성합니다:

| 상품 ID | 유형 | 가격 |
|---------|------|------|
| `basic_monthly` | 월간 구독 | ₩1,900 |
| `basic_yearly` | 연간 구독 | ₩19,000 |
| `pro_monthly` | 월간 구독 | ₩4,900 |
| `pro_yearly` | 연간 구독 | ₩49,000 |
| `lifetime` | 비소모성 (평생) | ₩59,000 |

### 1.4 Offering 설정

RevenueCat 대시보드에서:
1. Offerings → "default" offering 생성
2. 생성한 상품들을 Offering에 추가
3. 각 상품을 해당 Entitlement에 연결:
   - `basic_monthly`, `basic_yearly` → `basic` Entitlement
   - `pro_monthly`, `pro_yearly`, `lifetime` → `pro` Entitlement

### 1.5 코드에 API 키 적용

`lib/core/entitlements.dart` 파일에서:

```dart
// 테스트 키를 실제 키로 변경
const String revenueCatApiKey = 'appl_XXXXXXXXXXXXXXXXXXXXXXXX'; // 실제 API 키
```

---

## 2. Google AdMob 설정

### 2.1 AdMob 계정 설정

1. **계정 생성**: https://admob.google.com 에서 계정 생성

2. **앱 등록**:
   - Apps → "Add App"
   - Android와 iOS 각각 등록

3. **App ID 복사**:
   - 앱 설정에서 **App ID** 복사 (형식: `ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY`)

### 2.2 광고 단위 생성

각 앱(Android/iOS)에서 배너 광고 단위를 생성합니다:

1. Apps → 앱 선택 → Ad units → "Add ad unit"
2. **Banner** 선택
3. 이름: `home_banner` 등으로 설정
4. **Ad unit ID** 복사 (형식: `ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY`)

### 2.3 코드에 광고 ID 적용

`lib/core/entitlements.dart` 파일의 `AdConfig` 클래스에서:

```dart
class AdConfig {
  /// 테스트 배너 광고 ID (개발용) - 그대로 유지
  static const String testBannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
  
  /// 실제 배너 광고 ID (프로덕션) - 아래를 실제 ID로 변경
  static const String bannerAdUnitIdAndroid = 'ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY';
  static const String bannerAdUnitIdIos = 'ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY';
}
```

---

## 3. Android 설정

### 3.1 AndroidManifest.xml 수정

`android/app/src/main/AndroidManifest.xml` 파일에 AdMob App ID 추가:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
        android:label="receipt_ledger"
        ...>
        
        <!-- AdMob App ID 추가 (REQUIRED) -->
        <meta-data
            android:name="com.google.android.gms.ads.APPLICATION_ID"
            android:value="ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY"/>
        
        <!-- 기존 내용들... -->
    </application>
</manifest>
```

> ⚠️ **주의**: `ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY`를 AdMob에서 복사한 실제 App ID로 교체하세요.

### 3.2 build.gradle 확인

`android/app/build.gradle`에서 minSdk가 21 이상인지 확인:

```gradle
android {
    defaultConfig {
        minSdk = 21  // 최소 21 이상
    }
}
```

---

## 4. iOS 설정

### 4.1 Info.plist 수정

`ios/Runner/Info.plist` 파일에 AdMob App ID 추가:

```xml
<dict>
    <!-- 기존 내용들... -->
    
    <!-- AdMob App ID 추가 (REQUIRED) -->
    <key>GADApplicationIdentifier</key>
    <string>ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY</string>
    
    <!-- SKAdNetwork ID 추가 (광고 추적용) -->
    <key>SKAdNetworkItems</key>
    <array>
        <dict>
            <key>SKAdNetworkIdentifier</key>
            <string>cstr6suwn9.skadnetwork</string>
        </dict>
    </array>
</dict>
```

### 4.2 iOS 배포 타겟 확인

`ios/Podfile`에서 최소 버전 확인:

```ruby
platform :ios, '12.0'  # 최소 12.0 이상
```

---

## 5. 코드 수정 필요 사항

### 5.1 entitlements.dart 수정 체크리스트

| 항목 | 현재 값 | 변경 필요 |
|------|---------|----------|
| `revenueCatApiKey` | `test_XrYkyXGIFqID...` | ✅ 실제 API 키로 변경 |
| `bannerAdUnitIdAndroid` | `ca-app-pub-XXXX...` | ✅ 실제 광고 ID로 변경 |
| `bannerAdUnitIdIos` | `ca-app-pub-XXXX...` | ✅ 실제 광고 ID로 변경 |

### 5.2 파일 위치

```
lib/core/entitlements.dart   ← API 키 및 광고 ID
android/app/src/main/AndroidManifest.xml   ← Android AdMob App ID
ios/Runner/Info.plist   ← iOS AdMob App ID
```

---

## 📌 테스트 방법

### 개발 중 테스트

1. **광고 테스트**: 
   - `kDebugMode`에서는 자동으로 테스트 광고 ID 사용
   - 실제 광고 ID로 테스트 시 테스트 기기 등록 필요

2. **구독 테스트**:
   - RevenueCat 대시보드에서 Sandbox 사용자 추가
   - iOS: TestFlight 빌드 사용
   - Android: Internal 테스트 트랙 사용

### 프로덕션 배포 전

1. RevenueCat API 키가 Production 키인지 확인
2. AdMob 광고 ID가 실제 프로덕션 ID인지 확인
3. 스토어 심사 정책 준수 확인

---

## ❓ 문제 해결

### 광고가 표시되지 않는 경우

1. AdMob App ID가 올바르게 설정되었는지 확인
2. 인터넷 연결 확인
3. AdMob 대시보드에서 앱 상태 확인

### 구독이 작동하지 않는 경우

1. RevenueCat API 키 확인
2. 상품 ID가 스토어와 일치하는지 확인
3. Entitlement 연결 확인
