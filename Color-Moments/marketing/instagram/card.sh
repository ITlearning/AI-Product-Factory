#!/bin/bash
# 인스타 카드(1080×1350)를 output/ 에 굽는다.
#   ./card.sh <사진> <단어> [날짜 표기] [#색]                 「오늘의 단어」 — 뜻은 Shared/Word/words.json
#   ./card.sh pebble <앱 스크린샷> <조약돌 이름> [날짜 표기] [확대]   「오늘의 조약돌」 — 한 줄은 Shared/Day/PebbleName.swift
#   ./card.sh reel [pebble] ...                                  릴스(1080×1920, 소리 없는 mp4 + 표지 JPEG) — 나머지는 위와 같다
#   예) ./card.sh ~/Downloads/IMG_1234.jpeg 윤슬 "10월 12일"
#       ./card.sh pebble ~/Downloads/IMG_1240.PNG 그믐 "10월 11일" 1.6
#       ./card.sh reel ~/Downloads/IMG_1234.jpeg 윤슬 "10월 12일"
# 조약돌 스크린샷은 돌이 화면 가운데 오게 찍는다(가운데 원만 남고 가장자리는 녹는다). 돌이 작으면 [확대]를 1.3~2 로.
set -euo pipefail
cd "$(dirname "$0")"

KIND=word REEL=
while [ "${1:-}" = pebble ] || [ "${1:-}" = reel ]; do
  [ "$1" = pebble ] && KIND=pebble || REEL=1; shift
done
[ $# -ge 2 ] || { sed -n 2,9p "$0" >&2; exit 1; }
PHOTO="$1" NAME="$2" DATE="${3:-}" EXTRA="${4:-}"
[ -f "$PHOTO" ] || { echo "사진이 없어요: $PHOTO" >&2; exit 1; }

CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
FONT=../app-store/fonts/NanumMyeongjo-Bold.ttf
mkdir -p ../app-store/fonts output .work
[ -f "$FONT" ] || curl -fsSL -o "$FONT" https://github.com/google/fonts/raw/main/ofl/nanummyeongjo/NanumMyeongjo-Bold.ttf

if [ "$KIND" = word ]; then
  LINE=$(python3 -I - ../../Shared/Word/words.json "$NAME" <<'EOF'
import json, sys
d = json.load(open(sys.argv[1]))
hits = [w for w in d["words"] if w["word"] == sys.argv[2]]
if not hits:
    sys.exit(f"단어 목록에 없어요: {sys.argv[2]}")
if all(w["id"] in d["retired"] for w in hits):
    sys.exit(f"은퇴한 단어예요: {sys.argv[2]}")
print(hits[0]["meaning"])
EOF
)
  OPTS="color=$EXTRA"
else
  LINE=$(python3 -I - ../../Shared/Day/PebbleName.swift "$NAME" <<'EOF'
import re, sys
src = open(sys.argv[1], encoding="utf-8").read()
hits = re.findall(r'name: "' + re.escape(sys.argv[2]) + r'", line: "([^"]+)"', src)
if not hits:
    sys.exit(f"조약돌 이름 목록에 없어요: {sys.argv[2]}")
print(hits[0])
EOF
)
  OPTS="kind=pebble&zoom=${EXTRA:-1}"
fi

# HEIC 는 크롬이 못 읽는다 — JPEG 로 바꿔 둔다.
SRC=".work/photo.jpg"
sips -s format jpeg -Z 2400 "$PHOTO" --out "$SRC" >/dev/null

enc() { python3 -I -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))' "$1"; }
URL="file://$PWD/card.html?photo=$(enc "$PWD/$SRC")&word=$(enc "$NAME")&meaning=$(enc "$LINE")&date=$(enc "$DATE")&$OPTS"
OUT="output/$(date +%Y%m%d)-$KIND-$NAME"

if [ -n "$REEL" ]; then
  [ .work/encode -nt encode.swift ] || swiftc -O -swift-version 5 encode.swift -o .work/encode
  node reel.mjs "$URL&reel=1" .work/frames 30 >/dev/null
  .work/encode .work/frames "$OUT-reel.mp4" 30
  cp "$(ls .work/frames/*.jpg | tail -1)" "$OUT-reel-cover.jpg"
  echo "$OUT-reel.mp4"
  exit
fi

"$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
  --allow-file-access-from-files --virtual-time-budget=4000 \
  --window-size=1080,1350 --screenshot="$OUT.png" "$URL" >/dev/null 2>&1
echo "$OUT.png"
