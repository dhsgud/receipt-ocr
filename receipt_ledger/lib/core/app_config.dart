// 앱 전역 설정
// 프로덕션 빌드 시 [kAdminMode]를 false로 설정하세요.

/// 관리자 모드 활성화 여부
/// - true: 설정 페이지에 "개발자 설정" 버튼 표시
/// - false: 관리자 설정 숨김 (프로덕션용)
const bool kAdminMode = true;  // TODO: 출시 시 false로 변경

/// 기본 OCR 제공자
/// 프로덕션에서는 'gemini'만 사용
const String kDefaultOcrProvider = 'gemini';
