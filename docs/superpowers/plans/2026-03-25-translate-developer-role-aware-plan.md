# Translate-Developer Role-Aware PM Flow Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rework Translate-Developer into a role-aware explainer that defaults to PM/planner use, asks only for audience selection, rewrites the whole message in easy Korean, explains technical terms, reports only evidence-backed impact, and politely calls out what still needs more context.

**Architecture:** Keep the current single-page app and `/api/translate` flow, but redesign the translation contract around four stable blocks, add audience state and context-rich input guidance on the frontend, and split the server prompt into shared rules plus audience presets. Update the fallback rule engine to emit the same no-guess contract so the UI behaves consistently in AI and fallback modes.

**Tech Stack:** JavaScript ESM frontend, Vercel serverless function, OpenAI Responses API with structured outputs, existing local rule engine, Node built-in tests

---

## File Structure

Planned project area: `Translate-Developer/`

- Create: `Translate-Developer/src/ai/prompt.js`
- Create: `Translate-Developer/src/data/audiences.js`
- Modify: `Translate-Developer/api/translate.js`
- Modify: `Translate-Developer/src/api/translate.js`
- Modify: `Translate-Developer/src/app.js`
- Modify: `Translate-Developer/src/config.js`
- Modify: `Translate-Developer/src/data/examples.js`
- Modify: `Translate-Developer/src/engine/fallback-engine.js`
- Modify: `Translate-Developer/src/engine/index.js`
- Modify: `Translate-Developer/src/engine/rule-engine.js`
- Modify: `Translate-Developer/src/engine/schema.js`
- Modify: `Translate-Developer/src/engine/types.js`
- Modify: `Translate-Developer/src/styles.css`
- Modify: `Translate-Developer/src/ui/state.js`
- Modify: `Translate-Developer/src/ui/templates.js`
- Modify: `Translate-Developer/tests/api/translate.test.js`
- Modify: `Translate-Developer/tests/engine/rule-engine.test.js`
- Modify: `Translate-Developer/tests/ui/app.test.js`

## Chunk 1: Redesign the Translation Contract

### Task 1: Replace the old summary/action contract with the approved four-block contract

**Files:**
- Modify: `Translate-Developer/src/engine/types.js`
- Modify: `Translate-Developer/src/engine/schema.js`
- Modify: `Translate-Developer/src/engine/index.js`
- Test: `Translate-Developer/tests/api/translate.test.js`
- Test: `Translate-Developer/tests/engine/rule-engine.test.js`

- [ ] **Step 1: Write the failing contract tests**

```js
test("accepts a valid role-aware translation payload", () => {
  assert.equal(
    isValidTranslationResult({
      rewrittenMessage: "쉽게 풀어쓴 본문",
      confirmedImpact: "입력에 나온 영향만 정리한 문장",
      needsMoreContext: "더 알려주면 정확해지는 부분",
      termExplanations: [{ term: "타임아웃", explanation: "응답이 너무 늦어서 요청이 멈춘 상태" }]
    }),
    true
  );
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd Translate-Developer && node --test tests/api/translate.test.js tests/engine/rule-engine.test.js`
Expected: FAIL because the old schema still expects `summary`, `easyExplanation`, `importantNow`, `actionForReader`, and `termPairs`

- [ ] **Step 3: Implement the new shared contract**

Include:
- updated `TranslationResult` typedef
- renamed schema fields
- validator and normalization logic for `termExplanations`
- exports kept stable through `src/engine/index.js`

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd Translate-Developer && node --test tests/api/translate.test.js tests/engine/rule-engine.test.js`
Expected: PASS for the schema-level assertions

- [ ] **Step 5: Commit**

```bash
git add Translate-Developer/src/engine/types.js Translate-Developer/src/engine/schema.js Translate-Developer/src/engine/index.js Translate-Developer/tests/api/translate.test.js Translate-Developer/tests/engine/rule-engine.test.js
git commit -m "feat: redefine translate developer output contract"
```

### Task 2: Update the fallback rule engine to stay conservative and emit the new fields

**Files:**
- Modify: `Translate-Developer/src/engine/rule-engine.js`
- Modify: `Translate-Developer/src/engine/fallback-engine.js`
- Test: `Translate-Developer/tests/engine/rule-engine.test.js`

- [ ] **Step 1: Write the failing fallback-behavior tests**

```js
test("uses a friendly unknowns block instead of guessing", () => {
  const result = translateWithRules("배포 후 결제 API에서 타임아웃이 반복돼서 확인 중입니다.");
  assert.match(result.needsMoreContext, /이 대화만으로는|앞뒤 맥락/);
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd Translate-Developer && node --test tests/engine/rule-engine.test.js`
Expected: FAIL because the fallback engine does not yet return `needsMoreContext`

- [ ] **Step 3: Implement the minimal fallback rewrite**

Include:
- friendly `rewrittenMessage`
- `termExplanations` generated from current rule helpers
- `confirmedImpact` only when the input provides evidence
- `needsMoreContext` that politely states missing context instead of guessing

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd Translate-Developer && node --test tests/engine/rule-engine.test.js`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Translate-Developer/src/engine/rule-engine.js Translate-Developer/src/engine/fallback-engine.js Translate-Developer/tests/engine/rule-engine.test.js
git commit -m "feat: align fallback engine with no-guess contract"
```

## Chunk 2: Add Audience Selection and New Result Layout

### Task 3: Add audience metadata and state support

**Files:**
- Create: `Translate-Developer/src/data/audiences.js`
- Modify: `Translate-Developer/src/ui/state.js`
- Modify: `Translate-Developer/src/app.js`
- Test: `Translate-Developer/tests/ui/app.test.js`

- [ ] **Step 1: Write the failing state and rendering tests**

```js
test("defaults the selected audience to PM/기획자", () => {
  const state = createInitialState();
  assert.equal(state.audience, "pm-planner");
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd Translate-Developer && node --test tests/ui/app.test.js`
Expected: FAIL because app state does not track audience yet

- [ ] **Step 3: Implement audience state and metadata**

Include:
- one shared source of truth for audience ids and labels
- default audience value in app state
- state update helper for audience changes
- app event binding for the new audience buttons

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd Translate-Developer && node --test tests/ui/app.test.js`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Translate-Developer/src/data/audiences.js Translate-Developer/src/ui/state.js Translate-Developer/src/app.js Translate-Developer/tests/ui/app.test.js
git commit -m "feat: add audience selection state"
```

### Task 4: Rebuild the visible UI around context-rich input and the approved block order

**Files:**
- Modify: `Translate-Developer/src/ui/templates.js`
- Modify: `Translate-Developer/src/styles.css`
- Modify: `Translate-Developer/src/data/examples.js`
- Test: `Translate-Developer/tests/ui/app.test.js`

- [ ] **Step 1: Write the failing UI copy and layout tests**

```js
test("renders audience buttons and the new result labels", () => {
  const markup = renderAppMarkup(createInitialState(), options);
  assert.match(markup, /PM\/기획자/);
  assert.match(markup, /쉽게 다시 쓴 내용/);
  assert.match(markup, /더 알려주면 정확해지는 부분/);
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd Translate-Developer && node --test tests/ui/app.test.js`
Expected: FAIL because the UI still renders the MVP copy and old labels

- [ ] **Step 3: Implement the new UI layer**

Include:
- audience selector buttons near the top of the composer
- helper copy that asks for surrounding Slack context
- example messages rewritten as short thread-like inputs
- result blocks ordered around rewrite, glossary, impact, and unknowns
- current term table updated to match the new glossary naming

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd Translate-Developer && node --test tests/ui/app.test.js`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Translate-Developer/src/ui/templates.js Translate-Developer/src/styles.css Translate-Developer/src/data/examples.js Translate-Developer/tests/ui/app.test.js
git commit -m "feat: redesign ui for role-aware translation"
```

## Chunk 3: Thread Audience Through the API Path

### Task 5: Send the selected audience from the browser to the server

**Files:**
- Modify: `Translate-Developer/src/api/translate.js`
- Modify: `Translate-Developer/src/ui/state.js`
- Test: `Translate-Developer/tests/ui/app.test.js`

- [ ] **Step 1: Write the failing request-shape test**

```js
test("passes the selected audience into the async translation request", async () => {
  const requestTranslation = async (input, audience) => ({ ok: true, result: fakeResult });
  const state = await submitTranslationAsync(seedState, { requestTranslation });
  assert.equal(capturedAudience, "pm-planner");
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd Translate-Developer && node --test tests/ui/app.test.js`
Expected: FAIL because `requestAiTranslation` currently only accepts `input`

- [ ] **Step 3: Implement the minimal client request change**

Include:
- `requestAiTranslation(input, audience)`
- POST body containing `input` and `audience`
- state submission path updated to forward the selected audience

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd Translate-Developer && node --test tests/ui/app.test.js`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Translate-Developer/src/api/translate.js Translate-Developer/src/ui/state.js Translate-Developer/tests/ui/app.test.js
git commit -m "feat: send audience selection with api requests"
```

### Task 6: Add a dedicated audience-aware prompt builder and stricter server rules

**Files:**
- Create: `Translate-Developer/src/ai/prompt.js`
- Modify: `Translate-Developer/api/translate.js`
- Modify: `Translate-Developer/src/config.js`
- Test: `Translate-Developer/tests/api/translate.test.js`

- [ ] **Step 1: Write the failing API tests for audience-aware prompt generation**

```js
test("builds a PM/planner prompt that forbids guessing", async () => {
  await handleTranslateRequest(fakeRequest("...", "pm-planner"), { apiKey: "test-key", fetchImpl });
  assert.match(capturedRequestBody, /추정하지 마라/);
  assert.match(capturedRequestBody, /PM\/기획자/);
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd Translate-Developer && node --test tests/api/translate.test.js`
Expected: FAIL because the API route has one generic system prompt and no audience input

- [ ] **Step 3: Implement the prompt builder and model update**

Include:
- shared prompt rules
- audience-specific preset text
- no-guess / friendly-unknowns instructions
- default model changed from `gpt-4.1-mini` to `gpt-5.4`
- environment override preserved through `OPENAI_MODEL`

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd Translate-Developer && node --test tests/api/translate.test.js`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Translate-Developer/src/ai/prompt.js Translate-Developer/api/translate.js Translate-Developer/src/config.js Translate-Developer/tests/api/translate.test.js
git commit -m "feat: add audience-aware no-guess ai prompt"
```

## Chunk 4: Final Verification and Regression Coverage

### Task 7: Lock in the new end-to-end behavior with UI and API regression tests

**Files:**
- Modify: `Translate-Developer/tests/ui/app.test.js`
- Modify: `Translate-Developer/tests/api/translate.test.js`
- Modify: `Translate-Developer/tests/engine/rule-engine.test.js`

- [ ] **Step 1: Add the missing regression cases**

```js
test("renders the friendly unknowns label", () => {
  assert.match(markup, /더 알려주면 정확해지는 부분/);
});

test("does not accept speculative impact text in normalized responses", () => {
  assert.equal(normalizeTranslationResult(speculativePayload), null);
});
```

- [ ] **Step 2: Run the focused tests**

Run: `cd Translate-Developer && node --test tests/ui/app.test.js tests/api/translate.test.js tests/engine/rule-engine.test.js`
Expected: PASS

- [ ] **Step 3: Run the full project verification**

Run: `cd Translate-Developer && npm run verify`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add Translate-Developer/tests/ui/app.test.js Translate-Developer/tests/api/translate.test.js Translate-Developer/tests/engine/rule-engine.test.js
git commit -m "test: cover role-aware pm translation flow"
```

## Notes for the Implementer

- Keep the visible UI simple. Audience is the only explicit user choice in this scope.
- Do not add speculative copy such as likely impact, possible cause, or assumed next step unless the input directly supports it.
- If the fallback engine cannot confidently describe impact, prefer a short safe sentence plus a stronger `needsMoreContext` field.
- Avoid creating a separate layout per audience. Reuse the same rendering structure and only vary prompt emphasis and explanatory copy.

Plan complete and saved to `docs/superpowers/plans/2026-03-25-translate-developer-role-aware-plan.md`. Ready to execute?
