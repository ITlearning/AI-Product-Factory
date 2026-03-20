import test from "node:test";
import assert from "node:assert/strict";

import { validateInput } from "../../src/utils/validation.js";

test("rejects empty text", () => {
  assert.equal(validateInput("   ").ok, false);
});

test("warns when the message is too long", () => {
  const result = validateInput("a".repeat(281));

  assert.equal(result.ok, true);
  assert.match(result.reason, /짧은 메시지/);
});
