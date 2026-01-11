#!/bin/bash
# Receipt Ledger Sync + OCR Server - 라즈베리파이 설치 스크립트
# PaddleOCR 기반 영수증 OCR 서버

echo "========================================"
echo "  Receipt Ledger OCR Server 설치"
echo "  For Raspberry Pi 5"
echo "========================================"
echo ""

# 현재 디렉토리 확인
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SYNC_DIR="$SCRIPT_DIR/sync_server"

# 시스템 패키지 확인 (Raspberry Pi OS Bookworm 호환)
echo "[1/6] 시스템 패키지 설치 중..."
sudo apt update
sudo apt install -y python3 python3-pip python3-venv
sudo apt install -y libatlas3-base libopenblas-dev || true
sudo apt install -y libgl1 libglib2.0-0t64 || true

# 가상환경 생성
echo "[2/6] Python 가상환경 설정 중..."
cd "$SYNC_DIR"
python3 -m venv venv
source venv/bin/activate

# pip 업그레이드
echo "[3/6] pip 업그레이드 중..."
pip install --upgrade pip wheel setuptools

# 기본 의존성 설치
echo "[4/6] 기본 패키지 설치 중..."
pip install fastapi uvicorn pydantic python-multipart requests Pillow
# 이전 PaddleOCR 관련 패키지 제거 (필요 시)
pip uninstall -y paddlepaddle paddleocr opencv-python-headless || true

# PaddleOCR 설치 (제거됨 - Llama.cpp 사용)
echo "[5/6] Llama.cpp 연동 설정 (모델은 별도 실행 필요)"

# systemd 서비스 파일 생성
echo "[6/6] Systemd 서비스 설정 중..."
SERVICE_FILE="/etc/systemd/system/receipt-sync.service"

sudo tee $SERVICE_FILE > /dev/null <<EOF
[Unit]
Description=Receipt Ledger OCR Server (Llama.cpp Backend)
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$SYNC_DIR
Environment="PATH=$SYNC_DIR/venv/bin"
ExecStart=$SYNC_DIR/venv/bin/python -m uvicorn ocr_server:app --host 0.0.0.0 --port 9999
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# 서비스 활성화
sudo systemctl daemon-reload
sudo systemctl enable receipt-sync.service
sudo systemctl start receipt-sync.service

echo ""
echo "========================================"
echo "  설치 완료!"
echo "========================================"
echo ""
echo "서버 상태 확인: sudo systemctl status receipt-sync"
echo "서버 로그 확인: sudo journalctl -u receipt-sync -f"
echo "서버 재시작:   sudo systemctl restart receipt-sync"
echo ""
echo "⚠️ 중요: Llama.cpp 서버가 별도로 실행 중이어야 합니다!"
echo "Llama Server Port: 8888"
echo "OCR Server Port:   9999"
echo ""
echo "공유기에서 9999 포트를 라즈베리파이 IP로 포워딩하세요."
echo ""

