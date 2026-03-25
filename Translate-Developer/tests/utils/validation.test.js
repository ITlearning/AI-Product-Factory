import test from "node:test";
import assert from "node:assert/strict";

import { validateInput } from "../../src/utils/validation.js";

test("rejects empty text", () => {
  assert.equal(validateInput("   ").ok, false);
});

test("warns when the message is too long", () => {
  const result = validateInput("a".repeat(1201));

  assert.equal(result.ok, true);
  assert.match(result.reason, /맥락을 함께 넣는 건 좋지만/);
});
