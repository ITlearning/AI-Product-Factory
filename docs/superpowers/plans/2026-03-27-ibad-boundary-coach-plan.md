# IBAD 첫 거절문 추천 구현 계획

> **에이전트 작업자용:** 하위 에이전트를 쓸 수 있으면 `superpowers:subagent-driven-development`를, 그렇지 않으면 `superpowers:executing-plans`를 사용해 이 계획을 실행한다. 단계 추적에는 체크박스 문법(`- [ ]`)을 사용한다.

**목표:** `IBAD/app`을 단순한 3개 답장 생성기에서, 지금 바로 보낼 첫 거절문 1개를 추천하고 통제된 대안 2개와 짧은 가이드 맥락을 함께 주는 흐름으로 확장한다.

**구현 방향:** 기존 단일 페이지 앱과 Vercel 함수를 유지하되, 요청 필드 `blockerType` 하나와 막힘 이유에 따라 추천 톤과 UI 강조를 정하는 얇은 결정론적 추천 레이어를 추가한다. OpenAI 응답 계약은 `replyOptions`만 반환하던 구조에서 `replyOptions`, `recommendedTone`, `coachNote`, `avoidPhrase`를 포함하는 작은 추천 팩으로 확장하고, 기존 안전성 검사도 그대로 유지해 위험한 답장을 걸러낸다.

**범위 조정 메모:** 이 계획은 초기 `boundary coach` 표현을 1차 제품 기준으로 낮춰 읽는다. 즉 상담형 제품으로 넓히지 않고, `질문 1개 추가 + 첫 답장 1개를 더 선명하게 추천`하는 수준으로 한정한다.

**기술 스택:** 바닐라 JS SPA, Node 테스트 러너, Vercel 서버리스 함수, OpenAI Responses API

---

## 파일 구조

- 수정: `IBAD/app/src/domain/options.js`
  책임: UI, 검증, 프롬프트 빌딩이 함께 쓰는 막힘 이유 옵션과 공용 enum 추가
- 생성: `IBAD/app/src/domain/coaching.js`
  책임: 막힘 이유에서 추천 톤과 짧은 가이드 문구로 이어지는 결정론적 매핑 관리
- 수정: `IBAD/app/src/ui/state.js`
  책임: `blockerType`을 상태에 들고 다니고, 더 풍부한 결과 계약을 보존하며, 요청에 포함해 전송
- 수정: `IBAD/app/src/app.js`
  책임: 막힘 이유 필드 변경 이벤트를 바인딩하고 기존 렌더 흐름 유지
- 수정: `IBAD/app/src/ui/templates.js`
  책임: 막힘 이유 선택기, 추천 결과 카드, 가이드 메모, 피해야 할 표현 영역 렌더링
- 수정: `IBAD/app/src/styles.css`
  책임: 막힘 이유 칩/카드, 추천 카드 강조, 추천 패널 스타일 추가
- 수정: `IBAD/app/src/utils/validation.js`
  책임: 요청 경계에서 `blockerType` 검증
- 수정: `IBAD/app/src/api/generate-reply.js`
  책임: 브라우저 클라이언트에서 `blockerType`을 API로 보내고 새 결과 구조를 받도록 조정
- 수정: `IBAD/app/src/domain/schema.js`
  책임: `recommendedTone`, `coachNote`, `avoidPhrase`를 포함해 결과 정규화
- 수정: `IBAD/app/api/generate-reply.js`
  책임: 프롬프트에 막힘 이유 맥락을 포함하고 확장된 구조화 결과를 요청
- 수정: `IBAD/app/tests/ui/app.test.js`
  책임: 막힘 이유 입력과 추천 결과 셸을 회귀 테스트로 고정
- 생성: `IBAD/app/tests/domain/coaching.test.js`
  책임: 막힘 이유와 추천 결과 매핑 고정
- 수정: `IBAD/app/tests/domain/schema.test.js`
  책임: 확장된 추천 팩 스키마 고정
- 수정: `IBAD/app/tests/api/generate-reply.test.js`
  책임: 프롬프트 내용, 요청 페이로드, 정규화된 결과 구조 고정
- 수정: `IBAD/app/README.md`
  책임: 막힘 이유를 반영하는 제품 포지셔닝과 결과 구조 문서화
- 수정: `IBAD/ibeonen-an-dwae-feature-definition.md`
  책임: 기능 정의 문서를 새 제품 방향과 맞춤

## 청크 1: 막힘 이유 입력과 추천 결과 셸 추가

### 작업 1: 막힘 이유 기반 셸을 테스트로 먼저 고정

**대상 파일:**
- 수정: `IBAD/app/tests/ui/app.test.js`

- [ ] **1단계: 새 막힘 이유 질문에 대한 실패 테스트 추가**

```js
assert.match(markup, /지금 막히는 이유가 뭐예요/);
assert.match(markup, /미안해서 시작이 안 돼요/);
assert.match(markup, /너무 차갑게 보일까 걱정돼요/);
assert.match(markup, /말이 길어질까 봐 걱정돼요/);
```

- [ ] **2단계: 추천 팩 결과 셸에 대한 실패 테스트 추가**

```js
assert.match(markup, /추천 시작 문장/);
assert.match(markup, /피해야 할 표현/);
assert.match(markup, /이럴 때는 이렇게 시작하면 돼요/);
```

- [ ] **3단계: 예전의 무거운 입력이 다시 들어오지 않음을 회귀 테스트로 유지**

```js
assert.doesNotMatch(markup, /관계 타입/);
assert.doesNotMatch(markup, /거절 강도/);
```

- [ ] **4단계: UI 테스트 파일을 실행해 올바른 이유로 실패하는지 확인**

실행: `cd IBAD/app && node --test tests/ui/app.test.js`
예상: 현재 마크업에는 막힘 이유 선택기와 추천 결과 셸이 없으므로 FAIL

- [ ] **5단계: 셸 기대값 테스트 커밋**

```bash
git add IBAD/app/tests/ui/app.test.js
git commit -m "test: lock ibad blocker-aware shell"
```

### 작업 2: 막힘 이유 선택기와 추천 결과 레이아웃 구현

**대상 파일:**
- 수정: `IBAD/app/src/domain/options.js`
- 생성: `IBAD/app/src/domain/coaching.js`
- 수정: `IBAD/app/src/ui/state.js`
- 수정: `IBAD/app/src/app.js`
- 수정: `IBAD/app/src/ui/templates.js`
- 수정: `IBAD/app/src/styles.css`

- [ ] **1단계: 공용 막힘 이유 옵션 목록 추가**

```js
export const BLOCKER_OPTIONS = [
  { value: "guilt", label: "미안해서 시작이 안 돼요" },
  { value: "tone-anxiety", label: "너무 차갑게 보일까 걱정돼요" },
  { value: "overexplaining", label: "말이 길어질까 봐 걱정돼요" }
];
```

- [ ] **2단계: UI 곳곳에 문자열을 흩뿌리지 말고 추천 매핑 파일로 분리**

```js
export const BLOCKER_COACHING = {
  guilt: {
    recommendedTone: "soft",
    coachNote: "미안함을 길게 풀어주기보다 결론 한 번, 감사 한 번이면 충분해요."
  },
  "tone-anxiety": {
    recommendedTone: "polite-firm",
    coachNote: "예의는 유지하되 결론을 먼저 두면 차갑기보다 분명하게 읽혀요."
  },
  overexplaining: {
    recommendedTone: "short",
    coachNote: "설명이 길어질수록 다시 붙잡힐 수 있어요. 한 문장으로 먼저 끝내세요."
  }
};
```

- [ ] **3단계: 초기 상태와 필드 업데이트에 `blockerType` 추가**

```js
return {
  input: "",
  situationType: SITUATION_OPTIONS[0].value,
  blockerType: BLOCKER_OPTIONS[1].value,
  result: null,
  feedback: null,
  isLoading: false
};
```

- [ ] **4단계: `src/app.js`에서 새 필드를 바인딩하고 요청에 함께 전송**

```js
const blockerSelect = root.querySelector("#blocker-type");

blockerSelect?.addEventListener("change", (event) => {
  state = updateField(state, "blockerType", event.currentTarget.value);
});
```

- [ ] **5단계: 결과 셸을 추천 카드 중심 구조로 재구성**

```js
<section class="coach-panel">
  <h2>추천 시작 문장</h2>
  <p>이럴 때는 이렇게 시작하면 돼요.</p>
  <p class="coach-note">${escapeHtml(result.coachNote)}</p>
  <p class="avoid-phrase">피해야 할 표현: ${escapeHtml(result.avoidPhrase)}</p>
</section>
```

- [ ] **6단계: 추천 카드 강조와 짧은 가이드 카피를 위한 스타일 추가**

실행: `IBAD/app/src/styles.css` 업데이트
예상: 추천 답장이 기본 선택처럼 읽히고, 나머지 두 카드는 분명한 보조 선택지로 보임

- [ ] **7단계: UI 테스트 재실행**

실행: `cd IBAD/app && node --test tests/ui/app.test.js`
예상: PASS

- [ ] **8단계: 막힘 이유 기반 UI 커밋**

```bash
git add IBAD/app/src/domain/options.js IBAD/app/src/domain/coaching.js IBAD/app/src/ui/state.js IBAD/app/src/app.js IBAD/app/src/ui/templates.js IBAD/app/src/styles.css IBAD/app/tests/ui/app.test.js
git commit -m "feat: add ibad blocker-aware coaching shell"
```

## 청크 2: API 계약을 추천 팩으로 확장

### 작업 3: 확장된 스키마와 프롬프트 계약을 테스트로 먼저 고정

**대상 파일:**
- 생성: `IBAD/app/tests/domain/coaching.test.js`
- 수정: `IBAD/app/tests/domain/schema.test.js`
- 수정: `IBAD/app/tests/api/generate-reply.test.js`

- [ ] **1단계: 추천 매핑 회귀 테스트 추가**

```js
assert.equal(BLOCKER_COACHING["tone-anxiety"].recommendedTone, "polite-firm");
assert.match(BLOCKER_COACHING.overexplaining.coachNote, /한 문장/);
```

- [ ] **2단계: 전체 추천 팩 구조를 요구하도록 스키마 테스트 확장**

```js
const result = normalizeReplyResult({
  replyOptions: [...],
  recommendedTone: "polite-firm",
  coachNote: "예의는 유지하되 결론을 먼저 두면 차갑기보다 분명하게 읽혀요.",
  avoidPhrase: "나중에 보자"
});
```

- [ ] **3단계: API 테스트에서 `blockerType`과 새 프롬프트 줄을 검증**

```js
const prompt = buildUserPrompt({
  input: "친구 약속을 거절하고 싶어.",
  situationType: "promise",
  blockerType: "tone-anxiety"
});

assert.match(prompt, /막히는 이유: tone-anxiety/);
assert.match(prompt, /추천 톤을 정할 기준/);
```

- [ ] **4단계: 성공 mock payload에 추천 팩 필드 추가**

```js
{
  replyOptions: [...],
  recommendedTone: "polite-firm",
  coachNote: "예의는 유지하되 결론을 먼저 두면 차갑기보다 분명하게 읽혀요.",
  avoidPhrase: "나중에 보자"
}
```

- [ ] **5단계: 구현 전에 계약 테스트를 실행해 실제로 실패하는지 확인**

실행: `cd IBAD/app && node --test tests/domain/coaching.test.js tests/domain/schema.test.js tests/api/generate-reply.test.js`
예상: 아직 `blockerType`을 받지 않고 추천 팩 메타데이터도 반환하지 않으므로 FAIL

- [ ] **6단계: 계약 우선 테스트 커밋**

```bash
git add IBAD/app/tests/domain/coaching.test.js IBAD/app/tests/domain/schema.test.js IBAD/app/tests/api/generate-reply.test.js
git commit -m "test: lock ibad boundary pack contract"
```

### 작업 4: 추천 팩 스키마, 검증, 프롬프트 구현

**대상 파일:**
- 수정: `IBAD/app/src/utils/validation.js`
- 수정: `IBAD/app/src/api/generate-reply.js`
- 수정: `IBAD/app/src/domain/schema.js`
- 수정: `IBAD/app/api/generate-reply.js`
- 생성: `IBAD/app/src/domain/coaching.js`

- [ ] **1단계: `input`, `situationType`와 함께 `blockerType`도 검증**

```js
if (!SUPPORTED_BLOCKER_VALUES.has(blockerType)) {
  return { ok: false, message: "지원하지 않는 막힘 이유입니다." };
}
```

- [ ] **2단계: 브라우저 클라이언트에서 `blockerType` 전송**

```js
body: JSON.stringify({
  input: payload.input,
  situationType: payload.situationType,
  blockerType: payload.blockerType
})
```

- [ ] **3단계: `normalizeReplyResult()`가 `recommendedTone`, `coachNote`, `avoidPhrase`를 필수로 받도록 확장**

```js
required: ["replyOptions", "recommendedTone", "coachNote", "avoidPhrase"]
```

```js
return {
  replyOptions: normalizedReplyOptions,
  recommendedTone,
  coachNote,
  avoidPhrase
};
```

- [ ] **4단계: 서버 프롬프트에 막힘 이유 맥락과 추천 기준 추가**

```js
"사용자가 막히는 이유에 맞춰 가장 먼저 보여줄 추천 톤을 정한다.",
`막히는 이유: ${payload.blockerType}`,
"recommendedTone은 soft, polite-firm, short 중 하나만 반환한다.",
"coachNote는 사용자에게 보여줄 짧은 편집 메모 한 문장으로 작성한다.",
"avoidPhrase는 다시 붙잡힐 수 있는 표현 하나만 준다."
```

- [ ] **5단계: 기존 unsafe-result 재시도 동작 유지**

실행: 세 답장 모두에 `collectReplySafetyIssues()`를 계속 적용
예상: 열린 여지를 남기는 표현, 과도한 사과, 과한 길이는 여전히 `UNSAFE_RESULT`를 반환

- [ ] **6단계: 계약 중심 테스트 재실행**

실행: `cd IBAD/app && node --test tests/domain/coaching.test.js tests/domain/schema.test.js tests/api/generate-reply.test.js`
예상: PASS

- [ ] **7단계: 추천 팩 구현 커밋**

```bash
git add IBAD/app/src/utils/validation.js IBAD/app/src/api/generate-reply.js IBAD/app/src/domain/schema.js IBAD/app/api/generate-reply.js IBAD/app/src/domain/coaching.js IBAD/app/tests/domain/coaching.test.js IBAD/app/tests/domain/schema.test.js IBAD/app/tests/api/generate-reply.test.js
git commit -m "feat: add ibad boundary pack generation contract"
```

## 청크 3: 제품 문서 정리와 전체 검증

### 작업 5: 제품 문서 동기화와 전체 검증 실행

**대상 파일:**
- 수정: `IBAD/app/README.md`
- 수정: `IBAD/ibeonen-an-dwae-feature-definition.md`

- [ ] **1단계: IBAD README에 막힘 이유 입력과 추천 출력 구조 반영**

```md
- 입력:
  - 받은 메시지
  - 요청 종류 선택: `약속` / `부탁`
  - 막히는 이유 선택

- 출력:
  - 추천 시작 문장 1개
  - 대안 2개
  - coach note
  - 피해야 할 표현 1개
```

- [ ] **2단계: 기능 정의 문서도 새 제품 포지셔닝에 맞게 수정**

```md
`이번엔 안 돼`는 거절문 생성기가 아니라,
답장을 못 보내고 멈춘 사람에게 지금 보낼 시작 문장을 잡아주는 서비스다.
```

- [ ] **3단계: 전체 IBAD 검증 명령 실행**

실행: `cd IBAD/app && npm run verify`
예상: PASS

- [ ] **4단계: 최종 diff 범위 점검**

실행: `git diff --stat`
예상: 이 기능과 직접 관련된 IBAD 파일, 그리고 이 두 개의 기획 문서만 수정됨

- [ ] **5단계: 문서 동기화와 검증 결과 커밋**

```bash
git add IBAD/app/README.md IBAD/ibeonen-an-dwae-feature-definition.md
git commit -m "docs: describe ibad first-reply recommendation flow"
```

- [ ] **6단계: 검증 요약과 함께 인계**

```text
`IBAD/app`은 이제 막힘 이유를 입력받고, 추천 거절문 1개와 대안 2개를 보여주며, 기존 안전 가드레일도 유지한다. `npm run verify`가 통과했다.
```
