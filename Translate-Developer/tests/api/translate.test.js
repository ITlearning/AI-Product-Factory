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
  summary: "결제 기능에 문제가 있어 확인 중입니다.",
  easyExplanation: "결제 관련 연결 문제 때문에 정상 처리되지 않을 수 있습니다.",
  importantNow: "지금은 결제가 늦어지거나 실패할 수 있습니다.",
  actionForReader: "급한 결제는 잠시 뒤 다시 시도하도록 안내하면 됩니다.",
  termPairs: [{ original: "API", simplified: "시스템 연결" }]
};

function fakeRequest(input) {
  return {
    method: "POST",
    async json() {
      return { input };
    }
  };
}

test("accepts a valid AI translation payload", () => {
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
