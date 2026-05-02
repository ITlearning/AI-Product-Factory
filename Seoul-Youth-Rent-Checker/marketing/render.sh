#!/usr/bin/env bash
# 마케팅 콘텐츠 자동 렌더 — Chrome headless로 HTML → PNG.
#
# 사용:
#   ./marketing/render.sh                # 기본: carousel 5장
#   ./marketing/render.sh story-1        # 단일 template 렌더
#
# 출력: marketing/output/{name}.png
# 인스타 캐러셀(1080×1080) / 스토리(1080×1920) / 트위터 카드(1200×675) 등.

set -euo pipefail

CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/templates"
OUTPUT_DIR="$SCRIPT_DIR/output"

mkdir -p "$OUTPUT_DIR"

if [ ! -x "$CHROME" ]; then
  echo "ERROR: Chrome not found at $CHROME"
  echo "Install Google Chrome 또는 CHROME 변수 수정."
  exit 1
fi

# Template 1개 렌더 (이름, 가로, 세로)
render() {
  local name="$1"
  local width="$2"
  local height="$3"
  local template="$TEMPLATE_DIR/$name.html"
  local output="$OUTPUT_DIR/$name.png"

  if [ ! -f "$template" ]; then
    echo "skip: $template not found"
    return 0
  fi

  echo "rendering: $name (${width}×${height})"
  # --virtual-time-budget: 외부 자원(폰트 CDN 등) 대기 시간 ms.
  # --run-all-compositor-stages-before-draw: 레이아웃·페인트 완료 후 캡처.
  "$CHROME" \
    --headless=new \
    --disable-gpu \
    --hide-scrollbars \
    --no-default-browser-check \
    --no-first-run \
    --window-size="$width","$height" \
    --screenshot="$output" \
    --default-background-color=00000000 \
    --virtual-time-budget=10000 \
    --run-all-compositor-stages-before-draw \
    "file://$template" \
    > /dev/null 2>&1

  if [ -f "$output" ]; then
    local size=$(du -h "$output" | cut -f1)
    echo "  → $output ($size)"
  else
    echo "  ERROR: $output not generated"
    return 1
  fi
}

# 인자 없으면 carousel 5장 default
if [ $# -eq 0 ]; then
  for i in 1 2 3 4 5; do
    render "carousel-$i" 1080 1080
  done
  echo ""
  echo "✅ Done. 인스타 캐러셀 5장 생성:"
  ls -lh "$OUTPUT_DIR"/carousel-*.png 2>/dev/null
else
  # 인자로 지정한 template만
  for name in "$@"; do
    # story 명명 규칙이면 9:16, 그 외 1:1
    if [[ "$name" == story* ]]; then
      render "$name" 1080 1920
    elif [[ "$name" == twitter* ]]; then
      render "$name" 1200 675
    else
      render "$name" 1080 1080
    fi
  done
fi
