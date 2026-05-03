# AI-Product-Factory Agent Guide

이 파일은 저장소의 에이전트 진입점 맵이다. 백과사전이 아니라 맵이다.
실제 규칙과 계약은 각 문서에 있고, 이 파일은 어디를 봐야 하는지만 알려준다.

---

## Repo Map

| 경로 | 설명 | 상태 |
|------|------|------|
| [`IBAD/app`](IBAD/app) | 한국어 거절 메시지 웹 앱 | active |
| [`Translate-Developer`](Translate-Developer) | 개발자 언어 → 일반 한국어 번역 웹 앱 | active |
| [`Spending-Personality`](Spending-Personality) | 소비 성격 진단 웹 앱 | active |
| [`Date-Soragodong`](Date-Soragodong) | 커플 데이트 코스 뽑기 웹 앱 | active |
| `UGGK` | 초기 단계; 디렉토리 미생성, 명시적 구현 요청이 없으면 docs/spec-first | spec-first |
| [`docs`](docs) | 계획, 설계 노트, 프로세스 문서 | active |

---

## Source of Truth

### 실존 문서

| 문서 | 역할 | 위치 |
|------|------|------|
| Process Charter | 책임 경계, 실행 경로, 중단 규칙, 리뷰 게이트 | [`docs/process/CHARTER.md`](docs/process/CHARTER.md) |
| AGENTS.md | 저장소 진입점 맵 (이 파일) | [`AGENTS.md`](AGENTS.md) |
| ARCHITECTURE.md | 기술 아키텍처 | [`ARCHITECTURE.md`](ARCHITECTURE.md) |
| PLANS.md | 계획 관리 규칙 | [`docs/PLANS.md`](docs/PLANS.md) |
| QUALITY_SCORE.md | 리뷰 점수 계산 구조 | [`docs/QUALITY_SCORE.md`](docs/QUALITY_SCORE.md) |
| PRODUCT_SENSE.md | 제품 감각 가이드 | [`docs/PRODUCT_SENSE.md`](docs/PRODUCT_SENSE.md) |
| RELIABILITY.md | 신뢰성 기준 | [`docs/RELIABILITY.md`](docs/RELIABILITY.md) |
| SECURITY.md | 보안 기준 | [`docs/SECURITY.md`](docs/SECURITY.md) |
| SEQUENCE | 6단계 실행 시퀀스 본문 | [`docs/process/SEQUENCE.md`](docs/process/SEQUENCE.md) |
| INTAKE | 1줄/1쪽 입구 자동 분기 | [`docs/process/INTAKE.md`](docs/process/INTAKE.md) |
| PRD_TEMPLATE | PRD 11필드 양식 | [`docs/process/PRD_TEMPLATE.md`](docs/process/PRD_TEMPLATE.md) |
| EXECUTION | 병렬 dispatch + ralph loop 패턴 | [`docs/process/EXECUTION.md`](docs/process/EXECUTION.md) |
| DECOMPOSITION | Sprint/PR 분해 수치 기준 | [`docs/process/DECOMPOSITION.md`](docs/process/DECOMPOSITION.md) |
| EVIDENCE | 검증 증거 포맷 | [`docs/process/EVIDENCE.md`](docs/process/EVIDENCE.md) |
| DOC_LINT | 문서 전용 변경 검증 규칙 | [`docs/process/DOC_LINT.md`](docs/process/DOC_LINT.md) |
| COMMON | 다른 프로젝트 시드용 범용 프로세스 템플릿 | [`docs/process/COMMON.md`](docs/process/COMMON.md) |

두 문서가 충돌하면 CHARTER.md가 우선한다.

---

## Process Path

```
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

## Guardrails

에이전트 행동 제약의 상세는 [`docs/process/CHARTER.md`](docs/process/CHARTER.md)에 있다. 맵에서는 존재만 안내한다.

- **Stop Rules**: 즉시 중단 조건 → [`CHARTER.md → Stop Rules`](docs/process/CHARTER.md#stop-rules)
- **Non-Goals**: 부활 금지 항목 (codex/Symphony, spec-lock 같은 무거운 lock 의식, 자동 점수 게이트) → [`CHARTER.md → Non-Goals`](docs/process/CHARTER.md#non-goals)
- **Review Gates**: 리뷰 프로세스 및 점수 참고값 기준 → [`CHARTER.md → Review Gates`](docs/process/CHARTER.md#review-gates)

---

## Routing

태스크당 하나의 primary target path를 기본으로 한다.

- `IBAD/app`
- `Translate-Developer`
- `Spending-Personality`
- `Date-Soragodong`
- `UGGK`
- `docs`

태스크가 명시적으로 cross-cutting이라고 하지 않는 한 여러 서비스에 걸쳐 범위를 넓히지 않는다.

---

## Validation

| 대상 | 명령 |
|------|------|
| [`IBAD/app`](IBAD/app) | `cd IBAD/app && npm run verify` |
| [`Translate-Developer`](Translate-Developer) | `cd Translate-Developer && npm run verify` |
| [`Spending-Personality`](Spending-Personality) | `cd Spending-Personality && npm run verify` |
| [`Date-Soragodong`](Date-Soragodong) | `cd Date-Soragodong && npm run verify` |
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
