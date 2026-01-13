# Receipt Ledger Vision OCR Server - 라즈베리파이 5 설치 가이드

SmolVLM-500M Vision 모델과 llama.cpp를 사용한 영수증 OCR 서버

## 📋 준비물
- 라즈베리파이 5 (4GB 이상 권장, 8GB 추천)
- Raspberry Pi OS 64-bit (Bookworm)
- 인터넷 연결
- 최소 2GB 여유 저장공간

---

## 🚀 설치 방법

### 1단계: 파일 복사

**SCP로 복사 (Windows PowerShell):**
```powershell
scp -r c:\Users\ikm11\Desktop\receipt-ocr\sync_server pi@192.168.x.x:~/receipt-ledger/
scp c:\Users\ikm11\Desktop\receipt-ocr\setup_raspberry_pi.sh pi@192.168.x.x:~/receipt-ledger/
```

### 2단계: 설치 스크립트 실행

```bash
cd ~/receipt-ledger
chmod +x setup_raspberry_pi.sh
./setup_raspberry_pi.sh
```

⚠️ **설치 시간**: llama.cpp 빌드 + 모델 다운로드로 약 20-30분 소요

---

## ✅ 설치 완료 후

### 서버 구성

| 서비스 | 포트 | 설명 |
|--------|------|------|
| `llama-vision` | 408 | SmolVLM-500M Vision 모델 서버 |
| `receipt-ocr` | 9999 | OCR API 서버 |

### 상태 확인
```bash
sudo systemctl status llama-vision
sudo systemctl status receipt-ocr
```

### 연결 테스트
```bash
# llama.cpp 서버 (Vision)
curl http://localhost:408/health

# OCR 서버
curl http://localhost:9999/health
```

---

## 🔧 관리 명령어

| 명령어 | 설명 |
|--------|------|
| `sudo systemctl restart llama-vision` | Llama 서버 재시작 |
| `sudo systemctl restart receipt-ocr` | OCR 서버 재시작 |
| `sudo journalctl -u llama-vision -f` | Llama 로그 확인 |
| `sudo journalctl -u receipt-ocr -f` | OCR 로그 확인 |

---

## 🔌 포트포워딩 설정

공유기 관리 페이지에서:

1. **포트 408** → 라즈베리파이 IP (llama.cpp)
2. **포트 9999** → 라즈베리파이 IP (OCR)

---

## 📱 앱 설정

앱은 자동으로 `183.96.3.137:9999`로 OCR 요청을 보냅니다.
OCR 서버가 llama.cpp 서버(`183.96.3.137:408`)에 연결합니다.

---

## 🔒 보안 팁

```bash
# 방화벽 설정
sudo ufw allow 408/tcp
sudo ufw allow 9999/tcp
sudo ufw enable
```
