# IBAD Boundary Coach Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Evolve `IBAD/app` from a flat three-card reply generator into a blocker-aware boundary coach that recommends one send-now reply, keeps two controlled alternatives, and adds compact coaching context.

**Architecture:** Keep the existing single-page app and Vercel function, but add one new request field, `blockerType`, and a thin deterministic coaching layer that maps blocker choice to recommended tone and UI emphasis. The OpenAI response contract grows from `replyOptions` only to a small boundary pack with `replyOptions`, `recommendedTone`, `coachNote`, and `avoidPhrase`, while the existing safety checks continue to gate unsafe replies.

**Tech Stack:** Vanilla JS SPA, Node test runner, Vercel serverless function, OpenAI Responses API

---

## File Structure

- Modify: `IBAD/app/src/domain/options.js`
  Responsibility: add blocker options and shared enums used by UI, validation, and prompt building
- Create: `IBAD/app/src/domain/coaching.js`
  Responsibility: deterministic mapping from blocker type to recommended tone and coach copy
- Modify: `IBAD/app/src/ui/state.js`
  Responsibility: carry `blockerType`, submit the richer payload, and preserve the new result contract
- Modify: `IBAD/app/src/app.js`
  Responsibility: bind blocker field changes and keep render flow intact
- Modify: `IBAD/app/src/ui/templates.js`
  Responsibility: render blocker selector, recommended result card, coaching note, and avoid-phrase callout
- Modify: `IBAD/app/src/styles.css`
  Responsibility: add blocker chips/cards, recommended-card emphasis, and compact coaching panel styles
- Modify: `IBAD/app/src/utils/validation.js`
  Responsibility: validate `blockerType` at request boundaries
- Modify: `IBAD/app/src/api/generate-reply.js`
  Responsibility: send `blockerType` to the API and accept the new boundary-pack result shape
- Modify: `IBAD/app/src/domain/schema.js`
  Responsibility: normalize `recommendedTone`, `coachNote`, and `avoidPhrase` in addition to reply options
- Modify: `IBAD/app/api/generate-reply.js`
  Responsibility: include blocker context in prompts and request the richer structured result
- Modify: `IBAD/app/tests/ui/app.test.js`
  Responsibility: lock the blocker-aware shell and recommended-result rendering
- Create: `IBAD/app/tests/domain/coaching.test.js`
  Responsibility: lock blocker-to-recommendation mapping
- Modify: `IBAD/app/tests/domain/schema.test.js`
  Responsibility: lock the expanded boundary-pack schema
- Modify: `IBAD/app/tests/api/generate-reply.test.js`
  Responsibility: lock prompt content, request payload, and richer normalized result
- Modify: `IBAD/app/README.md`
  Responsibility: document the blocker-aware product framing and result structure
- Modify: `IBAD/ibeonen-an-dwae-feature-definition.md`
  Responsibility: sync the feature-definition doc with the new product position

## Chunk 1: Add The Blocker Input And Recommended Result Shell

### Task 1: Lock the blocker-aware shell in tests

**Files:**
- Modify: `IBAD/app/tests/ui/app.test.js`

- [ ] **Step 1: Add failing shell assertions for the new blocker question**

```js
assert.match(markup, /지금 막히는 이유가 뭐예요/);
assert.match(markup, /미안해서 시작이 안 돼요/);
assert.match(markup, /너무 차갑게 보일까 걱정돼요/);
assert.match(markup, /말이 길어질까 봐 걱정돼요/);
```

- [ ] **Step 2: Add failing result assertions for the recommended boundary pack**

```js
assert.match(markup, /추천 시작 문장/);
assert.match(markup, /피해야 할 표현/);
assert.match(markup, /이럴 때는 이렇게 시작하면 돼요/);
```

- [ ] **Step 3: Keep a regression assertion that the app still does not reintroduce old heavy inputs**

```js
assert.doesNotMatch(markup, /관계 타입/);
assert.doesNotMatch(markup, /거절 강도/);
```

- [ ] **Step 4: Run the UI test file to verify it fails for the right reason**

Run: `cd IBAD/app && node --test tests/ui/app.test.js`
Expected: FAIL because the current markup has no blocker selector or recommended-result shell

- [ ] **Step 5: Commit the shell expectation changes**

```bash
git add IBAD/app/tests/ui/app.test.js
git commit -m "test: lock ibad blocker-aware shell"
```

### Task 2: Implement the blocker selector and recommended result layout

**Files:**
- Modify: `IBAD/app/src/domain/options.js`
- Create: `IBAD/app/src/domain/coaching.js`
- Modify: `IBAD/app/src/ui/state.js`
- Modify: `IBAD/app/src/app.js`
- Modify: `IBAD/app/src/ui/templates.js`
- Modify: `IBAD/app/src/styles.css`

- [ ] **Step 1: Add the shared blocker option list**

```js
export const BLOCKER_OPTIONS = [
  { value: "guilt", label: "미안해서 시작이 안 돼요" },
  { value: "tone-anxiety", label: "너무 차갑게 보일까 걱정돼요" },
  { value: "overexplaining", label: "말이 길어질까 봐 걱정돼요" }
];
```

- [ ] **Step 2: Add a focused coaching map file instead of scattering strings through the UI**

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

- [ ] **Step 3: Extend initial state and field updates with `blockerType`**

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

- [ ] **Step 4: Bind the new field in `src/app.js` and submit it with the request**

```js
const blockerSelect = root.querySelector("#blocker-type");

blockerSelect?.addEventListener("change", (event) => {
  state = updateField(state, "blockerType", event.currentTarget.value);
});
```

- [ ] **Step 5: Rework the result shell to emphasize one recommended card**

```js
<section class="coach-panel">
  <h2>추천 시작 문장</h2>
  <p>이럴 때는 이렇게 시작하면 돼요.</p>
  <p class="coach-note">${escapeHtml(result.coachNote)}</p>
  <p class="avoid-phrase">피해야 할 표현: ${escapeHtml(result.avoidPhrase)}</p>
</section>
```

- [ ] **Step 6: Add visual emphasis for the recommended card and compact coaching copy**

Run: update `IBAD/app/src/styles.css`
Expected: the recommended reply reads as the default choice, while the other two remain visibly secondary

- [ ] **Step 7: Run the UI tests again**

Run: `cd IBAD/app && node --test tests/ui/app.test.js`
Expected: PASS

- [ ] **Step 8: Commit the blocker-aware UI**

```bash
git add IBAD/app/src/domain/options.js IBAD/app/src/domain/coaching.js IBAD/app/src/ui/state.js IBAD/app/src/app.js IBAD/app/src/ui/templates.js IBAD/app/src/styles.css IBAD/app/tests/ui/app.test.js
git commit -m "feat: add ibad blocker-aware coaching shell"
```

## Chunk 2: Expand The API Contract Into A Boundary Pack

### Task 3: Lock the richer schema and prompt contract in tests

**Files:**
- Create: `IBAD/app/tests/domain/coaching.test.js`
- Modify: `IBAD/app/tests/domain/schema.test.js`
- Modify: `IBAD/app/tests/api/generate-reply.test.js`

- [ ] **Step 1: Add a coaching-map regression test**

```js
assert.equal(BLOCKER_COACHING["tone-anxiety"].recommendedTone, "polite-firm");
assert.match(BLOCKER_COACHING.overexplaining.coachNote, /한 문장/);
```

- [ ] **Step 2: Update schema tests to require the full boundary-pack shape**

```js
const result = normalizeReplyResult({
  replyOptions: [...],
  recommendedTone: "polite-firm",
  coachNote: "예의는 유지하되 결론을 먼저 두면 차갑기보다 분명하게 읽혀요.",
  avoidPhrase: "나중에 보자"
});
```

- [ ] **Step 3: Update API tests to send `blockerType` and assert the new prompt lines**

```js
const prompt = buildUserPrompt({
  input: "친구 약속을 거절하고 싶어.",
  situationType: "promise",
  blockerType: "tone-anxiety"
});

assert.match(prompt, /막히는 이유: tone-anxiety/);
assert.match(prompt, /추천 톤을 정할 기준/);
```

- [ ] **Step 4: Update the successful mock payload to include the boundary-pack fields**

```js
{
  replyOptions: [...],
  recommendedTone: "polite-firm",
  coachNote: "예의는 유지하되 결론을 먼저 두면 차갑기보다 분명하게 읽혀요.",
  avoidPhrase: "나중에 보자"
}
```

- [ ] **Step 5: Run contract-focused tests to confirm they fail before implementation**

Run: `cd IBAD/app && node --test tests/domain/coaching.test.js tests/domain/schema.test.js tests/api/generate-reply.test.js`
Expected: FAIL because the app does not yet accept `blockerType` or return boundary-pack metadata

- [ ] **Step 6: Commit the contract-first test changes**

```bash
git add IBAD/app/tests/domain/coaching.test.js IBAD/app/tests/domain/schema.test.js IBAD/app/tests/api/generate-reply.test.js
git commit -m "test: lock ibad boundary pack contract"
```

### Task 4: Implement the boundary-pack schema, validation, and prompt changes

**Files:**
- Modify: `IBAD/app/src/utils/validation.js`
- Modify: `IBAD/app/src/api/generate-reply.js`
- Modify: `IBAD/app/src/domain/schema.js`
- Modify: `IBAD/app/api/generate-reply.js`
- Create: `IBAD/app/src/domain/coaching.js`

- [ ] **Step 1: Validate `blockerType` alongside `input` and `situationType`**

```js
if (!SUPPORTED_BLOCKER_VALUES.has(blockerType)) {
  return { ok: false, message: "지원하지 않는 막힘 이유입니다." };
}
```

- [ ] **Step 2: Send `blockerType` from the browser client**

```js
body: JSON.stringify({
  input: payload.input,
  situationType: payload.situationType,
  blockerType: payload.blockerType
})
```

- [ ] **Step 3: Expand `normalizeReplyResult()` to require `recommendedTone`, `coachNote`, and `avoidPhrase`**

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

- [ ] **Step 4: Include blocker context and recommendation instructions in the server prompt**

```js
"사용자가 막히는 이유에 맞춰 가장 먼저 보여줄 추천 톤을 정한다.",
`막히는 이유: ${payload.blockerType}`,
"recommendedTone은 soft, polite-firm, short 중 하나만 반환한다.",
"coachNote는 사용자에게 보여줄 짧은 편집 메모 한 문장으로 작성한다.",
"avoidPhrase는 다시 붙잡힐 수 있는 표현 하나만 준다."
```

- [ ] **Step 5: Preserve the existing unsafe-result retry behavior**

Run: keep `collectReplySafetyIssues()` on all three reply options
Expected: open-door phrases, over-apology, and excessive length still return `UNSAFE_RESULT`

- [ ] **Step 6: Run the contract-focused tests again**

Run: `cd IBAD/app && node --test tests/domain/coaching.test.js tests/domain/schema.test.js tests/api/generate-reply.test.js`
Expected: PASS

- [ ] **Step 7: Commit the boundary-pack implementation**

```bash
git add IBAD/app/src/utils/validation.js IBAD/app/src/api/generate-reply.js IBAD/app/src/domain/schema.js IBAD/app/api/generate-reply.js IBAD/app/src/domain/coaching.js IBAD/app/tests/domain/coaching.test.js IBAD/app/tests/domain/schema.test.js IBAD/app/tests/api/generate-reply.test.js
git commit -m "feat: add ibad boundary pack generation contract"
```

## Chunk 3: Finish Product Docs And End-To-End Verification

### Task 5: Sync docs and run full verification

**Files:**
- Modify: `IBAD/app/README.md`
- Modify: `IBAD/ibeonen-an-dwae-feature-definition.md`

- [ ] **Step 1: Update the IBAD README to describe the blocker-aware input and recommended output**

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

- [ ] **Step 2: Update the feature-definition doc so product positioning matches the app**

```md
`이번엔 안 돼`는 거절문 생성기가 아니라,
답장을 못 보내고 멈춘 사람에게 지금 보낼 시작 문장을 잡아주는 서비스다.
```

- [ ] **Step 3: Run the full IBAD verification command**

Run: `cd IBAD/app && npm run verify`
Expected: PASS

- [ ] **Step 4: Inspect the final diff for scope discipline**

Run: `git diff --stat`
Expected: only IBAD files and the two planning/docs artifacts touched for this feature

- [ ] **Step 5: Commit the docs sync and verification pass**

```bash
git add IBAD/app/README.md IBAD/ibeonen-an-dwae-feature-definition.md
git commit -m "docs: describe ibad boundary coach flow"
```

- [ ] **Step 6: Hand off with a concise validation summary**

```text
`IBAD/app` now captures blocker context, highlights one recommended boundary start, keeps two alternatives, and preserves the existing safety guardrails. `npm run verify` passed.
```
