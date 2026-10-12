#!/bin/bash
# 인스타 「오늘의 단어」 카드(1080×1350)를 output/ 에 굽는다.
#   ./card.sh <사진> <단어> [날짜 표기] [#색]
#   ./card.sh ~/Downloads/IMG_1234.jpeg 윤슬 "10월 12일"
# 뜻은 Shared/Word/words.json 에서 찾는다. 은퇴한 단어는 거절한다. 색을 안 주면 사진에서 가장 흔한 색.
set -euo pipefail
cd "$(dirname "$0")"

[ $# -ge 2 ] || { sed -n 2,5p "$0" >&2; exit 1; }
PHOTO="$1" WORD="$2" DATE="${3:-}" COLOR="${4:-}"
[ -f "$PHOTO" ] || { echo "사진이 없어요: $PHOTO" >&2; exit 1; }

CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
FONT=../app-store/fonts/NanumMyeongjo-Bold.ttf
mkdir -p ../app-store/fonts output .work
[ -f "$FONT" ] || curl -fL -o "$FONT" https://github.com/google/fonts/raw/main/ofl/nanummyeongjo/NanumMyeongjo-Bold.ttf

MEANING=$(python3 -I - ../../Shared/Word/words.json "$WORD" <<'EOF'
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

# HEIC 는 크롬이 못 읽는다 — JPEG 로 바꿔 둔다.
SRC=".work/photo.jpg"
sips -s format jpeg -Z 2400 "$PHOTO" --out "$SRC" >/dev/null

enc() { python3 -I -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))' "$1"; }
URL="file://$PWD/card.html?photo=$(enc "$PWD/$SRC")&word=$(enc "$WORD")&meaning=$(enc "$MEANING")&date=$(enc "$DATE")&color=$(enc "$COLOR")"
OUT="output/$(date +%Y%m%d)-$WORD.png"

"$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
  --allow-file-access-from-files --virtual-time-budget=4000 \
  --window-size=1080,1350 --screenshot="$OUT" "$URL" >/dev/null 2>&1
echo "$OUT"
