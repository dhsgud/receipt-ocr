#!/bin/bash

# iPhone 설치 도우미 스크립트

echo "📱 iPhone 연결 확인 중..."
flutter devices

echo ""
echo "---------------------------------------------------"
echo "👉 아이폰이 목록에 보이지 않는다면:"
echo "1. USB 케이블로 맥북에 연결해주세요."
echo "2. 아이폰 잠금을 해제하고 '이 컴퓨터 신뢰'를 눌러주세요."
echo "---------------------------------------------------"
echo ""

# 디바이스 ID 자동 감지 (아이폰만 필터링)
DEVICE_ID=$(flutter devices | grep "ios" | cut -d "•" -f 2 | xargs)

if [ -z "$DEVICE_ID" ]; then
    # ios라고 명시된게 없으면 darwin-arm64(Mac) 제외하고 찾기 시도
    # (단순화를 위해 사용자에게 직접 실행 요청)
    echo "❌ 아이폰을 찾을 수 없습니다."
    echo "연결 후 다시 실행해주세요."
    exit 1
fi

echo "✅ 아이폰 감지됨: $DEVICE_ID"
echo "🚀 앱 설치 및 실행을 시작합니다..."
echo "주의: Xcode 서명(Signing) 문제가 발생하면 Xcode에서 Team을 선택해야 합니다."

flutter run -d $DEVICE_ID --release
