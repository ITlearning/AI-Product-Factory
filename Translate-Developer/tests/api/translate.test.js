import test from "node:test";
import assert from "node:assert/strict";

import {
  extractStructuredResult,
  handleTranslateRequest
} from "../../api/translate.js";
import {
  isValidTranslationResult,
  normalizeTranslationResult
} from "../../src/engine/schema.js";

const validPayload = {
  rewrittenMessage: "배포 뒤 결제 연결이 자주 늦어지거나 끊겨서, 지금 원인을 확인하고 있어요.",
  confirmedImpact: "이 메시지에는 실제 사용자 결제 실패가 직접적으로 적혀 있지 않아요.",
  needsMoreContext: "실제 결제 실패가 얼마나 발생하는지는 앞뒤 대화가 더 있으면 명확해져요.",
  termExplanations: [{ term: "API", explanation: "시스템끼리 정보를 주고받는 연결" }]
};

function fakeRequest(input, audience = "pm-planner") {
  return {
    method: "POST",
    async json() {
      return { input, audience };
    }
  };
}

test("accepts a valid role-aware translation payload", () => {
  assert.equal(isValidTranslationResult(validPayload), true);
  assert.deepEqual(normalizeTranslationResult(validPayload), validPayload);
});

test("returns 400 for empty input", async () => {
  const response = await handleTranslateRequest(fakeRequest(""), { apiKey: "test-key" });

  assert.equal(response.status, 400);
});

test("returns normalized structured output from the OpenAI response", async () => {
  const response = await handleTranslateRequest(fakeRequest("로그인 서버 에러입니다."), {
    apiKey: "test-key",
    fetchImpl: async () =>
      new Response(
        JSON.stringify({
          output: [
            {
              content: [
                {
                  type: "output_text",
                  text: JSON.stringify(validPayload)
                }
              ]
            }
          ]
        }),
        {
          status: 200,
          headers: { "Content-Type": "application/json" }
        }
      )
  });

  assert.equal(response.status, 200);

  const body = await response.json();
  assert.deepEqual(body.result, validPayload);
  assert.equal(body.source, "ai");
});

test("extracts structured result from json payload content", () => {
  const result = extractStructuredResult({
    output: [
      {
        content: [
          {
            json: validPayload
          }
        ]
      }
    ]
  });

  assert.deepEqual(result, validPayload);
});

test("extracts structured result from parsed payload content", () => {
  const result = extractStructuredResult({
    output: [
      {
        content: [
          {
            parsed: validPayload
          }
        ]
      }
    ]
  });

  assert.deepEqual(result, validPayload);
});

test("builds a PM/planner prompt that forbids guessing", async () => {
  let capturedBody = "";
  await handleTranslateRequest(fakeRequest("배포 후 결제 API에서 타임아웃이 반복돼서 확인 중입니다."), {
    apiKey: "test-key",
    fetchImpl: async (_url, init) => {
      capturedBody = String(init?.body ?? "");
      return new Response(JSON.stringify({ output: [{ content: [{ json: validPayload }] }] }), {
        status: 200,
        headers: { "Content-Type": "application/json" }
      });
    }
  });

  assert.match(capturedBody, /PM\/기획자/);
  assert.match(capturedBody, /추정하지 마라/);
});

test("preserves OpenAI rate limit status for the browser client", async () => {
  const response = await handleTranslateRequest(fakeRequest("로그인 서버 에러입니다."), {
    apiKey: "test-key",
    fetchImpl: async () =>
      new Response(
        JSON.stringify({
          error: {
            message: "Rate limit reached."
          }
        }),
        {
          status: 429,
          headers: { "Content-Type": "application/json" }
        }
      )
  });

  assert.equal(response.status, 429);

  const body = await response.json();
  assert.equal(body.error, "Rate limit reached.");
  assert.equal(body.upstreamStatus, 429);
});
