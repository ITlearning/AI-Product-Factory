import test from "node:test";
import assert from "node:assert/strict";

import { generateCharacterResult } from "../../src/character-engine.js";
import { SAMPLE_NOTE, SAMPLE_TRANSACTIONS, SHELL_MILESTONES } from "../../src/content.js";
import { escapeHtml, renderAppMarkup } from "../../src/app.js";

test("renders the spending personality shell", () => {
  const markup = renderAppMarkup();

  assert.match(markup, /오늘의 소비를 캐릭터처럼 읽어보는 첫 화면/);
  assert.match(markup, /캐릭터 만들기 준비 중/);
  assert.match(markup, /Delivery path/);
  assert.match(markup, /입력된 소비 문장을 바탕으로 한 가벼운 해석/);
});

test("shows seeded sample transactions in the input shell", () => {
  const markup = renderAppMarkup();

  for (const transaction of SAMPLE_TRANSACTIONS) {
    assert.match(markup, new RegExp(escapeRegExp(transaction)));
  }
});

test("includes the preview result and next milestones", () => {
  const markup = renderAppMarkup();
  const previewResult = generateCharacterResult(SAMPLE_TRANSACTIONS.join("\n"), { note: SAMPLE_NOTE });

  assert.equal(previewResult.status, "success");
  assert.match(markup, new RegExp(escapeRegExp(previewResult.characterName)));
  assert.match(markup, new RegExp(escapeRegExp(previewResult.nextMove)));

  for (const milestone of SHELL_MILESTONES) {
    assert.match(markup, new RegExp(escapeRegExp(milestone.title)));
  }
});

test("escapes interpolated strings before they enter markup", () => {
  assert.equal(
    escapeHtml(`<&>"'`),
    "&lt;&amp;&gt;&quot;&#39;"
  );
});

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}
