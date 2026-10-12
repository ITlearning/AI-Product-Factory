#!/bin/bash
# /birthday 공유 미리보기 이미지 굽기 — tools/og-birthday.html → img/og-birthday.jpg (1200×630).
# 예시 카드의 말은 그 날짜의 달에 어울리는 말이어야 한다(테스트가 본다).
set -euo pipefail
cd "$(dirname "$0")/.."
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
  --virtual-time-budget=5000 --window-size=1200,630 --screenshot=/tmp/og-birthday.png "file://$PWD/tools/og-birthday.html" >/dev/null 2>&1
sips -s format jpeg -s formatOptions 88 /tmp/og-birthday.png --out img/og-birthday.jpg >/dev/null
echo img/og-birthday.jpg
