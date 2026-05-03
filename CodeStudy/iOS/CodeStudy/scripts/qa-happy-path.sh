#!/usr/bin/env bash
#
# qa-happy-path.sh — 시뮬레이터 부팅 + Debug 빌드 + 앱 설치까지 자동화한 뒤,
# Claude Code(ios-simulator-mcp)에게 줄 happy path 시나리오를 출력한다.
#
# 사용법:
#   ./scripts/qa-happy-path.sh                    # 기본: iPhone 17
#   ./scripts/qa-happy-path.sh "iPhone 16 Pro"   # 다른 시뮬레이터
#
set -euo pipefail

cd "$(dirname "$0")/.."

DEVICE="${1:-iPhone 17}"
BUNDLE_ID="com.itlearning.codestudy"
SCHEME="CodeStudy"
SCENARIO_FILE="scripts/qa-happy-path.md"

echo "📱 시뮬레이터 준비 중: $DEVICE"

# 시뮬레이터 UDID 조회.
UDID=$(xcrun simctl list devices available | grep -E "^\s*$DEVICE\s+\(" | grep -oE "[A-F0-9-]{36}" | head -1)
if [[ -z "$UDID" ]]; then
  echo "❌ '$DEVICE' 시뮬레이터를 찾을 수 없습니다." >&2
  echo "   사용 가능 목록: xcrun simctl list devices available | grep iPhone" >&2
  exit 1
fi
echo "   UDID: $UDID"

# 부팅 (이미 부팅돼 있으면 무시).
xcrun simctl boot "$UDID" 2>/dev/null || true
open -a Simulator
echo "✅ 시뮬레이터 부팅 완료"

# Debug 빌드 (Release보다 디버깅 편함).
echo ""
echo "🔨 Debug 빌드 중..."
xcodebuild \
  -project CodeStudy.xcodeproj \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=$UDID" \
  -derivedDataPath build/qa-derived \
  build 2>&1 | xcpretty || (echo "❌ 빌드 실패" >&2; exit 1)

APP_PATH="build/qa-derived/Build/Products/Debug-iphonesimulator/CodeStudy.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "❌ 빌드 산출물 못 찾음: $APP_PATH" >&2
  exit 1
fi

# 기존 앱 제거 (clean state) 후 설치.
xcrun simctl uninstall "$UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl install "$UDID" "$APP_PATH"
echo "✅ 앱 설치 완료: $BUNDLE_ID"

# 안내 출력.
cat <<EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🤖 Happy Path QA 시나리오를 Claude Code에게 맡길 차례

새 Claude Code 세션에서 아래 한 줄로 호출:

   "$SCENARIO_FILE 시나리오를 따라 happy path QA 진행해줘.
    시뮬레이터는 이미 부팅돼 있고 앱도 설치돼 있어.
    UDID는 $UDID."

또는 IDB로 직접 앱만 띄우려면:
   xcrun simctl launch $UDID $BUNDLE_ID
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
