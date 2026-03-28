import test from "node:test";
import assert from "node:assert/strict";

import { generateCharacterResult } from "../../src/character-engine.js";
import { PREVIEW_CASES, SAMPLE_NOTE, SAMPLE_TRANSACTIONS } from "../../src/content.js";
import { escapeHtml, getPreviewModel, renderAppMarkup } from "../../src/app.js";

test("renders the result-first spending personality screen", () => {
  const markup = renderAppMarkup();

  assert.match(markup, /오늘 나는 어떤 소비 캐릭터였는지 10초 안에 이해하는 결과 화면/);
  assert.match(markup, /다른 하루로 다시 생성/);
  assert.match(markup, /저장\/공유 카드/);
  assert.match(markup, /해석에 쓰인 소비 로그/);
});

test("shows seeded sample transactions in the source snapshot", () => {
  const markup = renderAppMarkup();

  for (const transaction of SAMPLE_TRANSACTIONS) {
    assert.match(markup, new RegExp(escapeRegExp(transaction)));
  }
});

test("includes the preview result, action hint, and share card content", () => {
  const markup = renderAppMarkup();
  const previewResult = generateCharacterResult(SAMPLE_TRANSACTIONS.join("\n"), { note: SAMPLE_NOTE });
  const preview = getPreviewModel();

  assert.equal(previewResult.status, "success");
  assert.match(markup, new RegExp(escapeRegExp(previewResult.characterName)));
  assert.match(markup, new RegExp(escapeRegExp(previewResult.nextMove)));
  assert.match(markup, new RegExp(escapeRegExp(preview.previewCase.title)));
  assert.match(markup, new RegExp(escapeRegExp(preview.totalAmountText)));
});

test("escapes interpolated strings before they enter markup", () => {
  assert.equal(
    escapeHtml(`<&>"'`),
    "&lt;&amp;&gt;&quot;&#39;"
  );
});

test("supports alternate preview cases through wrapped scenario indexes", () => {
  const secondPreview = getPreviewModel(1);
  const wrappedPreview = getPreviewModel(PREVIEW_CASES.length + 1);
  const markup = renderAppMarkup({ scenarioIndex: PREVIEW_CASES.length + 1 });

  assert.equal(wrappedPreview.previewCase.label, secondPreview.previewCase.label);
  assert.match(markup, new RegExp(escapeRegExp(secondPreview.previewCase.note)));
  assert.match(markup, new RegExp(escapeRegExp(secondPreview.result.characterName)));
});

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}
