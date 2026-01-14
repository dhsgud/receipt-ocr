#!/bin/bash
# Receipt Ledger Sync Server - 제거 스크립트

set -e

SERVICE_NAME="receipt-sync"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "Receipt Ledger Sync Server 제거"
echo "=========================================="

# 1. 서비스 중지 및 비활성화
echo "[1/3] 서비스 중지 및 비활성화..."
if systemctl is-active --quiet "$SERVICE_NAME"; then
    sudo systemctl stop "$SERVICE_NAME"
fi
if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
    sudo systemctl disable "$SERVICE_NAME"
fi
echo "  - 서비스 중지됨"

# 2. 서비스 파일 삭제
echo "[2/3] 서비스 파일 삭제..."
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
if [ -f "$SERVICE_FILE" ]; then
    sudo rm "$SERVICE_FILE"
    sudo systemctl daemon-reload
fi
echo "  - 서비스 파일 삭제됨"

# 3. 가상환경 삭제 (선택)
echo "[3/3] 정리..."
read -p "가상환경도 삭제하시겠습니까? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -rf "$SCRIPT_DIR/venv"
    echo "  - 가상환경 삭제됨"
fi

echo ""
echo "=========================================="
echo "✅ 제거 완료!"
echo "=========================================="
