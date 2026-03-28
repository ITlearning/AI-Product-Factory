import test from "node:test";
import assert from "node:assert/strict";

import { DEFAULT_EXAMPLE } from "../../src/data/examples.js";
import { DEFAULT_AUDIENCE } from "../../src/data/audiences.js";
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

  assert.match(markup, /개발자 설명을 함께 일하는 비개발자가 이해하게 풀어줍니다/);
  assert.match(markup, /PM\/기획자/);
  assert.match(markup, /쉽게 풀어보기/);
});

test("loads an example message into state", () => {
  const state = applyExample(createInitialState(), DEFAULT_EXAMPLE);

  assert.equal(state.input, DEFAULT_EXAMPLE);
});

test("defaults the selected audience to PM/기획자", () => {
  const state = createInitialState();

  assert.equal(state.audience, DEFAULT_AUDIENCE);
});

test("renders translated output after submit", async () => {
  const nextState = await submitTranslationAsync(
    applyExample(createInitialState(), DEFAULT_EXAMPLE),
    {
      requestTranslation: async () => ({
        ok: true,
        result: {
          rewrittenMessage: "배포 뒤 결제 연결이 자주 늦어지거나 끊겨서, 지금 원인을 확인하고 있어요.",
          confirmedImpact: "이 메시지에는 실제 사용자 결제 실패가 직접적으로 적혀 있지 않아요.",
          needsMoreContext: "실제 결제 실패가 얼마나 발생하는지는 앞뒤 대화가 더 있으면 명확해져요.",
          termExplanations: [{ term: "API", explanation: "시스템끼리 정보를 주고받는 연결" }]
        }
      })
    }
  );
  const markup = renderAppMarkup(nextState, {
    defaultExample: DEFAULT_EXAMPLE,
    examples: [DEFAULT_EXAMPLE]
  });

  assert.match(markup, /쉽게 다시 쓴 내용/);
  assert.match(markup, /전문 용어 풀이/);
  assert.match(markup, /더 알려주면 정확해지는 부분/);
  assert.match(markup, /AI 설명/);
});

test("uses fallback mode when the API request fails", async () => {
  const state = await submitTranslationAsync(applyExample(createInitialState(), DEFAULT_EXAMPLE), {
    requestTranslation: async () => ({
      ok: false,
      message: "failed",
      reason: "upstream_failure"
    })
  });

  assert.equal(state.engineSource, "fallback");
  assert.equal(state.feedback?.type, "warning");
  assert.match(state.feedback?.message ?? "", /AI 응답이 불안정해 기본 설명 모드로 전환했습니다/);
});

test("explains when the local preview is missing the translate api route", async () => {
  const state = await submitTranslationAsync(applyExample(createInitialState(), DEFAULT_EXAMPLE), {
    requestTranslation: async () => ({
      ok: false,
      message: "AI 설명 요청에 실패했습니다.",
      reason: "missing_api_route",
      status: 404
    })
  });

  assert.equal(state.engineSource, "fallback");
  assert.match(state.feedback?.message ?? "", /AI 서버 경로\(\/api\/translate\)/);
  assert.match(state.feedback?.message ?? "", /vercel dev/);
});

test("explains when the OpenAI API key is missing", async () => {
  const state = await submitTranslationAsync(applyExample(createInitialState(), DEFAULT_EXAMPLE), {
    requestTranslation: async () => ({
      ok: false,
      message: "OPENAI_API_KEY is not configured.",
      reason: "missing_api_key",
      status: 500
    })
  });

  assert.equal(state.engineSource, "fallback");
  assert.match(state.feedback?.message ?? "", /OpenAI API 키가 설정되지 않아/);
});

test("passes the selected audience into the async translation request", async () => {
  let capturedAudience = "";
  const state = await submitTranslationAsync(applyExample(createInitialState(), DEFAULT_EXAMPLE), {
    requestTranslation: async (_input, audience) => {
      capturedAudience = audience;
      return {
        ok: true,
        result: {
          rewrittenMessage: "쉽게 풀어쓴 내용",
          confirmedImpact: "확인된 영향이 아직 명확하지 않아요.",
          needsMoreContext: "앞뒤 대화가 더 있으면 정확해져요.",
          termExplanations: []
        }
      };
    }
  });

  assert.equal(capturedAudience, DEFAULT_AUDIENCE);
  assert.equal(state.engineSource, "ai");
});

test("marks state as loading before async translation completes", () => {
  const loadingState = startTranslation(applyExample(createInitialState(), DEFAULT_EXAMPLE));

  assert.equal(loadingState.isLoading, true);
});
