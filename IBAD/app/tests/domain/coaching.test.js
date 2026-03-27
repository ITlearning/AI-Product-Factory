import test from "node:test";
import assert from "node:assert/strict";

import { BLOCKER_COACHING, getCoachingForBlocker } from "../../src/domain/coaching.js";

test("maps blocker types to a deterministic recommended tone and coach note", () => {
  assert.equal(BLOCKER_COACHING["tone-anxiety"].recommendedTone, "polite-firm");
  assert.match(BLOCKER_COACHING.overexplaining.coachNote, /한 문장/);
});

test("returns coaching details for a supported blocker type", () => {
  assert.deepEqual(getCoachingForBlocker("guilt"), {
    recommendedTone: "soft",
    coachNote: "미안함을 길게 풀어주기보다 결론 한 번, 감사 한 번이면 충분해요."
  });
});
