import test from "node:test";
import assert from "node:assert/strict";

import { PREVIEW_RESULT, SAMPLE_TRANSACTIONS, SHELL_MILESTONES } from "../../src/content.js";
import { renderAppMarkup } from "../../src/app.js";

test("renders the spending personality shell", () => {
  const markup = renderAppMarkup();

  assert.match(markup, /오늘의 소비를 캐릭터처럼 읽어보는 첫 화면/);
  assert.match(markup, /캐릭터 만들기 준비 중/);
  assert.match(markup, /Delivery path/);
});

test("shows seeded sample transactions in the input shell", () => {
  const markup = renderAppMarkup();

  for (const transaction of SAMPLE_TRANSACTIONS) {
    assert.match(markup, new RegExp(transaction.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")));
  }
});

test("includes the preview result and next milestones", () => {
  const markup = renderAppMarkup();

  assert.match(markup, new RegExp(PREVIEW_RESULT.title));

  for (const milestone of SHELL_MILESTONES) {
    assert.match(markup, new RegExp(milestone.title));
  }
});
