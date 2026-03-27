import test from "node:test";
import assert from "node:assert/strict";

import {
  detectUnsupportedScope,
  findReplySafetyIssues
} from "../../src/domain/safety.js";

test("flags unsupported work relationship input", () => {
  const verdict = detectUnsupportedScope({
    situationType: "favor",
    input: "팀장님이 오늘 밤까지 해달라고 했어요."
  });

  assert.equal(verdict.supported, false);
});

test("flags open-door language when alternatives are disabled", () => {
  const issues = findReplySafetyIssues("이번엔 어렵고 다음에 시간 되면 보자.", {
    includeAlternative: false
  });

  assert.equal(issues[0]?.code, "OPEN_DOOR_PHRASE");
  assert.match(issues[0]?.phrase ?? "", /다음에|시간 되면/);
});

test("flags follow-up reply requests as unsupported", () => {
  const verdict = detectUnsupportedScope({
    situationType: "favor",
    input: "내가 이미 한번 거절했는데 다시 뭐라고 답해야 할지 모르겠어."
  });

  assert.equal(verdict.supported, false);
});
