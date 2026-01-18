#!/bin/bash
# Receipt Ledger OCR Server 시작 스크립트 (Raspberry Pi용)

echo "========================================"
echo "Receipt Ledger OCR Server 시작"
echo "========================================"

cd ~/receipt-ocr/sync_server

echo "서버 IP: 0.0.0.0 (모든 네트워크 인터페이스)"
echo "포트: 9999"
echo ""

# 가상환경 활성화 (있는 경우)
if [ -f "../venv/bin/activate" ]; then
    source ../venv/bin/activate
elif [ -f "venv/bin/activate" ]; then
    source venv/bin/activate
fi

# 서버 시작
python3 ocr_server.py
