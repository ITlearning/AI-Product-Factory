# AI-Product-Factory — Claude Code 진입점

이 파일은 Claude Code가 세션 시작 시 자동으로 읽는 진입점이다. 저장소의 에이전트 가이드, 운영 규칙, 프로세스 시퀀스를 한 곳에 모았다.

루트 `AGENTS.md`는 다른 에이전트 호환성과 기존 외부 링크 보존을 위해 짧은 redirect 문서로 유지된다 — 진입점 본문은 모두 이 파일에 있다.

---

## Repo Map

| 경로 | 설명 | 상태 |
|------|------|------|
| [`IBAD/app`](IBAD/app) | 한국어 거절 메시지 웹 앱 | active |
| [`Translate-Developer`](Translate-Developer) | 개발자 언어 → 일반 한국어 번역 웹 앱 | active |
| [`Spending-Personality`](Spending-Personality) | 소비 성격 진단 웹 앱 | active |
| [`Date-Soragodong`](Date-Soragodong) | 커플 데이트 코스 뽑기 웹 앱 | active |
| [`CodeStudy/iOS`](CodeStudy/iOS) | 코드 학습 iOS 앱 (CodeStudy) | active (1.2.1 출시) |
| [`Seoul-Youth-Rent-Checker`](Seoul-Youth-Rent-Checker) | 서울 청년월세지원 자격 체커 v0.1 | active |
| `UGGK` | 초기 단계; 디렉토리 미생성, 명시적 구현 요청이 없으면 docs/spec-first | spec-first |
| [`docs`](docs) | 계획, 설계 노트, 프로세스 문서 | active |

---

## Source of Truth

### 실존 문서

| 문서 | 역할 | 위치 |
|------|------|------|
| Process Charter | 책임 경계, 실행 경로, 중단 규칙, 리뷰 게이트 | [`docs/process/CHARTER.md`](docs/process/CHARTER.md) |
| CLAUDE.md | Claude Code 진입점 (이 파일) | [`CLAUDE.md`](CLAUDE.md) |
| ARCHITECTURE.md | 기술 아키텍처 | [`ARCHITECTURE.md`](ARCHITECTURE.md) |
| PLANS.md | 계획 관리 규칙 | [`docs/PLANS.md`](docs/PLANS.md) |
| QUALITY_SCORE.md | 리뷰 점수 계산 구조 | [`docs/QUALITY_SCORE.md`](docs/QUALITY_SCORE.md) |
| PRODUCT_SENSE.md | 제품 감각 가이드 | [`docs/PRODUCT_SENSE.md`](docs/PRODUCT_SENSE.md) |
| RELIABILITY.md | 신뢰성 기준 | [`docs/RELIABILITY.md`](docs/RELIABILITY.md) |
| SECURITY.md | 보안 기준 | [`docs/SECURITY.md`](docs/SECURITY.md) |
| SEQUENCE | 6단계 실행 시퀀스 본문 | [`docs/process/SEQUENCE.md`](docs/process/SEQUENCE.md) |
| INTAKE | 1줄/1쪽 입구 자동 분기 | [`docs/process/INTAKE.md`](docs/process/INTAKE.md) |
| PRD_TEMPLATE | PRD 13필드 양식 (시각화 2필드 포함) | [`docs/process/PRD_TEMPLATE.md`](docs/process/PRD_TEMPLATE.md) |
| EXECUTION | 병렬 dispatch + ralph loop 패턴 | [`docs/process/EXECUTION.md`](docs/process/EXECUTION.md) |
| DECOMPOSITION | Sprint/PR 분해 수치 기준 | [`docs/process/DECOMPOSITION.md`](docs/process/DECOMPOSITION.md) |
| EVIDENCE | 검증 증거 포맷 | [`docs/process/EVIDENCE.md`](docs/process/EVIDENCE.md) |
| DOC_LINT | 문서 전용 변경 검증 규칙 | [`docs/process/DOC_LINT.md`](docs/process/DOC_LINT.md) |
| COMMON | 다른 프로젝트 시드용 범용 프로세스 템플릿 | [`docs/process/COMMON.md`](docs/process/COMMON.md) |

두 문서가 충돌하면 CHARTER.md가 우선한다.

---

## Process Path

```text
[1] INTAKE → [2] DISCOVERY → [3] PRD DRAFT → [4] PARALLEL REVIEW → [5] DECOMPOSITION → [6] EXECUTION
```

단계마다 Tabber 승인 게이트를 거친다 ([1] INTAKE는 자동 분기 + 신호 충돌 시 1회 확인). 경로를 건너뛰거나 순서를 바꿀 수 없다.

각 단계의 소유자, 게이트 조건, 사용 스킬은 [`docs/process/SEQUENCE.md`](docs/process/SEQUENCE.md) 본문과 [`docs/process/CHARTER.md → Execution Contract`](docs/process/CHARTER.md#execution-contract)에서 본다.

---

## Ownership Boundary

- **인간 소유**: PRD, 목표/비목표/성공 기준, 우선순위/범위, stop 조건, 단계마다 승인, 최종 머지 결정
- **에이전트 소유**: 시퀀스 실행, 계획 분해, 구현, 검증, 리뷰 대응, PR handoff

인간 소유 항목이 부재하거나 모호하면 에이전트는 진행하지 않고 질문한다.

전체 경계 표는 [`docs/process/CHARTER.md → Ownership`](docs/process/CHARTER.md#ownership-boundary)을 본다.

---

## Routing

라우팅은 두 층이다. (1) 새 작업의 입구 라우팅, (2) 기존 코드 변경의 서비스 라우팅.

### (1) 입구 라우팅 (새 PRD 시작 시)

새 작업은 [`docs/process/INTAKE.md`](docs/process/INTAKE.md)의 자동 분기 룰을 따른다.

- **1줄 아이디어** → [2] DISCOVERY (`/office-hours`)
- **1쪽 brief** → [3] PRD DRAFT (`/brainstorming`)
- 분기 신호 상충 시 Tabber에게 1회 확인

이후 단계는 [`docs/process/SEQUENCE.md`](docs/process/SEQUENCE.md)를 본다.

### (2) 서비스 라우팅 (기존 코드 변경 시)

태스크당 하나의 primary target path를 기본으로 한다.

- `IBAD/app`
- `Translate-Developer`
- `Spending-Personality`
- `Date-Soragodong`
- `CodeStudy/iOS`
- `Seoul-Youth-Rent-Checker`
- `UGGK`
- `docs`

태스크가 명시적으로 cross-cutting이라고 하지 않는 한 여러 서비스에 걸쳐 범위를 넓히지 않는다. cross-cutting 판정 기준은 [`docs/process/PRD_TEMPLATE.md`](docs/process/PRD_TEMPLATE.md)의 Allowed Touch Surface / Disallowed Areas 필드 + [`ARCHITECTURE.md`](ARCHITECTURE.md) Invariant #6을 본다.

---

## Guardrails

에이전트 행동 제약의 상세는 [`docs/process/CHARTER.md`](docs/process/CHARTER.md)에 있다. 진입점에서는 존재만 안내한다.

- **Stop Rules**: 즉시 중단 조건 → [`CHARTER.md → Stop Rules`](docs/process/CHARTER.md#stop-rules)
- **Non-Goals**: 부활 금지 항목 (codex/Symphony, spec-lock 같은 무거운 lock 의식, 자동 점수 게이트) → [`CHARTER.md → Non-Goals`](docs/process/CHARTER.md#non-goals)
- **Review Gates**: 리뷰 프로세스 및 점수 참고값 기준 → [`CHARTER.md → Review Gates`](docs/process/CHARTER.md#review-gates)

---

## Validation

| 대상 | 명령 |
|------|------|
| [`IBAD/app`](IBAD/app) | `cd IBAD/app && npm run verify` |
| [`Translate-Developer`](Translate-Developer) | `cd Translate-Developer && npm run verify` |
| [`Spending-Personality`](Spending-Personality) | `cd Spending-Personality && npm run verify` |
| [`Date-Soragodong`](Date-Soragodong) | `cd Date-Soragodong && npm run verify` |
| [`CodeStudy/iOS`](CodeStudy/iOS) | Xcode build (서비스 README 참고) |
| [`Seoul-Youth-Rent-Checker`](Seoul-Youth-Rent-Checker) | `cd Seoul-Youth-Rent-Checker && npm run verify` |
| `UGGK` | 표준 검증 명령 없음 (디렉토리 미생성) |
| docs/planning 파일만 변경 | [`docs/process/DOC_LINT.md`](docs/process/DOC_LINT.md) 수동 체크리스트 수행 |

---

## Delivery

- 브랜치에서 작업한다. `main`에 직접 커밋하지 않는다.
- 커밋/푸시 전 검증한다.
- 기본 handoff는 PR이다.
- PR 제목과 본문은 한국어 기본이다.
- 변경 내용, 이유, 사용자 영향, 확인 방법을 평문으로 요약한다.
- 기획/브레인스토밍 작업의 기본 handoff는 상세한 인간 가독 요약이다. "문서 참조"만으로는 부족하다.
- 작업 보고 시 코드 변경은 (경로, 행동 변화, 검증 방법), 비코드 작업은 (권장 사항, 트레이드오프, 다음 결정)을 인라인으로 포함한다.

---

## 에이전트 행동 가이드

### gstack

gstack provides browser automation and QA skills. Install it before using any `/browse` or browser-based skills.

**Install:**
```bash
git clone --single-branch --depth 1 https://github.com/garrytan/gstack.git ~/.claude/skills/gstack && cd ~/.claude/skills/gstack && ./setup
```

**Rules:**
- For ALL web browsing, use the `/browse` skill from gstack — never use `mcp__claude-in-chrome__*` tools
- Never call `mcp__claude-in-chrome__*` tools under any circumstances

**Available gstack skills:**
`/office-hours`, `/plan-ceo-review`, `/plan-eng-review`, `/plan-design-review`, `/design-consultation`, `/design-shotgun`, `/design-html`, `/review`, `/ship`, `/land-and-deploy`, `/canary`, `/benchmark`, `/browse`, `/connect-chrome`, `/qa`, `/qa-only`, `/design-review`, `/setup-browser-cookies`, `/setup-deploy`, `/retro`, `/investigate`, `/document-release`, `/codex`, `/cso`, `/autoplan`, `/careful`, `/freeze`, `/guard`, `/unfreeze`, `/gstack-upgrade`, `/learn`

### 언어 규칙

- 한국어로 대화할 때는 자연스러운 한국어를 사용한다. 영어를 직역하지 않는다.
- AskUserQuestion의 질문, 옵션 레이블, 설명 모두 실제 한국어 화자가 쓰는 표현으로 작성한다.
- 번역 투의 어색한 문장 (예: "데이터가 달라질어요", "앉을 벴들때") 은 금지한다.

### 멀티 에이전트 병렬 실행 원칙

- N개의 독립 작업(탐색, 기획, 검색, 리뷰 등)이 있으면 **무조건 멀티 에이전트 병렬 실행**을 시도한다.
- 단일 에이전트는 이전 결과에 의존하는 순차 작업에만 사용한다.
- 하나의 메시지에 여러 Agent 도구 호출을 포함해서 병렬로 보낸다.

### Skill routing

When the user's request matches an available skill, ALWAYS invoke it using the Skill tool as your FIRST action. Do NOT answer directly, do NOT use other tools first. The skill has specialized workflows that produce better results than ad-hoc answers.

Key routing rules:
- Product ideas, "is this worth building", brainstorming → invoke office-hours
- Bugs, errors, "why is this broken", 500 errors → invoke investigate
- Ship, deploy, push, create PR → invoke ship
- QA, test the site, find bugs → invoke qa
- Code review, check my diff → invoke review
- Update docs after shipping → invoke document-release
- Weekly retro → invoke retro
- Design system, brand → invoke design-consultation
- Visual audit, design polish → invoke design-review
- Architecture review → invoke plan-eng-review
