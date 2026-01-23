#!/bin/bash
# llama.cpp Vision OCR Server - 라즈베리파이 5 설치 스크립트

echo "========================================"
echo "  llama.cpp Vision OCR Server Setup"
echo "  For Raspberry Pi 5 (8GB RAM)"
echo "========================================"
echo ""

# 현재 디렉토리 확인
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LLAMA_DIR="$SCRIPT_DIR/llama.cpp"
MODELS_DIR="$SCRIPT_DIR/models"
SYNC_DIR="$SCRIPT_DIR/sync_server"

# 메모리 체크
TOTAL_MEM=$(free -g | awk '/^Mem:/{print $2}')
echo "사용 가능한 RAM: ${TOTAL_MEM}GB"

if [ "$TOTAL_MEM" -lt 7 ]; then
    echo "⚠️  경고: 8GB RAM 이상 권장. 현재 ${TOTAL_MEM}GB 감지됨"
    echo "    계속하시겠습니까? (y/n)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "설치 취소됨"
        exit 1
    fi
fi

# 시스템 패키지 설치
echo "[1/5] 시스템 패키지 설치 중..."
sudo apt update
sudo apt install -y build-essential cmake git curl wget
sudo apt install -y python3 python3-pip python3-venv python3-dev
sudo apt install -y libgl1 libglib2.0-0t64 || true

# llama.cpp 빌드
echo "[2/5] llama.cpp 빌드 중..."
cd "$LLAMA_DIR"
mkdir -p build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
cmake --build . --config Release -j$(nproc)

# 모델 디렉토리 생성
echo "[3/5] 모델 디렉토리 설정 중..."
mkdir -p "$MODELS_DIR"
echo "모델 파일을 $MODELS_DIR 에 배치하세요"

# Python 가상환경 설정
echo "[4/5] Python 가상환경 설정 중..."
cd "$SYNC_DIR"
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip wheel setuptools
pip install pillow fastapi uvicorn pydantic python-multipart requests

# systemd 서비스 파일 생성
echo "[5/5] 서비스 설정 중..."

# llama-server 서비스
LLAMA_SERVICE="/etc/systemd/system/llama-server.service"
sudo tee $LLAMA_SERVICE > /dev/null <<EOF
[Unit]
Description=llama.cpp Vision LLM Server
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$LLAMA_DIR/build/bin
ExecStart=$LLAMA_DIR/build/bin/llama-server -m $MODELS_DIR/model.gguf --host 0.0.0.0 --port 408
Restart=always
RestartSec=30
MemoryMax=6G

[Install]
WantedBy=multi-user.target
EOF

# OCR API 서버 서비스
OCR_API_SERVICE="/etc/systemd/system/receipt-ocr.service"
sudo tee $OCR_API_SERVICE > /dev/null <<EOF
[Unit]
Description=Receipt Ledger OCR API Server
After=network.target llama-server.service
Wants=llama-server.service

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

sudo systemctl daemon-reload
sudo systemctl enable receipt-ocr.service

echo ""
echo "========================================"
echo "  빌드 완료!"
echo "========================================"
echo ""
echo "다음 단계:"
echo "1. 모델 파일을 $MODELS_DIR/model.gguf 로 복사"
echo "2. 서비스 시작:"
echo "   sudo systemctl enable llama-server"
echo "   sudo systemctl start llama-server"
echo "   sudo systemctl start receipt-ocr"
echo ""
echo "🔹 llama.cpp 서버: 포트 408"
echo "🔹 OCR API 서버: 포트 9999"
echo ""
