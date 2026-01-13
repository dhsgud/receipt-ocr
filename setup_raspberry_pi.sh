#!/bin/bash
# Receipt Ledger OCR Server - 라즈베리파이 5 설치 스크립트
# SmolVLM-500M Vision 모델 + Llama.cpp 서버

echo "========================================"
echo "  Receipt Ledger Vision OCR Server"
echo "  For Raspberry Pi 5 (SmolVLM-500M)"
echo "========================================"
echo ""

# 현재 디렉토리 확인
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SYNC_DIR="$SCRIPT_DIR/sync_server"
MODEL_DIR="$HOME/models"

# 시스템 패키지 설치
echo "[1/7] 시스템 패키지 설치 중..."
sudo apt update
sudo apt install -y python3 python3-pip python3-venv
sudo apt install -y build-essential cmake git curl wget
sudo apt install -y libatlas3-base libopenblas-dev || true
sudo apt install -y libgl1 libglib2.0-0t64 || true

# llama.cpp 빌드
echo "[2/7] llama.cpp 빌드 중..."
cd "$SCRIPT_DIR"
if [ ! -d "llama.cpp" ]; then
    git clone https://github.com/ggml-org/llama.cpp.git
fi
cd llama.cpp
cmake -B build
cmake --build build --config Release -j$(nproc)

# SmolVLM-500M 모델 다운로드
echo "[3/7] SmolVLM-500M Vision 모델 다운로드 중..."
mkdir -p "$MODEL_DIR"
cd "$MODEL_DIR"

# 모델 파일 다운로드 (Q8_0 양자화 버전 - 약 550MB 총합)
if [ ! -f "SmolVLM-500M-Instruct-Q8_0.gguf" ]; then
    echo "  - 메인 모델 다운로드 중 (437MB)..."
    wget -c https://huggingface.co/ggml-org/SmolVLM-500M-Instruct-GGUF/resolve/main/SmolVLM-500M-Instruct-Q8_0.gguf
fi

if [ ! -f "mmproj-SmolVLM-500M-Instruct-Q8_0.gguf" ]; then
    echo "  - Vision Projector 다운로드 중 (109MB)..."
    wget -c https://huggingface.co/ggml-org/SmolVLM-500M-Instruct-GGUF/resolve/main/mmproj-SmolVLM-500M-Instruct-Q8_0.gguf
fi

# Python 가상환경 설정
echo "[4/7] Python 가상환경 설정 중..."
cd "$SYNC_DIR"
python3 -m venv venv
source venv/bin/activate

# pip 업그레이드 & 의존성 설치
echo "[5/7] Python 패키지 설치 중..."
pip install --upgrade pip wheel setuptools
pip install fastapi uvicorn pydantic python-multipart requests Pillow

# Llama.cpp 서버 서비스 파일 생성
echo "[6/7] Llama.cpp 서버 서비스 설정 중..."
LLAMA_SERVICE="/etc/systemd/system/llama-vision.service"

sudo tee $LLAMA_SERVICE > /dev/null <<EOF
[Unit]
Description=Llama.cpp Vision Server (SmolVLM-500M)
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$SCRIPT_DIR/llama.cpp/build/bin
ExecStart=$SCRIPT_DIR/llama.cpp/build/bin/llama-server \
    -m $MODEL_DIR/SmolVLM-500M-Instruct-Q8_0.gguf \
    --mmproj $MODEL_DIR/mmproj-SmolVLM-500M-Instruct-Q8_0.gguf \
    --host 0.0.0.0 \
    --port 408 \
    -c 4096 \
    -t 4
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# OCR 서버 서비스 파일 생성
echo "[7/7] OCR 서버 서비스 설정 중..."
OCR_SERVICE="/etc/systemd/system/receipt-ocr.service"

sudo tee $OCR_SERVICE > /dev/null <<EOF
[Unit]
Description=Receipt Ledger OCR Server
After=network.target llama-vision.service
Wants=llama-vision.service

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
sudo systemctl enable llama-vision.service
sudo systemctl enable receipt-ocr.service
sudo systemctl start llama-vision.service
sleep 10  # llama.cpp 서버 시작 대기
sudo systemctl start receipt-ocr.service

echo ""
echo "========================================"
echo "  설치 완료!"
echo "========================================"
echo ""
echo "🔹 Llama Vision 서버: 포트 408"
echo "🔹 OCR 서버: 포트 9999"
echo ""
echo "서버 상태 확인:"
echo "  sudo systemctl status llama-vision"
echo "  sudo systemctl status receipt-ocr"
echo ""
echo "서버 로그 확인:"
echo "  sudo journalctl -u llama-vision -f"
echo "  sudo journalctl -u receipt-ocr -f"
echo ""
echo "공유기에서 포트 포워딩 설정:"
echo "  - 408 포트 → 라즈베리파이 IP (llama.cpp)"
echo "  - 9999 포트 → 라즈베리파이 IP (OCR)"
echo ""
