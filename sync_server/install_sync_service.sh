#!/bin/bash
# Receipt Ledger Sync Server - Raspberry Pi 설치 스크립트
# 이 스크립트를 한 번만 실행하면 동기화 서버가 자동으로 시작되고,
# 재부팅 후에도 자동으로 실행됩니다.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_NAME="receipt-sync"
USER=$(whoami)

echo "=========================================="
echo "Receipt Ledger Sync Server 설치"
echo "=========================================="

# 1. Python 가상환경 생성 및 패키지 설치
echo "[1/5] Python 가상환경 설정 중..."
if [ ! -d "$SCRIPT_DIR/venv" ]; then
    python3 -m venv "$SCRIPT_DIR/venv"
    echo "  - 가상환경 생성됨"
fi

source "$SCRIPT_DIR/venv/bin/activate"
pip install --quiet --upgrade pip
pip install --quiet fastapi uvicorn pydantic
echo "  - 필수 패키지 설치됨"
deactivate

# 2. 실행 스크립트 생성
echo "[2/5] 실행 스크립트 생성 중..."
cat > "$SCRIPT_DIR/run_sync_server.sh" << 'EOF'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/venv/bin/activate"
cd "$SCRIPT_DIR"
exec python sync_server.py
EOF
chmod +x "$SCRIPT_DIR/run_sync_server.sh"
echo "  - run_sync_server.sh 생성됨"

# 3. systemd 서비스 파일 생성
echo "[3/5] systemd 서비스 파일 생성 중..."
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

sudo tee "$SERVICE_FILE" > /dev/null << EOF
[Unit]
Description=Receipt Ledger Sync Server
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$SCRIPT_DIR
ExecStart=$SCRIPT_DIR/run_sync_server.sh
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

# 환경설정
Environment="PATH=$SCRIPT_DIR/venv/bin:/usr/local/bin:/usr/bin:/bin"

[Install]
WantedBy=multi-user.target
EOF
echo "  - $SERVICE_FILE 생성됨"

# 4. 서비스 활성화 및 시작
echo "[4/5] 서비스 활성화 및 시작..."
sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_NAME"
sudo systemctl start "$SERVICE_NAME"
echo "  - 서비스 활성화됨"

# 5. 상태 확인
echo "[5/5] 서비스 상태 확인..."
sleep 2
if systemctl is-active --quiet "$SERVICE_NAME"; then
    echo ""
    echo "=========================================="
    echo "✅ 설치 완료!"
    echo "=========================================="
    echo ""
    echo "서버 포트: 8888"
    echo "서비스 이름: $SERVICE_NAME"
    echo ""
    echo "유용한 명령어:"
    echo "  - 상태 확인:    sudo systemctl status $SERVICE_NAME"
    echo "  - 로그 보기:    sudo journalctl -u $SERVICE_NAME -f"
    echo "  - 서버 재시작:  sudo systemctl restart $SERVICE_NAME"
    echo "  - 서버 중지:    sudo systemctl stop $SERVICE_NAME"
    echo ""
    
    # IP 주소 표시
    IP_ADDR=$(hostname -I | awk '{print $1}')
    echo "앱에서 동기화 서버 주소: http://${IP_ADDR}:8888"
    echo ""
else
    echo ""
    echo "❌ 서비스 시작 실패!"
    echo "로그 확인: sudo journalctl -u $SERVICE_NAME -n 50"
    exit 1
fi
