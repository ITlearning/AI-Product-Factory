import test from "node:test";
import assert from "node:assert/strict";

import { CHARACTER_RESULT_STATUS } from "../../src/character-contract.js";
import {
  buildAppViewModel,
  createInitialAppState,
  escapeHtml,
  renderAppMarkup
} from "../../src/app.js";
import {
  INPUT_PLACEHOLDER,
  SAMPLE_NOTE,
  SAMPLE_TRANSACTIONS,
  SHELL_MILESTONES
} from "../../src/content.js";

test("renders the paste-first input screen with a disabled initial button", () => {
  const markup = renderAppMarkup();
  const viewModel = buildAppViewModel(createInitialAppState());

  assert.equal(viewModel.canGenerate, false);
  assert.equal(viewModel.previewState, "example");
  assert.match(markup, /붙여넣기 중심 입력 구역/);
  assert.match(markup, /소비를 붙여넣으면 열립니다/);
  assert.match(markup, /샘플 넣어보기/);
  assert.match(markup, new RegExp(escapeRegExp(INPUT_PLACEHOLDER.split("\n")[1])));
});

test("keeps the flow soft when mixed input includes only one parseable transaction", () => {
  const state = {
    transactionsInput: ["회의 끝나고 급히 이동", "18:34 카카오T 택시 14,200원"].join("\n"),
    note: "",
    hasGenerated: false
  };
  const viewModel = buildAppViewModel(state);
  const markup = renderAppMarkup(state);

  assert.equal(viewModel.previewState, "input-feedback");
  assert.equal(viewModel.result.status, CHARACTER_RESULT_STATUS.NEEDS_MORE_DATA);
  assert.equal(viewModel.parsedTransactionCount, 1);
  assert.equal(viewModel.ignoredLineCount, 1);
  assert.match(markup, /캐릭터를 만들기엔 재료가 조금 부족해요/);
  assert.match(markup, /설명 줄이나 메모가 섞여도 괜찮아요/);
});

test("builds an anticipation preview when enough parseable lines exist despite noise", () => {
  const state = {
    transactionsInput: [
      "오늘은 피곤해서 이동이 많았음",
      "07:42 신한 체크 GS25 성수점 4,800원",
      "18:34 카카오T 택시 14,200원"
    ].join("\n"),
    note: "야근한 날",
    hasGenerated: false
  };
  const viewModel = buildAppViewModel(state);

  assert.equal(viewModel.previewState, "anticipation");
  assert.equal(viewModel.result.status, CHARACTER_RESULT_STATUS.SUCCESS);
  assert.equal(viewModel.parsedTransactionCount, 2);
  assert.equal(viewModel.ignoredLineCount, 1);
  assert.match(viewModel.footerCopy, /근거 카드와 내일의 한 수/);
});

test("renders the full generated result after the user submits", () => {
  const state = {
    transactionsInput: SAMPLE_TRANSACTIONS.join("\n"),
    note: SAMPLE_NOTE,
    hasGenerated: true
  };
  const viewModel = buildAppViewModel(state);
  const markup = renderAppMarkup(state);

  assert.equal(viewModel.previewState, "generated-success");
  assert.equal(viewModel.result.status, CHARACTER_RESULT_STATUS.SUCCESS);
  assert.match(markup, new RegExp(escapeRegExp(viewModel.result.characterName)));
  assert.match(markup, new RegExp(escapeRegExp(viewModel.result.nextMove)));

  for (const evidence of viewModel.result.evidence) {
    assert.match(markup, new RegExp(escapeRegExp(evidence.label)));
  }

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
