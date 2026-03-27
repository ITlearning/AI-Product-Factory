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

function successfulReplySet() {
  return {
    replyOptions: [
      { text: "오늘은 좀 어려울 것 같아.", toneLabel: "부드럽게", whyItWorks: "부담을 낮춘다." },
      { text: "이번엔 어려워. 고마운데 패스할게.", toneLabel: "예의 있게 확실하게", whyItWorks: "균형이 좋다." },
      { text: "이번엔 어려워.", toneLabel: "짧게 끝내기", whyItWorks: "짧게 끝낸다." }
    ],
    recommendedTone: "polite-firm",
    coachNote: "예의는 유지하되 결론을 먼저 두면 차갑기보다 분명하게 읽혀요.",
    avoidPhrase: "나중에 보자"
  };
}

function unsafeReplySet() {
  return {
    replyOptions: [
      { text: "이번엔 어렵고 다음에 시간 되면 보자.", toneLabel: "부드럽게", whyItWorks: "부드럽다." },
      { text: "이번엔 안 될 것 같아.", toneLabel: "예의 있게 확실하게", whyItWorks: "짧다." },
      { text: "오늘은 안 될 것 같아.", toneLabel: "짧게 끝내기", whyItWorks: "분명하다." }
    ],
    recommendedTone: "soft",
    coachNote: "미안함을 길게 풀어주기보다 결론 한 번, 감사 한 번이면 충분해요.",
    avoidPhrase: "다음에 시간 되면 보자"
  };
}

test("returns 400 for empty input", async () => {
  const response = await handleGenerateReplyRequest(
    fakeRequest({
      input: "",
      situationType: "promise",
      blockerType: "tone-anxiety"
    }),
    { apiKey: "test-key" }
  );

  assert.equal(response.status, 400);
});

test("returns unsupported response for out-of-scope input", async () => {
  const response = await handleGenerateReplyRequest(
    fakeRequest({
      input: "팀장님이 오늘 부탁한 일을 대신해 달라고 했어요.",
      situationType: "favor",
      blockerType: "tone-anxiety"
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
      situationType: "promise",
      blockerType: "tone-anxiety"
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
                    json: successfulReplySet()
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
  assert.deepEqual(body.result, successfulReplySet());
});

test("returns typed unsafe-result errors", async () => {
  let callCount = 0;
  const response = await handleGenerateReplyRequest(
    fakeRequest({
      input: "친구가 오늘 보자고 했는데 가기 싫다.",
      situationType: "promise",
      blockerType: "guilt"
    }),
    {
      apiKey: "test-key",
      fetchImpl: async () => {
        callCount += 1;

        return new Response(
          JSON.stringify({
            output: [
              {
                content: [
                  {
                    json: unsafeReplySet()
                  }
                ]
              }
            ]
          }),
          {
            status: 200,
            headers: { "Content-Type": "application/json" }
          }
        );
      }
    }
  );

  assert.equal(response.status, 502);
  const body = await response.json();
  assert.equal(body.code, "UNSAFE_RESULT");
  assert.equal(callCount, 2);
});

test("retries once when the first AI result is unsafe", async () => {
  let callCount = 0;
  const response = await handleGenerateReplyRequest(
    fakeRequest({
      input: "친구가 오늘 보자고 했는데 쉬고 싶다.",
      situationType: "promise",
      blockerType: "overexplaining"
    }),
    {
      apiKey: "test-key",
      fetchImpl: async () => {
        callCount += 1;

        if (callCount === 1) {
          return new Response(
            JSON.stringify({
              output: [
                {
                content: [
                  {
                    json: unsafeReplySet()
                  }
                ]
              }
              ]
            }),
            {
              status: 200,
              headers: { "Content-Type": "application/json" }
            }
          );
        }

        return new Response(
          JSON.stringify({
            output: [
              {
                content: [
                  {
                    json: successfulReplySet()
                  }
                ]
              }
            ]
          }),
          {
            status: 200,
            headers: { "Content-Type": "application/json" }
          }
        );
      }
    }
  );

  assert.equal(response.status, 200);
  const body = await response.json();
  assert.equal(body.result.replyOptions.length, 3);
  assert.equal(callCount, 2);
});

test("returns invalid-schema errors when AI output is malformed", async () => {
  const response = await handleGenerateReplyRequest(
    fakeRequest({
      input: "친구 부탁을 거절하고 싶다.",
      situationType: "favor",
      blockerType: "tone-anxiety"
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
            json: successfulReplySet()
          }
        ]
      }
    ]
  });

  assert.equal(result?.replyOptions[0].toneLabel, "부드럽게");
});

test("builds an OpenAI user prompt from the request payload", () => {
  const prompt = buildUserPrompt({
    input: "친구 약속을 거절하고 싶어.",
    situationType: "promise",
    blockerType: "tone-anxiety"
  });

  assert.match(prompt, /상대 메시지를 받고도 답장을 못 보내는 사람/);
  assert.match(prompt, /상황 타입: promise/);
  assert.match(prompt, /막히는 이유: tone-anxiety/);
  assert.match(prompt, /추천 톤을 정할 기준/);
  assert.doesNotMatch(prompt, /관계 타입/);
  assert.doesNotMatch(prompt, /거절 강도/);
});
