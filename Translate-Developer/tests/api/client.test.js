import test from "node:test";
import assert from "node:assert/strict";

import { requestAiTranslation } from "../../src/api/translate.js";

test("classifies a missing api route so the UI can explain local preview limits", async () => {
  const originalFetch = globalThis.fetch;

  globalThis.fetch = async () =>
    new Response("<html>Not Found</html>", {
      status: 404,
      headers: { "Content-Type": "text/html; charset=utf-8" }
    });

  try {
    const result = await requestAiTranslation("배포 후 에러가 납니다.", "pm-planner");

    assert.equal(result.ok, false);
    assert.equal(result.reason, "missing_api_route");
    assert.equal(result.status, 404);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("preserves missing api key failures from the translate api", async () => {
  const originalFetch = globalThis.fetch;

  globalThis.fetch = async () =>
    new Response(JSON.stringify({ error: "OPENAI_API_KEY is not configured." }), {
      status: 500,
      headers: { "Content-Type": "application/json; charset=utf-8" }
    });

  try {
    const result = await requestAiTranslation("배포 후 에러가 납니다.", "pm-planner");

    assert.equal(result.ok, false);
    assert.equal(result.reason, "missing_api_key");
    assert.equal(result.message, "OPENAI_API_KEY is not configured.");
    assert.equal(result.status, 500);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("classifies an upstream rate limit even when the api route wraps it", async () => {
  const originalFetch = globalThis.fetch;

  globalThis.fetch = async () =>
    new Response(JSON.stringify({ error: "Rate limit reached.", upstreamStatus: 429 }), {
      status: 502,
      headers: { "Content-Type": "application/json; charset=utf-8" }
    });

  try {
    const result = await requestAiTranslation("배포 후 에러가 납니다.", "pm-planner");

    assert.equal(result.ok, false);
    assert.equal(result.reason, "rate_limited");
    assert.equal(result.status, 429);
  } finally {
    globalThis.fetch = originalFetch;
  }
});
