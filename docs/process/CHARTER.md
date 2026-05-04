# CHARTER.md — Process 헌장

**Status:** active (M-2 신규)
**Last updated:** 2026-05-03
**Owner:** Tabber

이 문서는 `AI-Product-Factory` 저장소의 **프로세스 헌장**이다. 기능을 정의하지 않는다. 책임 경계, 실행 경로, 중단 규칙, 리뷰 게이트만 고정한다.

---

## 1. Purpose

이 헌장은 기획부터 PR 머지까지 6단계 시퀀스가 어떤 책임 분담과 어떤 게이트로 굴러가는지를 한 장으로 못 박는다. 핵심 목표는 **단단한 기획 베이스**를 만드는 것이며, 그 위에서 멀티 에이전트가 분해·구현·검증·PR handoff 한다.

이 문서는 기존 `docs/harness/CHARTER.md`를 변형 흡수하여 신규 작성된 것이다. codex/Symphony 환경 가정과 spec-lock 의식은 제거되었고, gstack 스킬 라우팅과 6단계 시퀀스는 새로 추가되었다. 본 헌장은 기존 `docs/harness/CHARTER.md`를 **대체**한다.

실행 흐름의 본문(각 단계 입력/출력/스킬/게이트)은 [SEQUENCE.md](SEQUENCE.md)가 source of truth이다. 본 문서는 그 흐름을 **누가 소유하고 어떻게 멈추는가**만 다룬다.

---

## 2. Ownership Boundary

### 인간 (Tabber) 소유

| 항목 | 설명 |
|------|------|
| PRD 원문 작성 | 제품 요구사항의 최초 작성은 Tabber가 수행한다. 에이전트는 양식과 질문으로 보조한다 |
| 목표 / 비목표 결정 | 무엇을 만들고 무엇을 만들지 않을지는 Tabber가 결정한다 |
| 성공 기준 확정 | 측정 가능한 완료 조건은 Tabber가 정의한다 |
| 단계마다 승인 | [2]→[3], [3]→[4], [4]→[5], [5]→[6] 모든 전이의 승인 게이트는 Tabber가 통과시킨다 |
| 우선순위·범위 확정 | 작업 순서와 범위 조정은 Tabber 판단 |
| stop 결정 | 어디서 멈출지 Tabber가 선언한다 |
| 최종 머지 결정 | PR 단위 머지 승인은 Tabber가 한다 |

### 에이전트 (Claude Code) 소유

| 항목 | 설명 |
|------|------|
| 시퀀스 실행 | 6단계 흐름의 각 단계를 실제로 굴린다 |
| 분해 | PRD를 Sprint/PR 단위로 분해한다 ([5] DECOMPOSITION) |
| 구현 | 코드, 테스트, 문서, 스크립트를 작성한다 ([6] EXECUTION) |
| 검증 | 자동화된 검증과 evidence 수집을 수행한다 |
| 리뷰 대응 | 리뷰 피드백을 반영하고 재검증한다 |
| PR handoff | 완료된 작업을 PR로 제출하고 Tabber에게 알린다 |

### 경계 규칙

- **PRD 잠금 의식 없음.** Tabber가 PRD를 명시적으로 "잠그지" 않아도 시퀀스는 시작된다. 잠금 대신 **단계마다 승인 게이트**가 통제권을 보장한다.
- 에이전트는 인간 소유 항목을 **대체하지 않는다**. 제안은 OK, 확정은 금지.
- 인간 소유 항목이 부재하거나 모호하면 에이전트는 **진행하지 않고 질문**한다.
- 어떤 단계든 게이트에서 Tabber가 "수정 요청" 또는 "중단"이라 답하면 에이전트는 그 답을 따른다. 우회 금지.

---

## 3. Multi-Agent Execution Principle

**모든 구현 작업은 멀티 에이전트로 수행한다.**

본 원칙은 본 헌장 내 다른 섹션과 모든 하위 실행 문서보다 우선한다. 하위 문서가 본 원칙과 충돌하면, 해당 문서를 즉시 본 원칙에 맞게 동기화한다.

| 규칙 | 설명 |
|------|------|
| 단일 에이전트 직접 구현 금지 | 에이전트가 스스로 코드를 작성하는 단일 루프 실행은 금지한다. 반드시 독립적인 서브에이전트들로 분산한다 |
| 구현 + 리뷰 동시 병렬 실행 | 구현 에이전트와 리뷰 에이전트를 동시에 띄운다. 구현이 끝나면 리뷰 결과가 이미 준비돼 있어야 한다 |
| 독립 서브에이전트 원칙 | 각 서브에이전트는 독립된 컨텍스트를 갖는다. 서브에이전트 간 결과를 공유할 때는 오케스트레이터가 명시적으로 전달한다 |
| 병렬 dispatch는 단일 메시지 | N개 독립 작업이 있으면 한 메시지에 N개 Agent 호출을 동시에 보낸다. 순차 호출 금지 |

병렬이 적용되는 위치는 [4] PARALLEL REVIEW와 [6] EXECUTION 두 곳이다. 자세한 dispatch 패턴은 [EXECUTION.md](EXECUTION.md)에 있다.

---

## 4. Pre-Task Review Condition Protocol

**작업 시작 전, Tabber에게 리뷰 조건을 확인한다.**

### 절차

1. Tabber가 "작업 진행해줘" 또는 구현 요청을 하면, 에이전트는 즉시 구현에 들어가지 않는다.
2. 먼저 다음을 확인한다.
   - 이 작업에 특별히 통과해야 하는 조건이 있는가?
   - 리뷰 기준으로 추가해야 할 항목이 있는가?
3. Tabber가 조건을 제시하면 → 해당 조건을 리뷰 게이트에 추가하고 작업 시작.
4. Tabber가 "없다 / 바로 진행해"라고 하면 → 기본 [QUALITY_SCORE.md](../QUALITY_SCORE.md) 기준으로 진행.

### 조건 미통과 시

- 제시된 조건 중 **하나라도** 통과하지 못하면 해당 작업은 **실패**로 간주한다.
- 에이전트는 실패 원인을 보고하고 작업을 **재시작**한다.
- 재시작 시 이전 실패 원인을 컨텍스트에 포함한다.

### 코드 리뷰 필수

코드 변경이 포함된 모든 작업은 머지 전 코드 리뷰를 **반드시** 수행한다. 리뷰 건너뜀은 금지한다. PR 단위 리뷰는 [6] EXECUTION의 PR handoff 시점에 일어난다.

---

## 5. Execution Contract

### 공식 실행 경로

```
INTAKE → DISCOVERY → PRD DRAFT → PARALLEL REVIEW → DECOMPOSITION → EXECUTION
```

각 단계의 입력/출력/사용 스킬/승인 게이트/산출물 저장 위치는 [SEQUENCE.md](SEQUENCE.md)가 source of truth이다. 본 헌장은 **누가 소유하는가**와 **어떤 스킬을 쓰는가**만 요약한다.

### 단계별 소유자 + 사용 스킬

| 단계 | 단계 소유자 | 사용 스킬 / 도구 |
|------|------------|-----------------|
| [1] INTAKE | 에이전트 (자동 분기), Tabber (분기 신호 상충 시) | (자동 분기 — 별도 스킬 없음) |
| [2] DISCOVERY | 에이전트 + Tabber 1:1 대화 | `/office-hours` |
| [3] PRD DRAFT | 에이전트 + Tabber 1:1 대화 | `/brainstorming` (한 번에 한 질문), `/writing-plans` (필요 시) |
| [4] PARALLEL REVIEW | 3 에이전트 동시 dispatch | `/plan-ceo-review`, `/plan-eng-review`, `/plan-design-review` |
| [5] DECOMPOSITION | 단일 에이전트 (일관된 분해) | `/writing-plans` |
| [6] EXECUTION | 멀티 에이전트 (PR 단위 병렬) | `Agent` (subagent), `ralph-loop:ralph-loop`, `/ship`, `/qa`, `/review` |

### 경로 이탈 금지

- 위 경로를 **건너뛰거나 순서를 바꿀 수 없다**.
- 어떤 단계든 승인 게이트를 통과하지 못하면 다음 단계로 넘어가지 않는다.
- 경로 변경이 필요하면 Tabber에게 변경 사유를 보고하고 승인을 받는다.
- 게이트에서 거부 시 직전 단계로 후퇴는 가능하다 ([4]에서 PRD 수정이 필요하면 [3]으로 되돌림). 그러나 단계 자체를 생략할 수는 없다.

---

## 6. gstack 스킬 라우팅 표

각 단계가 어떤 gstack 스킬과 묶이는지 한눈에 본다.

| 단계 | 사용 스킬 / 도구 |
|------|----------------|
| [1] INTAKE | (자동 분기 — 별도 스킬 없음) |
| [2] DISCOVERY | `/office-hours` |
| [3] PRD DRAFT | `/brainstorming` (한 번에 한 질문), `/writing-plans` (필요 시) |
| [4] PARALLEL REVIEW | `/plan-ceo-review`, `/plan-eng-review`, `/plan-design-review` (3 에이전트 동시 dispatch) |
| [5] DECOMPOSITION | `/writing-plans` |
| [6] EXECUTION | `Agent` (subagent), `ralph-loop:ralph-loop`, `/ship`, `/qa`, `/review` |

### 라우팅 원칙

- 사용자의 요청이 위 표의 단계와 매칭되면 **해당 스킬을 첫 액션으로 호출**한다. 직접 답변하지 않는다.
- 스킬은 단계의 워크플로를 안전하게 굴리는 도구다. 임의의 ad-hoc 답변보다 항상 우선한다.
- 표에 없는 도구를 끼워 넣고 싶으면 Tabber에게 먼저 묻는다.

---

## 7. Stop Rules

에이전트는 다음 상황에서 **즉시 중단**하고 Tabber에게 보고한다.

| 규칙 | 설명 |
|------|------|
| 기획 이탈 감지 | PRD 또는 이전 단계 산출물과 다른 방향으로 진행 중임을 인지한 경우 |
| 모호성 해소 불가 | 요구사항 해석이 2개 이상 가능하고 에이전트 스스로 판단할 근거가 없는 경우 |
| 범위 확대 유혹 | 현재 PR의 허용 수정 범위를 넘는 변경이 필요해 보이는 경우 |
| 외부 의존성 장벽 | 외부 API, 서비스, 라이브러리의 제약으로 진행 불가한 경우 |
| 산출물 부재 | 이전 단계의 산출물 파일이 `docs/plans/` 또는 `docs/reviews/`에 저장되어 있지 않은 채로 다음 단계 진입 시도 시 |
| 추측 진행 | source of truth가 없는 상태에서 구두 합의나 추측에 기반한 진행 시 |
| blocker 은폐 | 발견한 blocker를 보고하지 않고 우회하려는 자기 자신을 인지한 경우 |

### 중단 시 행동

1. 현재 상태를 기록한다 (무엇을 하고 있었고, 어디서 막혔는지).
2. Tabber에게 보고한다 (중단 사유 + 제안 선택지).
3. Tabber의 지시가 올 때까지 해당 작업을 진행하지 않는다.

### 무거운 stop rule을 두지 않는 이유

자동 점수 게이트, 잠금 의식, "통과 못 하면 자동 반려" 같은 무거운 룰은 본 헌장에 두지 않는다. 단계마다 Tabber 승인 게이트가 같은 역할을 더 가볍게 한다.

---

## 8. Review Gates

### 두 종류의 게이트

| 게이트 | 위치 | 통과 기준 |
|-------|------|----------|
| 단계 승인 게이트 | [2]→[3], [3]→[4], [4]→[5], [5]→[6] | Tabber가 "OK / 수정 요청 / 중단" 중 OK라 답함 |
| PR 단위 리뷰 게이트 | [6] EXECUTION의 PR handoff 시점 | PR 코드 리뷰 통과 + Tabber 머지 승인 |

### 병렬 리뷰는 [4]단계에서만

- [4] PARALLEL REVIEW는 3 에이전트(`/plan-ceo-review`, `/plan-eng-review`, `/plan-design-review`)가 단일 메시지에 동시 dispatch 된다.
- 3 보고서가 모두 도착하면 한 화면에서 비교 → 액션 아이템 합의 → PRD 수정 또는 통과.
- 세 리뷰가 상반될 때 자동 우선순위는 없다. **Tabber가 결정**한다.
- 산출물 저장 위치: `docs/reviews/<date>-<topic>/<role>.md` (`<role>` ∈ `ceo`, `eng`, `design`).

### 점수는 참고값

- [QUALITY_SCORE.md](../QUALITY_SCORE.md)의 점수 구조는 **Tabber 판단의 참고값**이다.
- 점수 미달 시 자동 반려는 하지 않는다. 머지 결정은 항상 Tabber.
- 점수가 낮으면 에이전트는 "왜 낮은지"와 "수정 안을 무엇으로 할지"를 보고하고 Tabber 결정을 기다린다.

### PR 단위 리뷰

- [6] EXECUTION에서 각 PR이 생성되면 코드 리뷰 (`/review`)가 머지 전 필수.
- 리뷰 결과를 반영해 수정·재검증한 뒤 Tabber 머지 승인을 요청한다.
- Tabber가 "머지 OK" 답을 주면 그제야 머지한다.

---

## 9. Source of Truth Map

| 문서 | 역할 | 위치 |
|------|------|------|
| CHARTER.md | 프로세스 헌장, 책임 경계, 실행 경로 | [`docs/process/CHARTER.md`](CHARTER.md) |
| SEQUENCE.md | 6단계 흐름 본문 | [`docs/process/SEQUENCE.md`](SEQUENCE.md) |
| INTAKE.md | 1줄/1쪽 입구 자동 분기 | [`docs/process/INTAKE.md`](INTAKE.md) |
| PRD_TEMPLATE.md | PRD 양식 | [`docs/process/PRD_TEMPLATE.md`](PRD_TEMPLATE.md) |
| EXECUTION.md | 병렬 dispatch + ralph loop 패턴 | [`docs/process/EXECUTION.md`](EXECUTION.md) |
| DECOMPOSITION.md | Sprint/PR 분해 수치 룰 | [`docs/process/DECOMPOSITION.md`](DECOMPOSITION.md) |
| EVIDENCE.md | PR 검증 증거 포맷 | [`docs/process/EVIDENCE.md`](EVIDENCE.md) |
| DOC_LINT.md | 문서 변경 검증 룰 | [`docs/process/DOC_LINT.md`](DOC_LINT.md) |
| CLAUDE.md | 저장소 진입점 (Claude Code 자동 로드) | [`CLAUDE.md`](../../CLAUDE.md) |
| AGENTS.md | redirect → CLAUDE.md (외부 호환성용) | [`AGENTS.md`](../../AGENTS.md) |
| ARCHITECTURE.md | 기술 아키텍처 | [`ARCHITECTURE.md`](../../ARCHITECTURE.md) |
| PRODUCT_SENSE.md | 제품 감각 가이드 | [`docs/PRODUCT_SENSE.md`](../PRODUCT_SENSE.md) |
| RELIABILITY.md | 신뢰성 기준 | [`docs/RELIABILITY.md`](../RELIABILITY.md) |
| SECURITY.md | 보안 기준 | [`docs/SECURITY.md`](../SECURITY.md) |
| PLANS.md | 계획 관리 규칙 | [`docs/PLANS.md`](../PLANS.md) |
| QUALITY_SCORE.md | 리뷰 점수 참고값 | [`docs/QUALITY_SCORE.md`](../QUALITY_SCORE.md) |

### 규칙

- 위 맵에 없는 문서는 source of truth가 아니다.
- 두 문서가 충돌하면 본 헌장(CHARTER.md)이 우선한다.
- 실행 흐름의 세부는 SEQUENCE.md가 우선한다 (본 헌장은 흐름의 뼈대만 다룬다).

---

## 10. Glossary

| 용어 | 정의 |
|------|------|
| PRD | Product Requirements Document. Tabber가 작성하는 제품 요구사항 문서 |
| INTAKE | [1] 단계. 1줄 아이디어 vs 1쪽 brief 자동 분기 |
| DISCOVERY | [2] 단계. `/office-hours`로 실수요·문제 정의 후 1쪽 brief 산출 |
| PRD DRAFT | [3] 단계. `/brainstorming`으로 PRD 양식을 채움 |
| PARALLEL REVIEW | [4] 단계. CEO/Eng/Design 3 에이전트 동시 검토 |
| DECOMPOSITION | [5] 단계. PRD를 Sprint/PR 단위로 분해 (DAG 포함) |
| EXECUTION | [6] 단계. PR 단위 병렬 실행 + 머지 |
| ralph loop | PR 안에서 굴리는 자율 반복 루프 (구현 → test → 검증 → 수정 → 재검증). 패턴명 |
| 단계 승인 게이트 | 단계 전이에서 Tabber가 "OK / 수정 / 중단" 중 하나로 답하는 통제 지점 |
| gstack | Claude Code용 스킬 번들. `/office-hours`, `/plan-*-review`, `/brainstorming`, `/writing-plans`, `/ship`, `/qa`, `/review` 등을 포함 |
| source of truth | 특정 주제에 대한 유일한 권위 있는 문서 |

---

## 11. Non-Goals

이 헌장이 **하지 않는 것**.

| 비목표 | 설명 |
|--------|------|
| codex / Symphony / Linear 라우팅 부활 | 이미 dead. 잔재만 제거한 상태이며 복원하지 않는다 |
| 무거운 lock 의식 부활 | PRD를 명시적으로 잠그는 단계는 두지 않는다. 단계 승인 게이트로 충분 |
| 자동 점수 게이트 | 역할별 ≥7 / 평균 ≥8.0 같은 hard threshold로 자동 반려하지 않는다. 점수는 참고값 |
| "입장 허가" 의식 | PRD를 별도 양식에 통과시키는 게이트는 두지 않는다. PRD 그 자체가 산출물 |
| 완전 자동 프로젝트 생성 | "기획서만 던져주면 된다"는 목표가 아니다. 단계마다 Tabber 승인이 필수 |
| AI의 제품 결정 대행 | 에이전트는 제품 판단을 대신하지 않는다 |
| 서비스별 예외 규칙 정의 | 이 문서는 공통 프로세스만 다룬다 |

---

## 12. Cross-References

- [SEQUENCE.md](SEQUENCE.md) — 6단계 흐름 본문 (단계별 입력/출력/스킬/게이트)
- [INTAKE.md](INTAKE.md) — 1줄 아이디어 vs 1쪽 brief 자동 분기 룰
- [PRD_TEMPLATE.md](PRD_TEMPLATE.md) — PRD 양식 + 작성 예시
- [EXECUTION.md](EXECUTION.md) — 병렬 dispatch + ralph loop 패턴
- [DECOMPOSITION.md](DECOMPOSITION.md) — Sprint/PR 분해 수치 룰
- [EVIDENCE.md](EVIDENCE.md) — PR 검증 증거 포맷
- [DOC_LINT.md](DOC_LINT.md) — 문서 변경 검증 룰
- [CLAUDE.md](../../CLAUDE.md) — 저장소 진입점 (Claude Code 자동 로드). AGENTS.md는 redirect로 유지.
- [ARCHITECTURE.md](../../ARCHITECTURE.md) — 기술 아키텍처

---

## 13. Change Log

| 날짜 | PR | 변경 내용 |
|------|-----|----------|
| 2026-05-03 | M-2 PR (TBD) | `docs/harness/CHARTER.md`를 변형 흡수하여 `docs/process/CHARTER.md` 신규 생성. codex/Symphony 가정 제거, gstack 라우팅 추가, Multi-Agent + Pre-Task Review 유지 |
| 2026-05-04 | claude-md-merge | Source of Truth Map의 진입점을 AGENTS.md → CLAUDE.md로 갱신. AGENTS.md는 redirect 행으로 유지. |
