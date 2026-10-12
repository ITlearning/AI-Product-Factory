#!/bin/bash
# 화면 녹화 → 릴스(1080×1920). 위에 한 줄 문구, 가운데 녹화 화면, 끝에 「댓글에 생일 / 프로필 링크」 장면 3초.
#   ./screenreel.sh <녹화.mp4> <시작초> <끝초> "위 문구(줄바꿈은 \n)" "아래 작은 문구" "끝 장면 문구"
#   예) ./screenreel.sh ~/Downloads/rec.mp4 2.4 14.5 "생일만 넣으면\n그날의 우리말이 나와요" "같은 생일이어도 사람마다 달라요" "내 생일엔\n어떤 말이 나올까?"
# 녹화 위 6%(상태 막대·녹화 점)와 아래 10%(사파리 도구 막대)는 잘라 낸다. 소리는 인스타에서 고른다.
set -euo pipefail
cd "$(dirname "$0")"
[ $# -eq 6 ] || { sed -n 2,5p "$0" >&2; exit 1; }
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
FONT=../app-store/fonts/NanumMyeongjo-Bold.ttf
mkdir -p ../app-store/fonts output .work
[ -f "$FONT" ] || curl -fsSL -o "$FONT" https://github.com/google/fonts/raw/main/ofl/nanummyeongjo/NanumMyeongjo-Bold.ttf
enc() { python3 -I -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1].replace("\\n", "\n")))' "$1"; }
URL="file://$PWD/screenreel.html?hook=$(enc "$4")&sub=$(enc "$5")&end=$(enc "$6")"
for part in bg end; do
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 --allow-file-access-from-files \
    --virtual-time-budget=3000 --window-size=1080,1920 --screenshot=".work/screen-$part.png" "$URL&part=$part" >/dev/null 2>&1
done
[ .work/screenreel -nt screenreel.swift ] || swiftc -O -swift-version 5 screenreel.swift -o .work/screenreel
DIR="output/$(date +%Y%m%d)-screenreel"
mkdir -p "$DIR"
.work/screenreel "$1" "$2" "$3" .work/screen-bg.png .work/screen-end.png "$DIR/릴스.mp4" 0.06,0.10 >/dev/null
echo "$DIR/릴스.mp4"
open "$DIR" 2>/dev/null || true
