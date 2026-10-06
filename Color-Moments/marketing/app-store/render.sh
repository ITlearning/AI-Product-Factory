#!/bin/bash
# 몽돌 App Store 미리보기 6장을 output/ 에 굽는다.
#   ./render.sh                  6.9인치 6장(1320×2868, 알파 없는 PNG) mongdol-N.png + 이어 붙인 panorama.png
#                                + 6.1인치 6장(1206×2622) medium-N.png — App Store Connect 필수 칸(Dynamic Island 중형)
#   ./render.sh preview          panorama-preview.png 한 장만 (빠른 확인용)
#   ./render.sh notch            6.5인치 노치 판 6장(1284×2778) notch-N.png + notch-panorama.png
#   ./render.sh notch preview    notch-panorama-preview.png 한 장만
set -euo pipefail
cd "$(dirname "$0")"

CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
FONT=fonts/NanumMyeongjo-Bold.ttf
mkdir -p fonts output
[ -f "$FONT" ] || curl -fL -o "$FONT" https://github.com/google/fonts/raw/main/ofl/nanummyeongjo/NanumMyeongjo-Bold.ttf
[ -d input ] || { echo "input/ 이 없어요 — 스크린샷·사진 원본(커밋 안 함)을 여기에 두세요. 목록은 docs/designs/mongdol-appstore-screens.md" >&2; exit 1; }

shoot() { # url width height out
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
    --allow-file-access-from-files --virtual-time-budget=6000 \
    --window-size="$2,$3" --screenshot="$4" "$1" >/dev/null 2>&1
}

PAGE="file://$PWD/index.html"

if [ "${1:-}" = "notch" ]; then
  shift
  # 장 사이 간격도 같은 비율로 — 60×1284/1320 ≈ 58
  W=1284 H=2778 GAP=58 PREVIEW_H=688 Q="device=notch" NAME=notch PREVIEW=notch-panorama-preview.png PANO=notch-panorama.png
else
  W=1320 H=2868 GAP=60 PREVIEW_H=691 Q="" NAME=mongdol PREVIEW=panorama-preview.png PANO=panorama.png
fi

if [ "${1:-}" = "preview" ]; then
  shoot "$PAGE${Q:+?$Q}" 1980 "$PREVIEW_H" "output/$PREVIEW"
  echo "output/$PREVIEW"
  exit 0
fi

for n in 1 2 3 4 5 6; do
  shoot "$PAGE?frame=$n${Q:+&$Q}" "$W" "$H" "output/raw-$n.png"
  # App Store 는 알파 채널이 있는 PNG 를 받지 않는다.
  ffmpeg -loglevel error -y -i "output/raw-$n.png" -pix_fmt rgb24 "output/$NAME-$n.png"
  rm "output/raw-$n.png"
done

# 6.1인치(Dynamic Island 중형)는 6.9인치와 비율이 같다(0.4603 대 0.4600) — 줄이기만 한다.
# 이 칸이 비면 스토어가 6.5인치 노치 판을 줄여 보여 준다.
if [ "$NAME" = mongdol ]; then
  for n in 1 2 3 4 5 6; do
    ffmpeg -loglevel error -y -i "output/mongdol-$n.png" -vf "scale=1206:2622:flags=lanczos" -pix_fmt rgb24 "output/medium-$n.png"
  done
fi

# 스토어처럼 장 사이 간격을 두고 이어 붙인 확인용 한 장
O="output/$NAME"
ffmpeg -loglevel error -y -i "$O-1.png" -i "$O-2.png" -i "$O-3.png" -i "$O-4.png" -i "$O-5.png" -i "$O-6.png" \
  -f lavfi -i "color=c=0x1d1d1f:s=${GAP}x${H}:d=1" \
  -filter_complex "[6]split=5[g1][g2][g3][g4][g5];[0][g1][1][g2][2][g3][3][g4][4][g5][5]hstack=inputs=11,scale=iw/2:-1" \
  -frames:v 1 "output/$PANO"
ls -1 "$O"-[1-6].png "output/$PANO"
[ "$NAME" = mongdol ] && ls -1 output/medium-[1-6].png
