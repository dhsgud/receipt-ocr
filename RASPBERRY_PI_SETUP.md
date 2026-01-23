# Receipt Ledger Vision OCR Server - 라즈베리파이 5 설치 가이드

**llama.cpp** 서버를 사용한 Vision LLM 영수증 OCR 서버

## 📋 준비물
- 라즈베리파이 5 (**8GB RAM 필수**)
- Raspberry Pi OS 64-bit (Bookworm)
- 인터넷 연결
- 최소 10GB 여유 저장공간 (모델 포함)
- Vision 모델 GGUF 파일 (예: LLaVA, SmolVLM, Qwen2-VL 등)

---

## 🚀 설치 방법

### 1단계: 파일 복사

**SCP로 복사 (Windows PowerShell):**
```powershell
scp -r c:\Users\ikm11\Desktop\receipt-ocr\sync_server pi@192.168.x.x:~/receipt-ledger/
scp -r c:\Users\ikm11\Desktop\receipt-ocr\llama.cpp pi@192.168.x.x:~/receipt-ledger/
scp c:\Users\ikm11\Desktop\receipt-ocr\setup_llamacpp.sh pi@192.168.x.x:~/receipt-ledger/
```

### 2단계: llama.cpp 빌드 (라즈베리파이에서)

```bash
cd ~/receipt-ledger/llama.cpp
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
cmake --build . --config Release -j4
```

### 3단계: 모델 준비

GGUF 형식의 Vision 모델을 `~/receipt-ledger/models/` 에 배치:
```bash
mkdir -p ~/receipt-ledger/models
# 모델 파일 복사 또는 다운로드
```

### 4단계: 서버 시작

```bash
cd ~/receipt-ledger/llama.cpp/build/bin
./llama-server -m ~/receipt-ledger/models/YOUR_MODEL.gguf --host 0.0.0.0 --port 408
```

---

## ✅ 설치 완료 후

### 서버 구성

| 서비스 | 포트 | 설명 |
|--------|------|------|
| `llama-server` | 408 | llama.cpp Vision LLM 서버 |
| `receipt-ocr` | 9999 | OCR API 서버 |

### 연결 테스트
```bash
# llama.cpp 서버
curl http://localhost:408/health

# OCR API 서버
curl http://localhost:9999/health
```

---

## 🔧 Systemd 서비스 설정 (선택)

### llama-server 서비스
```bash
sudo tee /etc/systemd/system/llama-server.service > /dev/null <<EOF
[Unit]
Description=llama.cpp Vision LLM Server
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$HOME/receipt-ledger/llama.cpp/build/bin
ExecStart=$HOME/receipt-ledger/llama.cpp/build/bin/llama-server -m $HOME/receipt-ledger/models/YOUR_MODEL.gguf --host 0.0.0.0 --port 408
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable llama-server
sudo systemctl start llama-server
```

---

## 🔌 포트포워딩 설정

공유기 관리 페이지에서:

1. **포트 408** → 라즈베리파이 IP (llama.cpp 서버)
2. **포트 9999** → 라즈베리파이 IP (OCR API)

---

## 📱 앱 설정

앱은 자동으로 `183.96.3.137:9999`로 OCR 요청을 보냅니다.
OCR 서버가 llama.cpp 서버(`183.96.3.137:408`)에 연결합니다.

---

## 💡 성능 팁

1. **첫 실행**: 모델 로딩에 시간 소요. 서비스 시작 후 잠시 대기 필요
2. **메모리**: 8GB RAM에서 동작. 모델 크기에 따라 성능 차이
3. **양자화**: Q4_K_M 또는 Q5_K_M 양자화 모델 권장
