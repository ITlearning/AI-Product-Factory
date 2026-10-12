#!/bin/bash
# 인스타 한 세트 — 피드 카드 PNG, 릴스 mp4·표지, 글(피드용·릴스용)을 output/<날짜>-<종류>-<이름>/ 에 모은다.
#   ./post.sh <사진> <단어> [날짜 표기] [#색] [-m "사진 이야기"]
#   ./post.sh pebble <앱 스크린샷> <조약돌 이름> [날짜 표기] [확대] [-m "사진 이야기"]
#   릴스 앞에 밈: -k <초록 배경 영상> [-h "앞 문구"]   (문구 기본값 「이런 단어가 있는 줄 몰랐던 나:」, 영상은 memes/ 에 — git 에 안 올림)
#   예) ./post.sh ~/Downloads/IMG_1234.HEIC 놀잇감 -m "컵 사이에 개구리 두 마리. 털이 보송보송했어요."
# 날짜를 안 주면 오늘. 「사진 이야기」는 본 것·있었던 일만 한두 줄 — 안 주면 그 줄 없이 만든다.
set -euo pipefail
cd "$(dirname "$0")"

NOTE= ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    -m) NOTE="${2:-}"; shift 2 ;;
    -k) export MEME="${2:-}"; shift 2 ;;
    -h) export HOOK="${2:-}"; shift 2 ;;
    *) ARGS+=("$1"); shift ;;
  esac
done
set -- "${ARGS[@]+"${ARGS[@]}"}"
KIND=word
[ "${1:-}" = pebble ] && { KIND=pebble; shift; }
[ $# -ge 2 ] || { sed -n 2,7p "$0" >&2; exit 1; }
PHOTO="$1" NAME="$2" DATE="${3:-$(date +'%-m월 %-d일')}" EXTRA="${4:-}"
P=; [ "$KIND" = pebble ] && P=pebble

STILL=$(MEME= HOOK= ./card.sh $P "$PHOTO" "$NAME" "$DATE" "$EXTRA")
REEL=$(./card.sh reel $P "$PHOTO" "$NAME" "$DATE" "$EXTRA")
DIR="${STILL%.png}"
rm -rf "$DIR" && mkdir -p "$DIR"
mv "$STILL" "$DIR/피드.png"
mv "$REEL" "$DIR/릴스.mp4"
mv "${REEL%.mp4}-cover.jpg" "$DIR/릴스-표지.jpg"

if [ "$KIND" = word ]; then
  LINE=$(python3 -I -c 'import json, sys; d = json.load(open(sys.argv[1])); print(next(w["meaning"] for w in d["words"] if w["word"] == sys.argv[2]))' ../../Shared/Word/words.json "$NAME")
  HEAD="$NAME
$LINE"
  REEL_HEAD="$NAME · $LINE"
  APP="사진을 담으면 그 순간에 맞는 우리말 하나를 붙여 주는 앱, 몽돌이에요."
  FEED_TAGS="#몽돌 #오늘의단어 #우리말"
  REEL_TAGS="#순우리말 #예쁜우리말 #오늘의단어 #몽돌"
else
  LINE=$(python3 -I -c 'import re, sys; print(re.findall(r"name: \"" + re.escape(sys.argv[2]) + r"\", line: \"([^\"]+)\"", open(sys.argv[1], encoding="utf-8").read())[0])' ../../Shared/Day/PebbleName.swift "$NAME")
  HEAD="오늘의 조약돌, $NAME
$LINE"
  REEL_HEAD="오늘의 조약돌, $NAME · $LINE"
  APP="하루 동안 담은 사진의 색으로 조약돌을 빚어 주는 앱, 몽돌이에요."
  FEED_TAGS="#몽돌 #오늘의조약돌"
  REEL_TAGS="#감성사진 #사진일기 #오늘의조약돌 #몽돌"
fi
STORY=; [ -n "$NOTE" ] && STORY="
$NOTE
"

cat > "$DIR/글.txt" <<TXT
[피드]
$HEAD
$STORY
$FEED_TAGS


[릴스]
$REEL_HEAD
$STORY
$APP
프로필 링크에서 받을 수 있어요.

$REEL_TAGS
TXT

echo "$DIR"
[ -z "$NOTE" ] && echo "사진 이야기(-m)가 없어서 그 줄은 비워 뒀어요." >&2
open "$DIR" 2>/dev/null || true
