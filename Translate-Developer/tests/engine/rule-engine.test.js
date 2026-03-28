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

test("uses a PM-friendly tone when the PM audience is selected", () => {
  const result = translateWithRules(
    "A: 이거 retain cycle 나는 것 같은데, ViewModel에서 closure 캡처 방식 확인해봤어?",
    "pm-planner"
  );

  assert.match(result.rewrittenMessage, /확실한 내용과 아직 확인 중인 내용/);
  assert.match(result.needsMoreContext, /PM 관점에서 더 확인되면 좋은 점:/);
});

test("uses a designer-friendly tone when the designer audience is selected", () => {
  const result = translateWithRules(
    "로그인 서버 에러 때문에 일부 사용자가 접속을 못 하고 있어서 긴급 대응 중입니다.",
    "designer"
  );

  assert.match(result.rewrittenMessage, /화면이나 사용 흐름/);
  assert.match(result.confirmedImpact, /이용 중에 영향을 받고|정상적으로 들어오지 못하는/);
});

test("uses a non-developer-friendly tone when the non-developer audience is selected", () => {
  const result = translateWithRules(
    "배포 후 결제 API에서 타임아웃이 반복돼서 확인 중입니다.",
    "non-developer"
  );

  assert.match(result.rewrittenMessage, /평소처럼 잘 안 될 수 있어서/);
  assert.match(result.needsMoreContext, /조금 더 알면 이해가 쉬운 점:/);
});
