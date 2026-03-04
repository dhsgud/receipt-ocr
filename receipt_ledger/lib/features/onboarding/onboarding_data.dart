import 'package:flutter/material.dart';

/// 온보딩 페이지 데이터 모델
class OnboardingPage {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final List<OnboardingFeature> features;

  const OnboardingPage({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.features,
  });
}

/// 온보딩 하위 기능 데이터
class OnboardingFeature {
  final String emoji;
  final String title;
  final String description;

  const OnboardingFeature({
    required this.emoji,
    required this.title,
    required this.description,
  });
}

/// 온보딩 페이지 목록 (5페이지)
const onboardingPages = <OnboardingPage>[
  // 1. 홈 화면
  OnboardingPage(
    title: '한눈에 보는 가계부',
    description: '이번 달 수입·지출·잔액을\n한눈에 확인하세요',
    icon: Icons.home_rounded,
    color: Color(0xFF6C5CE7),
    features: [
      OnboardingFeature(
        emoji: '💰',
        title: '월별 요약',
        description: '수입, 지출, 잔액을 카드로 확인',
      ),
      OnboardingFeature(
        emoji: '🎯',
        title: '저축 목표',
        description: '목표 설정 후 달성률 실시간 확인',
      ),
      OnboardingFeature(
        emoji: '📋',
        title: '오늘의 거래',
        description: '당일 거래 내역을 빠르게 확인',
      ),
    ],
  ),

  // 2. 영수증 등록
  OnboardingPage(
    title: 'AI 영수증 분석',
    description: '영수증을 촬영하면\nAI가 자동으로 분석해요',
    icon: Icons.add_a_photo_rounded,
    color: Color(0xFF00CEC9),
    features: [
      OnboardingFeature(
        emoji: '📸',
        title: '카메라 / 갤러리',
        description: '촬영 또는 갤러리에서 영수증 선택',
      ),
      OnboardingFeature(
        emoji: '🤖',
        title: 'AI 자동 입력',
        description: '금액, 상점, 카테고리 자동 인식',
      ),
      OnboardingFeature(
        emoji: '📦',
        title: '여러 장 일괄 등록',
        description: '여러 영수증을 한 번에 처리',
      ),
    ],
  ),

  // 3. 캘린더
  OnboardingPage(
    title: '캘린더로 관리',
    description: '날짜별 수입·지출을\n캘린더에서 한눈에 확인',
    icon: Icons.calendar_month_rounded,
    color: Color(0xFF0984E3),
    features: [
      OnboardingFeature(
        emoji: '📅',
        title: '날짜별 조회',
        description: '날짜를 탭하면 해당일 거래 목록 표시',
      ),
      OnboardingFeature(
        emoji: '🔴🟢',
        title: '수입/지출 마커',
        description: '캘린더에 금액 마커로 한눈에 파악',
      ),
      OnboardingFeature(
        emoji: '✏️',
        title: '편집 기능',
        description: '거래를 길게 눌러 수정·삭제 가능',
      ),
    ],
  ),

  // 4. 통계
  OnboardingPage(
    title: '지출 통계 분석',
    description: '카테고리별 지출을\n차트와 리포트로 분석',
    icon: Icons.pie_chart_rounded,
    color: Color(0xFF00B894),
    features: [
      OnboardingFeature(
        emoji: '🥧',
        title: '파이 차트',
        description: '카테고리별 지출 비율 시각화',
      ),
      OnboardingFeature(
        emoji: '📊',
        title: '카테고리 순위',
        description: '어디에 얼마 썼는지 순위 확인',
      ),
      OnboardingFeature(
        emoji: '👨‍👩‍👧',
        title: '전체 / 개인 필터',
        description: '파트너 데이터 합산 또는 개인만 보기',
      ),
    ],
  ),

  // 5. 설정 & 동기화
  OnboardingPage(
    title: '설정 & 동기화',
    description: '파트너 공유, 예산 관리,\n결제 알림 자동 등록까지',
    icon: Icons.settings_rounded,
    color: Color(0xFFFDA085),
    features: [
      OnboardingFeature(
        emoji: '💑',
        title: '파트너 공유',
        description: '공유키로 가계부 데이터를 실시간 동기화',
      ),
      OnboardingFeature(
        emoji: '💳',
        title: '결제 알림 자동 등록',
        description: '결제 알림을 감지해 자동으로 거래 등록',
      ),
      OnboardingFeature(
        emoji: '📈',
        title: '예산 & 고정비 관리',
        description: '카테고리별 예산 설정과 고정비 추적',
      ),
    ],
  ),
];
