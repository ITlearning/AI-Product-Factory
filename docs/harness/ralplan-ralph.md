# ralplan → ralph 공식 경로

이 문서는 spec-lock 이후의 두 핵심 워크플로우(ralplan, ralph)의 공식 실행 경로를 정의한다.
ralplan은 계획 수립, ralph는 반복 실행 루프다.

---

## Purpose

spec-lock된 요구사항을 **계획으로 변환**(ralplan)하고, 계획을 **반복 실행**(ralph)하는 공식 경로를 정의한다.

- ralplan: "무엇을 어떤 순서로 할 것인가"를 결정한다.
- ralph: "결정된 것을 실행하고 검증한다"를 반복한다.

두 워크플로우는 순차적이며, ralplan 완료 없이 ralph를 시작할 수 없다.

---

## Execution Path 상의 위치

```
PRD → admission → spec-lock → [ralplan] → sprint/PR 분해 → [ralph 실행] → 리뷰 점수 게이트
```

ralplan과 ralph는 실행 경로의 후반부를 담당한다. spec-lock 이전 단계는 이 문서의 범위 밖이다.

---

## ralplan (계획 수립)

### 정의

ralplan은 모호한 실행 요청을 계획 단계로 우회시키는 워크플로우다 (CHARTER.md Glossary). 이 과정에서 구조화된 계획이 산출된다.

### 전제 조건

| 조건 | 설명 |
|------|------|
| spec-lock 완료 | 인간이 spec-lock을 승인한 상태여야 한다 |
| admission output 존재 | 정리된 실행 계약이 존재해야 한다 |
| `[모호]`/`[미정]` 해소 | 모든 미결 항목이 spec-lock 시점에 처리된 상태여야 한다 |

전제 조건이 하나라도 미충족이면 ralplan을 시작하지 않는다 (fail-closed).

### 입력

spec-lock된 PRD에서 다음을 받는다 (PLANS.md ralplan 입출력 참조):

- 잠긴 목표
- 잠긴 비목표
- 잠긴 성공 기준
- 잠긴 대상 경로
- 허용/금지 수정 범위
- 제약/불변조건
- 검증 증거 요구사항

### 출력

ralplan은 다음을 생성한다:

- sprint 분해 (번호, 목표, 범위)
- sprint 내 PR 분해 (번호, 제목, 변경 대상, 검증 방법)
- PR 간 의존성/순서
- 예상 위험과 완화 방안
- 오픈 질문 (실행 전 해소 필요)

### 출력 유효성 검증

ralplan 출력은 다음을 충족해야 한다 (PLANS.md 상태 전환 규칙):

- sprint 1개 이상 존재
- 각 sprint에 PR 1개 이상 존재
- 각 PR에 검증 방법이 명시됨
- spec-lock된 모든 성공 기준이 최소 1개 PR에 매핑됨

유효성 미충족 시 계획을 수정한다. 수정 불가 시 인간에게 보고한다.

### ralplan이 하지 않는 것

- PRD의 목표/비목표를 변경하지 않는다.
- spec-lock된 항목을 재해석하지 않는다.
- 인간 승인 없이 범위를 확대하지 않는다.

### 오픈 질문 처리

ralplan 출력에 오픈 질문이 있으면:

1. 오픈 질문을 인간에게 보고한다.
2. 인간이 답변할 때까지 해당 질문에 의존하는 PR의 ralph 실행을 시작하지 않는다.
3. 답변이 spec-lock된 항목에 영향을 주면 spec-lock 해제 절차를 따른다 (spec-lock.md 참조).

---

## ralplan → ralph 전환

### 전환 조건

ralplan에서 ralph로 전환하려면 다음이 모두 충족되어야 한다:

| 조건 | 설명 |
|------|------|
| ralplan 출력 유효 | 출력 유효성 검증 통과 |
| 계획 상태 locked | 인간이 계획을 승인하여 locked 상태 (PLANS.md 상태 전환) |
| 오픈 질문 해소 | 실행 대상 PR에 영향을 주는 오픈 질문이 모두 해소됨 |

### 전환 불가 시

전환 조건 미충족 시:
- ralplan 출력 무효 → 계획 수정 후 재검증
- 계획 미승인 → 인간에게 승인 요청
- 오픈 질문 미해소 → 인간에게 보고 후 대기

---

## ralph (반복 실행 루프)

### 정의

ralph는 spec-lock 이후의 반복 실행 루프다 (CHARTER.md Glossary):

```
구현 → 검증 → 리뷰 → 수정 → 재검증
```

이 루프는 PR 단위로 실행된다. 각 PR이 리뷰 게이트를 통과할 때까지 반복한다.

### PR 단위 실행 사이클

하나의 PR에 대한 ralph 사이클:

```
1. 구현 ─→ 2. 검증 ─→ 3. 리뷰 ─→ 판정
                                    │
                          ┌─────────┼─────────┐
                          ▼         ▼         ▼
                        PASS     REVISE    REJECT
                          │         │         │
                          ▼         ▼         ▼
                     PR 완료    4. 수정    4. 수정
                                    │         │
                                    ▼         ▼
                              5. 재검증  5. 재검증
                                    │         │
                                    └────→ 3. 리뷰로 복귀
```

### 각 단계 상세

#### 1. 구현

- 분해된 PR 계획에 따라 코드/문서를 작성한다.
- spec-lock된 허용 수정 범위 내에서만 작업한다.
- 구현 중 제품 결정이 필요한 분기를 발견하면 PRODUCT_SENSE.md 규칙에 따라 인간에게 위임한다.
- 하나의 PR은 하나의 논리적 변경만 포함한다 (decomposition.md 참조).

#### 2. 검증

- `npm run verify` 또는 해당 서비스의 검증 명령을 실행한다 (RELIABILITY.md 검증 파이프라인).
- 검증 실패 시 수정한다. 수정 불가 시 인간에게 보고한다.
- 문서 전용 변경은 링크 유효성과 문서 간 정합성을 수동 확인한다.

#### 3. 리뷰

- 3개 역할(critic, architect, analyst)의 에이전트 리뷰를 수행한다 (QUALITY_SCORE.md).
- 각 역할이 10점 만점으로 채점한다.
- 판정 기준: `(모든 역할 ≥ 7) AND (평균 ≥ 8.0)` → PASS.

#### 4. 수정 (REVISE/REJECT 시)

- REJECT 시 7점 미만 역할, REVISE 시 가장 낮은 점수 역할부터 우선 대응한다 (QUALITY_SCORE.md 참조).
- 피드백 반영 후 변경된 부분을 재검증한다.
- REJECT/REVISE 합산 3회 연속 비통과 시 자동 에스컬레이션 (QUALITY_SCORE.md).

#### 5. 재검증

- 수정된 코드/문서에 대해 검증을 다시 실행한다.
- 검증 통과 후 리뷰(3단계)로 복귀한다.

### PR 완료 조건

하나의 PR이 완료되려면:

- 리뷰 게이트 PASS (QUALITY_SCORE.md 기준)
- 인간이 최종 병합 승인 (CHARTER.md Review Gates 임시 조항)
- 병합 후 다음 PR로 진행

### 실행 중 계획 변경

ralph 실행 중 계획 변경이 필요한 경우 PLANS.md 계획 변경 절차를 따른다:

- **경미한 변경** (spec-lock 영향 없음 + 단일 PR 내 + 의존성 변경 없음): 에이전트 자율 처리 + 인간에게 사후 보고.
- **중대한 변경** (위 3조건 중 하나라도 미충족): 즉시 중단 + 인간 보고 + spec-lock 해제 절차 (spec-lock.md 참조).

### Sprint 완료 조건

하나의 sprint가 완료되려면:

- sprint 내 모든 PR이 완료됨
- sprint 목표의 측정 가능한 완료 조건이 충족됨 (decomposition.md)

### 전체 계획 완료 조건

- 모든 sprint가 완료됨
- spec-lock된 모든 성공 기준이 충족됨
- 계획 상태를 `completed`로 전환 (PLANS.md 상태 전환)

---

## Stop Rules 연동

ralph 실행 중 CHARTER.md Stop Rules가 트리거되면:

1. 현재 PR 작업을 즉시 중단한다.
2. CHARTER.md 중단 시 행동(상태 기록, 보고, 대기)을 따른다.
3. 인간의 지시에 따라 재개, 계획 수정, 또는 spec-lock 해제를 진행한다.

### ralph 중단 사유

| 사유 | 대응 |
|------|------|
| 기획 이탈 감지 | 즉시 중단 + 인간 보고 |
| 모호성 해소 불가 | 즉시 중단 + 인간 질문 |
| 범위 확대 유혹 | 즉시 중단 + 인간 보고 |
| 외부 의존성 장벽 | 즉시 중단 + 인간 보고 |
| 리뷰 점수 미달 (3회 연속) | 자동 에스컬레이션 |
| blocker 발견 | 즉시 중단 + 인간 보고 |

---

## Fail-Closed 기본값

- spec-lock이 없으면 ralplan을 시작하지 않는다.
- ralplan 출력이 유효하지 않으면 ralph를 시작하지 않는다.
- 계획이 locked 상태가 아니면 ralph를 시작하지 않는다.
- 검증 실행 불가 시 PR을 커밋하지 않는다.
- 리뷰 판정이 모호하면 REVISE로 취급한다.
- 선행 PR 미완료 시 후행 PR을 시작하지 않는다.

---

## Cross-References

| 문서 | 관계 |
|------|------|
| [`docs/harness/CHARTER.md`](CHARTER.md) | Execution Contract, Stop Rules, Review Gates, Glossary (ralplan/ralph 정의) |
| [`docs/PLANS.md`](../PLANS.md) | ralplan 입출력, 계획 상태 전환, 계획 변경 절차 |
| [`docs/harness/spec-lock.md`](spec-lock.md) | ralplan 전제 조건 (spec-lock 완료), 해제 절차 |
| [`docs/harness/decomposition.md`](decomposition.md) | PR 크기 기준, Sprint 기준, 의존성 규칙 |
| [`docs/QUALITY_SCORE.md`](../QUALITY_SCORE.md) | 리뷰 점수 기준, PASS/REVISE/REJECT 판정, 에스컬레이션 |
| [`docs/RELIABILITY.md`](../RELIABILITY.md) | 검증 파이프라인, 롤백 기준 |
| [`AGENTS.md`](../../AGENTS.md) | Validation 테이블 (서비스별 검증 명령) |
| [`docs/PRODUCT_SENSE.md`](../PRODUCT_SENSE.md) | 구현 중 제품 결정 위임 규칙 |
| [`docs/harness/evidence-trail.md`](evidence-trail.md) | 검증 증거 포맷 (PR 0-13) |

---

## Change Log

| 날짜 | PR | 변경 내용 |
|------|-----|----------|
| 2026-03-31 | PR 0-12 | 초기 ralplan→ralph 공식 경로 작성 |
