# iOS 결제 알림 자동 등록 구현 계획 (보류)

> **상태**: 보류 (향후 구현 예정)  
> **작성일**: 2026-01-14  
> **우선순위**: 낮음

## 배경

Android에서는 `NotificationListenerService`를 통해 다른 앱의 알림을 읽을 수 있지만, iOS에서는 Apple의 보안 정책(Sandboxing)으로 인해 **다른 앱의 알림을 읽는 것이 기술적으로 불가능**합니다.

## iOS 제한 사항

- 각 앱은 자신의 알림만 접근 가능
- `NotificationServiceExtension`은 자신의 앱 알림만 수정 가능
- 다른 앱(카드사, 페이 앱)의 알림에 접근 불가
- 이는 App Store 정책이 아닌 **iOS 운영체제 자체의 제한**

## 대안 방법 분석

### 1. 이메일 파싱 ⭐⭐⭐⭐ (권장)

**카드사들은 결제 시 이메일도 발송함**

```
[흐름]
카드 결제 → 카드사 이메일 발송 → Gmail/iCloud API → 앱에서 파싱
```

| 항목 | 내용 |
|------|------|
| 장점 | iOS/Android 모두 동일하게 작동, 공식 API 지원 (Gmail, Microsoft Graph) |
| 단점 | OAuth 로그인 필요, 1-5분 딜레이 |
| 구현 난이도 | 중간 |
| 필요 작업 | Gmail OAuth 연동, 이메일 본문 정규식 파싱 |

### 2. SMS 전달 (via Mac) ⭐⭐

**iPhone + Mac 연동 시 SMS를 Mac에서 읽을 수 있음**

```
[흐름]
카드 결제 SMS → iPhone → Mac (Messages 앱) → AppleScript/Python → 서버 → 앱
```

| 항목 | 내용 |
|------|------|
| 장점 | 실시간에 가까움 |
| 단점 | Mac이 항상 켜져 있어야 함, 설정 복잡 |
| 구현 난이도 | 높음 |

### 3. Shortcuts(단축어) 반자동화 ⭐⭐

**iOS 단축어 앱 활용**

```
[흐름]
사용자가 단축어 실행 → URL Scheme으로 앱 열기 → 클립보드/입력값 처리
```

| 항목 | 내용 |
|------|------|
| 장점 | App Store 승인 문제 없음 |
| 단점 | 완전 자동화 불가 (수동 실행 필요) |
| 구현 난이도 | 낮음 |

### 4. Share Extension (공유 시트) ⭐⭐⭐⭐ (권장)

**가장 현실적인 반자동 방법**

```
[흐름]
카드사 앱 결제 화면 스크린샷 → 공유 버튼 → Receipt Ledger 선택 → OCR 처리
```

| 항목 | 내용 |
|------|------|
| 장점 | App Store 승인 OK, 기존 OCR 활용, 구현 간단 |
| 단점 | 완전 자동 아님 (사용자 액션 1회 필요) |
| 구현 난이도 | 낮음 |
| 필요 작업 | iOS Share Extension 추가, 이미지 수신 → OCR 연동 |

### 5. 카드사 API 직접 연동 ⭐⭐⭐⭐⭐ (Best, but Hard)

**알림이 아닌 소스에서 직접 가져오기**

```
[흐름]
사용자 로그인 → 카드사 API/웹 스크래핑 → 결제 내역 조회 → 앱 저장
```

| 항목 | 내용 |
|------|------|
| 장점 | 가장 정확한 데이터, iOS/Android 동일, 완전 자동화 |
| 단점 | 각 카드사별 구현, 공식 API 없으면 스크래핑, 인증 복잡 |
| 구현 난이도 | 매우 높음 |
| 참고 | 뱅크샐러드, 토스, 뱅크몬 등이 이 방식 사용 |

## 권장 구현 순서

1. **Phase 1: Share Extension** (가장 빠름)
   - iOS Share Extension 추가
   - 다른 앱에서 스크린샷 공유 시 Receipt Ledger로 바로 OCR

2. **Phase 2: 이메일 파싱** (자동화)
   - Gmail OAuth 연동
   - 카드사 이메일 자동 파싱
   - 주기적 백그라운드 동기화

3. **Phase 3: 단축어 연동** (선택)
   - URL Scheme 지원
   - Shortcuts 앱과 연동

## 기술 스택 (예상)

- **Share Extension**: Swift/Flutter Share Extension
- **이메일 파싱**: Gmail API (OAuth 2.0), 정규식 파싱
- **URL Scheme**: Flutter `uni_links` 패키지

## 참고 자료

- [Apple NotificationServiceExtension 문서](https://developer.apple.com/documentation/usernotifications/unnotificationserviceextension)
- [Gmail API 문서](https://developers.google.com/gmail/api)
- [Flutter Share Extension 가이드](https://pub.dev/packages/receive_sharing_intent)

---

> 이 문서는 향후 iOS 기능 구현 시 참고용으로 작성되었습니다.
