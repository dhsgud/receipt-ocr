# Receipt Ledger OCR Server - 라즈베리파이 설치 가이드

PaddleOCR 기반 영수증 OCR 서버를 라즈베리파이에 설치합니다.

## 📋 준비물
- 라즈베리파이 5 (4GB 이상 권장) + Raspberry Pi OS 64-bit
- 인터넷 연결
- SSH 접속 또는 직접 터미널 접근


---

## 🚀 설치 방법

### 1단계: 파일 복사
Windows에서 라즈베리파이로 `sync_server` 폴더 전체를 복사합니다.

**방법 A: USB로 복사**
```bash
# USB를 라즈베리파이에 연결 후
cp -r /media/pi/USB이름/sync_server ~/receipt-ledger/
```

**방법 B: SCP로 복사 (Windows PowerShell에서)**
```powershell
scp -r c:\Users\ikm11\Desktop\receipt-ocr\sync_server pi@라즈베리파이IP:~/receipt-ledger/
scp c:\Users\ikm11\Desktop\receipt-ocr\setup_raspberry_pi.sh pi@라즈베리파이IP:~/receipt-ledger/
```

### 2단계: 설치 스크립트 실행
라즈베리파이 터미널에서:
```bash
cd ~/receipt-ledger
chmod +x setup_raspberry_pi.sh
./setup_raspberry_pi.sh
```

---

## ✅ 설치 후 확인

### 서버 상태 확인
```bash
sudo systemctl status receipt-sync
```

### 서버 로그 실시간 확인
```bash
sudo journalctl -u receipt-sync -f
```

### 연결 테스트
```bash
# 헬스 체크
curl http://localhost:8888/health

# OCR 상태 확인
curl http://localhost:8888/api/ocr/status
```

---

## 🔧 관리 명령어

| 명령어 | 설명 |
|--------|------|
| `sudo systemctl start receipt-sync` | 서버 시작 |
| `sudo systemctl stop receipt-sync` | 서버 중지 |
| `sudo systemctl restart receipt-sync` | 서버 재시작 |
| `sudo systemctl status receipt-sync` | 상태 확인 |
| `sudo systemctl disable receipt-sync` | 자동시작 해제 |

---

## 🔌 포트포워딩 설정

공유기 관리 페이지에서:
1. **외부 포트**: 8888
2. **내부 IP**: 라즈베리파이 IP (예: 192.168.0.100)
3. **내부 포트**: 8888
4. **프로토콜**: TCP

라즈베리파이 IP 확인:
```bash
hostname -I
```

---

## 📱 앱 설정 변경

라즈베리파이를 사용하려면 앱의 설정 파일을 수정해야 합니다:

**파일**: `lib/core/constants/app_constants.dart`

```dart
// 기존 (데스크탑 서버)
static const String syncServerUrl = 'http://183.96.3.137:8888';

// 변경 (라즈베리파이 사용 시) - 공인 IP가 같다면 변경 불필요
static const String syncServerUrl = 'http://라즈베리파이공인IP:8888';
```

> ⚠️ **참고**: 라즈베리파이가 같은 공유기 뒤에 있고 포트포워딩을 설정했다면, 
> 기존 공인 IP(`183.96.3.137`)를 그대로 사용해도 됩니다.

---

## 🔒 보안 팁

1. **방화벽 설정** (선택사항)
```bash
sudo ufw allow 8888/tcp
sudo ufw enable
```

2. **비밀번호 변경**
```bash
passwd
```
