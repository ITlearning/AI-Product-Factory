# Harness 재설계 Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** codex/Symphony 가정에 묶인 `docs/harness/` 시스템을 Claude Code 네이티브 6단계 시퀀스(`docs/process/`)로 재구성한다.

**Architecture:** Absorb & Restructure. 좋은 자산(admission 9필드, decomposition 수치, evidence trail 포맷, ralph loop 패턴)은 흡수하면서 명칭/구조 갱신. dead weight(spec-lock, WORKFLOW.md, ralplan-ralph 명칭)는 제거. 4 PR로 의존성 순서대로 진행.

**Tech Stack:** Markdown 문서 + git. 각 PR은 별도 브랜치에서 작업 후 main으로 PR.

**Reference:** [docs/plans/2026-05-03-harness-redesign-design.md](2026-05-03-harness-redesign-design.md)

**Branch convention:** `chore/harness-redesign-m{1,2,3,4}-<topic>`

**Verification approach:** 코드 TDD가 아닌 문서 마이그레이션이므로 검증은 (1) 끊어진 링크 검사 (`grep -r "(\./docs/harness" .` 등), (2) `doc-lint.md` 9항목 체크리스트, (3) 시각적 인스펙션. 각 PR 끝에서 검증한다.

---

## Chunk 1: M-1 — `docs/process/` 골격 + 기존 자산 흡수

**Branch:** `chore/harness-redesign-m1-process-foundation`

**Files:**
- Create: `docs/process/SEQUENCE.md`
- Create: `docs/process/INTAKE.md`
- Create: `docs/process/PRD_TEMPLATE.md`
- Create: `docs/process/EXECUTION.md`
- Move: `docs/harness/decomposition.md` → `docs/process/DECOMPOSITION.md`
- Move: `docs/harness/evidence-trail.md` → `docs/process/EVIDENCE.md`
- Move: `docs/harness/doc-lint.md` → `docs/process/DOC_LINT.md`

### Task 1.1: 브랜치 생성 + `docs/process/` 폴더 골격

- [ ] **Step 1: main 최신화 + 브랜치 생성**

```bash
git checkout main && git pull
git checkout -b chore/harness-redesign-m1-process-foundation
mkdir -p docs/process
```

- [ ] **Step 2: README placeholder로 폴더 생성 표시 (한 번만)**

`docs/process/README.md` 내용:

```markdown
# docs/process/

기획→실행 시퀀스 문서. 진입점은 [SEQUENCE.md](SEQUENCE.md).

| 문서 | 역할 |
|------|------|
| [SEQUENCE.md](SEQUENCE.md) | 6단계 흐름 본문 |
| [INTAKE.md](INTAKE.md) | 1줄/1쪽 입구 자동 분기 |
| [PRD_TEMPLATE.md](PRD_TEMPLATE.md) | PRD 9필드 양식 |
| [EXECUTION.md](EXECUTION.md) | 병렬 + ralph loop 패턴 |
| [DECOMPOSITION.md](DECOMPOSITION.md) | Sprint/PR 분해 수치 |
| [EVIDENCE.md](EVIDENCE.md) | PR 검증 증거 포맷 |
| [DOC_LINT.md](DOC_LINT.md) | 문서 변경 검증 룰 |
| [CHARTER.md](CHARTER.md) | 책임 경계, 멀티에이전트 원칙 (M-2에서 추가) |
```

### Task 1.2: `docs/process/SEQUENCE.md` 작성

- [ ] **Step 1: 6단계 흐름 본문 작성**

설계 문서 §2를 옮기되 단독으로 읽힐 수 있게 보강. 핵심 섹션:
- Purpose
- Execution Path (6단계 다이어그램)
- 각 단계별: 입력 / 출력 / 사용 스킬 / 승인 게이트 / 산출물 저장 위치
- 단계 사이 흐름 규칙 (단계마다 Tabber 승인, 자동 진행 안 함)

- [ ] **Step 2: 끊어진 링크가 없는지 grep으로 확인**

```bash
grep -E '\]\([^)]+\)' docs/process/SEQUENCE.md
```

각 링크 대상이 실제 존재하는지 또는 같은 PR에서 만들 파일인지 확인.

### Task 1.3: `docs/process/INTAKE.md` 작성

- [ ] **Step 1: 자동 분기 룰 본문 작성**

내용 골자:
- 1줄 아이디어 vs 1쪽 brief 분기 신호 (텍스트 길이 ≤200자, Goal/Non-Goals/Success Criteria 키워드 ≥3)
- 두 신호 상충 시 Tabber 확인
- 분기 후 다음 단계 (DISCOVERY 또는 PRD DRAFT 직진)

### Task 1.4: `docs/process/PRD_TEMPLATE.md` 작성

- [ ] **Step 1: 기존 admission.md 9필드를 PRD 양식으로 변환**

`docs/harness/admission.md`에서 9 필드 구조를 가져오되 "입장 게이트" 의식 표현은 제거:
- Goal
- Non-Goals
- Success Criteria
- Target Path
- Allowed Touch Surface
- Disallowed Areas
- Constraints
- Dependencies
- Acceptance Evidence
- Open Questions
- Owner

각 필드 옆에 "왜 채우는가" 한 줄과 예시 한 줄.

- [ ] **Step 2: 빈 양식 + 채워진 예시 한 묶음 첨부**

빈 양식 + 짧은 예시(예: "CodeStudy 트랙별 추천 알고리즘 v0.1") 첨부.

### Task 1.5: `docs/process/EXECUTION.md` 작성

- [ ] **Step 1: 병렬 + ralph loop 본문**

내용 골자:
- 병렬 위치 두 곳 (기획 리뷰 / PR 단위 실행)
- 기획 리뷰 3에이전트 dispatch 패턴 (단일 메시지 동시)
- PR 단위 ralph loop 구조 (구현→test→검증→수정→재검증)
- worktree 격리 (`Agent isolation: "worktree"`)
- 의존성 처리 (DAG, 같은 레벨 동시, 의존 PR은 선행 머지 후)

- [ ] **Step 2: ralph-loop 스킬과의 매핑 표 첨부**

표: PR 단위 작업 → `ralph-loop:ralph-loop` 스킬 호출 패턴

### Task 1.6: 기존 3파일 이동

- [ ] **Step 1: git mv로 이동 (history 보존)**

```bash
git mv docs/harness/decomposition.md docs/process/DECOMPOSITION.md
git mv docs/harness/evidence-trail.md docs/process/EVIDENCE.md
git mv docs/harness/doc-lint.md docs/process/DOC_LINT.md
```

- [ ] **Step 2: 옮긴 3파일 안의 내부 링크 갱신**

```bash
grep -E '\]\([^)]*harness[^)]*\)' docs/process/*.md
```

링크가 `docs/harness/`를 가리키면 해당 파일이 M-2/M-3에서 어떻게 처리되는지 확인 후 갱신:
- `docs/process/`로 이미 이동한 파일 → 새 경로
- 곧 삭제될 파일 → 임시 주석 (M-3에서 정리)

### Task 1.7: 검증 + 커밋 + PR

- [ ] **Step 1: 끊어진 링크 검증**

```bash
grep -rE '\]\((\./)?docs/(harness|process)/' docs/process/ AGENTS.md
```

`docs/harness/` 가리키는 링크가 있어도 OK (M-2/M-3에서 정리). `docs/process/` 가리키는 링크는 모두 실제 파일 존재해야 함.

- [ ] **Step 2: doc-lint.md 9항목 자체 체크 (DOC_LINT.md 본문 따라)**

새 7파일에 대해 메타 정보(제목/목적/마지막 갱신 일자) 일관성 확인.

- [ ] **Step 3: 커밋**

```bash
git add docs/process/
git commit -m "$(cat <<'EOF'
docs(process): M-1 docs/process/ 골격 + 기존 자산 흡수

신규 4파일 (SEQUENCE/INTAKE/PRD_TEMPLATE/EXECUTION) + 이동 3파일
(decomposition→DECOMPOSITION, evidence-trail→EVIDENCE, doc-lint→DOC_LINT).
admission.md 9필드는 PRD_TEMPLATE.md로 흡수, ralph loop는 EXECUTION.md로
재배치. docs/harness/ 폴더 자체와 메타 문서(CHARTER/AGENTS) 갱신은
M-2/M-3에서 처리.

Refs: docs/plans/2026-05-03-harness-redesign-design.md §4 M-1
EOF
)"
```

- [ ] **Step 4: 푸시 + PR 생성**

```bash
git push -u origin chore/harness-redesign-m1-process-foundation
gh pr create --title "docs(process): M-1 docs/process/ 골격 + 기존 자산 흡수" --body "..."
```

PR body에 design doc 링크 + 다음 PR(M-2) 예정 명시.

- [ ] **Step 5: 머지 후 main 동기화**

PR 머지 후:
```bash
git checkout main && git pull
```

---

## Chunk 2: M-2 — CHARTER 변형 + 메타 문서 갱신

**Branch:** `chore/harness-redesign-m2-charter-meta`

**Files:**
- Create: `docs/process/CHARTER.md` (기존 `docs/harness/CHARTER.md`에서 변형)
- Modify: `AGENTS.md` (Source of Truth 표 + Harness Path 섹션)
- Modify: `docs/PLANS.md` (locked 단계 제거)
- Modify: `docs/QUALITY_SCORE.md` (점수 운영 부담 완화)

### Task 2.1: 브랜치 생성

- [ ] **Step 1: M-1 머지 확인 + 새 브랜치**

```bash
git checkout main && git pull
git log --oneline -5  # M-1 머지 커밋 확인
git checkout -b chore/harness-redesign-m2-charter-meta
```

### Task 2.2: `docs/process/CHARTER.md` 변형 작성

- [ ] **Step 1: 기존 docs/harness/CHARTER.md 읽기**

기존 본문에서 흡수할 부분 식별:
- 유지: Multi-Agent Execution Principle, Pre-Task Review Condition Protocol, Ownership Boundary, Stop Rules, Review Gates 골격
- 변형: Execution Contract (codex 가정 제거, 새 6단계 시퀀스로 갱신)
- 추가: gstack 스킬 라우팅 표

- [ ] **Step 2: docs/process/CHARTER.md 작성**

핵심 섹션:
1. Purpose (책임 경계, "잘 멈추기"가 아닌 "단단한 기획")
2. Ownership (인간 = PRD/승인, 에이전트 = 시퀀스 실행)
3. Multi-Agent Execution Principle (기존 본문 거의 유지)
4. Pre-Task Review Condition Protocol (기존 본문 거의 유지)
5. Execution Contract (새 6단계 시퀀스 표, [SEQUENCE.md](SEQUENCE.md) 본문 링크)
6. gstack 스킬 라우팅 표 (각 단계 → 스킬 매핑)
7. Stop Rules (단계마다 승인 흐름과 정합)
8. Review Gates (병렬 리뷰 [4]단계 기준)

- [ ] **Step 3: 변형 결과를 design doc과 대조**

design doc §1 흡수 변형 표의 CHARTER.md 항목 4가지 변형 모두 반영됐는지 체크.

### Task 2.3: `AGENTS.md` 갱신

- [ ] **Step 1: Source of Truth 표 갱신**

기존 표에서:
- 삭제 행: `WORKFLOW.md` (M-3 삭제 예정), `admission`/`spec-lock`/`ralplan-ralph` (모두 흡수/삭제됨)
- 변경 행: `CHARTER` 위치를 `docs/process/CHARTER.md`로
- 추가 행: `SEQUENCE`, `INTAKE`, `PRD_TEMPLATE`, `EXECUTION`
- 유지: `ARCHITECTURE`, `PLANS`, `QUALITY_SCORE`, `PRODUCT_SENSE`, `RELIABILITY`, `SECURITY`, `DECOMPOSITION`, `EVIDENCE`, `DOC_LINT`

- [ ] **Step 2: Harness Path 섹션을 SEQUENCE 링크로 대체**

기존 본문:
```
PRD → admission → spec-lock → ralplan → sprint/PR 분해 → ralph 실행 → 리뷰 점수 게이트
```

새 본문:
```
INTAKE → DISCOVERY → PRD DRAFT → PARALLEL REVIEW → DECOMPOSITION → EXECUTION
```
+ "단계마다 Tabber 승인" 한 줄 + `docs/process/SEQUENCE.md` 링크.

- [ ] **Step 3: Routing 섹션 갱신은 M-4에서 처리한다고 표시**

(임시 TODO 주석 또는 PR body에 명시)

### Task 2.4: `docs/PLANS.md` 변형

- [ ] **Step 1: locked 단계 제거**

생명주기 4단계(draft→locked→executing→completed) → 3단계(draft→executing→completed)로. "단계마다 승인" 흐름이 lock의 역할 대체한다는 한 줄 추가.

- [ ] **Step 2: ralplan 입출력 섹션 갱신**

"spec-lock된 PRD에서 받는다" → "PARALLEL REVIEW 통과한 PRD에서 받는다"로.

### Task 2.5: `docs/QUALITY_SCORE.md` 변형

- [ ] **Step 1: 운영 부담 완화**

기존 "역할별 ≥7 + 평균 ≥8.0" 같은 hard 게이트 → "Tabber 판단 기준의 참고 점수"로 톤 다운. 점수 미달 시 자동 반려가 아니라 Tabber 결정.

- [ ] **Step 2: 3역할(critic/architect/analyst) 구조는 유지**

기획 리뷰 단계 [4]에서 plan-ceo-review/plan-eng-review/plan-design-review 3 에이전트와 매핑. 둘은 호환됨을 명시.

### Task 2.6: 검증 + 커밋 + PR

- [ ] **Step 1: 끊어진 링크 검증**

```bash
grep -rE '\]\([^)]*\.md\)' AGENTS.md docs/process/CHARTER.md docs/PLANS.md docs/QUALITY_SCORE.md
```

각 링크 대상 존재 확인. `docs/harness/`로 가는 링크가 남아 있으면 안 됨 (M-3에서 삭제 예정이므로).

- [ ] **Step 2: 자체 일관성 검증**

`docs/process/CHARTER.md`의 6단계가 `docs/process/SEQUENCE.md`와 일치하는지 확인.

- [ ] **Step 3: 커밋 + PR**

```bash
git add docs/process/CHARTER.md AGENTS.md docs/PLANS.md docs/QUALITY_SCORE.md
git commit -m "docs(process): M-2 CHARTER 변형 + 메타 문서 갱신"
git push -u origin chore/harness-redesign-m2-charter-meta
gh pr create --title "..." --body "..."
```

- [ ] **Step 4: 머지 후 동기화**

---

## Chunk 3: M-3 — Dead weight 제거

**Branch:** `chore/harness-redesign-m3-dead-weight-removal`

**Files:**
- Delete: `WORKFLOW.md`
- Delete: `docs/harness/CHARTER.md`
- Delete: `docs/harness/admission.md`
- Delete: `docs/harness/spec-lock.md`
- Delete: `docs/harness/ralplan-ralph.md`
- Delete: `docs/harness/` 폴더 자체

### Task 3.1: 브랜치 생성 + 삭제 전 안전 점검

- [ ] **Step 1: M-2 머지 확인 + 브랜치**

```bash
git checkout main && git pull
git checkout -b chore/harness-redesign-m3-dead-weight-removal
```

- [ ] **Step 2: 삭제 대상이 어디서 참조되는지 전수 검사**

```bash
grep -rE '(WORKFLOW\.md|docs/harness/(CHARTER|admission|spec-lock|ralplan-ralph)\.md)' \
  --include='*.md' --include='*.json' --include='*.yaml' --include='*.yml' \
  . 2>/dev/null
```

남은 참조가 있으면 이 PR에서 함께 정리(주석/링크 제거). 없으면 다음 단계.

- [ ] **Step 3: docs/harness/ 폴더 잔존 파일 확인**

```bash
ls docs/harness/
```

M-1에서 3파일 이동, 그러면 남는 건 CHARTER/admission/spec-lock/ralplan-ralph 4파일이어야 함. 다른 게 남아 있으면 design doc과 대조.

### Task 3.2: 파일 삭제

- [ ] **Step 1: 4파일 + WORKFLOW.md 삭제**

```bash
git rm WORKFLOW.md
git rm docs/harness/CHARTER.md
git rm docs/harness/admission.md
git rm docs/harness/spec-lock.md
git rm docs/harness/ralplan-ralph.md
```

- [ ] **Step 2: docs/harness/ 빈 폴더 제거**

```bash
rmdir docs/harness/
```

(`git rm`로 모든 파일이 삭제되면 폴더는 자동으로 사라지지만 명시적으로 확인.)

### Task 3.3: 검증 + 커밋 + PR

- [ ] **Step 1: 끊어진 링크 재검증**

```bash
grep -rE '(WORKFLOW\.md|docs/harness/)' . --include='*.md' 2>/dev/null
```

결과 0줄이어야 함. 0줄이 아니면 남은 참조를 같이 갱신/제거.

- [ ] **Step 2: 검증 완료 확인**

```bash
ls docs/ docs/process/  # docs/harness/ 없음, docs/process/ 8파일
```

- [ ] **Step 3: 커밋 + PR**

```bash
git add -A
git commit -m "$(cat <<'EOF'
docs(process): M-3 dead weight 제거 (WORKFLOW + docs/harness/)

WORKFLOW.md (Symphony+Linear+codex 잔재) + docs/harness/ 폴더 통째로 제거.
admission/spec-lock/ralplan-ralph는 M-1, M-2에서 흡수/변형 완료. archive
폴더는 만들지 않음 — git history로 충분 (git show <commit>:<path>).

Refs: docs/plans/2026-05-03-harness-redesign-design.md §4 M-3
EOF
)"
git push -u origin chore/harness-redesign-m3-dead-weight-removal
gh pr create
```

- [ ] **Step 4: 머지 후 동기화**

---

## Chunk 4: M-4 — README + 링크 정비

**Branch:** `chore/harness-redesign-m4-readme-routing`

**Files:**
- Modify: `README.md` (루트)
- Modify: `AGENTS.md` (Routing 섹션)

### Task 4.1: 브랜치 생성

- [ ] **Step 1**

```bash
git checkout main && git pull
git checkout -b chore/harness-redesign-m4-readme-routing
```

### Task 4.2: 루트 `README.md` 갱신

- [ ] **Step 1: 새 시퀀스 진입 안내 1단락 추가**

기존 README.md에 "기획→실행 시퀀스" 섹션 (1단락) 추가:
- 입구: 1줄 아이디어 또는 1쪽 brief
- 본문: `docs/process/SEQUENCE.md` 6단계
- gstack 스킬 라우팅: `docs/process/CHARTER.md` 참고

- [ ] **Step 2: 기존 README의 codex/Symphony 언급 정리**

```bash
grep -nE '(symphony|codex|Symphony)' README.md
```

남은 잔재 한국어/영어 모두 검사 후 정리.

### Task 4.3: `AGENTS.md` Routing 섹션 갱신

- [ ] **Step 1: Routing 섹션 본문 갱신**

기존 routing이 Linear 라벨 기반이었다면 (WORKFLOW.md 시절 잔재) 새 시퀀스 기반으로:
- 새 PRD → INTAKE 시작
- 기존 머지된 코드 수정 → 단계 [3] 또는 [5]로 직진
- 단순 docs 수정 → DOC_LINT.md 따라

### Task 4.4: 끊어진 링크 전체 점검

- [ ] **Step 1: 전체 markdown 링크 검사**

```bash
find . -name '*.md' -not -path './node_modules/*' -not -path './.git/*' -not -path './.claude/*' \
  -exec grep -lE '\]\([^)]+\.md\)' {} \;
```

각 파일에서 `]\(`로 시작하는 링크 추출 후 대상 파일 존재 확인.

```bash
# 보조 도구 (선택)
# markdown-link-check 가 설치되어 있으면 활용
```

- [ ] **Step 2: 끊어진 링크 0건 확인**

남은 끊어진 링크는 이 PR에서 같이 수정.

### Task 4.5: 검증 + 커밋 + PR

- [ ] **Step 1: doc-lint 9항목 체크리스트 실행**

`docs/process/DOC_LINT.md` 본문 따라 갱신된 README/AGENTS 검증.

- [ ] **Step 2: 커밋 + PR**

```bash
git add README.md AGENTS.md
git commit -m "$(cat <<'EOF'
docs(process): M-4 README + AGENTS Routing 정비 — 새 시퀀스 진입 안내

루트 README.md에 docs/process/SEQUENCE.md 진입 안내 추가, AGENTS.md
Routing 섹션을 새 6단계 시퀀스 기준으로 갱신. codex/Symphony 잔재
문구 정리. 끊어진 링크 0건 확인.

Refs: docs/plans/2026-05-03-harness-redesign-design.md §4 M-4
EOF
)"
git push -u origin chore/harness-redesign-m4-readme-routing
gh pr create
```

- [ ] **Step 3: 머지 후 동기화**

---

## 마이그레이션 후 단계 (별도 작업, 이 plan 범위 밖)

### Dogfooding (플랜 본문이 아니라 후속 PRD)

다음 PRD 1개를 새 시퀀스로 처음부터 끝까지 굴려본다. 후보:
- CodeStudy의 다음 기능 (track별 추천 알고리즘 또는 학습 통계)
- Seoul-Youth-Rent-Checker v0.2

dogfooding에서 발견된 무거움/막힘은 즉시 미세 조정. 이 plan과 별개로 처리.

### 메모리 갱신

마이그레이션 4 PR 머지 완료 시:
- `project_harness_engineering.md` 갱신 (새 docs/process/ 구조 반영)
- `project_harness_operation_gap.md` 갱신 (재설계 완료 + dogfooding 단계로 진입 표시)
- `project_sprint0_complete.md` 갱신 또는 제거 검토

---

## 위험 요소

| 위험 | 완화 |
|------|------|
| 끊어진 링크 누락 | M-1, M-2, M-3, M-4 각 끝에서 grep 검증 + M-4에서 전체 점검 |
| `docs/harness/` 외부 참조(코드/스크립트/설정) 누락 | M-3 Step 2에서 전체 grep 검증 |
| CHARTER 변형 시 Multi-Agent 원칙 누락 | M-2 Task 2.2 Step 3에서 design doc과 대조 |
| 4 PR이 의존성 깨짐 | M-1 머지 후 M-2 시작 등 순차 진행 강제 |

## 비목표 (Non-Goals)

- 코드 변경 없음 (문서 마이그레이션만)
- 기존 머지된 9개 PR(#21~29) 재검토 없음
- spec-lock 같은 무거운 lock 의식 부활 없음
- archive 폴더 생성 없음 (git history 의존)
