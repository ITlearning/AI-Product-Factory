#!/bin/bash
# 몽돌 App Store 미리보기 6장을 output/ 에 굽는다.
#   ./render.sh            6장(1320×2868, 알파 없는 PNG) + 이어 붙인 panorama.png
#   ./render.sh preview    panorama-preview.png 한 장만 (빠른 확인용)
set -euo pipefail
cd "$(dirname "$0")"

CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
FONT=fonts/NanumMyeongjo-Bold.ttf
[ -f "$FONT" ] || curl -sfL -o "$FONT" https://github.com/google/fonts/raw/main/ofl/nanummyeongjo/NanumMyeongjo-Bold.ttf
mkdir -p output

shoot() { # url width height out
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
    --allow-file-access-from-files --virtual-time-budget=6000 \
    --window-size="$2,$3" --screenshot="$4" "$1" >/dev/null 2>&1
}

PAGE="file://$PWD/index.html"

if [ "${1:-}" = "preview" ]; then
  shoot "$PAGE" 1980 691 output/panorama-preview.png
  echo "output/panorama-preview.png"
  exit 0
fi

for n in 1 2 3 4 5 6; do
  shoot "$PAGE?frame=$n" 1320 2868 "output/raw-$n.png"
  # App Store 는 알파 채널이 있는 PNG 를 받지 않는다.
  ffmpeg -loglevel error -y -i "output/raw-$n.png" -pix_fmt rgb24 "output/mongdol-$n.png"
  rm "output/raw-$n.png"
done

# 스토어처럼 장 사이 간격(60px)을 두고 이어 붙인 확인용 한 장
ffmpeg -loglevel error -y -i output/mongdol-1.png -i output/mongdol-2.png -i output/mongdol-3.png \
  -i output/mongdol-4.png -i output/mongdol-5.png -i output/mongdol-6.png \
  -f lavfi -i color=c=0x1d1d1f:s=60x2868:d=1 \
  -filter_complex "[6]split=5[g1][g2][g3][g4][g5];[0][g1][1][g2][2][g3][3][g4][4][g5][5]hstack=inputs=11,scale=4110:-1" \
  -frames:v 1 output/panorama.png
ls -1 output/mongdol-*.png output/panorama.png
