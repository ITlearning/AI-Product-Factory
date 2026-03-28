# Spending-Personality Linear Package

Source PRD: `Spending-Personality/01-spending-personality-summary-prd.md`

## Routing decision

- target service label: `service:new-service`
- target directory: `Spending-Personality`
- package type: `parent issue + child execution issues + optional QA issue`
- execution fan-out readiness: `ready`
- reason:
  - PRD has a clear product goal
  - target directory is implied by the current folder name
  - MVP scope is concrete enough to split into PR-sized tasks
  - technical stack is not fixed yet, so the first child task should lock stack and app shell

## Parent issue

### Recommended title

```text
[New Service] Spending-Personality PRD 실행 계획
```

### Recommended labels

```text
service:new-service
role:planner
orchestrator:plan
autogen:approved
```

### Ready-to-paste body

```md
## What this issue is

기존 PRD를 실행 가능한 Linear child task 세트로 분해하고, Spending-Personality 서비스를 MVP 범위로 착수하기 위한 parent planning issue.

## PRD source

Spending-Personality/01-spending-personality-summary-prd.md

## Product summary

하루 소비 내역을 읽고 `오늘의 소비 캐릭터`를 캐릭터명, 한 줄 요약, 태그, 근거 소비, 내일의 한 수로 보여주는 서비스.

## Target directory

Spending-Personality

## Desired outcome

- MVP 범위로 실행 가능한 child issue 세트가 나온다
- 각 child issue 는 PR 가능한 단위다
- child issue 는 모두 `Todo`에 생성된다
- child issue 는 기본적으로 `autogen:pending-review` 상태다

## Constraints

- 새 top-level 디렉터리는 Spending-Personality 로 고정한다
- 기존 서비스는 기본적으로 건드리지 않는다
- 결과는 숫자 리포트보다 캐릭터 해석 경험을 우선한다
- UX 는 붙여넣기 중심이어야 한다

## Acceptance criteria

- child issue 마다 Target Path 와 Validation 이 있다
- 결과 화면, 생성 로직, 히스토리, QA 가 분리된 task 로 나온다
- 새 서비스 초기 스택 결정 task 가 포함된다

## Validation

- PRD 와 child issue 간 범위 모순이 없어야 한다
- child issue 가 한 PR 단위를 넘지 않아야 한다

## Human Review Triggers

- Target directory 가 바뀐다
- 다른 기존 서비스까지 직접 수정해야 한다
- 기술 스택 결정이 크게 엇갈린다
```

## Child execution issues

### 1. MVP stack 결정 및 서비스 shell scaffold

#### Title

```text
[New Service] Spending-Personality MVP stack 결정 및 서비스 shell scaffold
```

#### Labels

```text
service:new-service
role:developer
orchestrator:task
autogen:pending-review
```

#### Rationale

기술 스택과 기본 앱 shell 을 먼저 고정해야 이후 UI와 생성 로직 작업이 안정적으로 이어진다.

#### Ready-to-paste body

```md
## Why

Spending-Personality 서비스의 MVP를 구현하려면 먼저 기술 스택과 기본 앱 shell 을 고정해야 한다.

## Target Path

Spending-Personality

## Target directory

Spending-Personality

## Scope

- MVP에 맞는 웹 앱 스택 결정
- 새 top-level 서비스 디렉터리 scaffold
- 기본 실행/검증 스크립트 정의
- 첫 화면용 빈 앱 shell 준비

## Non-Goals

- 캐릭터 생성 로직 구현
- 결과 카드 완성
- 히스토리 기능 구현

## Acceptance Criteria

- Spending-Personality 디렉터리가 생성된다
- 기본 실행 경로와 verify 경로가 정리된다
- 첫 화면 shell 이 뜬다
- 이후 feature task 가 그 위에서 진행 가능하다

## Validation

- 서비스 로컬 실행 확인
- 서비스용 verify 명령 또는 동등한 기본 검증 정의

## Dependencies

- parent planning issue

## Human Review Triggers

- 스택 선택이 지나치게 무거워진다
- 다른 서비스와 공유 인프라를 강하게 요구한다
```

### 2. 붙여넣기 중심 입력 화면 구현

#### Title

```text
[New Service] Spending-Personality 붙여넣기 중심 입력 화면 구현
```

#### Labels

```text
service:new-service
role:developer
orchestrator:task
autogen:pending-review
```

#### Rationale

PRD의 핵심 UX는 최소 마찰 입력이므로, 입력 경험을 별도 PR 단위로 고정하는 것이 맞다.

#### Ready-to-paste body

```md
## Why

사용자가 가장 적은 마찰로 소비 내역을 넣을 수 있어야 MVP의 핵심 진입이 성립한다.

## Target Path

Spending-Personality

## Target directory

Spending-Personality

## Scope

- 소비 내역 멀티라인 입력
- 선택 메모 입력
- 예시 포맷 노출
- 생성 버튼 활성/비활성 상태
- 결과 예시 프리뷰 또는 기대감 전달 영역

## Non-Goals

- 실제 캐릭터 결과 로직 완성
- 히스토리 화면 구현

## Acceptance Criteria

- 붙여넣기 중심 UX 로 입력 가능하다
- 입력 형식이 완벽하지 않아도 기본 흐름이 유지된다
- 생성 전 기대감을 주는 프리뷰가 있다

## Validation

- 로컬 UI 확인
- 서비스 verify 명령 통과

## Dependencies

- Spending-Personality MVP stack 결정 및 서비스 shell scaffold

## Human Review Triggers

- 입력 포맷 제약이 너무 엄격해진다
- 요구사항이 금융 연동 쪽으로 확대된다
```

### 3. 소비 해석 계약 및 캐릭터 생성 로직 구현

#### Title

```text
[New Service] Spending-Personality 소비 해석 계약 및 캐릭터 생성 로직 구현
```

#### Labels

```text
service:new-service
role:developer
orchestrator:task
autogen:pending-review
```

#### Rationale

서비스의 핵심 차별점은 캐릭터 해석 엔진이므로 결과 계약과 생성 로직을 별도 task 로 잡아야 한다.

#### Ready-to-paste body

```md
## Why

이 서비스의 핵심 가치는 소비 텍스트를 `오늘의 소비 캐릭터` 결과 구조로 바꾸는 해석 엔진에 있다.

## Target Path

Spending-Personality

## Target directory

Spending-Personality

## Scope

- 입력 소비 텍스트 파싱 전략 정의
- 출력 스키마 정의
- 캐릭터명, 한 줄 요약, 태그 3개, 근거 소비 2~3개, 내일의 한 수 생성
- 추정성 문구 및 안전한 톤 규칙 반영

## Non-Goals

- 공유 카드 UI 완성
- 최근 캐릭터 히스토리 구현

## Acceptance Criteria

- PRD의 결과 구조가 코드 계약으로 고정된다
- 결과가 비꼬지 않는 관찰형 톤을 유지한다
- 파싱 실패/재료 부족 상태를 처리한다

## Validation

- 생성 계약 테스트
- 최소 happy path 와 에러 path 검증

## Dependencies

- Spending-Personality 붙여넣기 중심 입력 화면 구현

## Human Review Triggers

- 해석이 도덕 판단처럼 보인다
- 출력 구조가 PRD와 어긋난다
- 파싱 실패율이 높아 설계 변경이 필요하다
```

### 4. 결과 화면 및 공유 카드 구현

#### Title

```text
[New Service] Spending-Personality 결과 화면 및 공유 카드 구현
```

#### Labels

```text
service:new-service
role:developer
orchestrator:task
autogen:pending-review
```

#### Rationale

사용자가 가장 먼저 체감하는 가치가 결과 화면에 있으므로, 결과 표시 경험은 독립 task 로 분리하는 게 적절하다.

#### Ready-to-paste body

```md
## Why

사용자가 10초 안에 `오늘 나는 어떤 소비 캐릭터였는지` 이해하려면 결과 화면의 정보 우선순위가 정확해야 한다.

## Target Path

Spending-Personality

## Target directory

Spending-Personality

## Scope

- Character Hero
- Tag Chips
- Evidence Card
- Action Hint Block
- 저장/공유 가능한 카드형 결과
- 다시 생성 버튼

## Non-Goals

- 최근 캐릭터 히스토리 저장
- 친구 공유 피드 확장

## Acceptance Criteria

- 첫 화면에서 캐릭터명과 요약이 바로 보인다
- 근거 소비와 내일의 한 수가 짧고 납득 가능하다
- 저장/공유용 카드가 시각적으로 분리된다

## Validation

- 로컬 UI 확인
- 서비스 verify 명령 통과

## Dependencies

- Spending-Personality 소비 해석 계약 및 캐릭터 생성 로직 구현

## Human Review Triggers

- 결과 길이가 과하게 길어진다
- 톤이 모욕적이거나 유아적으로 흐른다
```

### 5. 최근 캐릭터 히스토리 MVP 구현

#### Title

```text
[New Service] Spending-Personality 최근 캐릭터 히스토리 MVP 구현
```

#### Labels

```text
service:new-service
role:developer
orchestrator:task
autogen:pending-review
```

#### Rationale

PRD가 얕은 히스토리 진입을 MVP에 포함하므로, 결과 생성과 분리된 별도 task 로 두는 편이 낫다.

#### Ready-to-paste body

```md
## Why

MVP에서도 `어제 나는 어떤 캐릭터였는지` 다시 볼 수 있는 얕은 히스토리 진입은 필요하다.

## Target Path

Spending-Personality

## Target directory

Spending-Personality

## Scope

- 최근 캐릭터 화면
- 최근 생성 결과 재노출
- 최소 저장 구조 정의

## Non-Goals

- 장기 통계
- 주간/월간 리포트
- 친구 비교 기능

## Acceptance Criteria

- 최근 결과를 다시 볼 수 있다
- 결과 구조가 현재 MVP 계약과 맞는다
- 얕은 히스토리 수준을 넘지 않는다

## Validation

- 로컬 흐름 확인
- 서비스 verify 명령 통과

## Dependencies

- Spending-Personality 결과 화면 및 공유 카드 구현

## Human Review Triggers

- 저장 방식이 인증/백엔드 구조까지 크게 확대된다
```

## Optional QA/review issues

### QA issue

#### Title

```text
[New Service] Spending-Personality MVP QA
```

#### Labels

```text
service:new-service
role:qa
orchestrator:task
autogen:pending-review
```

#### Ready-to-paste body

```md
## Goal

Spending-Personality MVP의 입력, 생성, 결과, 히스토리 흐름을 실제로 검증하고 버그나 톤 문제를 정리한다.

## Target Path

Spending-Personality

## Target directory

Spending-Personality

## Validation Focus

- 붙여넣기 입력
- 생성 중 상태
- 결과 톤과 근거 납득감
- 공유 카드
- 최근 캐릭터 재진입
- 에러/재료 부족 상태

## Human Review Triggers

- 결과 문구가 사용자에게 공격적으로 보인다
- 파싱 실패가 구조적이다
```

## Recommended labels

### Parent planning issue

```text
service:new-service
role:planner
orchestrator:plan
autogen:approved
```

### Child execution issue

```text
service:new-service
role:developer
orchestrator:task
autogen:pending-review
```

### QA issue

```text
service:new-service
role:qa
orchestrator:task
autogen:pending-review
```

## Approval gate and operator notes

- parent issue 는 Symphony가 잡아야 하므로 `autogen:approved`를 붙이는 쪽이 맞다
- child issue 는 처음엔 전부 `autogen:pending-review`로 둔다
- 검토 후 실행시킬 task만 아래처럼 바꾼다:

```text
autogen:pending-review 제거
autogen:approved 추가
```

- 지금 워크플로 기준에서는 새 서비스가 아직 라우팅 테이블에 없으므로, 당장은 `service:new-service`를 쓰는 게 가장 안전하다
- 모든 `service:new-service` 이슈 본문에는 `Target directory: Spending-Personality` 또는 동등한 명시를 넣는 게 좋다

## Special cautions

- 이 PRD는 제품 방향은 충분히 선명하지만 기술 스택이 비어 있다
- 첫 child task를 스택/쉘 고정용으로 둔 이유가 그 때문이다
- 새 서비스이므로 초반에 `README.md`와 `WORKFLOW.md`에 `Spending-Personality` 라우팅을 정식 등록할지 결정해야 한다
- 결과 톤은 `정확해서 웃긴 관찰`이어야 하고, 도덕 판단/비꼼/병리화로 흐르면 안 된다
- 파싱 실패 처리와 재료 부족 상태는 MVP에서 빼면 안 된다
- 히스토리는 얕은 MVP 수준까지만 두고, 주간/월간 리포트는 다음 단계로 미루는 게 맞다
