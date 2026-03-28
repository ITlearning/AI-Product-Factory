import test from "node:test";
import assert from "node:assert/strict";

import {
  assertCharacterResult,
  CHARACTER_RESULT_STATUS,
  OBSERVATIONAL_DISCLAIMER
} from "../../src/character-contract.js";
import { generateCharacterResult, parseTransactions } from "../../src/character-engine.js";
import { SAMPLE_NOTE, SAMPLE_TRANSACTIONS } from "../../src/content.js";

test("parses common spending lines with amounts and labels", () => {
  const transactions = parseTransactions(
    ["07:42 편의점 4,800원", "카카오T 택시 18,000원", "형식을 읽기 어려운 줄"].join("\n")
  );

  assert.equal(transactions.length, 2);
  assert.equal(transactions[0].label, "편의점");
  assert.equal(transactions[0].amount, 4800);
  assert.equal(transactions[1].category, "transport");
});

test("returns a contract-validated character result for the seeded sample", () => {
  const result = generateCharacterResult(SAMPLE_TRANSACTIONS.join("\n"), { note: SAMPLE_NOTE });

  assert.equal(result.status, CHARACTER_RESULT_STATUS.SUCCESS);
  assertCharacterResult(result);
  assert.equal(result.tags.length, 3);
  assert.ok(result.evidence.length >= 2 && result.evidence.length <= 3);
  assert.match(result.summary, /가까웠어요|읽혀요/);
  assert.equal(result.disclaimer, OBSERVATIONAL_DISCLAIMER);
});

test("returns a needs-more-data state when only one parsed transaction is available", () => {
  const result = generateCharacterResult("07:42 편의점 4,800원");

  assert.equal(result.status, CHARACTER_RESULT_STATUS.NEEDS_MORE_DATA);
  assertCharacterResult(result);
  assert.match(result.message, /재료가 조금 부족해요/);
});

test("returns a parse-failed state when no amount pattern is found", () => {
  const result = generateCharacterResult("오늘은 그냥 좀 바빴다\n택시를 탔다");

  assert.equal(result.status, CHARACTER_RESULT_STATUS.PARSE_FAILED);
  assertCharacterResult(result);
  assert.match(result.hint, /07:42 편의점 4,800원/);
});
