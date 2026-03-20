# Translate-Developer OpenAI Integration Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the MVP’s primary translation path with an OpenAI-backed Vercel serverless flow while preserving the current local rule engine as an automatic fallback.

**Architecture:** Keep the current static single-page UI, add a Vercel serverless `/api/translate` endpoint, call OpenAI `Responses API` with `gpt-4.1-mini` and structured JSON output, and fall back to the local rule engine if the API path fails.

**Tech Stack:** Vercel serverless functions, JavaScript ESM frontend, OpenAI Responses API, existing local rule engine, Node built-in tests

---

## File Structure

Planned project area: `Translate-Developer/`

- Create: `Translate-Developer/api/translate.js`
- Create: `Translate-Developer/src/api/translate.js`
- Create: `Translate-Developer/src/engine/schema.js`
- Create: `Translate-Developer/src/engine/fallback-engine.js`
- Create: `Translate-Developer/src/config.js`
- Create: `Translate-Developer/vercel.json`
- Create: `Translate-Developer/tests/api/translate.test.js`
- Modify: `Translate-Developer/package.json`
- Modify: `Translate-Developer/src/app.js`
- Modify: `Translate-Developer/src/ui/state.js`
- Modify: `Translate-Developer/src/ui/templates.js`
- Modify: `Translate-Developer/src/styles.css`
- Modify: `Translate-Developer/src/engine/index.js`
- Modify: `Translate-Developer/src/engine/rule-engine.js`
- Modify: `Translate-Developer/plan.md`

## Chunk 1: Shared Translation Contract

### Task 1: Extract shared schema helpers

**Files:**
- Create: `Translate-Developer/src/engine/schema.js`
- Modify: `Translate-Developer/src/engine/index.js`
- Test: `Translate-Developer/tests/api/translate.test.js`

- [ ] **Step 1: Write the failing schema validation test**

```js
test("accepts a valid AI translation payload", () => {
  assert.equal(isValidTranslationResult(validPayload), true);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm test -- tests/api/translate.test.js`
Expected: FAIL because schema helpers do not exist

- [ ] **Step 3: Implement the shared schema helpers**

Include:
- translation result validator
- term pair validator
- normalization helper for trimming strings

- [ ] **Step 4: Run test to verify it passes**

Run: `npm test -- tests/api/translate.test.js`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Translate-Developer/src/engine/schema.js Translate-Developer/src/engine/index.js Translate-Developer/tests/api/translate.test.js
git commit -m "feat: add shared translation schema validation"
```

## Chunk 2: Vercel API Path

### Task 2: Add the serverless translate endpoint

**Files:**
- Create: `Translate-Developer/api/translate.js`
- Create: `Translate-Developer/src/config.js`
- Create: `Translate-Developer/vercel.json`
- Modify: `Translate-Developer/package.json`
- Test: `Translate-Developer/tests/api/translate.test.js`

- [ ] **Step 1: Write the failing API route tests**

```js
test("returns 400 for empty input", async () => {
  const response = await handleTranslateRequest(fakeRequest(""));
  assert.equal(response.status, 400);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm test -- tests/api/translate.test.js`
Expected: FAIL because the API route does not exist

- [ ] **Step 3: Implement the Vercel route**

Include:
- request JSON parsing
- empty-input rejection
- environment-driven model selection
- safe error responses

- [ ] **Step 4: Run test to verify it passes**

Run: `npm test -- tests/api/translate.test.js`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Translate-Developer/api/translate.js Translate-Developer/src/config.js Translate-Developer/vercel.json Translate-Developer/package.json Translate-Developer/tests/api/translate.test.js
git commit -m "feat: add vercel translate api endpoint"
```

### Task 3: Connect OpenAI Responses API with structured output

**Files:**
- Modify: `Translate-Developer/api/translate.js`
- Modify: `Translate-Developer/src/engine/schema.js`
- Test: `Translate-Developer/tests/api/translate.test.js`

- [ ] **Step 1: Write the failing AI success-path test**

```js
test("returns normalized structured output from the OpenAI response", async () => {
  mockOpenAIResponse(validPayload);
  const response = await handleTranslateRequest(fakeRequest("로그인 서버 에러입니다."));
  assert.equal(response.status, 200);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm test -- tests/api/translate.test.js`
Expected: FAIL because OpenAI mapping is not implemented

- [ ] **Step 3: Implement the OpenAI call**

Include:
- `Responses API` request
- `gpt-4.1-mini` default model
- structured JSON schema request
- response normalization
- validation failure handling

- [ ] **Step 4: Run test to verify it passes**

Run: `npm test -- tests/api/translate.test.js`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Translate-Developer/api/translate.js Translate-Developer/src/engine/schema.js Translate-Developer/tests/api/translate.test.js
git commit -m "feat: integrate openai structured translations"
```

## Chunk 3: Frontend AI-First Flow

### Task 4: Add client API wrapper and fallback engine wiring

**Files:**
- Create: `Translate-Developer/src/api/translate.js`
- Create: `Translate-Developer/src/engine/fallback-engine.js`
- Modify: `Translate-Developer/src/engine/index.js`
- Modify: `Translate-Developer/src/ui/state.js`
- Test: `Translate-Developer/tests/ui/app.test.js`

- [ ] **Step 1: Write the failing fallback-flow UI test**

```js
test("uses fallback mode when the API request fails", async () => {
  mockFetchFailure();
  const state = await submitTranslationAsync(seedState);
  assert.equal(state.engineSource, "fallback");
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm test -- tests/ui/app.test.js`
Expected: FAIL because async API translation flow does not exist

- [ ] **Step 3: Implement the client translation path**

Include:
- browser fetch wrapper
- AI success return shape
- fallback to local rule engine
- state fields for source and loading

- [ ] **Step 4: Run test to verify it passes**

Run: `npm test -- tests/ui/app.test.js`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Translate-Developer/src/api/translate.js Translate-Developer/src/engine/fallback-engine.js Translate-Developer/src/engine/index.js Translate-Developer/src/ui/state.js Translate-Developer/tests/ui/app.test.js
git commit -m "feat: add ai-first translation flow with fallback"
```

### Task 5: Update UI for loading, source badge, and failure-safe messaging

**Files:**
- Modify: `Translate-Developer/src/app.js`
- Modify: `Translate-Developer/src/ui/templates.js`
- Modify: `Translate-Developer/src/styles.css`
- Modify: `Translate-Developer/tests/ui/app.test.js`

- [ ] **Step 1: Write the failing loading and source-badge test**

```js
test("renders AI mode badge on successful translation", async () => {
  mockFetchSuccess(validPayload);
  const markup = await renderAfterSubmit();
  assert.match(markup, /AI 번역/);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm test -- tests/ui/app.test.js`
Expected: FAIL because source badge and loading state do not exist

- [ ] **Step 3: Implement the UI updates**

Include:
- loading state on submit button
- `AI 번역` vs `기본 번역 모드` badge
- fallback-safe user messaging
- preserve result visibility and current layout hierarchy

- [ ] **Step 4: Run test to verify it passes**

Run: `npm test -- tests/ui/app.test.js`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Translate-Developer/src/app.js Translate-Developer/src/ui/templates.js Translate-Developer/src/styles.css Translate-Developer/tests/ui/app.test.js
git commit -m "feat: show ai translation state in ui"
```

## Chunk 4: Delivery And Documentation

### Task 6: Finalize environment docs and project notes

**Files:**
- Modify: `Translate-Developer/plan.md`
- Modify: `Translate-Developer/package.json`

- [ ] **Step 1: Write the failing delivery checklist in the project note**

```md
- [ ] local fallback works
- [ ] ai success path works
- [ ] missing API key is handled safely
- [ ] vercel deployment env documented
```

- [ ] **Step 2: Run verification before final doc update**

Run:
- `npm test`
- `npm run build`

Expected:
- PASS for all tests
- PASS for static build

- [ ] **Step 3: Update project notes**

Include:
- required env vars
- Vercel deployment assumptions
- fallback behavior
- next step note for streaming support

- [ ] **Step 4: Run final verification**

Run:
- `npm run lint`
- `npm test`
- `npm run build`

Expected:
- PASS

- [ ] **Step 5: Commit**

```bash
git add Translate-Developer/plan.md Translate-Developer/package.json
git commit -m "docs: document ai translation deployment"
```

## Execution Notes

- Keep the translation schema stable across AI and fallback paths.
- Do not expose `OPENAI_API_KEY` to the browser.
- Treat malformed AI output as a normal fallback case, not a fatal product error.
- Preserve the current deterministic rule engine as a resilience layer.
- If the OpenAI SDK adds avoidable weight, prefer direct `fetch` from the serverless function to the OpenAI API.

Plan complete and saved to `docs/superpowers/plans/2026-03-20-translate-developer-openai-plan.md`. Ready to execute?
