# Evidence Trail

이 문서는 검증 수행 결과를 구조화하여 기록하는 증거(evidence)의 포맷과 규칙을 정의한다.
evidence trail은 에이전트가 "무엇을 검증했고, 결과가 무엇이었는지"를 인간이 추적할 수 있게 한다.

---

## Purpose

evidence trail의 목적은 **검증의 투명성**이다.

- 에이전트가 검증을 수행했다는 주장만으로는 부족하다. 증거가 있어야 한다.
- 인간은 코드를 작성하지 않으므로, 검증 결과를 직접 실행하여 확인하지 않는다. 대신 증거를 읽고 판단한다.
- 리뷰 게이트에서 증거가 부재하면 검증 미수행으로 취급한다 (fail-closed).

---

## 증거 유형

| 유형 | 설명 | 예시 |
|------|------|------|
| 검증 파이프라인 결과 | `npm run verify` 등 자동 검증의 실행 결과 | lint 통과, 테스트 통과, 빌드 성공 |
| 리뷰 점수 | 에이전트 리뷰의 역할별 점수와 피드백 요약 | critic 8, architect 9, analyst 8, 평균 8.3 |
| 정합성 확인 | 문서 간 교차 참조, Source of Truth Map 동기화 확인 | AGENTS.md 승격 완료, Cross-References 유효 |
| 수동 확인 | 자동 검증이 없는 항목의 수동 확인 기록 | 링크 유효성, 문서 간 용어 일관성 |
| 스크린샷/로그 | UI 변경, 배포 결과 등의 시각적 증거 | 배포 성공 스크린샷, 콘솔 출력 |
| 변경 전후 비교 | 기존 동작과 변경 후 동작의 비교 | 기존 오류 → 수정 후 정상 동작 |

---

## Evidence Record 구조

하나의 PR에 대한 evidence record는 다음 구조를 따른다.

```markdown
## Evidence: [PR 제목]

- **PR**: [PR 번호/브랜치]
- **날짜**: [YYYY-MM-DD]
- **대상 서비스**: [서비스 경로]

### 검증 수행

| 검증 항목 | 방법 | 결과 | 비고 |
|-----------|------|------|------|
| [항목 1] | [자동/수동] | [PASS/FAIL] | [추가 정보] |
| [항목 2] | [자동/수동] | [PASS/FAIL] | [추가 정보] |

### 리뷰 점수

| 역할 | 점수 |
|------|------|
| critic | [N/10] |
| architect | [N/10] |
| analyst | [N/10] |
| **평균** | **[N/10]** |

> 통과 기준: 역할별 >= 7, 평균 >= 8.0 (QUALITY_SCORE.md)
> **PR 판정**: [PASS / REVISE / REJECT]

### 피드백 반영 이력

| 회차 | 주요 피드백 | 반영 내용 |
|------|-----------|----------|
| [1차] | [피드백 요약] | [반영 내용] |

### 미해결 사항

- [있으면 기술, 없으면 "없음"]

### 성공 기준 충족 여부

| 성공 기준 | 충족 여부 | 증거 |
|-----------|----------|------|
| [기준 1] | [Y/N] | [증거 설명] |
```

---

## 필수 항목

모든 evidence record는 다음을 포함해야 한다.

| 필수 항목 | 설명 | 부재 시 |
|-----------|------|---------|
| 검증 수행 테이블 | 최소 1개의 검증 항목과 결과 | 검증 미수행으로 취급 |
| 리뷰 점수 테이블 | 3개 역할의 점수와 최종 판정 | 리뷰 미수행으로 취급 |
| 성공 기준 충족 여부 | spec-lock된 성공 기준 대비 충족 상태 | sprint/계획 완료 판정 불가 |

### 선택 항목

| 선택 항목 | 포함 조건 |
|-----------|----------|
| 피드백 반영 이력 | REVISE/REJECT가 있었던 경우 |
| 미해결 사항 | 인간에게 보고할 잔여 이슈가 있는 경우 |
| 스크린샷/로그 | UI 변경 또는 배포가 포함된 경우 |
| 변경 전후 비교 | 버그 수정 또는 동작 변경이 포함된 경우 |

---

## 저장 위치

| 대상 | 위치 | 형식 |
|------|------|------|
| PR 단위 evidence | PR 본문 또는 PR 코멘트 | 위 Evidence Record 구조 |
| Sprint 단위 summary | `docs/evidence/sprint-{N}.md` (`{N}`은 Sprint 번호, 0부터 시작) | Sprint 내 PR evidence 요약 + sprint 목표 충족 여부 |
| 계획 완료 summary | `docs/evidence/plan-{slug}.md` (`{slug}`는 PRD 제목의 kebab-case) | 전체 성공 기준 충족 여부 + 최종 상태 |

### 저장 규칙

- PR evidence는 PR 생성 시 본문에 포함하거나, 리뷰 완료 후 코멘트로 추가한다.
- Sprint/계획 evidence 파일은 해당 단위가 완료될 때 생성한다.
- `docs/evidence/` 디렉토리는 최초 evidence 생성 시 만든다 (사전 생성 불필요).
- evidence 파일은 생성 후 수정하지 않는다. 정정이 필요하면 새 코멘트/파일로 추가한다 (append-only).

---

## Evidence와 다른 문서의 관계

| 시점 | evidence 역할 |
|------|-------------|
| ralph 실행 중 (검증 단계) | 검증 결과를 evidence record로 기록 |
| ralph 실행 중 (리뷰 단계) | 리뷰 점수와 피드백을 evidence record에 추가 |
| PR handoff | evidence record를 PR 본문/코멘트에 포함 |
| Sprint 완료 | sprint 내 evidence를 요약하여 sprint summary 생성 |
| 계획 완료 | 전체 evidence를 요약하여 plan summary 생성 |

---

## Fail-Closed 기본값

- evidence가 없으면 검증/리뷰가 수행되지 않은 것으로 취급한다.
- evidence의 검증 결과가 모호하면 FAIL로 취급한다.
- evidence record의 필수 항목이 하나라도 누락되면 불완전으로 취급한다.
- 불완전한 evidence로는 리뷰 게이트를 통과할 수 없다.

---

## Cross-References

| 문서 | 관계 |
|------|------|
| [`docs/process/CHARTER.md`](CHARTER.md) | Review Gates (evidence가 리뷰 판정의 근거) — M-2에서 추가 예정 |
| [`docs/process/EXECUTION.md`](EXECUTION.md) | ralph loop 실행 사이클 (검증→리뷰 단계에서 evidence 생성) |
| [`docs/QUALITY_SCORE.md`](../QUALITY_SCORE.md) | 리뷰 점수 기준 (evidence에 기록되는 점수의 출처) |
| [`docs/RELIABILITY.md`](../RELIABILITY.md) | 검증 파이프라인 (evidence에 기록되는 검증의 출처) |
| [`AGENTS.md`](../../AGENTS.md) | Validation 테이블 (서비스별 검증 명령) |
| [`docs/process/DOC_LINT.md`](DOC_LINT.md) | 문서 전용 변경 검증 규칙 (검증 결과를 evidence로 기록) |

---

## Change Log

| 날짜 | PR | 변경 내용 |
|------|-----|----------|
| 2026-03-31 | PR 0-13 | 초기 evidence trail 포맷 작성 |
