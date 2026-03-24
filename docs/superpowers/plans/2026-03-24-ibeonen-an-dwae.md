# 이번엔 안 돼 Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `IBAD/app` 하위에 OpenAI 기반 거절 답장 생성 웹앱 MVP를 만든다.

**Architecture:** 바닐라 JS SPA와 Vercel 서버리스 API를 사용한다. 서버는 OpenAI Responses API를 호출해 구조화 응답을 받고, 지원 범위 분기와 안전가드를 통과한 결과만 UI에 전달한다.

**Tech Stack:** Vanilla JS, Node.js, Vercel serverless functions, OpenAI Responses API, `node:test`

---

## File Structure

- `IBAD/app/package.json`
  - 앱 스크립트 정의
- `IBAD/app/index.html`
  - 앱 엔트리 HTML
- `IBAD/app/vercel.json`
  - 빌드 출력 설정
- `IBAD/app/scripts/build.mjs`
  - 정적 앱 빌드 스크립트
- `IBAD/app/scripts/check-syntax.mjs`
  - 기본 문법 검사 스크립트
- `IBAD/app/api/generate-reply.js`
  - 서버리스 OpenAI 호출 및 응답 정규화
- `IBAD/app/src/main.js`
  - 앱 부트스트랩
- `IBAD/app/src/app.js`
  - 루트 렌더 및 이벤트 바인딩
- `IBAD/app/src/config.js`
  - OpenAI URL, 기본 모델
- `IBAD/app/src/styles.css`
  - 화면 스타일
- `IBAD/app/src/api/generate-reply.js`
  - 브라우저에서 API 호출
- `IBAD/app/src/ui/state.js`
  - 입력, 로딩, 결과, 오류 상태 관리
- `IBAD/app/src/ui/templates.js`
  - 마크업 렌더
- `IBAD/app/src/domain/schema.js`
  - 서버 응답 스키마 정규화
- `IBAD/app/src/domain/options.js`
  - 관계 타입, 상황 타입, 강도 옵션 계약
- `IBAD/app/src/domain/safety.js`
  - 지원 범위, 여지 남김, 장문/사과 패턴 검사
- `IBAD/app/src/domain/examples.js`
  - 예시 입력 데이터
- `IBAD/app/src/utils/validation.js`
  - request payload 및 클라이언트 입력 검증
- `IBAD/app/tests/api/generate-reply.test.js`
  - 서버 API 테스트
- `IBAD/app/tests/domain/schema.test.js`
  - 스키마 정규화 테스트
- `IBAD/app/tests/domain/safety.test.js`
  - 지원 범위 및 안전가드 테스트
- `IBAD/app/tests/ui/app.test.js`
  - UI 상태/렌더 테스트

## Chunk 1: App Skeleton And Domain Contract

### Task 1: Bootstrap IBAD app shell

**Files:**
- Create: `IBAD/app/package.json`
- Create: `IBAD/app/index.html`
- Create: `IBAD/app/vercel.json`
- Create: `IBAD/app/scripts/build.mjs`
- Create: `IBAD/app/scripts/check-syntax.mjs`
- Create: `IBAD/app/src/main.js`
- Create: `IBAD/app/src/app.js`
- Create: `IBAD/app/src/config.js`
- Create: `IBAD/app/src/styles.css`
- Create: `IBAD/app/src/ui/state.js`
- Create: `IBAD/app/src/ui/templates.js`
- Create: `IBAD/app/src/domain/options.js`
- Create: `IBAD/app/tests/ui/app.test.js`

- [ ] **Step 1: Create `package.json` and the failing smoke test**

`IBAD/app/package.json` must include `"type": "module"` before the first test run.

```js
import test from "node:test";
import assert from "node:assert/strict";
import { renderAppMarkup } from "../../src/ui/templates.js";
import { createInitialState } from "../../src/ui/state.js";

test("renders the IBAD app shell", () => {
  const markup = renderAppMarkup(createInitialState(), { examples: [] });
  assert.match(markup, /이번엔 안 돼/);
  assert.match(markup, /관계 타입/);
  assert.match(markup, /답장 만들기/);
  assert.match(markup, /예의 있게 확실하게/);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd IBAD/app && node --test tests/ui/app.test.js`
Expected: FAIL because app files do not exist yet

- [ ] **Step 3: Create the shared option contract**

```js
export const RELATIONSHIP_OPTIONS = [
  { value: "close-friend", label: "친한 친구" },
  { value: "just-friend", label: "그냥 친구" },
  { value: "ambiguous", label: "애매한 사이" },
  { value: "barely-close", label: "거의 안 친함" }
];

export const SITUATION_OPTIONS = [
  { value: "promise", label: "약속 거절" },
  { value: "favor", label: "부탁 거절" }
];

export const STRENGTH_OPTIONS = [
  { value: "soft", label: "부드럽게" },
  { value: "polite-firm", label: "예의 있게 확실하게" },
  { value: "firm", label: "단호하게" }
];
```

- [ ] **Step 4: Create the minimal app shell state**

```js
import {
  RELATIONSHIP_OPTIONS,
  SITUATION_OPTIONS,
  STRENGTH_OPTIONS
} from "../domain/options.js";

export function createInitialState() {
  return {
    input: "",
    relationshipType: RELATIONSHIP_OPTIONS[1].value,
    situationType: SITUATION_OPTIONS[0].value,
    rejectionStrength: STRENGTH_OPTIONS[1].value,
    includeAlternative: false,
    result: null,
    feedback: null,
    isLoading: false
  };
}
```

- [ ] **Step 5: Add `renderAppMarkup()`, entry HTML, shared config, and a syntax-check script**

```js
import { STRENGTH_OPTIONS } from "../domain/options.js";

export function renderAppMarkup(state, { examples }) {
  return `
    <main>
      <h1>이번엔 안 돼</h1>
      <label>관계 타입</label>
      <span>${STRENGTH_OPTIONS[1].label}</span>
      <button type="submit">답장 만들기</button>
    </main>
  `;
}

export const DEFAULT_OPENAI_MODEL = "gpt-4.1-mini";
export const OPENAI_RESPONSES_URL = "https://api.openai.com/v1/responses";
```

- [ ] **Step 6: Wire `src/app.js` and `src/main.js` to render the shell**

```js
import { createInitialState } from "./ui/state.js";
import { renderAppMarkup } from "./ui/templates.js";

export function createApp(root) {
  root.innerHTML = renderAppMarkup(createInitialState(), { examples: [] });
}
```

- [ ] **Step 7: Run test to verify it passes**

Run: `cd IBAD/app && node --test tests/ui/app.test.js`
Expected: PASS

- [ ] **Step 8: Commit**

```bash
git add IBAD/app
git commit -m "feat: bootstrap ibad app shell"
```

### Task 2: Define the result contract and example data

**Files:**
- Create: `IBAD/app/src/domain/schema.js`
- Create: `IBAD/app/src/domain/examples.js`
- Create: `IBAD/app/tests/domain/schema.test.js`
- Test: `IBAD/app/tests/domain/schema.test.js`

- [ ] **Step 1: Write the failing schema test**

```js
test("normalizes a valid reply payload", () => {
  const result = normalizeReplyResult({
    replyOptions: [
      { text: "이번엔 어려울 것 같아.", toneLabel: "정중한 버전", whyItWorks: "짧고 분명함" },
      { text: "이번엔 안 될 것 같아.", toneLabel: "자연스러운 버전", whyItWorks: "부담 없이 선을 긋음" },
      { text: "이번 요청은 어렵겠어.", toneLabel: "단호한 버전", whyItWorks: "재요청 여지를 줄임" }
    ],
    avoidPhrases: ["다음에 보자"],
    openDoorRisk: "low",
    alternativeDifference: "대안을 넣으면 부드러워지지만 여지가 생길 수 있다."
  });

  assert.equal(result.replyOptions.length, 3);
  assert.equal(result.replyOptions[0].toneLabel, "정중한 버전");
  assert.equal(result.replyOptions[0].whyItWorks, "짧고 분명함");
  assert.equal(result.avoidPhrases[0], "다음에 보자");
  assert.equal(result.openDoorRisk, "low");
  assert.match(result.alternativeDifference, /대안을 넣으면/);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd IBAD/app && node --test tests/domain/schema.test.js`
Expected: FAIL because schema module does not exist yet

- [ ] **Step 3: Implement strict normalization**

```js
export function normalizeReplyResult(payload) {
  if (!payload || !Array.isArray(payload.replyOptions) || payload.replyOptions.length !== 3) {
    return null;
  }

  return {
    replyOptions: payload.replyOptions.map((option) => ({
      text: String(option.text ?? "").trim(),
      toneLabel: String(option.toneLabel ?? "").trim(),
      whyItWorks: String(option.whyItWorks ?? "").trim()
    })),
    avoidPhrases: Array.isArray(payload.avoidPhrases) ? payload.avoidPhrases.map(String) : [],
    openDoorRisk: String(payload.openDoorRisk ?? "").trim(),
    alternativeDifference: String(payload.alternativeDifference ?? "").trim()
  };
}
```

- [ ] **Step 4: Add example prompts for the UI**

```js
export const EXAMPLE_CASES = [
  "친구가 갑자기 주말에 만나자고 했는데 쉬고 싶다.",
  "애매한 사이가 소개를 부탁했는데 들어주고 싶지 않다."
];
```

- [ ] **Step 5: Run the domain tests**

Run: `cd IBAD/app && node --test tests/domain/schema.test.js`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add IBAD/app/src/domain IBAD/app/tests/domain
git commit -m "feat: add ibad reply schema contract"
```

## Chunk 2: Server Generation And Safety Guards

### Task 3: Add server-side validation and support-boundary checks

**Files:**
- Create: `IBAD/app/src/domain/safety.js`
- Create: `IBAD/app/src/utils/validation.js`
- Create: `IBAD/app/tests/domain/safety.test.js`

- [ ] **Step 1: Write failing safety tests**

```js
test("flags unsupported work relationship input", () => {
  const verdict = detectUnsupportedScope({
    relationshipType: "barely-close",
    situationType: "favor",
    input: "팀장님이 오늘 밤까지 해달라고 했어요."
  });

  assert.equal(verdict.supported, false);
});

test("flags open-door language when alternatives are disabled", () => {
  const issues = findReplySafetyIssues("이번엔 어렵고 다음에 시간 되면 보자.", {
    includeAlternative: false
  });

  assert.equal(issues[0].code, "OPEN_DOOR_PHRASE");
  assert.match(issues[0].phrase, /다음에/);
});

test("flags follow-up reply requests as unsupported", () => {
  const verdict = detectUnsupportedScope({
    relationshipType: "just-friend",
    situationType: "favor",
    input: "내가 이미 한번 거절했는데 다시 뭐라고 답해야 할지 모르겠어."
  });

  assert.equal(verdict.supported, false);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd IBAD/app && node --test tests/domain/safety.test.js`
Expected: FAIL because safety helpers do not exist yet

- [ ] **Step 3: Implement support-boundary rules**

```js
export function detectUnsupportedScope(input) {
  const blockedWords = [
    "팀장",
    "회사",
    "상사",
    "남자친구",
    "여자친구",
    "엄마",
    "아빠",
    "다시 뭐라고",
    "한번 거절했는데"
  ];
  const source = `${input.relationshipType} ${input.input}`;

  if (blockedWords.some((word) => source.includes(word))) {
    return {
      supported: false,
      message: "현재 버전은 친구/지인 대상의 약속·부탁 거절만 지원합니다."
    };
  }

  return { supported: true };
}
```

- [ ] **Step 4: Implement reply safety scanning**

```js
export function findReplySafetyIssues(text, options) {
  const issues = [];

  if (!options.includeAlternative && /다음에|나중에|시간 되면|기회 되면/.test(text)) {
    issues.push({
      code: "OPEN_DOOR_PHRASE",
      phrase: text.match(/다음에|나중에|시간 되면|기회 되면/)[0]
    });
  }

  if ((text.match(/미안/g) ?? []).length >= 2) {
    issues.push({ code: "TOO_APOLOGETIC", phrase: "미안" });
  }

  if (text.length > 120) {
    issues.push({ code: "TOO_LONG", phrase: text.slice(0, 20) });
  }

  return issues;
}
```

- [ ] **Step 5: Run tests**

Run: `cd IBAD/app && node --test tests/domain/safety.test.js`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add IBAD/app/src/domain/safety.js IBAD/app/src/utils/validation.js IBAD/app/tests/domain/safety.test.js
git commit -m "feat: add ibad safety and scope guards"
```

### Task 4: Implement `/api/generate-reply`

**Files:**
- Create: `IBAD/app/api/generate-reply.js`
- Modify: `IBAD/app/src/config.js`
- Modify: `IBAD/app/src/domain/schema.js`
- Create: `IBAD/app/tests/api/generate-reply.test.js`
- Test: `IBAD/app/tests/api/generate-reply.test.js`

- [ ] **Step 1: Write the failing API tests**

```js
test("rejects missing input", async () => {
  const response = await handleGenerateReplyRequest({
    method: "POST",
    json: async () => ({
      input: "",
      relationshipType: "just-friend",
      situationType: "promise",
      rejectionStrength: "polite-firm",
      includeAlternative: false
    })
  });

  assert.equal(response.status, 400);
});

test("returns unsupported response for out-of-scope input", async () => {
  const response = await handleGenerateReplyRequest({
    method: "POST",
    json: async () => ({
      input: "팀장님이 부탁했어요.",
      relationshipType: "barely-close",
      situationType: "favor",
      rejectionStrength: "polite-firm",
      includeAlternative: false
    })
  });

  assert.equal(response.status, 422);
});

test("returns normalized AI output for supported input", async () => {
  const response = await handleGenerateReplyRequest(
    {
      method: "POST",
      json: async () => ({
        input: "친구가 오늘 저녁에 만나자고 했는데 쉬고 싶다.",
        relationshipType: "just-friend",
        situationType: "promise",
        rejectionStrength: "polite-firm",
        includeAlternative: false
      })
    },
    {
      apiKey: "test-key",
      fetchImpl: async () =>
        new Response(
          JSON.stringify({
            output: [
              {
                content: [
                  {
                    json: {
                      replyOptions: [
                        { text: "오늘은 좀 쉬고 싶어서 이번엔 어려울 것 같아.", toneLabel: "정중한 버전", whyItWorks: "부드럽고 분명하다." },
                        { text: "오늘은 패스할게. 이번엔 안 될 것 같아.", toneLabel: "자연스러운 버전", whyItWorks: "짧고 자연스럽다." },
                        { text: "오늘은 안 될 것 같아.", toneLabel: "단호한 버전", whyItWorks: "여지를 줄인다." }
                      ],
                      avoidPhrases: ["다음에 보자"],
                      openDoorRisk: "low",
                      alternativeDifference: "대안을 넣지 않으면 더 깔끔하게 끝난다."
                    }
                  }
                ]
              }
            ]
          }),
          { status: 200, headers: { "Content-Type": "application/json" } }
        )
    }
  );

  assert.equal(response.status, 200);
});

test("returns typed unsafe-result errors", async () => {
  const response = await handleGenerateReplyRequest(
    {
      method: "POST",
      json: async () => ({
        input: "친구가 오늘 보자고 했는데 가기 싫다.",
        relationshipType: "just-friend",
        situationType: "promise",
        rejectionStrength: "polite-firm",
        includeAlternative: false
      })
    },
    {
      apiKey: "test-key",
      fetchImpl: async () =>
        new Response(
          JSON.stringify({
            output: [
              {
                content: [
                  {
                    json: {
                      replyOptions: [
                        { text: "이번엔 어렵고 다음에 시간 되면 보자.", toneLabel: "정중한 버전", whyItWorks: "부드럽다." },
                        { text: "이번엔 안 될 것 같아.", toneLabel: "자연스러운 버전", whyItWorks: "짧다." },
                        { text: "오늘은 안 될 것 같아.", toneLabel: "단호한 버전", whyItWorks: "분명하다." }
                      ],
                      avoidPhrases: ["다음에 보자"],
                      openDoorRisk: "high",
                      alternativeDifference: "대안이 있으면 더 열려 보인다."
                    }
                  }
                ]
              }
            ]
          }),
          { status: 200, headers: { "Content-Type": "application/json" } }
        )
    }
  );

  assert.equal(response.status, 502);
});

test("returns invalid-schema errors when AI output is malformed", async () => {
  const response = await handleGenerateReplyRequest(
    {
      method: "POST",
      json: async () => ({
        input: "친구 부탁을 거절하고 싶다.",
        relationshipType: "just-friend",
        situationType: "favor",
        rejectionStrength: "polite-firm",
        includeAlternative: false
      })
    },
    {
      apiKey: "test-key",
      fetchImpl: async () =>
        new Response(
          JSON.stringify({
            output: [{ content: [{ json: { replyOptions: [{ text: "하나만 있음" }] } }] }]
          }),
          { status: 200, headers: { "Content-Type": "application/json" } }
        )
    }
  );

  assert.equal(response.status, 502);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd IBAD/app && node --test tests/api/generate-reply.test.js`
Expected: FAIL because the API route does not exist yet

- [ ] **Step 3: Export `REPLY_JSON_SCHEMA` and implement `buildUserPrompt()`**

`IBAD/app/src/domain/schema.js` must export the structured output schema, and `IBAD/app/api/generate-reply.js` must define `buildUserPrompt(payload)` locally so executors do not guess where prompt composition lives.

- [ ] **Step 4: Implement request parsing and OpenAI call**

```js
const upstreamResponse = await fetchImpl(OPENAI_RESPONSES_URL, {
  method: "POST",
  headers: {
    "Content-Type": "application/json",
    Authorization: `Bearer ${apiKey}`
  },
  body: JSON.stringify({
    model,
    input: [
      { role: "system", content: [{ type: "input_text", text: SYSTEM_PROMPT }] },
      { role: "user", content: [{ type: "input_text", text: buildUserPrompt(payload) }] }
    ],
    text: {
      format: {
        type: "json_schema",
        name: REPLY_JSON_SCHEMA.name,
        schema: REPLY_JSON_SCHEMA.schema,
        strict: true
      }
    }
  })
});
```

- [ ] **Step 5: Normalize and reject unsafe results**

```js
const normalized = normalizeReplyResult(candidate);

if (!normalized) {
  return jsonResponse({ error: "AI returned an invalid result.", code: "INVALID_AI_SCHEMA" }, 502);
}

for (const option of normalized.replyOptions) {
  const issues = findReplySafetyIssues(option.text, {
    includeAlternative: payload.includeAlternative
  });

  if (issues.length > 0) {
    return jsonResponse({ error: "AI returned an unsafe result.", code: "UNSAFE_RESULT" }, 502);
  }
}
```

- [ ] **Step 6: Return typed responses for supported, unsupported, and unsafe cases**

```js
if (!scopeVerdict.supported) {
  return jsonResponse(
    {
      error: scopeVerdict.message,
      code: "UNSUPPORTED_SCOPE"
    },
    422
  );
}

return jsonResponse({ result: normalized, source: "ai" }, 200);
```

- [ ] **Step 7: Run API tests**

Run: `cd IBAD/app && node --test tests/api/generate-reply.test.js`
Expected: PASS

- [ ] **Step 8: Commit**

```bash
git add IBAD/app/api/generate-reply.js IBAD/app/src/config.js IBAD/app/tests/api/generate-reply.test.js
git commit -m "feat: add ibad generate reply api"
```

## Chunk 3: UI Integration And Verification

### Task 5: Connect the SPA to the API and render results

**Files:**
- Create: `IBAD/app/src/api/generate-reply.js`
- Modify: `IBAD/app/src/ui/state.js`
- Modify: `IBAD/app/src/ui/templates.js`
- Modify: `IBAD/app/src/app.js`
- Test: `IBAD/app/tests/ui/app.test.js`

- [ ] **Step 1: Expand the failing UI tests**

```js
test("renders generated reply cards", async () => {
  const state = await submitReplyRequest(
    {
      ...createInitialState(),
      input: "친구가 오늘 저녁에 보자고 했는데 쉬고 싶다."
    },
    {
      requestReplySet: async () => ({
        ok: true,
        result: {
          replyOptions: [
            { text: "오늘은 좀 쉬고 싶어서 이번엔 어려울 것 같아.", toneLabel: "정중한 버전", whyItWorks: "부드럽게 선을 긋는다." },
            { text: "오늘은 패스할게. 이번엔 안 될 것 같아.", toneLabel: "자연스러운 버전", whyItWorks: "짧고 분명하다." },
            { text: "오늘은 안 될 것 같아.", toneLabel: "단호한 버전", whyItWorks: "여지를 줄인다." }
          ],
          avoidPhrases: ["다음에 보자"],
          openDoorRisk: "low",
          alternativeDifference: "대안을 넣지 않으면 더 깔끔하게 끝난다."
        }
      })
    }
  );

  const markup = renderAppMarkup(state, { examples: [] });
  assert.match(markup, /정중한 버전/);
  assert.match(markup, /피해야 할 표현/);
  assert.match(markup, /여지 남김 여부/);
  assert.match(markup, /대안을 넣었을 때/);
});

test("renders unsupported-scope feedback", async () => {
  const state = await submitReplyRequest(
    {
      ...createInitialState(),
      input: "팀장님이 오늘 저녁에 같이 가자고 했다."
    },
    {
      requestReplySet: async () => ({
        ok: false,
        code: "UNSUPPORTED_SCOPE",
        message: "현재 버전은 친구/지인 대상의 약속·부탁 거절만 지원합니다."
      })
    }
  );

  assert.equal(state.feedback?.type, "warning");
});

test("updates form fields in state", () => {
  const state = updateField(createInitialState(), "relationshipType", "ambiguous");
  assert.equal(state.relationshipType, "ambiguous");
});
```

- [ ] **Step 2: Run UI tests to verify they fail**

Run: `cd IBAD/app && node --test tests/ui/app.test.js`
Expected: FAIL until state and template modules are complete

- [ ] **Step 3: Implement API client and state flow**

```js
export async function requestReplySet(payload) {
  const response = await fetch("/api/generate-reply", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload)
  });

  const body = await response.json();
  return response.ok
    ? { ok: true, result: body.result }
    : { ok: false, code: body.code, message: body.error };
}

export async function submitReplyRequest(state, { requestReplySet }) {
  const response = await requestReplySet({
    input: state.input,
    relationshipType: state.relationshipType,
    situationType: state.situationType,
    rejectionStrength: state.rejectionStrength,
    includeAlternative: state.includeAlternative
  });

  if (response.ok) {
    return {
      ...state,
      result: response.result,
      feedback: null
    };
  }

  return {
    ...state,
    result: null,
    feedback: {
      type: response.code === "UNSUPPORTED_SCOPE" ? "warning" : "error",
      message: response.message
    }
  };
}
```

- [ ] **Step 4: Bind textarea, selects, and checkbox events in `src/app.js`**

```js
textarea.addEventListener("input", (event) => {
  state = updateField(state, "input", event.currentTarget.value);
});

relationshipSelect.addEventListener("change", (event) => {
  state = updateField(state, "relationshipType", event.currentTarget.value);
});
```

- [ ] **Step 5: Render input controls, copy actions, and result cards**

```js
${state.result.replyOptions
  .map(
    (option) => `
      <article class="reply-card">
        <h3>${option.toneLabel}</h3>
        <p>${option.text}</p>
        <small>${option.whyItWorks}</small>
        <button type="button" data-copy-reply="${option.text}">복사</button>
      </article>
    `
  )
  .join("")}

<section>
  <h3>여지 남김 여부</h3>
  <p>${state.result.openDoorRisk}</p>
</section>
<section>
  <h3>대안을 넣었을 때 / 안 넣었을 때</h3>
  <p>${state.result.alternativeDifference}</p>
</section>
```

- [ ] **Step 6: Run UI tests**

Run: `cd IBAD/app && node --test tests/ui/app.test.js`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add IBAD/app/src/api/generate-reply.js IBAD/app/src/ui/state.js IBAD/app/src/ui/templates.js IBAD/app/src/app.js IBAD/app/tests/ui/app.test.js
git commit -m "feat: add ibad ui flow and results"
```

### Task 6: Verify the full app and document runtime needs

**Files:**
- Modify: `IBAD/app/package.json`
- Optional Create: `IBAD/README.md`

- [ ] **Step 1: Add verification scripts**

```json
{
  "scripts": {
    "lint": "node scripts/check-syntax.mjs",
    "test": "node --test",
    "build": "node scripts/build.mjs",
    "verify": "npm run lint && npm test && npm run build"
  }
}
```

- [ ] **Step 2: Run full verification**

Run: `cd IBAD/app && npm run verify`
Expected: all checks pass and `dist/` is generated

- [ ] **Step 3: Re-run UI tests for failure-path rendering**

Run: `cd IBAD/app && node --test tests/ui/app.test.js`
Expected: PASS for success, unsupported-scope, and failure rendering flows

- [ ] **Step 4: Document environment variables**

```md
- `OPENAI_API_KEY`
- optional `OPENAI_MODEL`
```

- [ ] **Step 5: Commit**

```bash
git add IBAD/app/package.json IBAD/README.md
git commit -m "docs: document ibad runtime and verification"
```

## Final Verification Checklist

- [ ] `cd IBAD/app && node --test tests/domain/schema.test.js`
- [ ] `cd IBAD/app && node --test tests/domain/safety.test.js`
- [ ] `cd IBAD/app && node --test tests/api/generate-reply.test.js`
- [ ] `cd IBAD/app && node --test tests/ui/app.test.js`
- [ ] `cd IBAD/app && npm run verify`

## Notes For Execution

- `Translate-Developer`는 참고만 하고 수정하지 않는다.
- 구현 파일은 모두 `IBAD/app` 아래에 둔다.
- fallback 자동 생성 로직은 추가하지 않는다.
- API 에러보다 안전가드 실패를 우선 보수적으로 처리한다.
- 민감한 원문 입력은 서버에 로그로 남기지 않는다.
