# INTAKE

> 6단계 시퀀스의 [1] 단계. 진입점 자동 분기.

## Purpose

INTAKE는 Tabber의 입력 형태를 보고 다음 단계를 자동으로 정한다. 1줄짜리 아이디어 파편이 들어오면 실수요·문제 정의가 빠져 있으니 [2] DISCOVERY로 보내고, 1쪽짜리 brief가 들어오면 PRD를 바로 채울 수 있는 재료가 갖춰져 있으니 [3] PRD DRAFT로 직진시킨다. INTAKE 자체는 판단 한 번과 저장 한 번이 전부다.

## 입구 두 갈래

| 입력 형태 | 다음 단계 | 사용 스킬 |
|----------|----------|-----------|
| **1줄 아이디어** (한 문단 이내, 문제·해결 모호) | [2] DISCOVERY | `/office-hours` |
| **1쪽 brief** (PRD 양식 키워드 다수, 구조화) | [3] PRD DRAFT 직진 | `/brainstorming` |

DISCOVERY는 실수요·문제 정의를 거쳐 1쪽 brief를 산출하므로, 1줄 입력은 결과적으로 [2] → [3] 경로를 밟는다. 이미 brief 수준으로 정리된 입력은 [2]를 건너뛴다.

## 자동 분기 룰

신호 두 가지를 본다. 둘 다 같은 방향이면 그쪽으로 보낸다. 상충하면 Tabber에게 한 번 묻는다.

### 신호 1: 텍스트 길이

- **≤ 200자**: 1줄 아이디어 후보 → DISCOVERY
- **> 200자**: brief 후보 → PRD DRAFT 후보

200자는 한국어 기준 한 문단 정도. 길이만으로는 단정하지 않고 신호 2와 함께 본다.

### 신호 2: PRD 양식 키워드

다음 키워드(또는 한국어 등가어)가 **3개 이상** 등장하면 brief 후보:

- `Goal` / 목표
- `Non-Goals` / 비목표
- `Success Criteria` / 성공 기준
- `Target Path` / 대상 경로
- `Constraints` / 제약
- `Dependencies` / 의존
- `Open Questions` / 미해결 질문
- `Owner` / 책임자

키워드가 보인다는 건 입력자가 이미 PRD 양식을 의식하고 썼다는 뜻이다. DISCOVERY로 다시 돌릴 필요 없이 [3]에서 양식만 채우면 된다.

### 신호 충돌 시

- 길이 ≤200자인데 키워드 ≥3개 → 짧지만 압축된 brief일 수 있음
- 길이 >200자인데 키워드 0~2개 → 길지만 구조화 안 된 아이디어 메모일 수 있음

이 두 경우 Tabber에게 **딱 한 번** 확인한다:

> "이 입력을 1줄 아이디어로 볼까요(=DISCOVERY로), 1쪽 brief로 볼까요(=PRD DRAFT 직진)?"

자동 추측 금지. INTAKE는 50/50 모호함을 강제로 결단하지 않는다.

### 판정 예시

| 입력 샘플 | 길이 | 키워드 | 판정 |
|----------|------|--------|------|
| "CodeStudy에 트랙별 추천 알고리즘 붙이고 싶음" | 30자 | 0개 | 1줄 → DISCOVERY |
| "Goal: 트랙별 추천. Non-Goals: 추천 모델 자체 학습. Success: D1 retention +5pp. Constraints: zero deps." | 90자 | 4개 | 충돌 → Tabber 확인 |
| "서울 청년월세지원 자격 체커 v0.2. 작년 v0.1에서 자격 판정 정확도 78%였는데 정책 개정 반영 누락됨. 5월 공고 release 일정에 맞춰..." (계속) | 600자 | 1개 | 충돌 → Tabber 확인 |
| 11필드 채워진 1쪽 brief (Goal, Non-Goals, Success Criteria, Target Path, Allowed Touch Surface, Disallowed Areas, Constraints, Dependencies, Acceptance Evidence, Open Questions, Owner 모두 포함) | 800자 | 11개 | brief → PRD DRAFT |

## 분기 후 행동

1. **다음 단계 명시**: "[2] DISCOVERY로 갑니다. 스킬 `/office-hours` 호출 예정." 또는 "[3] PRD DRAFT로 직진합니다. 스킬 `/brainstorming` 호출 예정."
2. **입력 원문 저장**: `docs/plans/<date>-<topic>-intake.md`에 1회 저장. `<date>`는 `YYYY-MM-DD`, `<topic>`은 입력에서 추출한 짧은 식별자(kebab-case).
3. **이력 보존**: 저장된 intake 파일은 Tabber가 나중에 검토 가능. 이후 단계 산출물(`-prd.md`, `-design.md`, `-plan.md`)은 같은 `<date>-<topic>` 접두를 공유한다.

저장 후 즉시 다음 단계로 넘어간다. INTAKE 단계는 별도 승인 게이트가 없다 (입력 원문을 그대로 보존하므로 되돌릴 게 없음). 첫 승인 게이트는 [2] DISCOVERY 또는 [3] PRD DRAFT의 산출물 시점.

## 비목표 (Non-Goals)

- **PRD를 작성하지 않는다.** PRD 작성은 [3] PRD DRAFT 단계의 일이다. INTAKE는 라우팅만 한다.
- **실수요를 검증하지 않는다.** 실수요·문제 정의는 [2] DISCOVERY 단계의 일이다. INTAKE는 입력의 형태만 보고 어디로 보낼지 정한다.
- **자동 분류를 끝까지 밀어붙이지 않는다.** 신호가 50/50으로 모호하면 Tabber에게 묻는다. 잘못된 라우팅으로 한 단계를 통째로 헛돌리는 비용이 한 번 묻는 비용보다 훨씬 크다.
- **새 라우팅 티어를 만들지 않는다.** 입구는 1줄/1쪽 두 갈래뿐. "0.5쪽" 같은 중간 티어는 도입하지 않는다 — 모호하면 그냥 묻는다.

## 관련 문서

- [SEQUENCE.md](SEQUENCE.md) — 6단계 흐름 본문 (INTAKE 다음 단계 [2]~[6] 참고)
- [PRD_TEMPLATE.md](PRD_TEMPLATE.md) — [3] 단계에서 채우는 PRD 11필드 양식 (자동 분기 키워드 신호의 출처)
