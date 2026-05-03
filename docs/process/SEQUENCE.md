# SEQUENCE.md — 기획→실행 6단계 시퀀스

**Status:** active (M-1 신규)
**Last updated:** 2026-05-03
**Owner:** Tabber

## 1. Purpose

이 문서는 AI-Product-Factory에서 아이디어를 PR 머지까지 끌고 가는 **6단계 시퀀스**를 정의한다. 핵심 원리는 세 가지: **단단한 기획 베이스**(즉흥 구현 금지), **단계마다 Tabber 승인**(자동 진행 금지), **멀티에이전트 병렬**(독립 작업은 동시 dispatch). codex/Symphony 가정에 묶여 있던 기존 `docs/harness/` 구조를 Claude Code 네이티브 흐름으로 재구성한 결과물이며, 입구는 1줄 아이디어 또는 1쪽 brief 두 가지를 모두 받는다.

## 2. Execution Path

```
[1] INTAKE (자동 분기)
     ├─ 1줄 아이디어 → [2]로
     └─ 1쪽 brief    → [3]으로 직진

[2] DISCOVERY              skill: /office-hours
     실수요·문제 정의             산출: 1쪽 brief
     ↓ 승인 게이트
[3] PRD DRAFT              skill: /brainstorming (한 번에 한 질문)
     11필드 양식                 산출: docs/plans/<date>-<topic>-prd.md
     ↓ 승인 게이트
[4] PARALLEL REVIEW        3 에이전트 동시:
     기획 검토                   /plan-ceo-review (스코프·10-star)
                               /plan-eng-review (아키·엣지)
                               /plan-design-review (UX·일관성)
     ↓ 승인 게이트             산출: docs/reviews/<date>-<topic>/<role>.md
[5] DECOMPOSITION          skill: /writing-plans
     PR ≤10파일/400줄           산출: Sprint 표 + PR 표 (의존성 DAG)
     Sprint ≤8PR/5일
     ↓ 승인 게이트
[6] EXECUTION              멀티 에이전트 병렬 + 각 PR 안 ralph loop
     PR 단위 자율 실행           skills: ralph-loop, /ship, /qa, /review
                               승인 게이트: PR 단위 (Tabber는 결과 PR 확인)
```

## 3. 단계별 스펙

### [1] INTAKE — 자동 분기

| 항목 | 내용 |
|------|------|
| 입력 | 1줄 아이디어 OR 1쪽 brief (텍스트 형태) |
| 출력 | 분기 결정: → [2] DISCOVERY 또는 → [3] PRD DRAFT |
| 사용 스킬 | (없음 — 메타 룰. 자동 분기 기준은 [INTAKE.md](INTAKE.md) 참고) |
| 승인 게이트 | 분기 신호가 상충할 때만 Tabber에게 1회 확인 |
| 산출물 저장 위치 | (저장 없음 — 다음 단계 입력으로 직접 전달) |

### [2] DISCOVERY — 실수요·문제 정의

| 항목 | 내용 |
|------|------|
| 입력 | 1줄 아이디어 |
| 출력 | 1쪽 brief (Goal, Non-Goals, Success Criteria 후보 포함) |
| 사용 스킬 | `/office-hours` |
| 승인 게이트 | "이 brief로 [3] PRD DRAFT 갈까?" → OK / 수정 / 중단 |
| 산출물 저장 위치 | `docs/plans/<date>-<topic>-brief.md` |

### [3] PRD DRAFT — 11필드 양식 작성

| 항목 | 내용 |
|------|------|
| 입력 | 1쪽 brief (DISCOVERY 통과분 또는 INTAKE 직진분) |
| 출력 | 11필드 PRD 1장 (Goal / Non-Goals / Success Criteria / Target Path / Allowed Touch Surface / Disallowed Areas / Constraints / Dependencies / Acceptance Evidence / Open Questions / Owner) |
| 사용 스킬 | `/brainstorming` (한 번에 한 질문 룰) |
| 승인 게이트 | "이 PRD로 [4] PARALLEL REVIEW 갈까?" → OK / 수정 / 중단 |
| 산출물 저장 위치 | `docs/plans/<date>-<topic>-prd.md` |

PRD 양식 본문은 [PRD_TEMPLATE.md](PRD_TEMPLATE.md) 참고.

### [4] PARALLEL REVIEW — 3 에이전트 동시 검토

| 항목 | 내용 |
|------|------|
| 입력 | PRD draft 1장 |
| 출력 | 3개 리뷰 보고서 (CEO / Eng / Design) + 합의 액션 아이템 |
| 사용 스킬 | `/plan-ceo-review`, `/plan-eng-review`, `/plan-design-review` (단일 메시지에 동시 dispatch) |
| 승인 게이트 | "이 리뷰 결과 반영해서 [5] DECOMPOSITION 갈까?" → OK / PRD 수정 후 재리뷰 / 중단. 세 리뷰가 상반될 때 자동 우선순위는 없으며 Tabber가 결정 |
| 산출물 저장 위치 | `docs/reviews/<date>-<topic>/<role>.md` (`<role>` ∈ `ceo`, `eng`, `design`) |

### [5] DECOMPOSITION — Sprint/PR 분해

| 항목 | 내용 |
|------|------|
| 입력 | PARALLEL REVIEW 통과한 PRD |
| 출력 | Sprint 표 + PR 표 (의존성 DAG 포함) |
| 사용 스킬 | `/writing-plans` |
| 승인 게이트 | "이 분해로 [6] EXECUTION 갈까?" → OK / 수정 / 중단 |
| 산출물 저장 위치 | `docs/plans/<date>-<topic>-plan.md` |

분해 수치 룰(PR ≤10파일/400줄, Sprint ≤8PR/5일)은 [DECOMPOSITION.md](DECOMPOSITION.md) 참고.

### [6] EXECUTION — PR 단위 병렬 + ralph loop

| 항목 | 내용 |
|------|------|
| 입력 | Sprint/PR 분해 표 (DAG) |
| 출력 | 머지된 PR 묶음 + 각 PR의 evidence trail |
| 사용 스킬 | `ralph-loop:ralph-loop` (PR 안 자율 루프), `/ship`, `/qa`, `/review` |
| 승인 게이트 | PR 단위. 각 PR이 생성되면 Tabber가 결과 확인 후 머지 결정. PR 단위로 OK / 재작업 요청 / 중단 |
| 산출물 저장 위치 | git PR + `docs/evidence/<pr-number>/` |

병렬 dispatch 패턴 + ralph loop 구조는 [EXECUTION.md](EXECUTION.md) 참고.

## 4. 단계 사이 흐름 규칙

- **단계마다 Tabber 승인 필수.** [2]→[3], [3]→[4], [4]→[5], [5]→[6] 모든 전이에서 승인 게이트 통과해야 다음 단계 진입.
- **예외 — [1] INTAKE:** [1]은 자동 분기를 기본으로 한다. 분기 신호가 명확하면 [1]→[2]로 자동 진행하며, 분기 신호가 상충할 때만 Tabber에게 1회 확인한다 ([INTAKE.md](INTAKE.md) 참고). 즉 INTAKE는 "확인 게이트"이지 "승인 게이트"가 아니다.
- **자동 진행 안 함.** 이전 단계 산출물이 완성되어도 Claude Code는 다음 단계로 자동 점프하지 않는다. 반드시 Tabber에게 확인 질문을 던지고 답을 받는다.
- **승인 게이트 패턴.** 표준 질문 형태: "이 결과로 [다음 단계 이름] 갈까?" Tabber 답은 셋 중 하나.
  - **OK** → 다음 단계 시작
  - **수정 요청** → 현재 단계 재작업 (산출물 갱신 후 다시 게이트로)
  - **중단** → 시퀀스 종료, 사유를 산출물 파일에 메모로 남김
- **산출물 저장이 게이트 통과의 전제.** 게이트 질문 던지기 전에 산출물 파일을 `docs/plans/` 또는 `docs/reviews/`에 먼저 쓴다. 답이 OK가 아닐 수 있으므로, 저장된 결과물이 다음 게이트의 기준이 된다.
- **이전 단계로 되돌리기.** [4]에서 PRD 수정이 필요하면 [3]으로 되돌려 PRD 갱신 후 다시 [4]로 진입. 시퀀스는 한 방향이지만 게이트에서 거부 시 직전 단계로 후퇴 가능.

## 5. 병렬 안 하는 곳

병렬은 **[4] PARALLEL REVIEW**와 **[6] EXECUTION** 두 곳에서만 한다. 나머지는 1:1 흐름.

| 단계 | 병렬 여부 | 이유 |
|------|----------|------|
| [1] INTAKE | 1:1 | Tabber와 자동 분기, 단일 결정 |
| [2] DISCOVERY | 1:1 | `/office-hours` 한 에이전트와 Tabber 대화 |
| [3] PRD DRAFT | 1:1 | `/brainstorming` 한 번에 한 질문 룰 |
| [4] PARALLEL REVIEW | **3 에이전트 병렬** | CEO/Eng/Design 각도 동시 검토 |
| [5] DECOMPOSITION | 1:1 | 단일 에이전트가 일관된 분해 수행 |
| [6] EXECUTION | **N PR 병렬** | DAG 같은 레벨 PR 동시, 의존 PR은 선행 머지 후 |
| 승인 게이트 | 1:1 | Tabber 1명이 결정자 |

## 6. 관련 문서

- [INTAKE.md](INTAKE.md) — 1줄 아이디어 vs 1쪽 brief 자동 분기 룰
- [PRD_TEMPLATE.md](PRD_TEMPLATE.md) — PRD 11필드 양식 + 작성 예시
- [DECOMPOSITION.md](DECOMPOSITION.md) — Sprint/PR 분해 수치 룰 (PR ≤10파일/400줄, Sprint ≤8PR/5일)
- [EXECUTION.md](EXECUTION.md) — 병렬 dispatch + ralph loop 구조
- [CHARTER.md](CHARTER.md) — 책임 경계, 멀티에이전트 원칙, gstack 스킬 라우팅 (M-2에서 추가될 예정)
