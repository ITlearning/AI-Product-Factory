# Plans

이 문서는 `AI-Product-Factory` 저장소에서 계획(plan)을 다루는 규칙을 정의한다.
계획은 일급 아티팩트다. 코드와 동일한 수준의 리뷰와 관리를 받는다.

---

## 계획의 위치

하네스 공식 경로에서 계획은 `spec-lock` 이후, `ralph 실행` 이전에 위치한다.

```
PRD → admission → spec-lock → [ralplan → sprint/PR 분해] → ralph 실행 → 리뷰 점수 게이트
                                ^^^^^^^^^^^^^^^^^^^^^^^^
                                이 문서가 다루는 범위
```

---

## 계획의 생명주기

```
draft → review → locked → executing → completed
                    ↓
                 revision (인간 승인 필요)
```

| 상태 | 설명 | 전환 조건 |
|------|------|----------|
| draft | ralplan이 생성한 초기 계획 | spec-lock 통과 후 자동 진입 |
| review | 에이전트 리뷰 + 인간 검토 중 | draft 완료 시 |
| locked | 인간이 승인하여 잠긴 계획 | 인간 승인 |
| executing | ralph가 sprint/PR 단위로 실행 중 | locked 상태에서 실행 시작 |
| completed | 모든 PR이 리뷰 게이트를 통과 | 전체 sprint 완료 |
| revision | 실행 중 계획 변경이 필요한 상태 | 인간 승인 후 진입 |

### 상태 전환 규칙

- `draft → review`: ralplan 출력이 다음 최소 유효성 기준을 모두 충족해야 진입한다.
  - sprint 1개 이상 존재
  - 각 sprint에 PR 1개 이상 존재
  - 각 PR에 검증 방법이 명시됨
  - 위 기준 미충족 시 review 진입 불가 (fail-closed)
- `review → locked`: 인간 승인 필수. 에이전트는 잠글 수 없다.
- `locked → executing`: 자동. locked 상태에서 ralph 실행 시작.
- `executing → revision`: 에이전트가 변경 필요성을 보고하고 인간이 승인하면 진입.
- `revision → review`: 수정된 계획이 다시 리뷰를 거친다.
- `executing → completed`: 모든 PR이 리뷰 게이트를 통과하면 완료.

---

## ralplan 입출력

### 입력 (spec-lock된 PRD에서 받는 것)

- 잠긴 목표
- 잠긴 비목표
- 잠긴 성공 기준
- 잠긴 대상 경로
- 허용/금지 수정 범위
- 제약/불변조건
- 검증 증거 요구사항

### 출력 (ralplan이 생성하는 것)

- sprint 분해 (번호, 목표, 범위)
- sprint 내 PR 분해 (번호, 제목, 변경 대상, 검증 방법)
- PR 간 의존성/순서
- 예상 위험과 완화 방안
- 오픈 질문 (실행 전 해소 필요)

### ralplan이 하지 않는 것

- PRD의 목표/비목표를 변경하지 않는다
- spec-lock된 항목을 재해석하지 않는다
- 인간 승인 없이 범위를 확대하지 않는다

---

## Sprint/PR 분해 원칙

> 이 섹션은 원칙만 다룬다. 수치 기준과 세부 규칙은 [`decomposition.md`](harness/decomposition.md)에서 정의한다.

### Sprint 분해

- 하나의 sprint는 하나의 명확한 목표를 가진다.
- sprint 간 의존성을 최소화한다.
- 각 sprint의 완료 조건이 측정 가능해야 한다.

### PR 분해

- 하나의 PR은 하나의 논리적 변경만 포함한다.
- PR은 독립적으로 리뷰 가능해야 한다.
- PR은 독립적으로 롤백 가능해야 한다.
- 각 PR에 검증 방법이 명시되어야 한다.

### PR 분해 시 금지 사항

- 여러 서비스를 하나의 PR에 묶지 않는다 (cross-cutting 명시 시 제외).
- 리팩토링과 기능 추가를 하나의 PR에 묶지 않는다.
- 검증 방법이 없는 PR을 만들지 않는다.

---

## 계획 변경 절차

실행 중 계획 변경이 필요한 경우, 먼저 경미/중대를 판정한다.

### 경미/중대 판정 기준

다음 3개 조건을 **모두** 충족하면 경미한 변경이다. 하나라도 미충족이면 중대한 변경으로 격상한다.

| 조건 | 경미 | 중대 |
|------|------|------|
| spec-lock된 항목에 영향 없음 | O | X |
| 단일 PR 범위 내 변경 | O | X |
| PR 간 의존성/순서 변경 없음 | O | X |

### 경미한 변경

1. 에이전트가 변경 사유를 기록한다.
2. 위 3개 조건 모두 충족을 확인한다.
3. 에이전트가 자율적으로 계획을 갱신한다.
4. 인간에게 변경 diff를 사후 보고한다.

인간의 사전 승인은 불필요하다. 단, spec-lock 영향 없음 확인은 사전 필수이며, 모호하면 중대한 변경으로 취급한다.

### 중대한 변경

1. 에이전트가 ralph 실행을 즉시 중단한다.
2. 진행 중인 PR은 중단하고 보류한다. 이미 리뷰 게이트를 통과한 PR은 유지한다.
3. 변경 사유와 영향 범위를 상세히 보고한다.
4. 계획 상태를 `revision`으로 전환한다.
5. 인간이 변경을 승인하거나 기각한다.
6. 승인 시 계획이 `review`로 돌아가 재검토를 거친다.
7. 기각 시 기존 계획대로 계속 실행하고, 보류한 PR을 재개한다.

### 변경 불가 항목

다음은 계획 변경으로 처리할 수 없고, spec-lock 해제 → 재admission이 필요하다:

- 잠긴 목표 변경
- 잠긴 비목표 변경
- 잠긴 성공 기준 변경
- 금지 영역 해제

---

## 계획 문서 저장 위치

| 유형 | 위치 |
|------|------|
| 설계/계획 문서 | `docs/plans/YYYY-MM-DD-{slug}.md` |
| 실행 중 계획 상태 | ralplan/ralph 세션 내 관리 |
| 완료된 계획 기록 | 해당 PR/커밋 히스토리 |

---

## Fail-Closed 기본값

- ralplan 출력이 없으면 sprint/PR 분해를 시작하지 않는다.
- 계획이 locked 상태가 아니면 ralph를 실행하지 않는다.
- 오픈 질문이 남아 있으면 해당 PR을 시작하지 않는다.
- 모호한 경우 계획을 확대 해석하지 않고 인간에게 질문한다.

---

## Cross-References

| 문서 | 관계 |
|------|------|
| [`docs/harness/CHARTER.md`](harness/CHARTER.md) | 실행 경로, 중단 규칙, 금지 조항 |
| [`AGENTS.md`](../AGENTS.md) | 하네스 경로 맵, 라우팅 |
| [`docs/harness/spec-lock.md`](harness/spec-lock.md) | spec-lock 해제/재잠금 절차 |
| [`docs/harness/admission.md`](harness/admission.md) | admission 통과 조건 |

---

## Change Log

| 날짜 | PR | 변경 내용 |
|------|-----|----------|
| 2026-03-31 | PR 0-4 | 초기 계획 관리 규칙 작성 |
