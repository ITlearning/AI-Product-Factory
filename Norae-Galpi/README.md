# 노래갈피 (Songmark)

노래에 얽힌 기억 아카이브. 로그인 없이, 곡 하나에 기억 한 편씩 쌓인다.

설계 정본: [`docs/designs/norae-galpi.md`](../docs/designs/norae-galpi.md) (rev.6, APPROVED)
· 화면: [`norae-galpi-wireframe.html`](../docs/designs/norae-galpi-wireframe.html)
· 토큰: [`norae-galpi-DESIGN.md`](../docs/designs/norae-galpi-DESIGN.md)
· 시드: [`norae-galpi-seed.md`](../docs/designs/norae-galpi-seed.md)

## 지금 상태

Next Steps **0번(시드)** 까지. DB·엔드포인트·화면은 아직 없다.

| Next Step | 상태 |
|---|---|
| 0. 시드 | 데이터·검증·로더 완료 / **유튜브 영상 ID 9곡 미정** |
| 1. Neon + 스키마 마이그레이션 | 미착수 |
| 2~11 | 미착수 |

## 구조

```
seed/seed.json        곡 11개 + 기억 11편. title·artist·artwork_url은 iTunes lookup(kr) 실측값
seed/validate.js      DB 없이 스키마 제약·PII를 재현 검사
seed/check.js         위 검사 CLI
seed/check-videos.js  적힌 유튜브 영상이 살아있는지 oEmbed로 확인
seed/load.js          멱등 로더. 마이그레이션 뒤에 돌린다
src/identity.js       기기 비밀키 → SHA-256. 해시는 반드시 서버에서 계산한다
src/labels.js         계절 4 · 시절 6. 스키마 CHECK와 화면 칩이 같이 본다
src/moderation.js     PII 정규식 — v1 모더레이션의 유일한 자동 층
```

## 명령

```bash
npm run verify         # lint + test
npm run seed:validate  # 시드가 스키마·PII를 통과하는지 (DB 불필요)
npm run seed:videos    # 시드의 유튜브 영상이 살아있는지 (네트워크 필요)
npm run seed:dry-run   # 무엇이 들어갈지 미리보기 (DB 불필요)
npm run migrate        # 스키마 (Next Step 1에서 생김)
npm run seed:load      # 실제 적재. DATABASE_URL 필요
```

`seed:validate`의 종료 코드 — 0 통과 / 1 에러 / 2 사람이 채울 칸이 남음.

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
