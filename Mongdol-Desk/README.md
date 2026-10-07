# 몽돌 데스크

iOS 앱 「몽돌」(`../Color-Moments`) 설정의 「건의하기」가 여는 **건의 페이지**와, 받은 건의를 읽는 **관리 페이지**.
원래 구글 설문이었는데 앱 디자인에 맞춰 따로 배포한다(2026-10-08 Tabber). 몽돌 ENFP 웹(`../Mongdol-ENFP-Web`)과는 **다른 Vercel 프로젝트**다 — 관례(정적 HTML + `api/` 서버리스 + Upstash)만 본떴고 파일은 나눠 쓰지 않는다.
나중에 다른 관리 기능이 붙을 수 있게 `/admin` 은 칸(섹션) 구조로 두었다. 지금 칸은 「건의함」 하나.

## 주소

| 주소 | 하는 일 |
|---|---|
| `/` | `/feedback` 으로 넘긴다(307, 쿼리 그대로) |
| `/feedback?v=<앱 버전>&b=<빌드>&d=<기종 식별자>` | 건의 쓰기. 앱이 SFSafariViewController 로 연다. 예: `/feedback?v=1.1.1&b=4&d=iPhone17,1` |
| `/admin` | 관리(토큰으로 연다) — 건의함 |
| `POST /api/feedback` | 건의 받기 |
| `GET·PATCH·DELETE /api/admin/feedback` | 건의 목록·읽음 표시·지우기(관리 토큰) |

- 쿼리는 모두 선택이다. 없으면 빈 값으로 가고 화면의 「몽돌 1.1.1 (4) · iPhone17,1 정보가 함께 가요.」 줄도 숨는다.
  모양: `v`·`b` = `[0-9A-Za-z._-]` 20자까지, `d` = `[0-9A-Za-z,._ -]` 40자까지. 어긋나면 그 값만 빈 값으로 보낸다(글을 잃지 않게).
  앱에선 `v` = `CFBundleShortVersionString`, `b` = `CFBundleVersion`, `d` = `utsname.machine`(시뮬레이터면 `SIMULATOR_MODEL_IDENTIFIER`)을 퍼센트 인코딩해서 붙이면 된다.
- 확장자 없는 주소는 `vercel.json` 의 `cleanUrls` 로(`feedback.html` → `/feedback`). 모든 응답에 `X-Robots-Tag: noindex, nofollow`, 페이지에도 `<meta name="robots">`.
- 서비스 워커·PWA 는 없다(앱 안 Safari 에서 한 번 쓰고 닫는 페이지라).

## 건의 페이지(`feedback.html` · `js/feedback.js`)

- 앱의 어둠 톤(`Color-Moments/DESIGN.md` §2 토큰: `#06070A`, 흰색 92/64/48/24) + ENFP 웹과 같은 글꼴(명조는 「몽돌」에만, 버튼만 IBM Plex Sans KR). `styles.css` 하나를 두 페이지가 같이 쓴다.
- 종류(불편한 점 `bug` / 바라는 기능 `wish` / 그 밖에 `etc`) — 기본 선택 없음, 안 고르면 `etc` 로 간다. 내용(필수, 2,000자, `61 / 2,000` 처럼 담백하게 센다), 답장 받을 곳(선택, 200자, 「적으면 답장할 때만 써요.」).
- 입력란 글자 16px — 그 아래면 iOS 가 입력할 때 화면을 확대한다.
- 보내기: 누르면 바로 잠기고(두 번 눌러도 한 번), 글마다 무작위 `cid` 를 같이 보내 응답만 못 받고 다시 눌러도 서버가 한 번만 저장한다. 성공하면 「잘 받았어요. 고마워요.」 화면, 실패하면 버튼 아래 다시 시도 안내(429 는 「한 시간에 다섯 번까지」).
- 허니팟: 화면 밖 `website` 입력. 차 있으면 서버가 성공처럼 답하고 저장하지 않는다.

## 관리 페이지(`admin.html` · `js/admin.js`)

- 처음 열면 토큰을 묻는다 → 이 브라우저 localStorage `mongdol.desk.token` 에만 둔다(try/catch, 못 써도 이번엔 쓴다). 「잠그기」로 지운다. 401 이면 지우고 다시 묻는다.
- 건의함: 최신순 50개씩(「더 불러오기」), 필터 전체·안 읽은 것·불편한 점·바라는 기능·그 밖에(불러온 것 안에서), 카드마다 종류·시각(서울)·내용·답장 받을 곳·버전·기종, 「읽음으로/안 읽음으로」, 「지우기」(확인 창).
- 사용자 글은 전부 `textContent` 로 넣는다.
- 칸 더하기: `admin.html` 의 `<nav class="sections">` 에 링크, `<section data-section>` 하나, 서버는 `api/admin/<이름>.js` 에서 `checkAdmin` 부터 부른다.

## 서버(`api/`)

- `api/feedback.js` — zod(`api/_lib/feedback.js` `FeedbackSchema`), 본문 16KB, IP 해시당 시간당 5(`@upstash/ratelimit`, 레이트리밋 장애면 통과), 색인 5,000개가 차면 503.
- `api/admin/feedback.js` — `GET ?offset&limit(≤100)` / `PATCH {id, read}` / `DELETE {id}`.
- `api/_lib/admin.js` `checkAdmin` — `ADMIN_TOKEN` 이 없으면 **503 으로 닫힘**, `Authorization: Bearer <ADMIN_TOKEN>` 을 `timingSafeEqual` 로 비교, 틀리면 401, IP 해시당 15분에 10번 틀리면 맞는 토큰도 429.
- `api/_lib/http.js` — ENFP 웹 `api/_lib/push.js` 의 `sendJSON`·`clientIp`·`readJSON`·`redisFromEnv`·`authorized` 를 옮겨 온 것.
- **IP 는 저장하지 않는다.** 레이트리밋·실패 횟수 키에만 sha256 앞 16자로 쓴다.

### Redis 키

ENFP 웹과 같은 Upstash DB 를 써도 겹치지 않게 접두사를 나눴다.

| 키 | 값 | 수명 |
|---|---|---|
| `mongdol:fb:<id>` | `{id, kind, text, contact, v, b, d, at(ms), read}` JSON | 지울 때까지 |
| `mongdol:fb:index` | ZSET score=받은 시각(ms), member=id | 지울 때까지 |
| `mongdol:fb:cid:<cid>` | 같은 글 두 번 받기 막기 | 1일 |
| `mongdol:fb:rl:*` | 보내기 레이트리밋 | 1시간 창 |
| `mongdol:desk:authfail:<IP 해시>` | 관리 토큰 틀린 횟수 | 15분 |

- id 는 `f` + 시각(36진) + 무작위 10자. `@upstash/redis` 는 ZSET member 도 JSON 처럼 생기면 숫자로 풀어 버려서 앞에 `f` 를 붙였다.
- 용량: 글 하나 최대 약 6~7KB(한글 2,000자 × 3바이트 + 나머지), 보통 1KB 안쪽. 상한 5,000개면 최악 약 35MB(Upstash 무료 256MB 안).

## 배포(새 Vercel 프로젝트)

```bash
cd Mongdol-Desk
npx vercel link            # 새 프로젝트 만들기(이름 예: mongdol-desk). Framework: Other, 빌드 명령·출력 폴더 비움
npx vercel env add ADMIN_TOKEN production        # 값: openssl rand -hex 24 로 만든 것
npx vercel env add KV_REST_API_URL production    # ENFP 웹과 같은 Upstash DB 를 쓰면 그 값 그대로
npx vercel env add KV_REST_API_TOKEN production
npx vercel --prod
```

- 루트 디렉터리는 `Mongdol-Desk`(이 폴더에서 CLI 로 올린다). Git 연결은 하지 않는다(계정 하루 배포 한도 — ENFP 웹과 같은 방식).
- Upstash 를 Vercel 「Storage → Connect」로 이 프로젝트에도 붙이면 `KV_REST_API_*` 가 자동으로 들어간다. 직접 넣을 땐 `UPSTASH_REDIS_REST_URL`·`UPSTASH_REDIS_REST_TOKEN` 이름도 받는다.
- **배포 때 지우면 안 되는 것:** `api/`, `package.json`, `package-lock.json`, `vercel.json`, `feedback.html`, `admin.html`, `styles.css`, `js/`. (`tests/`, `README.md` 는 지워도 된다. `node_modules/` 는 올리지 않는다.)
- 확인: `/feedback` 이 뜨는지, `/admin` 에서 토큰으로 열리는지, `curl -s -o /dev/null -w '%{http_code}' https://<주소>/api/admin/feedback` 가 `401`(환경변수가 없으면 `503`)인지.

## 시험

```bash
npm ci && npm run verify     # 문법 확인 + node --test (메모리 가짜 Redis — 실제 Redis 는 안 쓴다)
TZ=Asia/Seoul node tests/e2e.mjs <스크린샷 폴더> [webkit|chromium]   # 브라우저로 쓰기→보내기→관리(로그인·읽음·지우기), 390×844
```

- `tests/feedback-server.test.mjs` — 저장 형태(IP 없음) · 쿼리 없음 · 검증 실패 · 허니팟 · cid 중복 · 레이트리밋(IP 해시) · 5,000개 상한 · 관리 인증(환경변수 없음 503 / 없음·틀림 401 / 맞음 200) · 틀린 횟수 429 · 목록·쪽 나누기·읽음·지우기 · 색인만 남은 id 걷기.
- `tests/pages.test.mjs` — 두 페이지 noindex · 참조 파일이 이 폴더 안 · `vercel.json`.
- `tests/clock-redis.mjs` — ENFP 웹의 시계 달린 가짜 Redis 에 정렬 집합·mget 을 더한 것.
- `tests/e2e.mjs` 는 gstack 에 깔린 playwright 를 빌려 쓴다(의존성에 넣지 않았다).
