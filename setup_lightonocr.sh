#!/bin/bash
# LightOnOCR-2-1B Vision OCR Server - 라즈베리파이 5 설치 스크립트
# Hugging Face Transformers 기반

echo "========================================"
echo "  LightOnOCR-2-1B Vision OCR Server"
echo "  For Raspberry Pi 5 (8GB RAM)"
echo "========================================"
echo ""

# 현재 디렉토리 확인
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SYNC_DIR="$SCRIPT_DIR/sync_server"
CACHE_DIR="$HOME/.cache/huggingface"

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
echo "[1/6] 시스템 패키지 설치 중..."
sudo apt update
sudo apt install -y python3 python3-pip python3-venv python3-dev
sudo apt install -y build-essential cmake git curl wget
sudo apt install -y libatlas3-base libopenblas-dev || true
sudo apt install -y libgl1 libglib2.0-0t64 || true

# Swap 공간 확장 (8GB RAM에서 추가 안정성)
echo "[2/6] Swap 공간 설정 중..."
SWAPFILE=/swapfile
if [ ! -f "$SWAPFILE" ]; then
    sudo fallocate -l 4G $SWAPFILE
    sudo chmod 600 $SWAPFILE
    sudo mkswap $SWAPFILE
    sudo swapon $SWAPFILE
    echo "$SWAPFILE swap swap defaults 0 0" | sudo tee -a /etc/fstab
    echo "4GB swap 파일 생성 완료"
else
    echo "Swap 파일 이미 존재"
fi

# Python 가상환경 설정
echo "[3/6] Python 가상환경 설정 중..."
cd "$SYNC_DIR"
python3 -m venv venv
source venv/bin/activate

# pip 업그레이드
pip install --upgrade pip wheel setuptools

# PyTorch 설치 (ARM64 CPU 버전)
echo "[4/6] PyTorch 설치 중 (ARM64)..."
pip install torch torchvision --index-url https://download.pytorch.org/whl/cpu

# Transformers (소스에서 설치 - LightOnOCR 지원 필요)
echo "[5/6] Transformers 및 의존성 설치 중..."
pip install git+https://github.com/huggingface/transformers
pip install pillow pypdfium2
pip install fastapi uvicorn pydantic python-multipart requests

# 모델 사전 다운로드 (선택사항 - 첫 실행 시간 단축)
echo "[6/6] 모델 사전 다운로드 중... (약 2GB, 시간이 걸릴 수 있음)"
python3 -c "
from transformers import LightOnOcrForConditionalGeneration, LightOnOcrProcessor
print('Downloading model...')
LightOnOcrForConditionalGeneration.from_pretrained('lightonai/LightOnOCR-2-1B')
LightOnOcrProcessor.from_pretrained('lightonai/LightOnOCR-2-1B')
print('Model downloaded successfully!')
"

# systemd 서비스 파일 생성
echo "LightOnOCR 서버 서비스 설정 중..."
OCR_SERVICE="/etc/systemd/system/lightonocr.service"

sudo tee $OCR_SERVICE > /dev/null <<EOF
[Unit]
Description=LightOnOCR-2-1B Vision OCR Server
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$SYNC_DIR
Environment="PATH=$SYNC_DIR/venv/bin"
Environment="HF_HOME=$CACHE_DIR"
Environment="TRANSFORMERS_CACHE=$CACHE_DIR"
ExecStart=$SYNC_DIR/venv/bin/python -m uvicorn lightonocr_server:app --host 0.0.0.0 --port 408
Restart=always
RestartSec=30
# 메모리 제한 (OOM Killer 방지)
MemoryMax=6G

[Install]
WantedBy=multi-user.target
EOF

# OCR API 서버 서비스 (receipt-ocr)
OCR_API_SERVICE="/etc/systemd/system/receipt-ocr.service"

sudo tee $OCR_API_SERVICE > /dev/null <<EOF
[Unit]
Description=Receipt Ledger OCR API Server
After=network.target lightonocr.service
Wants=lightonocr.service

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
sudo systemctl enable lightonocr.service
sudo systemctl enable receipt-ocr.service

# 서비스 시작
echo "서비스 시작 중..."
sudo systemctl start lightonocr.service
echo "LightOnOCR 서버 시작됨. 모델 로딩 대기 중... (1-2분 소요될 수 있음)"
sleep 60  # 모델 로딩 대기

sudo systemctl start receipt-ocr.service
sleep 5

echo ""
echo "========================================"
echo "  설치 완료!"
echo "========================================"
echo ""
echo "🔹 LightOnOCR 서버: 포트 408"
echo "🔹 OCR API 서버: 포트 9999"
echo ""
echo "서버 상태 확인:"
echo "  sudo systemctl status lightonocr"
echo "  sudo systemctl status receipt-ocr"
echo ""
echo "서버 로그 확인:"
echo "  sudo journalctl -u lightonocr -f"
echo "  sudo journalctl -u receipt-ocr -f"
echo ""
echo "헬스체크:"
echo "  curl http://localhost:408/health"
echo "  curl http://localhost:9999/health"
echo ""
echo "공유기에서 포트 포워딩 설정:"
echo "  - 408 포트 → 라즈베리파이 IP (LightOnOCR)"
echo "  - 9999 포트 → 라즈베리파이 IP (OCR API)"
echo ""
