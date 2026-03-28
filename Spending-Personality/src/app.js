import {
  HERO_POINTS,
  INPUT_PLACEHOLDER,
  SAMPLE_NOTE,
  SAMPLE_TRANSACTIONS,
  SHELL_MILESTONES
} from "./content.js";
import { CHARACTER_RESULT_STATUS } from "./character-contract.js";
import { generateCharacterResult, parseTransactions } from "./character-engine.js";

/**
 * @param {string} value
 * @returns {string}
 */
export function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

export function createInitialAppState() {
  return {
    transactionsInput: "",
    note: "",
    hasGenerated: false
  };
}

/**
 * @param {HTMLElement} root
 */
export function createApp(root) {
  const state = createInitialAppState();
  root.innerHTML = renderAppMarkup(state);

  const form = root.querySelector("[data-composer-form]");
  const transactionsInput = root.querySelector("[data-transactions-input]");
  const noteInput = root.querySelector("[data-note-input]");
  const generateButton = root.querySelector("[data-generate-button]");
  const fillSampleButton = root.querySelector("[data-action='fill-sample']");
  const clearButton = root.querySelector("[data-action='clear-input']");
  const summarySlot = root.querySelector("[data-input-summary]");
  const previewSlot = root.querySelector("[data-preview-panel]");
  const footerCopy = root.querySelector("[data-footer-copy]");

  if (
    !(form instanceof HTMLFormElement) ||
    !(transactionsInput instanceof HTMLTextAreaElement) ||
    !(noteInput instanceof HTMLInputElement) ||
    !(generateButton instanceof HTMLButtonElement) ||
    !(fillSampleButton instanceof HTMLButtonElement) ||
    !(clearButton instanceof HTMLButtonElement) ||
    !(summarySlot instanceof HTMLElement) ||
    !(previewSlot instanceof HTMLElement) ||
    !(footerCopy instanceof HTMLElement)
  ) {
    throw new Error("App shell did not render the expected interactive elements");
  }

  const applyViewModel = () => {
    const viewModel = buildAppViewModel(state);

    generateButton.disabled = !viewModel.canGenerate;
    generateButton.textContent = viewModel.buttonLabel;
    fillSampleButton.textContent = viewModel.sampleButtonLabel;
    clearButton.disabled = !viewModel.canClear;
    footerCopy.textContent = viewModel.footerCopy;
    summarySlot.innerHTML = renderInputSummaryMarkup(viewModel);
    previewSlot.innerHTML = renderPreviewMarkup(viewModel);
  };

  const syncDraftFromDom = () => {
    state.transactionsInput = transactionsInput.value;
    state.note = noteInput.value;
  };

  form.addEventListener("submit", (event) => {
    event.preventDefault();
    syncDraftFromDom();

    if (!buildAppViewModel(state).canGenerate) {
      applyViewModel();
      return;
    }

    state.hasGenerated = true;
    applyViewModel();
  });

  root.addEventListener("input", (event) => {
    if (event.target !== transactionsInput && event.target !== noteInput) {
      return;
    }

    syncDraftFromDom();
    state.hasGenerated = false;
    applyViewModel();
  });

  root.addEventListener("click", (event) => {
    const actionTarget = event.target instanceof HTMLElement
      ? event.target.closest("[data-action]")
      : null;
    const action = actionTarget instanceof HTMLElement ? actionTarget.dataset.action : null;

    if (action === "fill-sample") {
      state.transactionsInput = SAMPLE_TRANSACTIONS.join("\n");
      state.note = SAMPLE_NOTE;
      state.hasGenerated = false;
      transactionsInput.value = state.transactionsInput;
      noteInput.value = state.note;
      applyViewModel();
      transactionsInput.focus();
      transactionsInput.setSelectionRange(
        state.transactionsInput.length,
        state.transactionsInput.length
      );
    }

    if (action === "clear-input") {
      state.transactionsInput = "";
      state.note = "";
      state.hasGenerated = false;
      transactionsInput.value = "";
      noteInput.value = "";
      applyViewModel();
      transactionsInput.focus();
    }
  });

  applyViewModel();
}

/**
 * @param {{
 *   transactionsInput?: string;
 *   note?: string;
 *   hasGenerated?: boolean;
 * }} [state]
 */
export function renderAppMarkup(state = createInitialAppState()) {
  const viewModel = buildAppViewModel(state);

  return `
    <main class="page-shell">
      <section class="hero-card">
        <div class="hero-copy">
          <span class="eyebrow">Paste-first spending character</span>
          <h1>오늘의 소비를 캐릭터처럼 읽어보는 첫 화면</h1>
          <p>
            카드 문자, 메신저 메모, 가계부 메모를 그대로 붙여넣고 오늘 소비의 분위기를
            바로 미리 볼 수 있는 입력 화면입니다. 형식을 엄격하게 강요하기보다, 금액이
            보이는 줄부터 부드럽게 읽어내는 MVP 흐름에 맞춰 구성했습니다.
          </p>
          <ul class="hero-points">
            ${HERO_POINTS.map((point) => `<li>${escapeHtml(point)}</li>`).join("")}
          </ul>
        </div>

        <aside class="hero-preview" aria-label="결과 예시">
          ${renderHeroPreview()}
        </aside>
      </section>

      <section class="workspace-grid">
        <section class="panel composer-panel" aria-labelledby="composer-title">
          <div class="panel-head">
            <p class="panel-kicker">Input</p>
            <h2 id="composer-title">붙여넣기 중심 입력 구역</h2>
          </div>

          <p class="composer-intro">
            메시지 원문을 예쁘게 다듬지 않아도 괜찮아요. 금액이 있는 줄부터 읽고, 설명이나
            메모 줄은 잠시 건너뛰면서 기본 흐름을 이어갑니다.
          </p>

          <div class="format-showcase" aria-label="예시 포맷">
            ${SAMPLE_TRANSACTIONS.map(
              (transaction) => `
                <div class="format-card">
                  <span>예시</span>
                  <strong>${escapeHtml(transaction)}</strong>
                </div>
              `
            ).join("")}
          </div>

          <form class="composer-form" data-composer-form>
            <label class="field">
              <span>하루 소비 내역</span>
              <p class="field-hint">카드 문자, 알림 텍스트, 메모를 여러 줄로 붙여넣어 주세요.</p>
              <textarea
                name="transactions"
                placeholder="${escapeHtml(INPUT_PLACEHOLDER)}"
                data-transactions-input
              >${escapeHtml(viewModel.transactionsInput)}</textarea>
            </label>

            <label class="field">
              <span>선택 메모</span>
              <p class="field-hint">오늘 분위기나 상황이 있으면 한 줄만 더 적어 주세요.</p>
              <input
                name="note"
                placeholder="예: 야근 후라 배달과 택시가 몰린 날"
                value="${escapeHtml(viewModel.note)}"
                data-note-input
              />
            </label>

            <div class="button-row">
              <div class="button-group">
                <button type="button" class="ghost-button" data-action="fill-sample">
                  ${escapeHtml(viewModel.sampleButtonLabel)}
                </button>
                <button
                  type="button"
                  class="ghost-button"
                  data-action="clear-input"
                  ${viewModel.canClear ? "" : "disabled"}
                >
                  모두 지우기
                </button>
              </div>

              <div class="summary-strip" data-input-summary>
                ${renderInputSummaryMarkup(viewModel)}
              </div>
            </div>

            <div class="composer-footer">
              <button
                type="submit"
                class="primary-button"
                data-generate-button
                ${viewModel.canGenerate ? "" : "disabled"}
              >
                ${escapeHtml(viewModel.buttonLabel)}
              </button>
              <p data-footer-copy>${escapeHtml(viewModel.footerCopy)}</p>
            </div>
          </form>
        </section>

        <section class="panel insight-panel" aria-labelledby="insight-title">
          <div class="panel-head">
            <p class="panel-kicker">Preview</p>
            <h2 id="insight-title">생성 전 기대감과 결과 흐름</h2>
          </div>

          <div class="preview-stack" data-preview-panel aria-live="polite">
            ${renderPreviewMarkup(viewModel)}
          </div>
        </section>
      </section>

      <section class="panel roadmap-panel" aria-labelledby="roadmap-title">
        <div class="panel-head">
          <p class="panel-kicker">Delivery path</p>
          <h2 id="roadmap-title">이 셸 위에 이어질 다음 단계</h2>
        </div>

        <div class="milestone-grid">
          ${SHELL_MILESTONES.map(
            (item) => `
              <article class="milestone-card">
                <span>${escapeHtml(item.label)}</span>
                <strong>${escapeHtml(item.title)}</strong>
                <p>${escapeHtml(item.copy)}</p>
              </article>
            `
          ).join("")}
        </div>
      </section>
    </main>
  `;
}

/**
 * @param {{
 *   transactionsInput?: string;
 *   note?: string;
 *   hasGenerated?: boolean;
 * }} state
 */
export function buildAppViewModel(state) {
  const transactionsInput = state.transactionsInput ?? "";
  const note = state.note ?? "";
  const hasGenerated = Boolean(state.hasGenerated);
  const hasInput = transactionsInput.trim().length > 0;
  const parsedTransactions = parseTransactions(transactionsInput);
  const rawLines = splitInputLines(transactionsInput);
  const rawLineCount = rawLines.length;
  const parsedTransactionCount = parsedTransactions.length;
  const ignoredLineCount = Math.max(rawLineCount - parsedTransactionCount, 0);
  const samplePreview = getPreviewResult();

  if (!hasInput) {
    return {
      transactionsInput,
      note,
      hasGenerated,
      hasInput,
      canGenerate: false,
      canClear: note.trim().length > 0,
      buttonLabel: "소비를 붙여넣으면 열립니다",
      sampleButtonLabel: "샘플 넣어보기",
      footerCopy: "예시를 눌러 바로 체험하거나, 카드 문자/메모를 그대로 붙여넣어 보세요.",
      previewState: "example",
      rawLineCount,
      parsedTransactionCount,
      ignoredLineCount,
      parsedTransactions,
      result: samplePreview
    };
  }

  const result = generateCharacterResult(transactionsInput, { note });

  return {
    transactionsInput,
    note,
    hasGenerated,
    hasInput,
    canGenerate: true,
    canClear: hasInput || note.trim().length > 0,
    buttonLabel: hasGenerated ? "다시 캐릭터 보기" : "오늘의 소비 캐릭터 보기",
    sampleButtonLabel: "샘플로 빠르게 보기",
    footerCopy: getFooterCopy(hasGenerated, result.status),
    previewState: getPreviewState(hasGenerated, result.status),
    rawLineCount,
    parsedTransactionCount,
    ignoredLineCount,
    parsedTransactions,
    result
  };
}

/**
 * @param {ReturnType<typeof buildAppViewModel>} viewModel
 * @returns {string}
 */
export function renderInputSummaryMarkup(viewModel) {
  if (!viewModel.hasInput) {
    return `
      <span class="summary-pill">입력 전</span>
      <span class="summary-pill">금액 줄 2건이면 충분</span>
      <span class="summary-pill">예시 포맷 제공</span>
    `;
  }

  return `
    <span class="summary-pill">총 ${viewModel.rawLineCount}줄</span>
    <span class="summary-pill">읽힘 ${viewModel.parsedTransactionCount}줄</span>
    <span class="summary-pill">건너뜀 ${viewModel.ignoredLineCount}줄</span>
  `;
}

/**
 * @param {ReturnType<typeof buildAppViewModel>} viewModel
 * @returns {string}
 */
export function renderPreviewMarkup(viewModel) {
  if (viewModel.previewState === "example") {
    return renderExamplePreview(viewModel.result);
  }

  if (viewModel.result.status === CHARACTER_RESULT_STATUS.SUCCESS) {
    return renderSuccessPreview(viewModel);
  }

  return renderFeedbackPreview(viewModel);
}

function renderHeroPreview() {
  const previewResult = getPreviewResult();

  return `
    <span class="preview-label">Preview</span>
    <strong class="preview-title">${escapeHtml(previewResult.characterName)}</strong>
    <p class="preview-summary">${escapeHtml(previewResult.summary)}</p>
    <div class="tag-list">
      ${previewResult.tags
        .map((tag) => `<span class="tag-pill">${escapeHtml(tag)}</span>`)
        .join("")}
    </div>
  `;
}

/**
 * @param {ReturnType<typeof getPreviewResult>} previewResult
 * @returns {string}
 */
function renderExamplePreview(previewResult) {
  return `
    <div class="status-banner">
      <p class="status-label">결과 예시</p>
      <h3>${escapeHtml(previewResult.characterName)}</h3>
      <p>${escapeHtml(previewResult.summary)}</p>
    </div>

    <div class="tag-list">
      ${previewResult.tags
        .map((tag) => `<span class="tag-pill">${escapeHtml(tag)}</span>`)
        .join("")}
    </div>

    <p class="preview-caption">
      아직 입력 전이어도 이 서비스가 어떤 톤의 캐릭터를 보여주는지 바로 감을 잡을 수
      있도록 예시 결과를 먼저 보여줍니다.
    </p>

    <div class="inline-hint">
      카드 문자처럼 보이는 소비 줄을 2개 이상 붙여넣으면 버튼이 활성화됩니다.
    </div>
  `;
}

/**
 * @param {ReturnType<typeof buildAppViewModel>} viewModel
 * @returns {string}
 */
function renderSuccessPreview(viewModel) {
  const isGenerated = viewModel.previewState === "generated-success";
  const result = viewModel.result;

  return `
    <div class="status-banner">
      <p class="status-label">${isGenerated ? "생성 완료" : "생성 전 미리보기"}</p>
      <h3>${escapeHtml(result.characterName)}</h3>
      <p>${escapeHtml(result.summary)}</p>
    </div>

    <div class="tag-list">
      ${result.tags.map((tag) => `<span class="tag-pill">${escapeHtml(tag)}</span>`).join("")}
    </div>

    <div class="summary-strip result-meta">
      ${renderInputSummaryMarkup(viewModel)}
    </div>

    <p class="pattern-note">${escapeHtml(result.patternObservation)}</p>

    ${
      isGenerated
        ? `
          <ul class="evidence-grid">
            ${result.evidence
              .map(
                (evidence) => `
                  <li class="evidence-card">
                    <div class="evidence-head">
                      <strong>${escapeHtml(evidence.label)}</strong>
                      <span>${escapeHtml(evidence.amountText)}</span>
                    </div>
                    <p>${escapeHtml(evidence.reason)}</p>
                  </li>
                `
              )
              .join("")}
          </ul>

          <div class="next-move">
            <span>내일의 한 수</span>
            <strong>${escapeHtml(result.nextMove)}</strong>
          </div>

          <p class="result-disclaimer">${escapeHtml(result.disclaimer)}</p>
        `
        : `
          ${renderParsedTransactionMarkup(viewModel.parsedTransactions)}
          <div class="inline-hint">
            버튼을 누르면 근거 카드와 내일의 한 수까지 같은 톤으로 이어서 펼쳐집니다.
          </div>
        `
    }
  `;
}

/**
 * @param {ReturnType<typeof buildAppViewModel>} viewModel
 * @returns {string}
 */
function renderFeedbackPreview(viewModel) {
  const isGenerated = viewModel.previewState === "generated-feedback";
  const statusLabel = isGenerated ? "생성 가이드" : "입력 중 가이드";

  return `
    <div class="feedback-card">
      <p class="status-label">${statusLabel}</p>
      <h3>${escapeHtml(viewModel.result.message)}</h3>
      <p>${escapeHtml(viewModel.result.hint)}</p>
    </div>

    <div class="summary-strip result-meta">
      ${renderInputSummaryMarkup(viewModel)}
    </div>

    ${renderParsedTransactionMarkup(viewModel.parsedTransactions)}

    <div class="inline-hint">
      설명 줄이나 메모가 섞여도 괜찮아요. 금액이 보이는 소비 줄만 2건 이상 있으면
      캐릭터 흐름을 이어갈 수 있습니다.
    </div>

    <div class="format-reminder">
      ${SAMPLE_TRANSACTIONS.slice(0, 2)
        .map((transaction) => `<span>${escapeHtml(transaction)}</span>`)
        .join("")}
    </div>
  `;
}

/**
 * @param {ReturnType<typeof parseTransactions>} transactions
 * @returns {string}
 */
function renderParsedTransactionMarkup(transactions) {
  if (transactions.length === 0) {
    return "";
  }

  return `
    <ul class="parsed-list">
      ${transactions
        .slice(0, 3)
        .map(
          (transaction) => `
            <li class="parsed-card">
              <strong>${escapeHtml(transaction.label)}</strong>
              <span>${escapeHtml(transaction.amountText)}</span>
            </li>
          `
        )
        .join("")}
    </ul>
  `;
}

/**
 * @param {boolean} hasGenerated
 * @param {string} status
 * @returns {string}
 */
function getFooterCopy(hasGenerated, status) {
  if (hasGenerated) {
    return "입력을 바꾸면 다시 미리보기 상태로 돌아가고, 현재 내용으로 곧바로 다시 생성할 수 있어요.";
  }

  if (status === CHARACTER_RESULT_STATUS.SUCCESS) {
    return "지금도 분위기는 읽히고 있어요. 버튼을 누르면 근거 카드와 내일의 한 수까지 펼쳐집니다.";
  }

  if (status === CHARACTER_RESULT_STATUS.NEEDS_MORE_DATA) {
    return "금액이 있는 소비 줄을 하나만 더 붙여넣으면 기본 흐름을 유지한 채 캐릭터를 만들 수 있어요.";
  }

  return "형식을 엄격하게 맞출 필요는 없지만, 금액이 보이는 소비 줄이 필요합니다.";
}

/**
 * @param {boolean} hasGenerated
 * @param {string} status
 * @returns {"example" | "anticipation" | "generated-success" | "input-feedback" | "generated-feedback"}
 */
function getPreviewState(hasGenerated, status) {
  if (status === CHARACTER_RESULT_STATUS.SUCCESS) {
    return hasGenerated ? "generated-success" : "anticipation";
  }

  return hasGenerated ? "generated-feedback" : "input-feedback";
}

/**
 * @param {string} input
 * @returns {string[]}
 */
function splitInputLines(input) {
  return input
    .split(/\r?\n/u)
    .map((line) => line.trim())
    .filter(Boolean);
}

function getPreviewResult() {
  const result = generateCharacterResult(SAMPLE_TRANSACTIONS.join("\n"), { note: SAMPLE_NOTE });

  if (result.status !== CHARACTER_RESULT_STATUS.SUCCESS) {
    throw new Error("Sample preview must generate a success result");
  }

  return result;
}
