# 노래갈피 (Songmark)

노래에 얽힌 기억 아카이브. 로그인 없이, 곡 하나에 기억 한 편씩 쌓인다.

설계 정본: [`docs/designs/norae-galpi.md`](../docs/designs/norae-galpi.md) (rev.6, APPROVED)
· 화면: [`norae-galpi-wireframe.html`](../docs/designs/norae-galpi-wireframe.html)
· 토큰: [`norae-galpi-DESIGN.md`](../docs/designs/norae-galpi-DESIGN.md)
· 시드: [`norae-galpi-seed.md`](../docs/designs/norae-galpi-seed.md)

## 지금 상태

**엔드포인트 9개 전부 완료.** 화면(Next Steps 5~10의 UI 절반)만 남았다.

| Next Step | 상태 |
|---|---|
| 0. 시드 | 데이터·검증·로더 완료 / **유튜브 영상 ID 9곡 미정** |
| 1. 스키마 마이그레이션 | SQL·러너·인덱스 결론 완료 / **Neon 프로젝트 생성은 Tabber 몫** |
| 2. 공통 모듈 3개 | `identity` · `itunes` · `db` 완료 |
| 3. 골든 테스트 | 드라이런 20곡 — `titleKey` 19/19, 원곡 1순위 19/19 |
| 4. `POST /api/memories` | 완료. 순서 못 박음 — 본문 → PII → 레이트리밋 → 곡 upsert → 글 → 퍼지 2키 |
| 5~10 (API 절반) | 곡 검색·영상 후보·피드·곡 상세·내 갈피·좋아요·신고·운영자 숨김 완료 |
| 5~10 (화면) | **미착수 — 프런트엔드 스택 결정 필요** |
| 11. 출시 | 미착수 |

### 엔드포인트 9개

| | |
|---|---|
| `GET  /api/song-search?q=` | ① 곡 검색. 자동 선택 없음 |
| `GET  /api/video-search?q=` · `?url=` | ② 영상 후보. 키 없으면 직접 링크만 |
| `POST /api/memories` | ③④ 기억 올리기 |
| `GET  /api/feed?sort=&season=&page=` | ⑤ 피드. 캐시 + SWR |
| `GET  /api/song?id=` | ⑥ 곡 상세 |
| `GET  /api/mine` | ⑦ 내 갈피. `X-Device-Key` 헤더 |
| `POST /api/likes` | 좋아요 토글. 개수는 응답에 없다 |
| `POST /api/reports` | 신고 |
| `POST /api/admin-hide` | 운영자 숨김. `X-Admin-Token` |

**기기 비밀키는 절대 쿼리스트링으로 받지 않는다.** URL은 프록시 로그·리퍼러·브라우저
히스토리에 남는 자리라, 거기 키가 실리면 서버에 해시만 저장하는 설계가 통째로 무의미해진다.
GET은 `X-Device-Key` 헤더, POST는 본문으로 받는다.

**미해결이던 인덱스 설계는 실측으로 닫았다** — `migrations/001_init.sql` 의 주석에 근거가 있다.
`docs/designs/norae-galpi.md` 의 나머지 미해결(동시 등록 경합 화면, Neon CU 소진 경로 등)은 그대로다.

## 구조

```
seed/seed.json        곡 11개 + 기억 11편. title·artist·artwork_url은 iTunes lookup(kr) 실측값
seed/validate.js      DB 없이 스키마 제약·PII를 재현 검사
seed/check.js         위 검사 CLI
seed/check-videos.js  적힌 유튜브 영상이 살아있는지 oEmbed로 확인
seed/load.js          멱등 로더. 마이그레이션 뒤에 돌린다
migrations/001_init.sql  테이블 4 + 인덱스 4. 인덱스를 왜 그렇게 잡았는지 주석에 실측이 있다
migrations/run.js     멱등 러너. -- 주석을 먼저 지우고 ;로 쪼갠다 (순서가 반대면 깨진다)
src/feed.js           ⑤ 피드 쿼리 2번 + 곡 단위 접기
src/identity.js       기기 비밀키 → SHA-256. 해시는 반드시 서버에서 계산한다
src/itunes.js         검색(us) → 표기(kr) → 한글 재정렬 → MR 하향. titleKey 정규화
src/db.js             Neon 클라이언트. 트랜잭션도 multi-statement도 없다
src/kv.js             Upstash Redis. 없어도 서비스는 돈다(캐시 미스·레이트리밋 통과)
src/cache.js          피드 캐시 3키. **퍼지 대상이 트리거마다 다르다**
src/ratelimit.js      작성 분당 1편·일 20편, 유튜브 검색 일 100회(태평양 자정 리셋)
src/songs.js          곡 upsert. 시드 로더와 API가 같은 경로를 쓴다
src/memories.js       기억 올리기. 순서가 못 박혀 있다
src/youtube.js        ② 영상 후보. 키 없음·쿼터 소진·403이 전부 같은 폴백을 탄다
src/read.js           피드·곡 상세·내 갈피·좋아요
src/moderation-actions.js  신고·자동 숨김·운영자 숨김
src/http.js           핸들러 공통. 본문·헤더를 로그에 안 남긴다
api/*.js              엔드포인트 9개. 전부 Pages 스타일 (req, res)
DESIGN.md             토큰·컴포넌트 사양 (docs/designs/norae-galpi-DESIGN.md 사본)
src/labels.js         계절 4 · 시절 6. 스키마 CHECK와 화면 칩이 같이 본다
src/moderation.js     PII 정규식 — v1 모더레이션의 유일한 자동 층
tests/fixtures/itunes-dryrun.json  드라이런 20곡의 실제 iTunes 응답. 테스트는 네트워크를 안 탄다
```

## 명령

```bash
npm run verify         # lint + test
npm run seed:validate  # 시드가 스키마·PII를 통과하는지 (DB 불필요)
npm run seed:videos    # 시드의 유튜브 영상이 살아있는지 (네트워크 필요)
npm run seed:dry-run   # 무엇이 들어갈지 미리보기 (DB 불필요)
npm run migrate        # 스키마 적용. DATABASE_URL 필요
npm run seed:load      # 실제 적재. DATABASE_URL 필요
```

`seed:validate`의 종료 코드 — 0 통과 / 1 에러 / 2 사람이 채울 칸이 남음.

테스트는 PGlite(WASM Postgres)에 **실제 마이그레이션을 적용해서** 돌린다. Neon 없이도 스키마·제약·
피드 쿼리·실행 계획을 확인할 수 있다. 단 PGlite는 PostgreSQL 18, Neon은 보통 17이라
**실행 계획은 Neon에서 다를 수 있다.**

## 시드를 채우는 법

`seed/seed.json`의 `youtube_video_id`가 `null`인 곡에 영상 ID 11자를 넣는다.
`https://www.youtube.com/watch?v=**XtYGk-kvWP0**` 에서 굵은 부분.

넣고 나서 `npm run seed:videos`로 **영상 제목을 눈으로 대조한다.** 형식 검사는
곡과 다른 영상이 붙은 것을 잡지 못한다 — 「그래 우리 함께」의 기억이 BTS 봄날에 붙는 사고가 그 경로다.

`source: "youtube"`인 「그래 우리 함께」는 영상 ID가 **곡의 열쇠 그 자체**라
그 곡에 붙일 영상을 먼저 정해야 한다. 아트워크도 그 영상의 oEmbed 썸네일에서 온다.

## 지켜야 하는 것

- **자체 스트리밍을 하지 않는다.** 재생은 유튜브 임베드로만. 죽은 음악 서비스들의 사인이 전부 음원 권리·비용이었다
- **기기 비밀키 원본을 로그에 남기지 않는다.** 요청 본문 로깅도 포함
- **행을 지우지 않는다.** 운영자 처리는 `memories.status` 변경이지 DELETE가 아니다
- Vercel 함수는 Pages 스타일 `(req, res)` + `export const config = { runtime: "nodejs" }`
- Neon HTTP 드라이버는 multi-statement·트랜잭션을 지원하지 않는다
