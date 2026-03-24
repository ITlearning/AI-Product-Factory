# 이번엔 안 돼 Design

## Summary

`이번엔 안 돼`는 받은 메시지나 상황 설명을 바탕으로, 관계와 상황에 맞는 거절 답장 3개를 즉시 생성하는 웹앱이다. MVP의 핵심은 문장 다양성보다 `예의는 지키되 여지를 남기지 않는` 출력 품질에 있다.

구현은 `IBAD/` 아래 새 앱으로 진행한다. 기존 `Translate-Developer`는 구조 참고용으로만 사용하며 수정하지 않는다.

## Approved Decisions

- 작업 위치: `IBAD/` 하위 새 앱
- 제품 형태: 단일 페이지 웹앱 + Vercel 서버리스 API
- 생성 방식: OpenAI Responses API 기반 실제 생성
- 안전 정책: 서버 측 구조화 응답 검증 + 후처리 안전가드
- 범위 정책: MVP 지원 범위 외 입력은 생성하지 않고 제한 안내 반환
- fallback 정책: 로컬 자동 생성 fallback 없음, 재시도 중심
- 개인정보 정책: 원문 대화 로그를 남기지 않는 방향으로 구현

## Product Goal

사용자가 받은 메시지나 상황 설명을 입력하면, 바로 복사해서 보낼 수 있는 거절 답장 3개를 제공한다. 답장은 관계 거리감과 상황 맥락을 반영해야 하며, 지나치게 차갑거나 반대로 여지를 남기는 표현을 줄여야 한다.

## MVP Scope

### In Scope

- 받은 메시지 또는 상황 설명 입력
- 관계 타입 선택
  - 친한 친구
  - 그냥 친구
  - 애매한 사이
  - 거의 안 친함
- 상황 타입 선택
  - 약속 거절
  - 부탁 거절
- 거절 강도 선택
  - 부드럽게
  - 예의 있게 확실하게
  - 단호하게
- 대안 제시 여부 선택
- 답장 3개 생성
- 각 답장 톤 설명
- 피해야 할 표현 안내
- 여지 남김 여부 표시
- 대안을 넣었을 때와 안 넣었을 때의 차이 설명

### Out of Scope

- 연인 관계 전용 모드
- 가족 관계 전용 모드
- 직장/상사/업무 거절
- 후속 답장 생성
- 장기 대화 히스토리
- 로그인, 저장, 공유

## Architecture

### Frontend

앱은 `IBAD/` 하위의 독립된 SPA로 구현한다. 한 화면 안에서 입력 폼, 도움말 영역, 결과 카드 영역을 모두 처리한다.

화면 구성:

- Hero: 서비스 가치 제안과 예시
- Input Panel: 메시지/상황 설명, 관계, 상황, 강도, 대안 여부
- Helper Panel: 사용 팁, 지원 범위, 예시 입력
- Results Panel:
  - 답장 3개
  - 각 답장 톤 라벨
  - 짧은 설명
  - 피해야 할 표현
  - 여지 남김 여부
  - 대안 유무 차이

프런트는 로딩, 성공, 제한 안내, 에러를 명확히 구분하고, 결과는 바로 복사 가능한 형태로 보여준다.

### Serverless API

서버리스 함수는 `/api/generate-reply` 하나로 시작한다.

책임:

1. 입력 payload 검증
2. MVP 지원 범위 분기
3. OpenAI Responses API 호출
4. 구조화 JSON 응답 검증
5. 후처리 안전가드 적용
6. 정규화된 결과 반환

브라우저는 OpenAI API를 직접 호출하지 않는다.

### OpenAI Output Contract

모델은 자유 텍스트가 아니라 구조화된 JSON만 반환해야 한다.

최소 응답 구조:

- `replyOptions`
  - 3개의 답장 후보
  - 각 항목은 `text`, `toneLabel`, `whyItWorks`
- `avoidPhrases`
- `openDoorRisk`
- `alternativeDifference`

이 계약을 서버에서 다시 검증하고, 검증 실패 시 결과를 노출하지 않는다.

## Safety Guard Design

이 제품의 핵심 품질은 안전가드에 있다. 서버는 모델 출력에 대해 아래 검사를 수행한다.

### 1. Support Boundary Check

입력이 다음 범주에 속하면 생성하지 않는다.

- 연인/가족/직장 상하관계
- 후속 답장이나 장기 맥락이 필요한 상황
- 관계 타입과 상황 타입이 비어 있거나 충돌하는 입력

이 경우 `현재 버전 지원 범위`를 짧게 안내한다.

### 2. Schema Validation

아래를 보장한다.

- 답장 후보가 정확히 3개 존재
- 각 항목에 필수 문자열 필드 존재
- 빈 문자열, 과도하게 긴 문자열, 중복 답장 방지

### 3. Tone Guard

아래 표현 패턴을 검사한다.

- 지나친 사과 반복
- 공격적이거나 비꼬는 표현
- 지나치게 딱딱한 통보형 표현

### 4. Open-Door Guard

대안 미제시일 때 아래 표현을 차단하거나 재생성한다.

- `다음에`
- `나중에`
- `언젠가`
- `시간 되면`
- `기회 되면`
- `다음엔 보자`

### 5. Over-Explanation Guard

핵심 결론보다 긴 변명형 답장을 제한한다. 답장은 복붙 가능한 길이로 유지한다.

## UX Behavior

### Happy Path

1. 사용자가 입력한다.
2. 생성 버튼을 누른다.
3. 로딩 상태를 보여준다.
4. 결과 카드 3개가 나타난다.
5. 사용자는 마음에 드는 답장을 복사해 사용한다.

### Unsupported Path

지원 범위 외 입력이면 생성 대신 제한 안내를 보여준다.

### Failure Path

- 입력 검증 실패: 즉시 수정 안내
- API 실패: 재시도 안내
- 안전가드 실패: 안전한 결과를 만들지 못했다는 메시지와 재생성 유도

## File Layout

작업은 모두 `IBAD/` 아래에서 진행한다.

예상 구조:

- `IBAD/app/package.json`
- `IBAD/app/index.html`
- `IBAD/app/vercel.json`
- `IBAD/app/api/generate-reply.js`
- `IBAD/app/src/app.js`
- `IBAD/app/src/main.js`
- `IBAD/app/src/config.js`
- `IBAD/app/src/styles.css`
- `IBAD/app/src/ui/templates.js`
- `IBAD/app/src/ui/state.js`
- `IBAD/app/src/api/generate-reply.js`
- `IBAD/app/src/domain/schema.js`
- `IBAD/app/src/domain/safety.js`
- `IBAD/app/src/domain/examples.js`
- `IBAD/app/src/utils/validation.js`
- `IBAD/app/tests/...`

## Testing Strategy

### Server

- request payload validation
- support boundary branching
- schema normalization
- open-door phrase rejection
- long/apologetic reply filtering

### Frontend

- initial render
- input update
- loading state
- successful result render
- unsupported-scope message
- upstream failure message

## Success Criteria

- 사용자가 결과를 보고 바로 복사해서 보내고 싶다고 느낀다
- 답장 3개가 톤 차이를 가지되 모두 관계를 불필요하게 자극하지 않는다
- 대안 미제시 선택 시 애매한 재접점 표현이 줄어든다
- 지원 범위 외 요청에는 무리하게 생성하지 않는다

## Risks

- 모델이 지나치게 사과하거나 여지를 남길 수 있음
- 관계 미묘함을 과도하게 단순화할 수 있음
- 너무 짧고 단호하면 차갑게 느껴질 수 있음
- 사용자가 실제 개인 대화를 그대로 넣는 경우 민감 정보가 포함될 수 있음

## Mitigations

- 구조화 응답 강제
- 서버 후처리 안전가드
- 지원 범위 분기
- 원문 로그 비저장
- UI에서 민감 정보 주의 문구 제공
