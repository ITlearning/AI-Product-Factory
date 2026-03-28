import test from "node:test";
import assert from "node:assert/strict";

import {
  BLOCKER_COACHING,
  getCoachingForBlocker,
  getRecommendedOptionIndex,
  getReplyToneByIndex
} from "../../src/domain/coaching.js";

test("returns the configured coaching mapping for a blocker", () => {
  assert.equal(BLOCKER_COACHING["tone-anxiety"].recommendedTone, "polite-firm");
  assert.match(BLOCKER_COACHING.overexplaining.coachNote, /한 문장/);
});

test("falls back to the default blocker coaching", () => {
  const coaching = getCoachingForBlocker("unknown");

  assert.equal(coaching.recommendedTone, "polite-firm");
});

test("maps recommendation order consistently", () => {
  assert.equal(getRecommendedOptionIndex("soft"), 0);
  assert.equal(getRecommendedOptionIndex("polite-firm"), 1);
  assert.equal(getReplyToneByIndex(2), "short");
});
