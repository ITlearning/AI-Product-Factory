#!/bin/bash
# 사진 여러 장 슬라이드 릴스 — 사진이 화면을 채우고 장마다 단어가 뜬다. 소리는 인스타에서 고른다.
#   ./slides.sh [-t 장당 초] <사진> <단어> <사진> <단어> ...
#   예) ./slides.sh ~/Downloads/IMG_1.HEIC 윤슬 ~/Downloads/IMG_2.HEIC 볕뉘 ~/Downloads/IMG_3.HEIC 해거름
# 결과는 output/<날짜>-slides-<첫 단어>/ 에 릴스.mp4·릴스-표지.jpg·글.txt. 날짜 줄은 사진에 찍힌 날(없으면 비움).
set -euo pipefail
cd "$(dirname "$0")"

PER=2.2
[ "${1:-}" = -t ] && { PER="$2"; shift 2; }
{ [ $# -ge 4 ] && [ $(($# % 2)) -eq 0 ]; } || { sed -n 2,5p "$0" >&2; exit 1; }

FONT=../app-store/fonts/NanumMyeongjo-Bold.ttf
mkdir -p ../app-store/fonts output .work/slides
[ -f "$FONT" ] || curl -fsSL -o "$FONT" https://github.com/google/fonts/raw/main/ofl/nanummyeongjo/NanumMyeongjo-Bold.ttf
rm -f .work/slides/*

enc() { python3 -I -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))' "$1"; }
Q="per=$PER" CAP= i=0 FIRST="$2"
while [ $# -gt 0 ]; do
  PHOTO="$1" WORD="$2"; shift 2
  [ -f "$PHOTO" ] || { echo "사진이 없어요: $PHOTO" >&2; exit 1; }
  MEANING=$(python3 -I - ../../Shared/Word/words.json "$WORD" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
hits = [w for w in d["words"] if w["word"] == sys.argv[2] and w["id"] not in d["retired"]]
if not hits:
    sys.exit(f"단어 목록에 없거나 은퇴한 단어예요: {sys.argv[2]}")
print(hits[0]["meaning"])
PY
)
  SHOT=$(mdls -raw -name kMDItemContentCreationDate "$PHOTO" 2>/dev/null || true)
  WHEN=$(date -j -f "%Y-%m-%d %H:%M:%S %z" "$SHOT" +"%-m월 %-d일" 2>/dev/null || true)
  sips -s format jpeg -Z 2400 "$PHOTO" --out ".work/slides/$i.jpg" >/dev/null
  Q="$Q&p$i=$(enc "$PWD/.work/slides/$i.jpg")&w$i=$(enc "$WORD")&m$i=$(enc "$MEANING")&d$i=$(enc "$WHEN")"
  CAP="$CAP$WORD · $MEANING
"
  i=$((i + 1))
done

DIR="output/$(date +%Y%m%d)-slides-$FIRST"
rm -rf "$DIR" && mkdir -p "$DIR"
node reel.mjs "file://$PWD/slides.html?$Q&n=$i" .work/frames 30 >/dev/null
[ .work/encode -nt encode.swift ] || swiftc -O -swift-version 5 encode.swift -o .work/encode
.work/encode .work/frames "$DIR/릴스.mp4" 30
# 표지는 첫 장에 단어가 다 뜬 때 — 마지막 장면은 「몽돌」 한 줄이 덮는다.
cp ".work/frames/$(printf 'f%05d.jpg' "$(python3 -I -c "print(round(($PER - .2) * 30))")")" "$DIR/릴스-표지.jpg"

cat > "$DIR/글.txt" <<TXT
${CAP}
사진을 담으면 그 순간에 맞는 우리말 하나를 붙여 주는 앱, 몽돌이에요.
프로필 링크에서 받을 수 있어요.

#순우리말 #예쁜우리말 #오늘의단어 #몽돌
TXT

echo "$DIR"
open "$DIR" 2>/dev/null || true
