# Receipt Ledger Vision OCR Server - 라즈베리파이 5 설치 가이드

**LightOnOCR-2-1B** Vision 모델과 Hugging Face Transformers를 사용한 영수증 OCR 서버

## 📋 준비물
- 라즈베리파이 5 (**8GB RAM 필수**)
- Raspberry Pi OS 64-bit (Bookworm)
- 인터넷 연결
- 최소 10GB 여유 저장공간 (모델 포함)

---

## 🚀 설치 방법

### 1단계: 파일 복사

**SCP로 복사 (Windows PowerShell):**
```powershell
scp -r c:\Users\ikm11\Desktop\receipt-ocr\sync_server pi@192.168.x.x:~/receipt-ledger/
scp c:\Users\ikm11\Desktop\receipt-ocr\setup_lightonocr.sh pi@192.168.x.x:~/receipt-ledger/
```

### 2단계: 설치 스크립트 실행

```bash
cd ~/receipt-ledger
chmod +x setup_lightonocr.sh
./setup_lightonocr.sh
```

⚠️ **설치 시간**: PyTorch + Transformers 설치 + 모델 다운로드(~2GB)로 약 30-60분 소요

---

## ✅ 설치 완료 후

### 서버 구성

| 서비스 | 포트 | 설명 |
|--------|------|------|
| `lightonocr` | 408 | LightOnOCR-2-1B Vision 모델 서버 |
| `receipt-ocr` | 9999 | OCR API 서버 |

### 상태 확인
```bash
sudo systemctl status lightonocr
sudo systemctl status receipt-ocr
```

### 연결 테스트
```bash
# LightOnOCR 서버
curl http://localhost:408/health

# OCR API 서버
curl http://localhost:9999/health
```

---

## 🔧 관리 명령어

| 명령어 | 설명 |
|--------|------|
| `sudo systemctl restart lightonocr` | LightOnOCR 서버 재시작 |
| `sudo systemctl restart receipt-ocr` | OCR 서버 재시작 |
| `sudo journalctl -u lightonocr -f` | LightOnOCR 로그 확인 |
| `sudo journalctl -u receipt-ocr -f` | OCR 로그 확인 |

---

## 🔌 포트포워딩 설정

공유기 관리 페이지에서:

1. **포트 408** → 라즈베리파이 IP (LightOnOCR 서버)
2. **포트 9999** → 라즈베리파이 IP (OCR API)

---

## 📱 앱 설정

앱은 자동으로 `183.96.3.137:9999`로 OCR 요청을 보냅니다.
OCR 서버가 LightOnOCR 서버(`183.96.3.137:408`)에 연결합니다.

---

## 🔒 보안 팁

```bash
# 방화벽 설정
sudo ufw allow 408/tcp
sudo ufw allow 9999/tcp
sudo ufw enable
```

---

## 💡 성능 팁

1. **첫 실행**: 모델 로딩에 1-2분 소요. 서비스 시작 후 잠시 대기 필요
2. **메모리**: 8GB RAM에서 여유롭게 동작. 다른 무거운 프로세스 동시 실행 비권장
3. **추론 속도**: 영수증 1장당 약 10-30초 소요 (이미지 크기에 따라 다름)

---

## 🔄 기존 SmolVLM에서 마이그레이션

기존 llama.cpp + SmolVLM-500M 사용 시:

```bash
# 기존 서비스 중지
sudo systemctl stop llama-vision
sudo systemctl disable llama-vision

# 새 LightOnOCR 설치
./setup_lightonocr.sh
```
