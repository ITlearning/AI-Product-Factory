#!/usr/bin/env bash
#
# release.sh — CodeStudy 마케팅 버전 업 + TestFlight 배포 (대화형)
#
# 사용법:
#   ./scripts/release.sh                  # 대화형
#   ./scripts/release.sh 1.2.0            # 버전 인자로
#   ./scripts/release.sh 1.2.0 --no-deploy   # 버전만 올리고 fastlane 안 부름
#   ./scripts/release.sh 1.2.0 -y         # confirm 생략
#
set -euo pipefail

# --help는 다른 검증보다 먼저.
for arg in "$@"; do
  case "$arg" in
    -h|--help) sed -n '3,9p' "$0"; exit 0 ;;
  esac
done

# 스크립트 위치 기준 프로젝트 루트로 이동.
cd "$(dirname "$0")/.."

PBXPROJ="CodeStudy.xcodeproj/project.pbxproj"

if [[ ! -f "$PBXPROJ" ]]; then
  echo "❌ $PBXPROJ 를 찾을 수 없습니다. CodeStudy/iOS/CodeStudy 디렉토리에서 실행해주세요." >&2
  exit 1
fi

# 메인 앱의 현재 MARKETING_VERSION 추출.
# pbxproj엔 메인 앱(1.1.0)과 Tests(1.0)가 따로 있지만, 메인 앱은 항상 semver(x.y.z)
# 형태로 관리하므로 그 패턴으로 필터.
CURRENT=$(grep -E "MARKETING_VERSION = [0-9]+\.[0-9]+\.[0-9]+;" "$PBXPROJ" | head -1 | sed -E 's/.*= (.*);/\1/')

if [[ -z "$CURRENT" ]]; then
  echo "❌ 현재 MARKETING_VERSION을 추출할 수 없습니다. pbxproj 형식을 확인해주세요." >&2
  exit 1
fi

echo "📦 현재 버전: $CURRENT"

# 인자 파싱.
NEW=""
SKIP_CONFIRM=false
NO_DEPLOY=false
for arg in "$@"; do
  case "$arg" in
    -y|--yes)        SKIP_CONFIRM=true ;;
    --no-deploy)     NO_DEPLOY=true ;;
    -h|--help)       ;;  # 위에서 이미 처리.
    [0-9]*) NEW="$arg" ;;
    *) echo "❌ 알 수 없는 인자: $arg" >&2; exit 1 ;;
  esac
done

# 버전 미입력 시 대화형 입력.
if [[ -z "$NEW" ]]; then
  read -r -p "🎯 새 버전 (예: $(echo "$CURRENT" | awk -F. '{print $1"."$2+1".0"}')): " NEW
fi

# 검증.
if [[ -z "$NEW" ]]; then
  echo "❌ 버전이 비어있어 종료." >&2
  exit 1
fi
if ! [[ "$NEW" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "❌ 버전 형식이 잘못됨: $NEW (예: 1.2.0)" >&2
  exit 1
fi
if [[ "$CURRENT" == "$NEW" ]]; then
  echo "ℹ️  현재 버전과 동일합니다. 종료." >&2
  exit 0
fi

# git 상태 클린 검증.
if [[ -n "$(git status --porcelain "$PBXPROJ")" ]]; then
  echo "❌ pbxproj에 unstaged 변경사항이 있습니다. 먼저 정리해주세요." >&2
  exit 1
fi

ACTION_DESC="$CURRENT → $NEW"
if [[ "$NO_DEPLOY" == false ]]; then
  ACTION_DESC="$ACTION_DESC + TestFlight 배포"
fi

echo ""
echo "📝 작업 요약:"
echo "   $ACTION_DESC"
echo ""

if [[ "$SKIP_CONFIRM" == false ]]; then
  read -r -p "계속 진행? [y/N] " yn
  if [[ "$yn" != "y" && "$yn" != "Y" ]]; then
    echo "취소됨."
    exit 0
  fi
fi

# pbxproj 수정 (메인 앱의 정확한 현재 값만 치환 — Tests의 "1.0"은 패턴 매칭 안 됨).
sed -i '' "s/MARKETING_VERSION = $CURRENT;/MARKETING_VERSION = $NEW;/g" "$PBXPROJ"

# 변경 검증 — grep exit code만 사용 (변수 안 거치는 게 set -u 환경에서 안전).
if ! grep -qF "MARKETING_VERSION = $NEW;" "$PBXPROJ"; then
  echo "❌ 버전 치환이 적용되지 않음. 롤백." >&2
  git checkout -- "$PBXPROJ"
  exit 1
fi

echo "✅ pbxproj 수정 완료"

# 커밋.
git add "$PBXPROJ"
git commit -m "chore(CodeStudy): bump version to $NEW"
echo "✅ 커밋 완료"

if [[ "$NO_DEPLOY" == true ]]; then
  echo ""
  echo "🛑 --no-deploy 지정. 배포는 건너뜁니다."
  echo "   직접 배포하려면: bundle exec fastlane beta"
  exit 0
fi

# fastlane beta 호출.
echo ""
echo "🚀 TestFlight 배포 시작..."
bundle exec fastlane beta
