import test from "node:test";
import assert from "node:assert/strict";

import { DEFAULT_EXAMPLE } from "../../src/data/examples.js";
import {
  applyExample,
  createInitialState,
  startTranslation,
  submitTranslationAsync
} from "../../src/ui/state.js";
import { renderAppMarkup } from "../../src/ui/templates.js";

test("renders the translator shell", () => {
  const markup = renderAppMarkup(createInitialState(), {
    defaultExample: DEFAULT_EXAMPLE,
    examples: [DEFAULT_EXAMPLE]
  });

  assert.match(markup, /개발자 설명을 비전공자 언어로 바꿉니다/);
  assert.match(markup, /개발자 메시지/);
  assert.match(markup, /번역하기/);
});

test("loads an example message into state", () => {
  const state = applyExample(createInitialState(), DEFAULT_EXAMPLE);

  assert.equal(state.input, DEFAULT_EXAMPLE);
});

test("renders translated output after submit", async () => {
  const nextState = await submitTranslationAsync(
    applyExample(createInitialState(), DEFAULT_EXAMPLE),
    {
      requestTranslation: async () => ({
        ok: true,
        result: {
          summary: "결제 기능에 문제가 있어 확인 중입니다.",
          easyExplanation: "시스템 연결 문제로 결제가 불안정할 수 있습니다.",
          importantNow: "지금은 결제가 늦어지거나 실패할 수 있습니다.",
          actionForReader: "급한 결제는 잠시 뒤 다시 시도하도록 안내하면 됩니다.",
          termPairs: [{ original: "API", simplified: "시스템 연결" }]
        }
      })
    }
  );
  const markup = renderAppMarkup(nextState, {
    defaultExample: DEFAULT_EXAMPLE,
    examples: [DEFAULT_EXAMPLE]
  });

  assert.match(markup, /한 줄 요약/);
  assert.match(markup, /쉬운 설명/);
  assert.match(markup, /원문 대비/);
  assert.match(markup, /AI 번역/);
});

test("uses fallback mode when the API request fails", async () => {
  const state = await submitTranslationAsync(applyExample(createInitialState(), DEFAULT_EXAMPLE), {
    requestTranslation: async () => ({
      ok: false,
      message: "failed"
    })
  });

  assert.equal(state.engineSource, "fallback");
  assert.equal(state.feedback?.type, "warning");
});

test("marks state as loading before async translation completes", () => {
  const loadingState = startTranslation(applyExample(createInitialState(), DEFAULT_EXAMPLE));

  assert.equal(loadingState.isLoading, true);
});
