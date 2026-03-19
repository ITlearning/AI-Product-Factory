# Translate-Developer MVP Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a deployable single-page web app that translates short developer-written messages into structured plain-language output for non-technical users using a rule-based engine.

**Architecture:** Create a static TypeScript SPA with a small UI layer and a pluggable translation engine boundary. Implement the first engine as deterministic client-side rules so the app is fast to ship, cheap to host, and ready for later LLM substitution behind the same result schema.

**Tech Stack:** TypeScript, lightweight SPA frontend, static CSS, minimal test setup, static deployment

---

## File Structure

Planned project area: `Translate-Developer/`

- Create: `Translate-Developer/package.json`
- Create: `Translate-Developer/tsconfig.json`
- Create: `Translate-Developer/index.html`
- Create: `Translate-Developer/src/main.ts`
- Create: `Translate-Developer/src/app.ts`
- Create: `Translate-Developer/src/styles.css`
- Create: `Translate-Developer/src/data/examples.ts`
- Create: `Translate-Developer/src/engine/types.ts`
- Create: `Translate-Developer/src/engine/dictionary.ts`
- Create: `Translate-Developer/src/engine/rules.ts`
- Create: `Translate-Developer/src/engine/rule-engine.ts`
- Create: `Translate-Developer/src/engine/index.ts`
- Create: `Translate-Developer/src/ui/render.ts`
- Create: `Translate-Developer/src/ui/templates.ts`
- Create: `Translate-Developer/src/ui/state.ts`
- Create: `Translate-Developer/src/utils/text.ts`
- Create: `Translate-Developer/src/utils/validation.ts`
- Create: `Translate-Developer/tests/engine/rule-engine.test.ts`
- Create: `Translate-Developer/tests/utils/validation.test.ts`
- Create: `Translate-Developer/tests/ui/app.test.ts`
- Modify: `Translate-Developer/plan.md`

## Chunk 1: Project Scaffold And Baseline UX

### Task 1: Scaffold the static SPA shell

**Files:**
- Create: `Translate-Developer/package.json`
- Create: `Translate-Developer/tsconfig.json`
- Create: `Translate-Developer/index.html`
- Create: `Translate-Developer/src/main.ts`
- Create: `Translate-Developer/src/app.ts`
- Create: `Translate-Developer/src/styles.css`

- [ ] **Step 1: Write the failing smoke test for app boot**

```ts
import { describe, expect, it } from "vitest";
import { createApp } from "../../src/app";

describe("createApp", () => {
  it("renders the translator shell", () => {
    document.body.innerHTML = '<div id="app"></div>';
    createApp(document.getElementById("app")!);
    expect(document.body.textContent).toContain("개발자 말을 쉽게");
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm test -- tests/ui/app.test.ts`
Expected: FAIL because app bootstrap files do not exist yet

- [ ] **Step 3: Create the minimal shell implementation**

```ts
export function createApp(root: HTMLElement) {
  root.innerHTML = `
    <main class="app-shell">
      <section class="hero">
        <h1>개발자 말을 쉽게</h1>
      </section>
    </main>
  `;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm test -- tests/ui/app.test.ts`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Translate-Developer/package.json Translate-Developer/tsconfig.json Translate-Developer/index.html Translate-Developer/src/main.ts Translate-Developer/src/app.ts Translate-Developer/src/styles.css Translate-Developer/tests/ui/app.test.ts
git commit -m "feat: scaffold translate developer app shell"
```

### Task 2: Apply intentional first-pass UX direction

**Files:**
- Modify: `Translate-Developer/src/app.ts`
- Modify: `Translate-Developer/src/styles.css`
- Create: `Translate-Developer/src/data/examples.ts`

- [ ] **Step 1: Write the failing test for example prompt hydration**

```ts
it("loads an example message into the input", () => {
  document.body.innerHTML = '<div id="app"></div>';
  createApp(document.getElementById("app")!);
  const button = screen.getByText("예시 써보기");
  button.click();
  expect((screen.getByLabelText("개발자 메시지") as HTMLTextAreaElement).value).not.toBe("");
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm test -- tests/ui/app.test.ts`
Expected: FAIL because the example action does not exist

- [ ] **Step 3: Implement the first interactive layout**

```ts
const exampleMessage = "배포 후 결제 API에서 타임아웃이 반복돼서 확인 중입니다.";
```

Include:
- hero explanation
- textarea input
- primary translate button
- example-fill action
- empty result placeholders

Before implementation, run a UI review pass with `ui-ux-pro-max` principles and keep the resulting layout intentional rather than generic.

- [ ] **Step 4: Run test to verify it passes**

Run: `npm test -- tests/ui/app.test.ts`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Translate-Developer/src/app.ts Translate-Developer/src/styles.css Translate-Developer/src/data/examples.ts Translate-Developer/tests/ui/app.test.ts
git commit -m "feat: add first translate developer interaction flow"
```

## Chunk 2: Rule Engine

### Task 3: Define the engine contract and input validation

**Files:**
- Create: `Translate-Developer/src/engine/types.ts`
- Create: `Translate-Developer/src/utils/validation.ts`
- Create: `Translate-Developer/tests/utils/validation.test.ts`

- [ ] **Step 1: Write the failing validation tests**

```ts
describe("validateInput", () => {
  it("rejects empty text", () => {
    expect(validateInput("   ").ok).toBe(false);
  });

  it("warns when the message is too long", () => {
    expect(validateInput("a".repeat(501)).reason).toContain("짧은 메시지");
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm test -- tests/utils/validation.test.ts`
Expected: FAIL because validation helpers are missing

- [ ] **Step 3: Implement the shared types and validation**

```ts
export type TranslationResult = {
  summary: string;
  easyExplanation: string;
  importantNow: string;
  actionForReader: string;
  termPairs: Array<{ original: string; simplified: string }>;
};
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm test -- tests/utils/validation.test.ts`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Translate-Developer/src/engine/types.ts Translate-Developer/src/utils/validation.ts Translate-Developer/tests/utils/validation.test.ts
git commit -m "test: add input validation for translate developer"
```

### Task 4: Build dictionary and phrase simplification rules

**Files:**
- Create: `Translate-Developer/src/engine/dictionary.ts`
- Create: `Translate-Developer/src/engine/rules.ts`
- Create: `Translate-Developer/tests/engine/rule-engine.test.ts`

- [ ] **Step 1: Write the failing rule test**

```ts
it("maps technical phrases into simpler explanations", () => {
  const result = translateWithRules("배포 후 결제 API에서 타임아웃이 반복돼서 확인 중입니다.");
  expect(result.easyExplanation).toContain("응답이 늦거나 멈추는 문제");
  expect(result.termPairs).toContainEqual({
    original: "타임아웃",
    simplified: "응답이 늦거나 멈추는 문제",
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm test -- tests/engine/rule-engine.test.ts`
Expected: FAIL because rule engine files do not exist

- [ ] **Step 3: Implement dictionary-driven rewriting**

```ts
const TERM_DICTIONARY = {
  "타임아웃": "응답이 늦거나 멈추는 문제",
  "배포": "새 버전을 반영하는 작업",
  "API": "시스템끼리 정보를 주고받는 연결 지점",
};
```

Include:
- deterministic replacements
- preserved key terms for comparison
- phrase-level normalization before sentence assembly

- [ ] **Step 4: Run test to verify it passes**

Run: `npm test -- tests/engine/rule-engine.test.ts`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Translate-Developer/src/engine/dictionary.ts Translate-Developer/src/engine/rules.ts Translate-Developer/tests/engine/rule-engine.test.ts
git commit -m "feat: add translate developer simplification rules"
```

### Task 5: Compose the rule engine output sections

**Files:**
- Create: `Translate-Developer/src/engine/rule-engine.ts`
- Create: `Translate-Developer/src/engine/index.ts`
- Modify: `Translate-Developer/tests/engine/rule-engine.test.ts`

- [ ] **Step 1: Write the failing structured output test**

```ts
it("returns the full translation contract", () => {
  const result = translateWithRules("서버 에러 때문에 로그인 기능이 잠깐 불안정합니다.");
  expect(result.summary).not.toBe("");
  expect(result.easyExplanation).not.toBe("");
  expect(result.importantNow).toContain("로그인");
  expect(result.actionForReader).not.toBe("");
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm test -- tests/engine/rule-engine.test.ts`
Expected: FAIL because the engine does not populate the full result shape yet

- [ ] **Step 3: Implement the minimal result composer**

```ts
export function translateWithRules(input: string): TranslationResult {
  return {
    summary,
    easyExplanation,
    importantNow,
    actionForReader,
    termPairs,
  };
}
```

Include heuristics for:
- blocker and urgency wording
- issue target extraction
- fallback phrasing when no strong rule matches

- [ ] **Step 4: Run test to verify it passes**

Run: `npm test -- tests/engine/rule-engine.test.ts`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Translate-Developer/src/engine/rule-engine.ts Translate-Developer/src/engine/index.ts Translate-Developer/tests/engine/rule-engine.test.ts
git commit -m "feat: compose structured translate developer output"
```

## Chunk 3: UI Wiring And Delivery

### Task 6: Connect input, validation, and result rendering

**Files:**
- Create: `Translate-Developer/src/ui/templates.ts`
- Create: `Translate-Developer/src/ui/render.ts`
- Create: `Translate-Developer/src/ui/state.ts`
- Modify: `Translate-Developer/src/app.ts`
- Modify: `Translate-Developer/src/styles.css`
- Modify: `Translate-Developer/tests/ui/app.test.ts`

- [ ] **Step 1: Write the failing interaction test**

```ts
it("renders translated output after submit", () => {
  document.body.innerHTML = '<div id="app"></div>';
  createApp(document.getElementById("app")!);
  const input = screen.getByLabelText("개발자 메시지");
  fireEvent.input(input, {
    target: { value: "배포 후 결제 API에서 타임아웃이 반복돼서 확인 중입니다." },
  });
  screen.getByText("번역하기").click();
  expect(screen.getByText("한 줄 요약")).toBeInTheDocument();
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm test -- tests/ui/app.test.ts`
Expected: FAIL because the engine is not wired into the UI yet

- [ ] **Step 3: Implement state-driven rendering**

```ts
type AppState = {
  input: string;
  error: string | null;
  result: TranslationResult | null;
};
```

Include:
- validation messaging
- submit handling
- result card rendering
- original vs simplified comparison rendering

- [ ] **Step 4: Run test to verify it passes**

Run: `npm test -- tests/ui/app.test.ts`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Translate-Developer/src/ui/templates.ts Translate-Developer/src/ui/render.ts Translate-Developer/src/ui/state.ts Translate-Developer/src/app.ts Translate-Developer/src/styles.css Translate-Developer/tests/ui/app.test.ts
git commit -m "feat: wire translate developer UI to rule engine"
```

### Task 7: Polish for deployability and document current scope

**Files:**
- Modify: `Translate-Developer/plan.md`
- Modify: `Translate-Developer/package.json`
- Modify: `Translate-Developer/src/styles.css`

- [ ] **Step 1: Write the failing acceptance checklist in the plan note**

```md
- [ ] input example works
- [ ] translation renders all output sections
- [ ] long-input warning appears
- [ ] layout works on mobile width
```

- [ ] **Step 2: Run the production build to verify it fails before final scripts are added**

Run: `npm run build`
Expected: FAIL because build scripts or configuration are incomplete

- [ ] **Step 3: Implement final delivery adjustments**

Include:
- build and test scripts
- responsive layout polish
- update `Translate-Developer/plan.md` with implemented MVP notes and next steps
- final UI review pass using `ui-ux-pro-max` guidance before closing the task

- [ ] **Step 4: Run verification to verify it passes**

Run:
- `npm test`
- `npm run build`

Expected:
- PASS for test suite
- PASS for production build

- [ ] **Step 5: Commit**

```bash
git add Translate-Developer/plan.md Translate-Developer/package.json Translate-Developer/src/styles.css
git commit -m "docs: finalize translate developer mvp scope"
```

## Execution Notes

- Keep the engine boundary stable even if the rule details change.
- Prefer deletion and small utilities over introducing extra abstraction.
- Add only the minimum dependencies needed to ship and test the SPA.
- If visual choices drift toward a generic layout, pause and run another `ui-ux-pro-max` review pass before continuing.
- Use representative Korean developer-message fixtures for regression coverage.

Plan complete and saved to `docs/superpowers/plans/2026-03-19-translate-developer-mvp.md`. Ready to execute?
