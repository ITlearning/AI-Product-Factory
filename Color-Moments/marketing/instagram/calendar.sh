#!/bin/bash
# 달력 덤프 릴스 — 사진을 찍은 날 칸에 하나씩 채우고, 다 차면 칸마다 단어가 뜬다. 소리는 인스타에서 고른다.
#   ./calendar.sh [-m 2026-10] [-b 배경 사진] <사진> <단어> <사진> <단어> ...
#   예) ./calendar.sh ~/Downloads/IMG_1.HEIC 윤슬 ~/Downloads/IMG_2.HEIC 볕뉘 ~/Downloads/IMG_3.HEIC 해거름
# 날짜는 사진에 찍힌 날 — 다른 날 칸에 넣으려면 단어 뒤에 @날짜(윤슬@2026-10-03). 달을 안 주면 사진이 가장 많은 달, 배경을 안 주면 첫 사진. 같은 날 사진이 여럿이면 앞의 것.
set -euo pipefail
cd "$(dirname "$0")"

YM= BG=
while [ "${1:-}" = -m ] || [ "${1:-}" = -b ]; do
  [ "$1" = -m ] && YM="$2" || BG="$2"; shift 2
done
{ [ $# -ge 2 ] && [ $(($# % 2)) -eq 0 ]; } || { sed -n 2,5p "$0" >&2; exit 1; }

FONT=../app-store/fonts/NanumMyeongjo-Bold.ttf
mkdir -p ../app-store/fonts output .work/cal
[ -f "$FONT" ] || curl -fsSL -o "$FONT" https://github.com/google/fonts/raw/main/ofl/nanummyeongjo/NanumMyeongjo-Bold.ttf
rm -f .work/cal/*

enc() { python3 -I -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))' "$1"; }
LIST= i=0
while [ $# -gt 0 ]; do
  PHOTO="$1" WORD="$2"; shift 2
  [ -f "$PHOTO" ] || { echo "사진이 없어요: $PHOTO" >&2; exit 1; }
  if [[ "$WORD" == *@* ]]; then DAY="${WORD#*@}" WORD="${WORD%@*}"
  else
    SHOT=$(mdls -raw -name kMDItemContentCreationDate "$PHOTO" 2>/dev/null || true)
    DAY=$(date -j -f "%Y-%m-%d %H:%M:%S %z" "$SHOT" +"%Y-%m-%d" 2>/dev/null) || { echo "찍은 날을 못 읽어서 뺐어요(단어@날짜 로 정해 주세요): $PHOTO" >&2; continue; }
  fi
  sips -s format jpeg -Z 600 "$PHOTO" --out ".work/cal/$i.jpg" >/dev/null
  LIST="$LIST$DAY	$PWD/.work/cal/$i.jpg	$WORD	$PHOTO
"
  i=$((i + 1))
done

# 날짜·단어 확인과 URL 만들기는 한곳에서 — 은퇴 단어는 거절, 달 밖 사진은 알려 주고 뺀다.
PY=$(cat <<'PY'
import collections, json, sys, urllib.parse
d = json.load(open(sys.argv[1]))
live = {w["word"]: w["meaning"] for w in d["words"] if w["id"] not in d["retired"]}
rows = [l.split("\t") for l in sys.stdin.read().splitlines() if l]
if not rows:
    sys.exit("달력에 넣을 사진이 없어요")
ym = sys.argv[2] or collections.Counter(r[0][:7] for r in rows).most_common(1)[0][0]
q, cap, seen = [f"ym={ym}"], [], set()
for day, path, word, src in sorted(rows):
    if word not in live:
        sys.exit(f"단어 목록에 없거나 은퇴한 단어예요: {word}")
    if day[:7] != ym:
        print(f"{ym} 밖이라 뺐어요: {src} ({day})", file=sys.stderr); continue
    n = int(day[8:])
    if n in seen:
        print(f"{n}일은 이미 있어서 뺐어요: {src}", file=sys.stderr); continue
    seen.add(n)
    q.append(f"p{n}={urllib.parse.quote(path)}&w{n}={urllib.parse.quote(word)}")
    cap.append(f"{n}일 {word} · {live[word]}")
print(ym, "&".join(q), urllib.parse.quote("\n".join(cap)))
PY
)
OUT=$(printf '%s' "$LIST" | python3 -I -c "$PY" ../../Shared/Word/words.json "$YM") || exit 1
read -r YM Q CAP <<<"$OUT"

BGJ=.work/cal/bg.jpg
if [ -n "$BG" ]; then sips -s format jpeg -Z 1600 "$BG" --out "$BGJ" >/dev/null; else cp .work/cal/0.jpg "$BGJ"; fi
DIR="output/$(date +%Y%m%d)-calendar-$YM"
rm -rf "$DIR" && mkdir -p "$DIR"
node reel.mjs "file://$PWD/calendar.html?$Q&bg=$(enc "$PWD/$BGJ")" .work/frames 30 >/dev/null
[ .work/encode -nt encode.swift ] || swiftc -O -swift-version 5 encode.swift -o .work/encode
.work/encode .work/frames "$DIR/릴스.mp4" 30
cp "$(ls .work/frames/*.jpg | tail -1)" "$DIR/릴스-표지.jpg"

cat > "$DIR/글.txt" <<TXT
$((10#${YM#*-}))월에 내 사진에 붙은 단어들

$(python3 -I -c 'import sys, urllib.parse; print(urllib.parse.unquote(sys.argv[1]))' "$CAP")

사진을 담으면 그 순간에 맞는 우리말 하나를 붙여 주는 앱, 몽돌이에요.
프로필 링크에서 받을 수 있어요.

#순우리말 #예쁜우리말 #오늘의단어 #몽돌
TXT

echo "$DIR"
open "$DIR" 2>/dev/null || true
