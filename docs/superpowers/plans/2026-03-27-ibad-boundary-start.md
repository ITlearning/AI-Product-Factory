# IBAD Boundary Start Pivot Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Pivot `IBAD/app` from a broad rejection-message generator into a minimal "start the reply" tool for users who freeze after receiving a promise/favor message.

**Architecture:** Keep the existing single-page app and Vercel function, but shrink the public input surface to `input + situationType` and simplify the AI result contract to three copy-ready reply cards. Move complexity out of the first screen, remove unused UI controls, and keep the backend focused on fixed output labels and safety checks.

**Tech Stack:** Vanilla JS SPA, Node test runner, Vercel serverless function, OpenAI Responses API

---

## File Structure

- Modify: `IBAD/app/src/ui/templates.js`
  Responsibility: minimal first screen markup, simplified result cards, no heavy guidance panel
- Modify: `IBAD/app/src/app.js`
  Responsibility: bind only the surviving form controls and result actions
- Modify: `IBAD/app/src/ui/state.js`
  Responsibility: client state shape, submit payload, loading/error transitions
- Modify: `IBAD/app/src/domain/options.js`
  Responsibility: keep only supported situation options and fixed result labels if needed
- Modify: `IBAD/app/src/domain/schema.js`
  Responsibility: validate the smaller AI response shape and enforce three distinct reply options
- Modify: `IBAD/app/src/utils/validation.js`
  Responsibility: validate the slimmer request payload
- Modify: `IBAD/app/src/api/generate-reply.js`
  Responsibility: client fetch payload for the new API contract
- Modify: `IBAD/app/api/generate-reply.js`
  Responsibility: new system prompt, user prompt, revision prompt, smaller structured output
- Modify: `IBAD/app/src/styles.css`
  Responsibility: simplify the landing layout and result card styling to match the new product framing
- Modify: `IBAD/app/src/domain/examples.js`
  Responsibility: keep example text aligned with promise/favor-only scope if examples remain internally
- Modify: `IBAD/app/tests/ui/app.test.js`
  Responsibility: lock the simplified shell and result rendering behavior
- Modify: `IBAD/app/tests/domain/schema.test.js`
  Responsibility: lock the reduced AI schema
- Modify: `IBAD/app/tests/api/generate-reply.test.js`
  Responsibility: lock the new request/response contract and prompt content
- Modify: `IBAD/app/README.md`
  Responsibility: document the new positioning, input model, and runtime behavior

## Chunk 1: Shrink the Frontend Surface

### Task 1: Lock the simplified shell in UI tests

**Files:**
- Modify: `IBAD/app/tests/ui/app.test.js`

- [ ] **Step 1: Write the failing UI assertions for the new MVP shell**

```js
test("renders the simplified IBAD shell", () => {
  const markup = renderAppMarkup(createInitialState());

  assert.match(markup, /답장을 못 보내고 있다면, 여기서 시작하세요/);
  assert.match(markup, /받은 메시지를 붙여넣어 주세요/);
  assert.match(markup, /약속/);
  assert.match(markup, /부탁/);
  assert.doesNotMatch(markup, /관계 타입/);
  assert.doesNotMatch(markup, /거절 강도/);
});
```

- [ ] **Step 2: Run the UI test file to verify it fails against the old shell**

Run: `cd IBAD/app && node --test tests/ui/app.test.js`
Expected: FAIL because the current markup still renders relationship/strength controls and old hero copy

- [ ] **Step 3: Update the existing test data for the new result shape**

```js
const result = {
  replyOptions: [
    { text: "오늘은 좀 어려울 것 같아.", toneLabel: "부드럽게", whyItWorks: "미안함은 남기고 결론은 분명하게 말한다." },
    { text: "이번엔 어려워. 고마운데 패스할게.", toneLabel: "예의 있게 확실하게", whyItWorks: "예의는 지키면서 재요청 여지를 줄인다." },
    { text: "이번엔 어려워.", toneLabel: "짧게 끝내기", whyItWorks: "짧게 마무리해 왕복을 줄인다." }
  ]
};
```

- [ ] **Step 4: Add assertions that the old guidance panel is gone**

```js
assert.doesNotMatch(markup, /피해야 할 표현/);
assert.doesNotMatch(markup, /여지 남김 여부/);
assert.match(markup, /복사/);
```

- [ ] **Step 5: Run the UI test file again and make sure it still fails only on implementation gaps**

Run: `cd IBAD/app && node --test tests/ui/app.test.js`
Expected: FAIL, but only because the application code still uses the old state/markup

- [ ] **Step 6: Commit the test-first shell expectations**

```bash
git add IBAD/app/tests/ui/app.test.js
git commit -m "test: lock ibad minimal reply-start shell"
```

### Task 2: Implement the minimal first screen and result cards

**Files:**
- Modify: `IBAD/app/src/ui/templates.js`
- Modify: `IBAD/app/src/app.js`
- Modify: `IBAD/app/src/ui/state.js`
- Modify: `IBAD/app/src/domain/options.js`
- Modify: `IBAD/app/src/domain/examples.js`
- Modify: `IBAD/app/src/styles.css`

- [ ] **Step 1: Remove dead state fields from the initial client state**

```js
export function createInitialState() {
  return {
    input: "",
    situationType: SITUATION_OPTIONS[0].value,
    result: null,
    feedback: null,
    isLoading: false
  };
}
```

- [ ] **Step 2: Keep only the `promise` / `favor` option list in `options.js`**

```js
export const SITUATION_OPTIONS = [
  { value: "promise", label: "약속" },
  { value: "favor", label: "부탁" }
];
```

- [ ] **Step 3: Simplify the rendered form**

```js
<form class="composer" data-role="composer">
  <p class="intro-copy">답장을 못 보내고 있다면, 여기서 시작하세요</p>
  <textarea ... placeholder="받은 메시지를 붙여넣어 주세요"></textarea>
  ${renderSelect("situation-type", "이건 어떤 요청인가요?", SITUATION_OPTIONS, state.situationType)}
  <button class="button button-primary" type="submit">답장 만들기</button>
</form>
```

- [ ] **Step 4: Remove old bindings from `app.js`**

```js
const situationSelect = root.querySelector("#situation-type");

situationSelect?.addEventListener("change", (event) => {
  state = updateField(state, "situationType", event.currentTarget.value);
});
```

- [ ] **Step 5: Replace the heavy results shell with three compact cards**

```js
<article class="reply-card">
  <span class="reply-label">${escapeHtml(option.toneLabel)}</span>
  <p class="reply-text">${escapeHtml(option.text)}</p>
  <p class="reply-why">${escapeHtml(option.whyItWorks)}</p>
  <button ...>복사하기</button>
</article>
```

- [ ] **Step 6: Simplify the CSS to support the new product posture**

Run: update `IBAD/app/src/styles.css`
Expected: first screen becomes a small, focused input surface instead of a dashboard-like layout

- [ ] **Step 7: Run the UI test file and make sure it passes**

Run: `cd IBAD/app && node --test tests/ui/app.test.js`
Expected: PASS

- [ ] **Step 8: Commit the frontend simplification**

```bash
git add IBAD/app/src/ui/templates.js IBAD/app/src/app.js IBAD/app/src/ui/state.js IBAD/app/src/domain/options.js IBAD/app/src/domain/examples.js IBAD/app/src/styles.css IBAD/app/tests/ui/app.test.js
git commit -m "feat: simplify ibad to reply-start flow"
```

## Chunk 2: Shrink the Backend Contract

### Task 3: Lock the smaller AI schema and request payload

**Files:**
- Modify: `IBAD/app/tests/domain/schema.test.js`
- Modify: `IBAD/app/tests/api/generate-reply.test.js`

- [ ] **Step 1: Update the schema test to require only `replyOptions`**

```js
const result = normalizeReplyResult({
  replyOptions: [
    { text: "오늘은 좀 어려울 것 같아.", toneLabel: "부드럽게", whyItWorks: "부담을 낮춘다." },
    { text: "이번엔 어려워. 고마운데 패스할게.", toneLabel: "예의 있게 확실하게", whyItWorks: "균형이 좋다." },
    { text: "이번엔 어려워.", toneLabel: "짧게 끝내기", whyItWorks: "짧게 끝낸다." }
  ]
});
```

- [ ] **Step 2: Update API tests to send only the new payload**

```js
fakeRequest({
  input: "친구가 오늘 저녁에 보자고 했는데 쉬고 싶다.",
  situationType: "promise"
})
```

- [ ] **Step 3: Update prompt assertions to the new framing**

```js
assert.match(prompt, /상대 메시지를 받고도 답장을 못 보내는 사람/);
assert.match(prompt, /상황 타입: promise/);
assert.doesNotMatch(prompt, /관계 타입/);
```

- [ ] **Step 4: Run the contract-focused tests to verify they fail**

Run: `cd IBAD/app && node --test tests/domain/schema.test.js tests/api/generate-reply.test.js`
Expected: FAIL because the current schema and prompts still require the old fields

- [ ] **Step 5: Commit the contract-first test changes**

```bash
git add IBAD/app/tests/domain/schema.test.js IBAD/app/tests/api/generate-reply.test.js
git commit -m "test: lock ibad reply-start api contract"
```

### Task 4: Implement the new API contract and prompt

**Files:**
- Modify: `IBAD/app/src/domain/schema.js`
- Modify: `IBAD/app/src/utils/validation.js`
- Modify: `IBAD/app/src/api/generate-reply.js`
- Modify: `IBAD/app/api/generate-reply.js`

- [ ] **Step 1: Reduce `normalizeReplyResult` to the fields the UI actually uses**

```js
required: ["replyOptions"]
```

```js
return {
  replyOptions: normalizedReplyOptions
};
```

- [ ] **Step 2: Validate only `input` and `situationType` on the request boundary**

```js
if (!SUPPORTED_SITUATION_VALUES.has(situationType)) {
  return { ok: false, message: "지원하지 않는 상황 타입입니다." };
}

return {
  ok: true,
  value: {
    input: inputCheck.normalized,
    situationType
  }
};
```

- [ ] **Step 3: Update the browser API client payload**

```js
body: JSON.stringify({
  input: payload.input,
  situationType: payload.situationType
})
```

- [ ] **Step 4: Rewrite the server prompt around the reply-start use case**

```js
const SYSTEM_PROMPT = [
  "당신은 상대 메시지를 받고도 답장을 못 보내는 사람을 돕는 한국어 어시스턴트다.",
  "약속 거절 또는 부탁 거절 상황만 다룬다.",
  "반드시 바로 보낼 수 있는 답장 3개를 만든다.",
  "순서는 부드럽게, 예의 있게 확실하게, 짧게 끝내기다.",
  "각 답장은 짧고, 변명은 줄이고, 다시 잡힐 표현은 피한다.",
  "반드시 지정된 JSON 스키마만 반환한다."
].join(" ");
```

- [ ] **Step 5: Keep the safety retry loop, but align it with the new output labels**

Run: update `IBAD/app/api/generate-reply.js`
Expected: unsafe open-door phrasing still retries once, but no code references removed frontend fields

- [ ] **Step 6: Run the contract-focused tests**

Run: `cd IBAD/app && node --test tests/domain/schema.test.js tests/api/generate-reply.test.js`
Expected: PASS

- [ ] **Step 7: Commit the backend contract pivot**

```bash
git add IBAD/app/src/domain/schema.js IBAD/app/src/utils/validation.js IBAD/app/src/api/generate-reply.js IBAD/app/api/generate-reply.js IBAD/app/tests/domain/schema.test.js IBAD/app/tests/api/generate-reply.test.js
git commit -m "feat: pivot ibad api to reply-start contract"
```

## Chunk 3: Docs and Verification

### Task 5: Update docs and run full verification

**Files:**
- Modify: `IBAD/app/README.md`
- Modify: `docs/plans/2026-03-27-ibad-boundary-start-design.md`
- Modify: `docs/superpowers/plans/2026-03-27-ibad-boundary-start.md`

- [ ] **Step 1: Update the runtime README to match the new product**

```md
- 첫 화면 입력: 받은 메시지 + 약속/부탁 선택
- 출력: 바로 복사할 수 있는 답장 3개
- 현재 범위: 약속/부탁 요청 거절
```

- [ ] **Step 2: Run the full project verification**

Run: `cd IBAD/app && npm run verify`
Expected: PASS with lint, all node tests, and build succeeding

- [ ] **Step 3: Sanity-check the production bundle output**

Run: `cd IBAD/app && node --test tests/ui/app.test.js`
Expected: PASS after the build, confirming no UI regressions slipped through

- [ ] **Step 4: Commit the docs and verification pass**

```bash
git add IBAD/app/README.md docs/plans/2026-03-27-ibad-boundary-start-design.md docs/superpowers/plans/2026-03-27-ibad-boundary-start.md
git commit -m "docs: capture ibad reply-start pivot"
```

## Notes for Executors

- Do not expand scope to romantic-interest / repeated-contact handling in this pass.
- Prefer deleting unused controls over hiding them.
- Do not preserve old guidance fields in the API contract unless a live UI element still reads them.
- Keep all verification local to `IBAD/app`; do not touch `Translate-Developer`.
- If `dist/` changes after `npm run build`, include only the generated files that the existing build process updates.
