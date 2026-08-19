#!/usr/bin/env bash
# 가드 음성 대조 — 일부러 위반을 심어 **가드가 실제로 죽는지** 본다.
#
# 통과만 보는 검사는 가드가 죽어 있어도 통과한다. 이 저장소는 public 이라
# 그 착각의 대가가 되돌릴 수 없는 노출이다. 그래서 양성(정상 통과)과
# 음성(위반 검출) 양쪽을 매번 확인한다.
#
# 위반은 **임시 디렉토리 사본**에 심는다 — 실제 public/ 을 건드리지 않는다.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0
check() { if [ "$2" = "0" ]; then printf '  ✅ %s\n' "$1"; PASS=$((PASS+1)); else printf '  ❌ %s — %s\n' "$1" "${3:-}"; FAIL=$((FAIL+1)); fi; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cp -R "$ROOT" "$WORK/repo"
GUARD="$WORK/repo/scripts/check-public-safe.sh"
PUB="$WORK/repo/public"
reset_pub() { rm -rf "$PUB"; cp -R "$ROOT/public" "$PUB"; }

run() { bash "$GUARD" >/dev/null 2>&1; echo $?; }
run_out() { bash "$GUARD" 2>&1; }

echo "가드 음성 대조"
echo ""
echo "[0) 기준선 — 현재 public/ 은 통과해야 한다]"
reset_pub
code=$(run); check "기준선 통과(exit 0)" "$([ "$code" = "0" ] && echo 0 || echo 1)" "exit=$code"

echo ""
echo "[1) 저작권 마커를 심으면 죽는가]"
reset_pub
printf '<p>어디가 2026 입결</p>' > "$PUB/leak.html"
code=$(run); check "비-0 종료" "$([ "$code" != "0" ] && echo 0 || echo 1)" "exit=$code"
out=$(run_out); check "파일명을 지목" "$(echo "$out" | grep -q 'leak.html' && echo 0 || echo 1)"

echo ""
echo "[2) 잔존 센티넬이 있으면 죽는가]"
reset_pub
printf '<!--JANUS-TIER:paid-->비밀<!--/JANUS-TIER-->' > "$PUB/baechi/index.html"
code=$(run); check "비-0 종료" "$([ "$code" != "0" ] && echo 0 || echo 1)" "exit=$code"
out=$(run_out); check "무엇을 하라고 말한다" "$(echo "$out" | grep -q 'tier_build.py' && echo 0 || echo 1)"

echo ""
echo "[3) 배치표 파일이 너무 크면 죽는가 — 마스터 통째 반입]"
reset_pub
head -c $((400 * 1024)) /dev/zero | tr '\0' 'x' > "$PUB/baechi/big.html"
code=$(run); check "비-0 종료" "$([ "$code" != "0" ] && echo 0 || echo 1)" "exit=$code"
out=$(run_out); check "KB 로 얼마나 넘었는지 말한다" "$(echo "$out" | grep -q 'KB >' && echo 0 || echo 1)"

echo ""
echo "[4) 데이터 확장자를 심으면 죽는가]"
reset_pub
printf 'a,b\n1,2\n' > "$PUB/data.csv"
code=$(run); check "비-0 종료" "$([ "$code" != "0" ] && echo 0 || echo 1)" "exit=$code"

echo ""
echo "[5) 실물 배치표인데 표식이 없으면 죽는가]"
reset_pub
printf '{"buildId":"x","tier":"free"}' > "$PUB/baechi/janus-build.json"
printf '<html><body>표식 없는 배치표</body></html>' > "$PUB/baechi/index.html"
code=$(run); check "비-0 종료" "$([ "$code" != "0" ] && echo 0 || echo 1)" "exit=$code"
out=$(run_out); check "누락한 표식을 이름으로 지목" "$(echo "$out" | grep -q '야누스 A6' && echo 0 || echo 1)"

echo ""
echo "[6) 시크릿을 심으면 죽는가]"
reset_pub
printf 'token=ghp_%s\n' "$(printf 'A%.0s' $(seq 1 30))" > "$PUB/secret.txt"
code=$(run); check "비-0 종료" "$([ "$code" != "0" ] && echo 0 || echo 1)" "exit=$code"

echo ""
echo "[7) 위반을 치우면 다시 통과하는가 — 가드가 '항상 죽는' 것이 아님을 증명]"
reset_pub
code=$(run); check "복구 후 통과" "$([ "$code" = "0" ] && echo 0 || echo 1)" "exit=$code"

echo ""
echo "─────────────────────────────"
echo "통과 $PASS · 실패 $FAIL"
[ "$FAIL" -eq 0 ] || exit 1
