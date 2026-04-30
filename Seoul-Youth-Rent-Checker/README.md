# 청년월세 체커 (Seoul Youth Rent Checker)

2026 서울시 청년월세지원 자격 5분 자가진단 웹 도구.

- 신청 기간: 2026-05-06 10:00 ~ 2026-05-19 18:00 KST
- 모집: 15,000명 / 월 20만원 × 12개월 = 240만원 / 생애 1회
- Source 공고: https://housing.seoul.go.kr/site/main/board/notice/12667

## Stack

- Vite + React 19 + Vercel `api/` Serverless (Node.js)
- Upstash Redis (Vercel Marketplace) — 익명 결과 6개월 TTL
- Cookie-bound 결과 URL `/r/[uuid]` (httpOnly UUID 매칭)
- JSON 데이터 + JS evaluator (`programs/seoul-youth-rent-2026.json` + `src/eligibility/evaluator.js`)
- @vercel/og (Node Serverless + Pretendard 서브셋)
- Zod 폼 검증
- Upstash Ratelimit 10 req/min/IP

## 디자인

자세한 토큰: [`DESIGN.md`](./DESIGN.md). 따뜻한 오프-화이트 (Toss 결).

## 개발

```bash
npm install
npm run dev          # Vite dev server
npm run dev:vercel   # Vercel dev (api/ + middleware 포함)
npm run verify       # lint + test + build
```

## 환경 변수

```
UPSTASH_REDIS_REST_URL=...
UPSTASH_REDIS_REST_TOKEN=...
```

Vercel 배포 시 자동 주입 (Upstash Marketplace 통합).

## 디렉토리

```
api/
  check.js              # POST 자격 평가 + KV 저장 + cookie set
  result/[uuid].js      # GET cookie 매칭 시 결과 반환
  og.js                 # OG 이미지 (도구 카드만, 결과 카드 X)
  fonts/                # Pretendard 서브셋 TTF
src/
  eligibility/
    evaluator.js        # JSON 기반 자격 평가
    utils.js            # 공통 유틸 (중위소득, 환산식, 4tier 매칭)
  pages/                # Landing, Form 8단계, Result
  components/           # 재사용 컴포넌트
  utils/                # 클라이언트 유틸
programs/
  seoul-youth-rent-2026.json   # 2026 서울시 청년월세지원 데이터
tests/
  eligibility/          # ~30 단위 테스트
  e2e/                  # Playwright happy path 1개
```

## 출시 체크리스트

- [ ] **5/1:** 도메인 확보 + Vercel 프로젝트 생성 + 빈 랜딩 배포
- [ ] **5/2:** programs/seoul-youth-rent-2026.json 작성 (PDF 직접 검증)
- [ ] **5/2:** evaluator + 30 단위 테스트
- [ ] **5/3:** 8단계 폼 + sessionStorage + 분기 로직
- [ ] **5/3:** 결과 페이지 + cookie 매칭 + KV
- [ ] **5/4:** OG 핸들러 + 친구 공유 + 알림 옵트인
- [ ] **5/4:** Playwright E2E + Rate limit
- [ ] **5/5 낮:** Tabber 본인 자격 입력 → PDF 분석과 결과 일치 검증
- [ ] **5/5 밤:** 프로덕션 배포 + 첫 SNS 공유
