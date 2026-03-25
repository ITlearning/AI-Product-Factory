import test from "node:test";
import assert from "node:assert/strict";

import {
  buildUserPrompt,
  extractStructuredResult,
  handleGenerateReplyRequest
} from "../../api/generate-reply.js";

function fakeRequest(body) {
  return {
    method: "POST",
    async json() {
      return body;
    }
  };
}

test("returns 400 for empty input", async () => {
  const response = await handleGenerateReplyRequest(
    fakeRequest({
      input: "",
      relationshipType: "just-friend",
      situationType: "promise",
      rejectionStrength: "polite-firm",
      includeAlternative: false
    }),
    { apiKey: "test-key" }
  );

  assert.equal(response.status, 400);
});

test("returns unsupported response for out-of-scope input", async () => {
  const response = await handleGenerateReplyRequest(
    fakeRequest({
      input: "팀장님이 부탁했어요.",
      relationshipType: "barely-close",
      situationType: "favor",
      rejectionStrength: "polite-firm",
      includeAlternative: false
    }),
    { apiKey: "test-key" }
  );

  assert.equal(response.status, 422);
  const body = await response.json();
  assert.equal(body.code, "UNSUPPORTED_SCOPE");
});

test("returns normalized AI output for supported input", async () => {
  const response = await handleGenerateReplyRequest(
    fakeRequest({
      input: "친구가 오늘 저녁에 만나자고 했는데 쉬고 싶다.",
      relationshipType: "just-friend",
      situationType: "promise",
      rejectionStrength: "polite-firm",
      includeAlternative: false
    }),
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
          {
            status: 200,
            headers: { "Content-Type": "application/json" }
          }
        )
    }
  );

  assert.equal(response.status, 200);
  const body = await response.json();
  assert.equal(body.result.replyOptions.length, 3);
});

test("returns typed unsafe-result errors", async () => {
  const response = await handleGenerateReplyRequest(
    fakeRequest({
      input: "친구가 오늘 보자고 했는데 가기 싫다.",
      relationshipType: "just-friend",
      situationType: "promise",
      rejectionStrength: "polite-firm",
      includeAlternative: false
    }),
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
          {
            status: 200,
            headers: { "Content-Type": "application/json" }
          }
        )
    }
  );

  assert.equal(response.status, 502);
  const body = await response.json();
  assert.equal(body.code, "UNSAFE_RESULT");
});

test("returns invalid-schema errors when AI output is malformed", async () => {
  const response = await handleGenerateReplyRequest(
    fakeRequest({
      input: "친구 부탁을 거절하고 싶다.",
      relationshipType: "just-friend",
      situationType: "favor",
      rejectionStrength: "polite-firm",
      includeAlternative: false
    }),
    {
      apiKey: "test-key",
      fetchImpl: async () =>
        new Response(
          JSON.stringify({
            output: [{ content: [{ json: { replyOptions: [{ text: "하나만 있음" }] } }] }]
          }),
          {
            status: 200,
            headers: { "Content-Type": "application/json" }
          }
        )
    }
  );

  assert.equal(response.status, 502);
  const body = await response.json();
  assert.equal(body.code, "INVALID_AI_SCHEMA");
});

test("extracts structured result from payload content", () => {
  const result = extractStructuredResult({
    output: [
      {
        content: [
          {
            json: {
              replyOptions: [
                { text: "이번엔 어렵겠어.", toneLabel: "정중한 버전", whyItWorks: "짧다." },
                { text: "이번엔 안 될 것 같아.", toneLabel: "자연스러운 버전", whyItWorks: "자연스럽다." },
                { text: "이번 요청은 어려워.", toneLabel: "단호한 버전", whyItWorks: "분명하다." }
              ],
              avoidPhrases: ["다음에 보자"],
              openDoorRisk: "low",
              alternativeDifference: "대안을 빼면 더 깔끔하다."
            }
          }
        ]
      }
    ]
  });

  assert.equal(result?.replyOptions[0].toneLabel, "정중한 버전");
});

test("builds an OpenAI user prompt from the request payload", () => {
  const prompt = buildUserPrompt({
    input: "친구 약속을 거절하고 싶어.",
    relationshipType: "just-friend",
    situationType: "promise",
    rejectionStrength: "polite-firm",
    includeAlternative: false
  });

  assert.match(prompt, /관계 타입: just-friend/);
  assert.match(prompt, /대안 제시 여부: 안 한다/);
});
