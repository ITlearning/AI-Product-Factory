#!/bin/bash
# 「작은 원이 커져 전면 사진이 되는」 캐러셀(5장) + 같은 움직임의 릴스. 마지막 장에서 단어가 뜬다.
#   ./circle.sh <사진> <단어> [-m "사진 이야기"] [-c "#1d3f8f"]   바탕색을 안 주면 사진의 대표 색을 어둡게
# 결과는 output/<날짜>-circle-<단어>/ 에 1~5.png(캐러셀 순서대로)·릴스.mp4·릴스-표지.jpg·글.txt.
set -euo pipefail
cd "$(dirname "$0")"

NOTE= COLOR= ARGS=()
while [ $# -gt 0 ]; do case "$1" in -m) NOTE="${2:-}"; shift 2 ;; -c) COLOR="${2:-}"; shift 2 ;; *) ARGS+=("$1"); shift ;; esac; done
set -- "${ARGS[@]+"${ARGS[@]}"}"
[ $# -eq 2 ] || { sed -n 2,4p "$0" >&2; exit 1; }
PHOTO="$1" WORD="$2"
[ -f "$PHOTO" ] || { echo "사진이 없어요: $PHOTO" >&2; exit 1; }

CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
FONT=../app-store/fonts/NanumMyeongjo-Bold.ttf
mkdir -p ../app-store/fonts output .work
[ -f "$FONT" ] || curl -fsSL -o "$FONT" https://github.com/google/fonts/raw/main/ofl/nanummyeongjo/NanumMyeongjo-Bold.ttf

MEANING=$(python3 -I - ../../Shared/Word/words.json "$WORD" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
hits = [w for w in d["words"] if w["word"] == sys.argv[2] and w["id"] not in d["retired"]]
if not hits:
    sys.exit(f"단어 목록에 없거나 은퇴한 단어예요: {sys.argv[2]}")
print(hits[0]["meaning"])
PY
)
sips -s format jpeg -Z 2400 "$PHOTO" --out .work/circle.jpg >/dev/null
enc() { python3 -I -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))' "$1"; }
URL="file://$PWD/circle.html?photo=$(enc "$PWD/.work/circle.jpg")&word=$(enc "$WORD")&meaning=$(enc "$MEANING")&color=$(enc "$COLOR")"
DIR="output/$(date +%Y%m%d)-circle-$WORD"
rm -rf "$DIR" && mkdir -p "$DIR"

for k in 1 2 3 4 5; do
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
    --allow-file-access-from-files --virtual-time-budget=4000 \
    --window-size=1080,1350 --screenshot="$DIR/$k.png" "$URL&slide=$k&slides=5" >/dev/null 2>&1
done
node reel.mjs "$URL&reel=1" .work/frames 30 >/dev/null
[ .work/encode -nt encode.swift ] || swiftc -O -swift-version 5 encode.swift -o .work/encode
.work/encode .work/frames "$DIR/릴스.mp4" 30
cp .work/frames/f00000.jpg "$DIR/릴스-표지.jpg"

STORY=; [ -n "$NOTE" ] && STORY="
$NOTE
"
cat > "$DIR/글.txt" <<TXT
이 사진에 붙은 단어는 끝까지 넘기면 나와요.

$WORD · $MEANING
$STORY
사진을 담으면 그 순간에 맞는 우리말 하나를 붙여 주는 앱, 몽돌이에요.
프로필 링크에서 받을 수 있어요.

#순우리말 #예쁜우리말 #오늘의단어 #몽돌
TXT

echo "$DIR"
open "$DIR" 2>/dev/null || true
