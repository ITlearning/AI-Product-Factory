# PRD_TEMPLATE

PRD를 잘 쓰기 위한 양식. 11개 필드.

---

## Purpose

PRD를 작성할 때 비워두면 안 되는 양식이다. Tabber(인간)가 직접 채우고, [4] PARALLEL REVIEW 단계로 넘긴다.

이 양식은 **PRD를 잘 쓰기 위한 가이드**일 뿐, PRD가 통과해야 하는 검문소가 아니다. [3] PRD DRAFT 단계 안에서 빈 채로 시작해 brainstorming으로 채워나가도 된다. 채워진 PRD는 `docs/plans/<date>-<topic>-prd.md`로 저장한다.

작성 흐름:

1. 빈 양식을 복사해 새 파일로 저장한다.
2. 알고 있는 것부터 채운다. 모르는 칸은 비워두거나 `Open Questions`로 옮긴다.
3. [4] PARALLEL REVIEW에서 인간/에이전트가 같이 점검하고 보강한다.

---

## 양식 구조

### Goal

- **정의**: 이 프로젝트가 달성하려는 한 가지 결과. 추상적인 가치 진술 대신 측정 가능한 변화로 쓴다.
- **예시**: CodeStudy 사용자가 자기 트랙(Swift/Python/JS)에 맞는 다음 문제를 추천 화면 진입 3초 안에 본다.

### Non-Goals

- **정의**: 이 PRD가 **하지 않는 일**. 범위 밖에 둘 항목을 명시해서 scope creep을 차단한다.
- **예시**: 추천 결과 SNS 공유, 다국어 추천 사유 텍스트, 학습 진도 시각화 개편.

### Success Criteria

- **정의**: 완료를 판정할 측정 가능한 기준. 숫자/비율/존재 여부 중 하나로 표현한다.
- **예시**: 추천 화면 진입 P95 응답 ≤ 300ms, 추천 결과 1주 클릭률 ≥ 35%, 트랙 미선택 사용자에게 빈 화면 노출 0건.

### Target Path

- **정의**: 변경이 일어날 서비스/모듈 경로. AGENTS.md Repo Map 기준으로 적는다.
- **예시**: `CodeStudy/iOS/CodeStudy/Features/Recommend/`

### Allowed Touch Surface

- **정의**: 이 PRD에서 **수정해도 되는** 파일/디렉터리 범위. ralph loop이 자유롭게 건드릴 수 있는 영역을 미리 합의한다.
- **예시**: `Features/Recommend/**`, `Core/Curriculum/RecommendationEngine.swift`, 관련 단위 테스트.

### Disallowed Areas

- **정의**: 이 PRD에서 **건드리면 안 되는** 영역. 다른 PR과 충돌하거나, 이 PRD 범위를 넘어가는 곳을 명시한다.
- **예시**: `Features/Onboarding/**`, App Group 스키마, Claude Haiku 호출 레이어.

### Constraints

- **정의**: 기술/비기능 제약. 라이브러리, 아키텍처, 성능, 프라이버시, 비용 한계 등.
- **예시**: zero deps 유지, 기존 MVVM+Observable 패턴 준수, 추천 1회당 LLM 호출 ≤ 1, 오프라인 폴백 필수.

### Dependencies

- **정의**: 이 PRD 실행에 **선행되어야 하는** 다른 작업/PRD/외부 자원.
- **예시**: PR #30 트랙 선택 화면 머지, Curriculum v0.5 데이터셋, App Group 마이그레이션 v0.4.

### Acceptance Evidence

- **정의**: 완료를 증명할 증거 형태. 스크린샷/지표/테스트/사용자 검증 중 어떤 것을 남길지 정한다.
- **예시**: 추천 화면 시뮬레이터 녹화 30초, 단위 테스트 커버리지 ≥ 80%, 클릭률 측정 대시보드 캡처 1주분.

### Open Questions

- **정의**: 아직 결정되지 않은 항목. PRD 작성 중에 떠오른 질문을 모아둔다. [4] PARALLEL REVIEW에서 해소한다.
- **예시**: 신규 사용자 첫 추천은 어떤 휴리스틱으로 시작할지? 추천 사유 텍스트는 룰 기반 vs LLM?

### Owner

- **정의**: PRD를 책임질 주인. 단일 인간 1명. 의사결정 충돌 시 이 사람이 자른다.
- **예시**: Tabber

---

## 빈 양식

복사해서 `docs/plans/<date>-<topic>-prd.md`로 저장하고 채운다.

```markdown
# PRD: <한 줄 제목>

## Goal

(이 프로젝트가 달성하려는 측정 가능한 결과 1개)

## Non-Goals

- (범위 밖에 두는 항목)
- (범위 밖에 두는 항목)

## Success Criteria

- [ ] (측정 가능한 기준 1)
- [ ] (측정 가능한 기준 2)

## Target Path

(변경이 일어날 서비스 경로 — AGENTS.md Repo Map 기준)

## Allowed Touch Surface

- (수정 허용 범위)

## Disallowed Areas

- (수정 금지 범위)

## Constraints

- (기술/비기능 제약)

## Dependencies

- (선행 PR/PRD/외부 자원)

## Acceptance Evidence

- (완료 증거 형태)

## Open Questions

- (미결정 질문)

## Owner

(인간 1명)
```

---

## 채워진 예시 — CodeStudy 트랙별 추천 알고리즘 v0.1

```markdown
# PRD: CodeStudy 트랙별 추천 알고리즘 v0.1

## Goal

CodeStudy 사용자가 자기 트랙(Swift/Python/JS)에 맞는 다음 문제를
추천 화면 진입 3초 안에 본다.

## Non-Goals

- 추천 결과 SNS 공유 기능
- 다국어 추천 사유 텍스트 (한국어 우선)
- 학습 진도 시각화 화면 개편

## Success Criteria

- [ ] 추천 화면 진입 P95 응답 ≤ 300ms
- [ ] 추천 결과 1주 클릭률 ≥ 35%
- [ ] 트랙 미선택 사용자에게 빈 화면 노출 0건

## Target Path

CodeStudy/iOS/CodeStudy/Features/Recommend/

## Allowed Touch Surface

- Features/Recommend/**
- Core/Curriculum/RecommendationEngine.swift
- 관련 단위 테스트

## Disallowed Areas

- Features/Onboarding/**
- App Group 스키마
- Claude Haiku 호출 레이어

## Constraints

- zero deps 유지
- MVVM+Observable 패턴 준수
- 추천 1회당 LLM 호출 ≤ 1
- 오프라인 폴백 필수

## Dependencies

- PR #30 트랙 선택 화면 머지
- Curriculum v0.5 데이터셋
- App Group 마이그레이션 v0.4

## Acceptance Evidence

- 추천 화면 시뮬레이터 녹화 30초
- 단위 테스트 커버리지 ≥ 80%
- 클릭률 측정 대시보드 캡처 1주분

## Open Questions

- 신규 사용자 첫 추천은 어떤 휴리스틱으로 시작할지?
- 추천 사유 텍스트는 룰 기반 vs LLM?

## Owner

Tabber
```

---

## 비목표 (Non-Goals)

- **PRD_TEMPLATE은 입장 게이트가 아니다.** 양식이 빈 채로 [3] PRD DRAFT 단계가 시작될 수 있다. 단계 [3] 안에서 brainstorming으로 채워나가는 것이 정상 흐름이다.
- **자동 반려 룰 없음.** 누락된 필드를 자동으로 검출해 막는 메커니즘은 두지 않는다. 점검은 [4] PARALLEL REVIEW에서 인간과 에이전트가 같이 한다.

---

## 관련 문서

- [SEQUENCE.md](SEQUENCE.md) — 6단계 흐름 본문 (PRD_TEMPLATE은 [3] PRD DRAFT의 양식)
- [EXECUTION.md](EXECUTION.md) — PRD 이후 병렬 리뷰 + ralph loop 패턴
