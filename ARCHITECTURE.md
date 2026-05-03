# Architecture

이 문서는 `AI-Product-Factory` 모노레포의 기술 아키텍처를 설명한다.
[matklad의 ARCHITECTURE.md 컨벤션](https://matklad.github.io/2021/02/06/ARCHITECTURE.md.html)을 따른다.

---

## High-Level Structure

```text
AI-Product-Factory/          ← 모노레포 루트
├── IBAD/app/                ← 서비스: 한국어 거절 메시지
├── Translate-Developer/     ← 서비스: 개발자 언어 번역
├── Spending-Personality/    ← 서비스: 소비 성격 진단
├── Date-Soragodong/         ← 서비스: 커플 데이트 코스 뽑기
├── CodeStudy/iOS/           ← 서비스: 코드 학습 iOS 앱 (CodeStudy)
├── Seoul-Youth-Rent-Checker/ ← 서비스: 서울 청년월세지원 자격 체커
├── UGGK/                    ← 서비스: 초기 단계 (디렉토리 미생성, spec-first)
├── docs/                    ← 설계 문서, 프로세스 문서
│   ├── process/             ← 프로세스 시퀀스 문서 (CHARTER / SEQUENCE / INTAKE / PRD_TEMPLATE / EXECUTION / DECOMPOSITION / EVIDENCE / DOC_LINT / COMMON)
│   ├── plans/               ← 설계/계획 문서
│   └── evidence/            ← PR 검증 증거 기록
├── scripts/                 ← 저장소 레벨 스크립트
├── AGENTS.md                ← 에이전트 진입점 맵
├── ARCHITECTURE.md          ← 이 파일
└── README.md                ← 저장소 운영 안내
```

---

## Design Decisions

### 모노레포 선택

이 저장소는 여러 독립 서비스를 하나의 리포에 모은 모노레포다. 각 서비스는 독립된 최상위 디렉토리에 위치하고, 서비스 간 코드 공유는 없다. 공유되는 것은 하네스 문서, 운영 규칙, 배포 인프라(Vercel) 뿐이다.

이 구조를 선택한 이유:
- 모노레포 하나에 공통 프로세스 문서를 두면 모든 서비스가 같은 6단계 시퀀스로 운영된다
- 서비스별 독립 리포를 두면 프로세스 규칙이 분산되어 일관성이 깨진다
- 작은 실험 서비스들이므로 리포 분리의 이점보다 통합 관리의 이점이 크다

### 서비스 간 독립성

서비스는 서로 의존하지 않는다. 각 서비스는:
- 자체 `package.json`과 의존성을 갖는다
- 자체 빌드/검증 파이프라인을 갖는다
- 독립적으로 배포된다
- 다른 서비스의 코드를 import하지 않는다

cross-cutting 작업은 명시적으로 선언된 경우에만 허용된다.

---

## Services

### IBAD/app

한국어 거절 메시지 생성 웹 앱.

| 항목 | 값 |
|------|-----|
| 경로 | `IBAD/app/` |
| 런타임 | Node.js (ESM) |
| 빌드 | `node scripts/build.mjs` |
| 검증 | `npm run verify` (lint → test → build) |
| 배포 | Vercel |
| 상태 | active |

### Translate-Developer

개발자 언어를 일반 한국어로 번역하는 웹 앱.

| 항목 | 값 |
|------|-----|
| 경로 | `Translate-Developer/` |
| 런타임 | Node.js (ESM) |
| 프레임워크 | Vite + React 19 |
| API | `api/translate.js` (Vercel serverless function) |
| 빌드 | `vite build` |
| 검증 | `npm run verify` (lint → test → build) |
| 배포 | Vercel |
| 상태 | active |

### Spending-Personality

소비 성격 진단 웹 앱.

| 항목 | 값 |
|------|-----|
| 경로 | `Spending-Personality/` |
| 런타임 | Node.js (ESM) |
| 빌드 | `node scripts/build.mjs` |
| 검증 | `npm run verify` (lint → test → build) |
| 배포 | Vercel |
| 상태 | active |

핵심 모듈:
- `src/character-engine.js` — 캐릭터 생성 엔진
- `src/character-contract.js` — 캐릭터 계약 정의
- `src/content.js` — 콘텐츠 데이터

### Date-Soragodong

커플 데이트 코스 뽑기 웹 앱. 갈 곳 / 먹을 곳 / 탈 것 / 금액 4가지 카테고리에서 랜덤으로 조합을 뽑아 공유할 수 있다.

| 항목 | 값 |
|------|-----|
| 경로 | `Date-Soragodong/` |
| 런타임 | Node.js (ESM) |
| 프레임워크 | Vite + React 19 |
| API | `api/og.js` (Vercel Edge Runtime — OG 이미지) |
| Middleware | `middleware.js` (Edge Middleware — /result OG 메타 주입) |
| 빌드 | `vite build` |
| 검증 | `npm run verify` (lint → test → build) |
| 배포 | Vercel |
| 상태 | active |

핵심 모듈:
- `src/utils/url.js` — buildResultUrl / buildOgUrl / parseCourseFromParams (URL 단일 소스)
- `src/utils/course.js` — drawCourse / redrawCourse (랜덤 코스 생성)
- `src/utils/random.js` — pickOne / pickOneDifferent (기본 랜덤 유틸)
- `src/data/cards.json` — 카드 데이터 (갈_곳 / 먹을_곳 / 탈_것 / 금액)
- `api/og.js` — Edge Runtime OG 이미지 생성 (@vercel/og + Satori)
- `middleware.js` — /result 라우트 OG 메타 태그 주입

**주요 아키텍처 결정:**
- SPA지만 OG 지원: Edge Middleware가 /result 요청에서 OG 메타 삽입
- Noto Sans KR 폰트: `api/fonts/NotoSansKR-subset.ttf`에 번들 (Satori는 시스템 폰트 없음)
- URL 인코딩: 모든 한글 값은 `URLSearchParams`가 자동 인코딩 (encodeURIComponent)

---

### UGGK

초기 단계 서비스. 디렉토리가 아직 생성되지 않았다. 명시적 구현 요청이 있을 때 생성한다. 그 전까지는 docs/spec-first로 취급한다.

| 항목 | 값 |
|------|-----|
| 경로 | `UGGK/` (미생성) |
| 검증 | 없음 |
| 상태 | spec-first (디렉토리 미생성) |

---

## Common Patterns

### 검증 파이프라인

모든 active 서비스는 동일한 3단계 검증 패턴을 따른다:

```
lint (check-syntax.mjs) → test (node --test) → build
```

`npm run verify`가 이 전체를 실행한다. 커밋 전 반드시 통과해야 한다.

### 배포 모델

모든 서비스는 Vercel에 배포된다.
- 각 서비스 루트에 `vercel.json` 존재
- serverless function은 `api/` 디렉토리에 위치
- 정적 빌드 출력은 서비스별 빌드 스크립트가 생성

### 빌드 스크립트

- Translate-Developer: Vite 사용 (`vite build`)
- IBAD/app, Spending-Personality: 커스텀 빌드 스크립트 (`scripts/build.mjs`)

---

## Orchestration Layer

### Process (Claude Code 네이티브)

이 저장소는 Claude Code 기반 6단계 프로세스 시퀀스로 운영된다.

| 항목 | 값 |
|------|-----|
| 진입점 | [`docs/process/SEQUENCE.md`](docs/process/SEQUENCE.md) |
| 헌장 | [`docs/process/CHARTER.md`](docs/process/CHARTER.md) |
| 입구 | 1줄 아이디어 또는 1쪽 brief (자동 분기, [`INTAKE.md`](docs/process/INTAKE.md)) |
| 단계 | INTAKE → DISCOVERY → PRD DRAFT → PARALLEL REVIEW → DECOMPOSITION → EXECUTION |
| 승인 | 단계마다 Tabber 승인 ([1] INTAKE는 자동 분기 + 신호 충돌 시 1회 확인) |
| 병렬 | [4] PARALLEL REVIEW(3 에이전트), [6] EXECUTION(독립 PR 동시 dispatch + ralph loop) |

상세는 [`docs/process/CHARTER.md`](docs/process/CHARTER.md) Execution Contract를 본다.

### CodeRabbit

PR 자동 리뷰가 `.coderabbit.yaml`로 설정되어 있다. 한국어로 응답하며, `dist/**`는 무시한다.

---

## Data Flow

서비스의 일반적인 데이터 흐름:

```
사용자 브라우저
    ↓ (HTTP)
Vercel Edge / CDN
    ↓
정적 프론트엔드 (Vite/vanilla)
    ↓ (fetch)
Vercel Serverless Function (api/)
    ↓ (HTTP)
외부 AI API (OpenAI 등)
    ↓
응답 → 프론트엔드 렌더링
```

모든 서비스는 stateless다. 서버 측 데이터베이스는 없다. 상태는 클라이언트 측에만 존재한다.

---

## Invariants

이 저장소에서 항상 참이어야 하는 불변 조건:

1. **서비스 독립성**: 서비스 간 import나 코드 공유 없음
2. **검증 필수**: active 서비스 변경 시 `npm run verify` 통과 필수
3. **브랜치 작업**: `main`에 직접 커밋하지 않음
4. **한국어 기본**: PR 제목/본문, 커밋 메시지는 한국어
5. **비밀 금지**: 토큰, API 키, 자격증명을 리포에 저장하지 않음
6. **단일 대상 경로**: 태스크당 하나의 서비스만 수정 (cross-cutting 명시 시 제외)

---

## Cross-References

| 문서 | 보는 이유 |
|------|----------|
| [`AGENTS.md`](AGENTS.md) | 에이전트 진입점, 라우팅, 검증 명령 |
| [`docs/process/CHARTER.md`](docs/process/CHARTER.md) | 책임 경계, 실행 경로, 중단 규칙, Non-Goals |
| [`docs/process/SEQUENCE.md`](docs/process/SEQUENCE.md) | 6단계 시퀀스 본문 |
| [`README.md`](README.md) | 저장소 운영, 서비스 리스트, 프로세스 진입 |

---

## Change Log

| 날짜 | PR | 변경 내용 |
|------|-----|----------|
| 2026-03-31 | PR 0-3 | 초기 아키텍처 문서 작성 |
| 2026-05-03 | M-3 | High-Level Structure 갱신 (docs/harness/→docs/process/, WORKFLOW.md 행 제거, CodeStudy/Seoul-Youth-Rent-Checker 추가). Orchestration Layer를 Symphony에서 Claude Code 네이티브 6단계 시퀀스로 교체. Cross-References docs/process/로 redirect |
