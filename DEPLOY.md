# 배포 — Cloudflare Pages

## 확정값 (2026-08-08, 세션인계 §3-①)

| 항목 | 값 |
|---|---|
| Pages 프로젝트 | `ianuspath` → 기본 주소 `ianuspath.pages.dev` |
| 원천 | **이 저장소의 `main` 브랜치** |
| 발행 디렉터리 | `public` |
| 빌드 명령 | 없음(정적) |
| 커스텀 도메인 | `ianuspath.com` · `www.ianuspath.com` |

## ⚠ 사람이 해야 하는 부분

**Cloudflare Pages 프로젝트 생성과 커스텀 도메인 연결은 대시보드 작업이라 코드 세션이 못 한다.**
아래 3·4번은 사용자가 직접 한다. 세션은 그 전후(저장소·빌드·검증)를 맡는다.

## 절차

1. **저장소 준비** — 이 저장소를 GitHub 에 public 으로 올린다.
   ```bash
   scripts/check-public-safe.sh     # 통과해야 push
   git push -u origin main
   ```

2. **반입** — 마케팅·무료 배치표를 플랫폼에서 가져온다.
   ```bash
   scripts/stage-from-platform.sh --platform ../10_platform/janus-platform
   ```

3. **[사람] Pages 프로젝트 생성** — Cloudflare 대시보드 → Workers & Pages → Create → Pages →
   Connect to Git → 이 저장소 → 프로젝트명 `ianuspath` · 발행 디렉터리 `public` · 빌드 명령 없음.

4. **[사람] 커스텀 도메인 연결** — `ianuspath.com` · `www.ianuspath.com`.

5. **완료 확인** — **로컬 스택을 내린 상태에서** 무료 배치표가 열려야 한다.
   ```bash
   docker compose -f ../10_platform/janus-platform/docker-compose.full.yml down
   curl -sI https://ianuspath.com/baechi/ | head -1
   ```
   맥 스택이 떠 있으면 "열린다"가 엣지에서 서빙된 증거가 되지 못한다. 반드시 내리고 확인한다.

## 무료판 빌드 ENV — 와일드카드를 빼지 말 것

```bash
IANUS_ALLOWED_HOSTS="ianuspath.com,www.ianuspath.com,*.ianuspath.pages.dev" \
IANUS_CANONICAL_ORIGIN="https://ianuspath.com" \
  python3 ops/placement/tier_build.py --src <마스터.html> --tier free
python3 ops/placement/tier_verify.py dist-tier/free --tier free   # 비-0 이면 배포 금지
```

`*.ianuspath.pages.dev` 를 빼면 **Pages 미리보기 배포가 미러로 판정돼 튕긴다**
(`<해시>.ianuspath.pages.dev` 로 나가기 때문). 하필 배포를 검증하는 그 순간에 걸린다.

값은 저장소에 커밋하지 않는다 — 산출물에는 djb2 해시만 들어간다(원본 주소만 평문이며,
리다이렉트 목적지라 해시로 만들 수 없다).

**사이드카 `janus-build.json` 을 HTML 과 함께** 올려야 한다. 하나만 올리면 A4 배포 감지
배너가 계속 뜬다.

## 선행 — 아직 안 풀린 것

무료 배치표 **실물**은 마스터에 `JANUS-TIER` 센티넬이 태깅돼야 나온다. 2026-08 실측 기준
실마스터 5종 전부 0건이고, 태깅은 배치표 독립 트랙 몫이다. 그때까지 `/baechi/` 는
자리표시자를 유지한다 — 주소를 먼저 잡아 두는 것이 목적이다.

확인:
```bash
grep -o 'JANUS-TIER' <마스터.html> | wc -l    # 0 이면 아직 미태깅
```
