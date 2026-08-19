#!/usr/bin/env bash
# 플랫폼 산출물 → 이 저장소로 반입.
#
# **이 저장소는 콘텐츠의 출처가 아니라 발행 표면이다.** 마케팅 카피도, 무료 배치표도
# 정본은 janus-platform 에 있고(O184: "정본은 웹앱, 정적은 공개용 사본"), 여기는 그 사본을
# Cloudflare Pages 가 읽어갈 수 있는 곳에 놓는 역할만 한다. 여기서 직접 고치면 두 벌이 되고,
# 두 벌이 되면 어느 쪽이 맞는지 아무도 모르게 된다.
#
# 사용:
#   scripts/stage-from-platform.sh --platform ../10_platform/janus-platform
#   scripts/stage-from-platform.sh --platform <경로> --skip-baechi   # 마케팅만
set -euo pipefail

PLATFORM=""
SKIP_BAECHI=0
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

while [ $# -gt 0 ]; do
  case "$1" in
    --platform) PLATFORM="${2:-}"; shift 2;;
    --skip-baechi) SKIP_BAECHI=1; shift;;
    *) echo "알 수 없는 인자: $1" >&2; exit 2;;
  esac
done
[ -n "$PLATFORM" ] || { echo "--platform <janus-platform 경로> 가 필요하다" >&2; exit 2; }
[ -d "$PLATFORM" ] || { echo "플랫폼 경로가 없다: $PLATFORM" >&2; exit 2; }

echo "· 플랫폼: $PLATFORM"

# ── 1) 마케팅 정적 사본 ─────────────────────────────────────────────────────
MK="$PLATFORM/marketing/dist"
if [ ! -d "$MK" ] || [ -z "$(ls -A "$MK" 2>/dev/null)" ]; then
  echo "· 마케팅 산출물이 없다 — 플랫폼에서 먼저 만들어라: (cd $PLATFORM && npm run gen:marketing)" >&2
  exit 1
fi
cp "$MK"/*.html "$ROOT/public/"
echo "· 마케팅: $(ls "$MK" | wc -l | tr -d ' ')개 파일 복사"

# ── 2) 무료 배치표 ──────────────────────────────────────────────────────────
if [ "$SKIP_BAECHI" -eq 1 ]; then
  echo "· 무료 배치표 건너뜀(--skip-baechi)"
else
  FREE="$PLATFORM/dist-tier/free"
  if [ ! -d "$FREE" ] || [ -z "$(ls -A "$FREE" 2>/dev/null)" ]; then
    cat >&2 <<'MSG'
· 무료판 산출물이 없다. 플랫폼에서 먼저 빌드해야 한다:

    JANUS_ALLOWED_HOSTS="ianuspath.com,www.ianuspath.com,*.ianuspath.pages.dev" \
    JANUS_CANONICAL_ORIGIN="https://ianuspath.com" \
      python3 ops/placement/tier_build.py --src <마스터.html> --tier free
    python3 ops/placement/tier_verify.py dist-tier/free --tier free   # 비-0 이면 반입 금지

  ⚠ 마스터에 JANUS-TIER 센티넬이 없으면 검증에서 죽는다(2026-08 기준 실마스터는 0건).
    태깅은 배치표 독립 트랙 몫이다. 그때까지 이 저장소는 자리표시자를 유지한다.
MSG
    exit 1
  fi
  # 검증을 통과한 산출물만 온다는 보장이 없으므로, 여기서도 최소한을 본다.
  [ -f "$FREE/janus-build.json" ] || { echo "· 사이드카(janus-build.json)가 없다 — HTML 만 올리면 배포 감지 배너가 계속 뜬다" >&2; exit 1; }
  rm -f "$ROOT/public/baechi"/*.html "$ROOT/public/baechi/janus-build.json"
  cp "$FREE"/* "$ROOT/public/baechi/"
  echo "· 무료 배치표: $(ls "$FREE" | wc -l | tr -d ' ')개 파일 복사"
fi

# ── 3) 반입 즉시 가드 ───────────────────────────────────────────────────────
echo ""
bash "$ROOT/scripts/check-public-safe.sh"
