#!/bin/bash
# Receipt Ledger Sync Server - 라즈베리파이 설치 스크립트

echo "========================================"
echo "  Receipt Ledger Sync Server 설치"
echo "  For Raspberry Pi"
echo "========================================"
echo ""

# 현재 디렉토리 확인
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SYNC_DIR="$SCRIPT_DIR/sync_server"

# Python 및 pip 확인
echo "[1/4] Python 환경 확인 중..."
if ! command -v python3 &> /dev/null; then
    echo "Python3가 설치되어 있지 않습니다. 설치합니다..."
    sudo apt update
    sudo apt install -y python3 python3-pip python3-venv
fi

# 가상환경 생성
echo "[2/4] Python 가상환경 설정 중..."
cd "$SYNC_DIR"
python3 -m venv venv
source venv/bin/activate

# 의존성 설치
echo "[3/4] 의존성 패키지 설치 중..."
pip install --upgrade pip
pip install fastapi uvicorn pydantic

# systemd 서비스 파일 생성
echo "[4/4] Systemd 서비스 설정 중..."
SERVICE_FILE="/etc/systemd/system/receipt-sync.service"

sudo tee $SERVICE_FILE > /dev/null << EOF
[Unit]
Description=Receipt Ledger Sync Server
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$SYNC_DIR
Environment="PATH=$SYNC_DIR/venv/bin"
ExecStart=$SYNC_DIR/venv/bin/python -m uvicorn sync_server:app --host 0.0.0.0 --port 8888
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
echo "서버 중지:     sudo systemctl stop receipt-sync"
echo ""
echo "서버 포트: 8888"
echo "공유기에서 8888 포트를 라즈베리파이 IP로 포워딩하세요."
echo ""
