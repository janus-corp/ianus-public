#!/usr/bin/env bash
# 공개 발행 가드 — 이 저장소에 들어가면 **되돌릴 수 없는 것**을 막는다.
#
# 왜 별도 검사인가: 플랫폼(janus-platform)의 `tier_verify.py` 는 **빌드 시점**에
# 산출물을 검증한다. 이 스크립트는 **발행 시점**에, 실제로 여기 놓인 파일을 본다.
# 두 시점 사이에 사람이 파일을 손으로 복사해 넣을 수 있고, 그게 이 저장소의 실제 위험이다.
# 그래서 일부러 **독립적이고 거친** 검사를 한다 — 티어 게이트를 흉내내지 않는다.
# (정밀 판정은 플랫폼 몫이다. 여기서 흉내내면 두 판정이 갈라지고, 갈라지면 둘 다 못 믿는다.)
#
# 실패하면 비-0. pre-commit 훅과 CI 가 같은 스크립트를 부른다.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PUB="$ROOT/public"
FAIL=0

say()  { printf '%s\n' "$*"; }
bad()  { printf '  ❌ %s\n' "$*"; FAIL=1; }
ok()   { printf '  ✅ %s\n' "$*"; }

say "공개 발행 가드 — $PUB"
[ -d "$PUB" ] || { say "  ❌ public/ 이 없다"; exit 2; }

# ── 1) 질량 — 마스터가 통째로 들어오면 여기서 걸린다 ────────────────────────
# 무료판 껍데기는 KB 단위다(플랫폼 실측 52~99KB). MB 급 파일은 그 자체로 사고 신호다.
BAECHI_FILE_MAX=$((256 * 1024))
BAECHI_SET_MAX=$((2 * 1024 * 1024))
ANY_FILE_MAX=$((4 * 1024 * 1024))

big=0
while IFS= read -r f; do
  sz=$(wc -c < "$f" | tr -d ' ')
  rel="${f#$PUB/}"
  if [ "$sz" -gt "$ANY_FILE_MAX" ]; then
    bad "파일이 너무 크다: $rel ($((sz/1024))KB > $((ANY_FILE_MAX/1024))KB)"
    big=1
  fi
  case "$rel" in
    baechi/*)
      if [ "$sz" -gt "$BAECHI_FILE_MAX" ]; then
        bad "무료 배치표 파일 상한 초과: $rel ($((sz/1024))KB > $((BAECHI_FILE_MAX/1024))KB)
     — 무료판 껍데기는 KB 단위여야 한다. 마스터가 그대로 들어왔는지 확인하라."
        big=1
      fi
      ;;
  esac
done < <(find "$PUB" -type f)
[ "$big" -eq 0 ] && ok "파일 질량 상한 통과"

if [ -d "$PUB/baechi" ]; then
  total=$(find "$PUB/baechi" -type f -exec wc -c {} + 2>/dev/null | tail -1 | awk '{print $1}')
  total=${total:-0}
  if [ "$total" -gt "$BAECHI_SET_MAX" ]; then
    bad "무료 배치표 합계 상한 초과: $((total/1024))KB > $((BAECHI_SET_MAX/1024))KB (분할 적재 의심)"
  else
    ok "무료 배치표 합계 $((total/1024))KB"
  fi
fi

# ── 2) 저작권 유래 마커 ─────────────────────────────────────────────────────
# 목록은 최후의 그물이다 — 이것만 믿지 않는다(질량이 1차 방어선).
FORBIDDEN=(
  '어디가' 'esteacher' '고속성장' '고속_어디가' '고속_표점' 'gosok' 'GOSOK'
  '__JANUS_RAWDATA__' '__JANUS_CUTS__'
)
hits=0
for tok in "${FORBIDDEN[@]}"; do
  n=$(grep -rlF "$tok" "$PUB" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$n" -gt 0 ]; then
    bad "금지 토큰 '$tok' — $n개 파일: $(grep -rlF "$tok" "$PUB" 2>/dev/null | sed "s#$PUB/##" | tr '\n' ' ')"
    hits=1
  fi
done
[ "$hits" -eq 0 ] && ok "저작권 유래 마커 0건"

# ── 3) 잔존 센티넬 — 상위 티어 영역이 안 지워진 채 들어온 것 ────────────────
n=$( { grep -rl 'JANUS-TIER' "$PUB" 2>/dev/null || true; } | wc -l | tr -d ' ')
if [ "$n" -gt 0 ]; then
  bad "'JANUS-TIER' 센티넬이 남아 있다 — $n개 파일.
     무료판은 상위 티어 영역이 **물리적으로 제거된** 산출물이어야 한다.
     플랫폼에서 tier_build.py --tier free 로 다시 만들어 가져와라."
else
  ok "잔존 센티넬 0건"
fi

# ── 4) 금지 확장자(gitignore 를 우회해 강제 추가된 경우) ────────────────────
n=$(find "$PUB" -type f \( -name '*.xlsx' -o -name '*.xls' -o -name '*.csv' -o -name '*.tsv' \
      -o -name '*.db' -o -name '*.sqlite' -o -name '*.sql' -o -name '*.dump' \) | wc -l | tr -d ' ')
if [ "$n" -gt 0 ]; then
  bad "데이터 파일 확장자 $n건 — public/ 에 원천 데이터를 두지 않는다"
else
  ok "데이터 확장자 0건"
fi

# ── 5) 시크릿 흔적(간이) ────────────────────────────────────────────────────
if grep -rElq '(BEGIN [A-Z ]*PRIVATE KEY|sk-[A-Za-z0-9]{20,}|ghp_[A-Za-z0-9]{20,})' "$PUB" 2>/dev/null; then
  bad "시크릿으로 보이는 문자열 검출"
else
  ok "시크릿 흔적 0건"
fi

# ── 6) 무료 배치표가 '실물'이면 필수 표식이 있어야 한다 ─────────────────────
# 자리표시자(준비 중)에는 표식을 요구하지 않는다 — 표식 요구가 자리표시자를 막으면
# "가드를 끄고 올리는" 우회를 부른다. 실물인지는 사이드카 존재로 판정한다.
if [ -f "$PUB/baechi/janus-build.json" ]; then
  html=$(find "$PUB/baechi" -name '*.html' | head -1)
  if [ -z "$html" ]; then
    bad "사이드카(janus-build.json)는 있는데 HTML 이 없다"
  else
    miss=()
    for m in 'data-janus-watermark' '__JANUS_TIER' '[야누스 A4]' '[야누스 A6]' '[야누스 A7]'; do
      grep -qF "$m" "$html" || miss+=("$m")
    done
    if [ ${#miss[@]} -gt 0 ]; then
      bad "무료판 필수 표식 누락: ${miss[*]}
     — 워터마크·면책·배포감지(A4)·미러감지(A6)·D-day(A7) 없이 공개하지 않는다."
    else
      ok "무료판 필수 표식 5종 존재"
    fi
  fi
else
  ok "무료 배치표 실물 없음(자리표시자) — 표식 검사 생략"
fi

say ""
if [ "$FAIL" -ne 0 ]; then
  say "✗ 발행 불가 — 위 항목을 해소하기 전에는 커밋·배포하지 않는다."
  say "  이 저장소는 public 이다. 한 번 올라간 것은 커밋을 되돌려도 사라지지 않는다."
  exit 1
fi
say "✓ 공개 발행 가드 통과"
