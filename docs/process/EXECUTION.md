# EXECUTION — 단계 [6] 실행 패턴

> 단계 [6] EXECUTION이 어떻게 굴러가는지 정의한다. 단계 [1]~[5](기획·리뷰·분해)는 이 문서 범위 밖이며 [SEQUENCE.md](SEQUENCE.md)를 참고한다.

---

## 1. Purpose

[5] DECOMPOSITION에서 N개의 PR로 분해된 작업을 실행하는 단계다. 독립적인 PR끼리는 단일 메시지에서 멀티 에이전트로 **병렬 dispatch**하고, 각 PR 내부는 **ralph loop**라는 자율 미니 루프로 굴러간다. Tabber는 단계 안의 매 스텝마다 들어오지 않는다 — 결과로 올라온 PR만 검토하고 머지 결정을 내린다. 즉 EXECUTION은 "PR 단위 자율 실행 + PR 단위 승인" 모델이다.

---

## 2. 병렬 dispatch 패턴

### 2.1 단일 메시지 다중 Agent 호출

분해 결과가 PR-A, PR-B, PR-C처럼 **같은 의존성 레벨**의 PR이라면, 하나의 어시스턴트 메시지 안에 `Agent` 도구 호출을 N개 포함시켜 동시에 띄운다. 순차 dispatch는 금지다 — 그러면 그냥 단일 에이전트와 같다.

```
message:
  Agent(prompt="PR-A 구현 + ralph loop", isolation="worktree")
  Agent(prompt="PR-B 구현 + ralph loop", isolation="worktree")
  Agent(prompt="PR-C 구현 + ralph loop", isolation="worktree")
```

### 2.2 worktree 격리

각 Agent 호출에는 `isolation: "worktree"` 옵션을 명시한다. 이 옵션이 없으면 PR끼리 같은 working tree를 공유해서 git 충돌이나 빌드 캐시 오염이 발생한다. worktree는 PR 머지(또는 폐기) 시점에만 정리한다.

### 2.3 의존성 처리 (DAG)

PR 간 의존성은 [5] DECOMPOSITION에서 DAG로 명시된다 ([DECOMPOSITION.md](DECOMPOSITION.md) §의존성 규칙).

| 관계 | 처리 |
|------|------|
| 같은 레벨 (독립) | 동시 dispatch |
| 의존 PR | 선행 PR이 main에 머지된 후 시작 |
| 사이클 발견 | DECOMPOSITION 단계로 되돌려 분해 재정리 |

선행 PR 미머지 상태에서 후행 PR을 띄우지 않는다 (fail-closed).

### 2.4 병렬 안 하는 곳

- 단계 [1] INTAKE / [2] DISCOVERY / [3] PRD DRAFT — Tabber와 1:1 대화이므로 병렬화 의미 없음
- 단계 [5] DECOMPOSITION — 단일 에이전트가 일관된 분해를 해야 함
- 승인 게이트 — Tabber 1명이 결정자

---

## 3. ralph loop (PR 내부 자율 미니 루프)

각 PR을 받은 Agent는 다음 미니 루프를 자율적으로 돌린다. 멈추지 않는 흐름이며 ESCAPE 조건에 도달할 때까지 반복한다.

```
1. 구현       → 2. lint/test  → 3. 검증
↑                                  ↓
5. 수정       ← 4. 실패 시 분석 ←
→ 통과 시 PR 생성 + Tabber 알림
```

### 3.1 각 단계 한 줄 설명

1. **구현** — PR 계획에 따라 코드/문서를 작성한다. 허용 수정 범위(PRD의 Allowed Touch Surface) 안에서만 작업한다.
2. **lint/test** — 프로젝트별 verify 명령(`npm run verify`, `swift test`, `xcodebuild test` 등)을 실행한다.
3. **검증** — 기능 검증을 돌린다 (`/qa` 스킬, XCUITest, swift-tdd 시나리오 등 PRD에 명시된 Acceptance Evidence).
4. **실패 시 분석** — 실패 로그를 읽고 원인을 식별한다. 경계 외부(허용 범위 밖)면 즉시 escalate.
5. **수정** — 식별된 원인을 고친 뒤 1번으로 돌아간다.

### 3.2 ESCAPE 조건

루프를 빠져나오는 두 경로:

- **(a) 통과** — lint/test + 검증 모두 PASS → PR 생성(`/ship` 또는 `gh pr create`) + Tabber에게 알림(코멘트/메시지). 이 PR은 Tabber 머지 승인 대기 상태가 된다.
- **(b) 5회 이상 수정 루프** — 동일한 검증 항목에 대해 수정→재검증을 5회 반복했는데도 PASS하지 못하면 즉시 중단하고 Tabber에게 escalate한다. 자동 재시도 무한 반복은 금지.

추가로 다음 상황도 즉시 escalate한다:

- PRD의 Allowed Touch Surface 밖을 건드려야 해결 가능할 때
- PRD의 Disallowed Areas/Constraints와 충돌할 때
- 외부 의존성(API, 인프라) 장벽으로 검증을 돌릴 수조차 없을 때

---

## 4. 도구 매핑

각 단계에서 어떤 gstack 스킬 / Agent 도구를 쓰는지.

| 단계 | 사용 도구 |
|------|----------|
| 구현 | `Agent` (subagent) |
| lint/test | `Bash` + 프로젝트 verify 명령 (`npm run verify`, `swift test`, `xcodebuild`, etc.) |
| 검증 | `/qa` 또는 `swift-tdd` / XCUITest 등 프로젝트별 Acceptance Evidence 도구 |
| 수정 | Agent loop (`ralph-loop:ralph-loop`) |
| PR 생성 | `/ship` 또는 `gh pr create` |
| PR 리뷰 (사후) | `/review` |

**메모:**
- `ralph-loop:ralph-loop` 스킬은 위 1→2→3→4→5 루프를 한 번 호출에 묶어주는 헬퍼다. 직접 Agent를 굴려도 동일한 흐름을 만들 수 있다.
- `/ship`은 PR 생성까지만 수행한다. 머지/배포 결정은 Tabber 몫.
- `/review`는 PR이 올라온 뒤 Tabber가 수동으로 트리거하거나 CI에 연결한다 (자동 판정 게이트로 쓰지 않음).

---

## 5. 검증 증거

각 PR이 ESCAPE 조건 (a) PASS로 빠져나갈 때, 다음 경로에 검증 로그를 남긴다.

```
docs/evidence/<PR-id>/
  EVIDENCE.md           # 요약 (PASS 항목, 명령, 결과)
  lint.log              # 원본 로그 (선택)
  test.log              # 원본 로그 (선택)
  qa-screenshots/       # /qa 또는 XCUITest 산출물
```

`<PR-id>`는 PR 번호 또는 PR slug (예: `pr-31-codestudy-track-recommend`).

EVIDENCE.md 포맷·필드는 [EVIDENCE.md](EVIDENCE.md) 본문을 따른다. 핵심은:

- 어떤 명령을 어느 커밋에서 돌렸는가
- PASS/FAIL 결과
- PRD의 Acceptance Evidence 항목과 1:1 매핑

증거 없이 PR을 생성하지 않는다. 증거 디렉터리가 없으면 Tabber가 머지하지 않는다 (운영 룰).

---

## 6. 비목표 (Non-Goals)

- **기획 단계 ([1]~[5])는 이 문서 범위 밖**이다. 그쪽은 [SEQUENCE.md](SEQUENCE.md)에서 정의한다.
- **단계 [6] 안에서는 단계마다 Tabber 승인 패턴이 적용되지 않는다.** ralph loop 내부의 1→2→3 단계마다 승인을 받는 게 아니라, **PR 단위 한 번**만 승인한다. PR 안의 micro 결정은 Agent 자율.
- **codex / Symphony / Linear 라우팅은 사용하지 않는다.** 옛 ralplan-ralph 문서의 spec-lock·계획 locked 상태·QUALITY_SCORE 자동 게이트 같은 의식은 모두 폐기됐다. 이 문서는 그 자리를 대체하는 새 정의다.
- **3 에이전트 리뷰 점수 자동 게이트 (critic/architect/analyst ≥7, 평균 ≥8.0)** 같은 hard gate를 두지 않는다. 점수는 [QUALITY_SCORE.md](../QUALITY_SCORE.md)에서 Tabber 판단의 참고값으로만 쓴다.
- **archive 폴더 / 별도 history 보존**은 만들지 않는다. PR과 git history로 충분하다.

---

## 7. 관련 문서

| 문서 | 관계 |
|------|------|
| [SEQUENCE.md](SEQUENCE.md) | 6단계 흐름 본문. 이 문서는 그 중 [6]단계의 상세 |
| [DECOMPOSITION.md](DECOMPOSITION.md) | PR 크기 기준, Sprint 기준, 의존성 DAG 규칙 |
| [EVIDENCE.md](EVIDENCE.md) | 검증 증거 포맷, `docs/evidence/<PR-id>/` 구조 |
| [PRD_TEMPLATE.md](PRD_TEMPLATE.md) | Allowed Touch Surface, Disallowed Areas, Acceptance Evidence 등 ralph loop 경계 정의 |
| [DOC_LINT.md](DOC_LINT.md) | 문서 변경 PR의 lint/test 대체 검증 룰 |
