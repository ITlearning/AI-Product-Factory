import test from "node:test";
import assert from "node:assert/strict";

import { translateWithRules } from "../../src/engine/index.js";

test("maps technical phrases into simpler explanations", () => {
  const result = translateWithRules("배포 후 결제 API에서 타임아웃이 반복돼서 확인 중입니다.");

  assert.match(result.easyExplanation, /응답이 늦거나 멈추는 문제/);
  assert.deepEqual(result.termPairs[0], {
    original: "타임아웃",
    simplified: "응답이 늦거나 멈추는 문제"
  });
});

test("returns the full translation contract", () => {
  const result = translateWithRules("서버 에러 때문에 로그인 기능이 잠깐 불안정합니다.");

  assert.notEqual(result.summary, "");
  assert.notEqual(result.easyExplanation, "");
  assert.match(result.importantNow, /로그인/);
  assert.notEqual(result.actionForReader, "");
  assert.ok(Array.isArray(result.termPairs));
});

test("explains user impact more clearly for urgent login issues", () => {
  const result = translateWithRules(
    "로그인 서버 에러 때문에 일부 사용자가 접속을 못 하고 있어서 긴급 대응 중입니다."
  );

  assert.match(result.summary, /바로 대응이 필요한 문제|문제가 있습니다/);
  assert.match(result.easyExplanation, /일부 사용자가 바로 영향을 받고 있습니다/);
  assert.match(result.importantNow, /빠른 안내가 중요합니다/);
});

test("handles queue delay messages with a clearer plain-language explanation", () => {
  const result = translateWithRules("알림 큐가 밀려서 발송이 조금 늦어지고 있습니다.");

  assert.match(result.summary, /늦어지고 있습니다|상황을 공유했습니다/);
  assert.match(result.easyExplanation, /처리 대기열이 쌓인 상태/);
  assert.match(result.actionForReader, /다른 채널 안내|안내/);
});
