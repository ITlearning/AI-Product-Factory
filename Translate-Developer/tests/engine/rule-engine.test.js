import test from "node:test";
import assert from "node:assert/strict";

import { translateWithRules } from "../../src/engine/index.js";

test("maps technical phrases into simpler explanations", () => {
  const result = translateWithRules("배포 후 결제 API에서 타임아웃이 반복돼서 확인 중입니다.");

  assert.match(result.rewrittenMessage, /원인을 확인하고 있어요|원인을 살펴보고 있어요/);
  assert.deepEqual(result.termExplanations[0], {
    term: "타임아웃",
    explanation: "응답이 늦거나 멈추는 문제"
  });
});

test("returns the full translation contract", () => {
  const result = translateWithRules("서버 에러 때문에 로그인 기능이 잠깐 불안정합니다.");

  assert.notEqual(result.rewrittenMessage, "");
  assert.notEqual(result.confirmedImpact, "");
  assert.notEqual(result.needsMoreContext, "");
  assert.ok(Array.isArray(result.termExplanations));
});

test("stays specific when the message already contains direct user impact", () => {
  const result = translateWithRules(
    "로그인 서버 에러 때문에 일부 사용자가 접속을 못 하고 있어서 긴급 대응 중입니다."
  );

  assert.match(result.confirmedImpact, /일부 사용자가 바로 영향을 받고/);
  assert.match(result.needsMoreContext, /원인|더/);
});

test("uses a friendly unknowns block instead of guessing", () => {
  const result = translateWithRules("알림 큐가 밀려서 발송이 조금 늦어지고 있습니다.");

  assert.match(result.rewrittenMessage, /처리 대기열이 쌓인 상태|평소보다 늦어지고/);
  assert.match(result.needsMoreContext, /이 대화만으로는|더 있으면 좋아요|앞뒤 대화/);
});
