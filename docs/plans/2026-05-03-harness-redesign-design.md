# Harness 재설계 설계안 (Claude Code 네이티브)

날짜: 2026-05-03
작성: Tabber × Claude Code 공동 설계 (brainstorming 스킬 기반)
상태: design 승인 완료, writing-plans 단계로 전환 예정

## 배경

2026-03-31 Sprint 0(`PR #20`) 머지로 `docs/harness/` 15개 문서 설치 완료. 그러나 33일간 admission instance 0개, spec-lock된 PRD 0개, evidence trail 디렉터리 없음. PR #21~29 (9개) 모두 admission/spec-lock 경로 우회한 직접 구현으로 머지됨.

진단:
- 기존 설계는 codex/Symphony 환경 가정에서 출발했으나 현재 그 환경을 사용하지 않음
- "잘 멈추기" 중심의 게이트(admission/spec-lock)가 무거워 우회 인센티브 발생
- Tabber의 원래 목표는 "잘 멈추기"가 아니라 **gstack 스킬을 활용한 단단한 기획 베이스 + 스프린트 분해 + 병렬 실행 + 세세한 대화 시퀀스**

본 설계는 Tabber × Claude Code 협업으로 codex/Symphony 가정을 도려내고 Claude Code 네이티브한 기획→실행 시퀀스를 새로 짠다.

## 합의된 요구사항

| 항목 | 결정 |
|------|------|
| 핵심 갈증 | 기획 단계가 단단해진다 |
| 산출물 수준 | PRD 1장 + Sprint/PR 분해 리스트 |
| 입구 | 1줄 아이디어 OR 1쪽 brief (자동 라우팅) |
| 흐름 | 단계마다 Tabber 승인 (full 대화) |
| 병렬 위치 | 기획 리뷰도, 실행도 |
| 자산 처리 | Absorb & Restructure (B): 좋은 자산 흡수, dead weight 제거 |

## 1. 자산 인벤토리

### 흡수→변형
| 문서 | 변형 내용 |
|------|----------|
| `docs/harness/CHARTER.md` | Symphony 가정 제거, gstack 라우팅 추가. Multi-Agent Execution Principle + Pre-Task Review Protocol 유지 |
| `docs/harness/admission.md` | 9 필드를 PRD 양식으로. "입장 게이트" 의식 제거 |
| `docs/harness/ralplan-ralph.md` | "ralplan" 부분은 SEQUENCE에 흡수, "ralph" 부분(자율 미니 루프)은 EXECUTION에 흡수. codex 명칭 폐기 |
| `docs/PLANS.md` | locked 단계 제거, 생명주기 가벼이 |
| `docs/QUALITY_SCORE.md` | 3역할 점수 구조 흡수, 운영 부담 완화 |

### 흡수 (변형 거의 없음)
- `docs/harness/decomposition.md` (PR ≤10파일/400줄, Sprint ≤8PR/5일)
- `docs/harness/evidence-trail.md`
- `docs/harness/doc-lint.md`

### 유지
- `ARCHITECTURE.md`, `docs/PRODUCT_SENSE.md`, `docs/RELIABILITY.md`, `docs/SECURITY.md`

### 변형 (메타 문서)
- `AGENTS.md` (Source of Truth 표 갱신, Harness Path → SEQUENCE 링크)

### 삭제
- `WORKFLOW.md` (Symphony + Linear + codex 잔재)
- `docs/harness/spec-lock.md` (lock 의식 제거, "단계마다 승인" 흐름으로 대체)
- `docs/harness/` 폴더 자체 (위 흡수/이동 후 빈 폴더 제거)

## 2. 새 시퀀스 (6단계)

### 폴더
`docs/process/`로 새로 만든다. `docs/harness/`라는 명칭에 묻은 codex/admission 무거움 잔재 차단.

### 흐름

```
[1] INTAKE (자동 분기)
     ├─ 1줄 아이디어 → [2]로
     └─ 1쪽 brief    → [3]으로 직진

[2] DISCOVERY              skill: /office-hours
     실수요·문제 정의             산출: 1쪽 brief
     ↓ 승인 게이트
[3] PRD DRAFT              skill: /brainstorming (한 번에 한 질문)
     9필드 양식                  산출: docs/plans/<date>-<topic>-prd.md
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

### 승인 게이트 동작

- 산출물을 `docs/plans/` 또는 `docs/reviews/`에 저장
- Claude Code가 "이 결과로 [다음 단계] 갈까?" 물음
- Tabber 답: OK / 수정 요청 / 중단

### INTAKE 자동 분기 기준
- 텍스트 길이 (≤200자 → 1줄, 그 이상 → brief 후보)
- Goal/Non-Goals/Success Criteria 같은 키워드 신호 (3개 이상 → brief)
- 두 신호가 상충하면 Tabber에게 확인

## 3. 병렬 모델

### A. 기획 리뷰 병렬 ([4])

PRD draft 1장 완성 시 3 에이전트를 단일 메시지에 동시 dispatch.

| 에이전트 | 역할 | 산출 |
|---------|------|------|
| `/plan-ceo-review` | 스코프·10-star·premise 도전 | scope/cut, 데이트 reality |
| `/plan-eng-review` | 아키·데이터·엣지·테스트 커버리지 | 기술 위험 카드 |
| `/plan-design-review` | UX·일관성·hierarchy·AI slop | UX 위험 카드 |

3 보고서가 모두 도착하면 한 화면 비교 → 액션 아이템 합의 → PRD 수정 또는 통과.

세 리뷰가 상반되면 Tabber가 결정 (자동 우선순위 없음).

### B. 실행 병렬 ([6])

분해된 PR이 N개라면 독립 PR끼리 단일 메시지에 동시 dispatch. 각 PR 내부는 **ralph loop**:

```
PR-N agent loop (자율, 멈추지 않음):
  1. 구현       → 2. lint/test  → 3. 검증
  ↑                                  ↓
  5. 수정       ← 4. 실패 시 분석 ←
  → 통과 시 PR 생성 + Tabber 알림
```

각 PR은 별도 worktree(`Agent` 도구 `isolation: "worktree"`)로 격리.

### 의존성

PR 간 의존성은 [5] DECOMPOSITION에서 DAG로 명시. 같은 레벨 PR은 동시, 의존 PR은 선행 머지 후 시작.

### 병렬 안 하는 곳
- INTAKE / DISCOVERY / PRD DRAFT (Tabber와 1:1 대화)
- DECOMPOSITION (단일 에이전트가 일관된 분해)
- 승인 게이트 (Tabber 1명이 결정자)

## 4. 마이그레이션

4 PR로 분해. 순서 M-1 → M-2 → M-3 → M-4.

### M-1: 골격 + 기존 자산 흡수
**신규 4파일**:
- `docs/process/SEQUENCE.md`
- `docs/process/INTAKE.md`
- `docs/process/PRD_TEMPLATE.md` (admission 9필드 흡수)
- `docs/process/EXECUTION.md` (병렬 + ralph loop)

**이동/흡수 3파일**:
- `decomposition.md` → `docs/process/DECOMPOSITION.md`
- `evidence-trail.md` → `docs/process/EVIDENCE.md`
- `doc-lint.md` → `docs/process/DOC_LINT.md`

규모: 7파일, ~350줄.

### M-2: 메타 문서 갱신
- `docs/process/CHARTER.md` (Symphony 제거, gstack 라우팅 추가, Multi-Agent + Pre-Task Review 유지)
- `AGENTS.md` (Source of Truth 표 + Harness Path → SEQUENCE)
- `docs/PLANS.md` (locked 제거)
- `docs/QUALITY_SCORE.md` (운영 부담 완화)

규모: 4파일, ~250줄.

### M-3: dead weight 제거
**삭제**:
- `WORKFLOW.md`
- `docs/harness/` 전체 (위에서 이동/흡수 끝난 후 폴더 제거)

archive 폴더는 만들지 않음. git history로 충분 (`git show <commit>:docs/harness/<file>`).

규모: 9파일 삭제.

### M-4: README + 링크 정비
- 루트 `README.md`에 새 시퀀스 진입 안내
- `AGENTS.md` Routing 섹션 갱신
- 끊어진 링크 점검 (doc-lint 룰로 검증)

규모: 2파일, ~50줄.

## 5. 마이그레이션 후 dogfooding

다음 PRD 1개를 새 시퀀스로 처음부터 끝까지 실행. 후보:
- CodeStudy의 다음 기능 (track별 추천, 학습 통계)
- Seoul-Youth-Rent-Checker v0.2

dogfooding에서 시퀀스가 무겁거나 막히는 곳이 발견되면 즉시 미세 조정. lighter 재단(C 옵션)이 아니라 운영 학습 기반 패치.

## 비목표 (Non-Goals)

- codex/Symphony 환경 복원 — 이미 dead. 잔재만 제거
- spec-lock 같은 무거운 lock 의식 부활 — "단계마다 승인" 흐름이 그 역할 대체
- AGENTS.md를 백과사전화 — 맵(~100줄) 유지
- 기존 머지된 9개 PR(#21~29)을 새 시퀀스 기준으로 재검토 — 과거는 과거대로

## Open Questions (실행 단계로 넘기기 전 점검)

1. `docs/process/CHARTER.md`에 들어갈 Multi-Agent Execution Principle 본문은 기존 CHARTER 그대로 옮길지 vs 더 짧게 줄일지 — M-2 작업 시 결정
2. INTAKE 자동 분기를 메타 문서로만 둘지 vs 입구 슬래시 커맨드(`/intake`)로 자동화할지 — dogfooding 후 결정
3. 실행 단계의 ralph-loop 스킬과 Agent 도구 isolation worktree를 어떻게 결합할지 — 첫 PR dogfooding 때 검증

## 참조

- 메모리: `project_sprint0_complete.md`, `project_harness_engineering.md`, `project_harness_operation_gap.md`
- 기존 자산: `docs/harness/CHARTER.md`, `docs/harness/admission.md`, `docs/harness/decomposition.md`
- gstack 스킬: `/office-hours`, `/plan-ceo-review`, `/plan-eng-review`, `/plan-design-review`, `/brainstorming`, `/writing-plans`, `ralph-loop:ralph-loop`, `/ship`, `/qa`, `/review`
