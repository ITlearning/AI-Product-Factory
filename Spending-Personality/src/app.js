import {
  HERO_POINTS,
  INPUT_PLACEHOLDER,
  PREVIEW_CASES,
  SAMPLE_NOTE,
  SAMPLE_TRANSACTIONS,
  SHELL_MILESTONES
} from "./content.js";
import { CHARACTER_RESULT_STATUS } from "./character-contract.js";
import { formatCurrency, generateCharacterResult, parseTransactions } from "./character-engine.js";
import {
  HISTORY_LIMIT,
  createHistoryEntry,
  loadHistoryEntries,
  recordHistoryEntry,
  saveHistoryEntries
} from "./history.js";

const HISTORY_PANEL_COPY = `최근 ${HISTORY_LIMIT}개 결과만 이 브라우저에 저장됩니다.`;

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
    hasGenerated: false,
    sampleIndex: 0,
    historyEntries: [],
    activeHistoryEntryId: null
  };
}

/**
 * @returns {Storage | null}
 */
function resolveStorage() {
  try {
    return globalThis.window?.localStorage ?? null;
  } catch {
    return null;
  }
}

/**
 * @param {object[]} historyEntries
 * @param {string | null | undefined} entryId
 * @returns {object | null}
 */
function findHistoryEntry(historyEntries, entryId) {
  if (!entryId) {
    return null;
  }

  return historyEntries.find((entry) => entry.id === entryId) ?? null;
}

/**
 * @param {object[]} historyEntries
 * @param {string} rawInput
 * @param {string} note
 * @returns {object | null}
 */
function findMatchingHistoryEntry(historyEntries, rawInput, note) {
  const normalizedInput = rawInput.trim();
  const normalizedNote = note.trim();

  return (
    historyEntries.find(
      (entry) => entry.rawInput === normalizedInput && entry.note === normalizedNote
    ) ?? null
  );
}

/**
 * @param {object} entry
 * @returns {number}
 */
function findSampleIndexForHistoryEntry(entry) {
  const foundIndex = PREVIEW_CASES.findIndex(
    (previewCase) =>
      previewCase.transactions.join("\n") === entry.rawInput &&
      (previewCase.note ?? "").trim() === entry.note
  );

  return foundIndex >= 0 ? foundIndex : 0;
}

/**
 * @param {ReturnType<typeof createInitialAppState>} state
 * @param {object} entry
 */
function applyHistoryEntry(state, entry) {
  state.transactionsInput = entry.rawInput;
  state.note = entry.note;
  state.hasGenerated = true;
  state.activeHistoryEntryId = entry.id;
  state.sampleIndex = findSampleIndexForHistoryEntry(entry);
}

/**
 * @param {HTMLTextAreaElement} transactionsInput
 * @param {HTMLInputElement} noteInput
 * @param {ReturnType<typeof createInitialAppState>} state
 */
function syncDomInputs(transactionsInput, noteInput, state) {
  transactionsInput.value = state.transactionsInput;
  noteInput.value = state.note;
}

/**
 * @param {ReturnType<typeof createInitialAppState>} state
 * @param {Pick<Storage, "getItem" | "setItem"> | null} storage
 */
function recordHistoryFromState(state, storage) {
  const viewModel = buildAppViewModel(state);

  if (!state.hasGenerated || viewModel.result.status !== CHARACTER_RESULT_STATUS.SUCCESS) {
    state.activeHistoryEntryId = null;
    return viewModel;
  }

  const reusedEntry = findMatchingHistoryEntry(state.historyEntries, state.transactionsInput, state.note);
  const historyEntry =
    reusedEntry ??
    createHistoryEntry({
      rawInput: state.transactionsInput,
      note: state.note,
      result: viewModel.result
    });

  state.historyEntries = recordHistoryEntry(historyEntry, state.historyEntries);
  state.activeHistoryEntryId = historyEntry.id;
  saveHistoryEntries(storage, state.historyEntries);

  return buildAppViewModel(state);
}

/**
 * @param {HTMLElement} root
 */
export function createApp(root) {
  const storage = resolveStorage();
  const state = createInitialAppState();

  state.historyEntries = loadHistoryEntries(storage);

  if (state.historyEntries.length > 0) {
    applyHistoryEntry(state, state.historyEntries[0]);
  }

  root.innerHTML = renderAppMarkup(state);

  const form = root.querySelector("[data-composer-form]");
  const transactionsInput = root.querySelector("[data-transactions-input]");
  const noteInput = root.querySelector("[data-note-input]");
  const generateButton = root.querySelector("[data-generate-button]");
  const fillSampleButton = root.querySelector("[data-action='fill-sample']");
  const clearButton = root.querySelector("[data-action='clear-input']");
  const summarySlot = root.querySelector("[data-input-summary]");
  const previewSlot = root.querySelector("[data-preview-panel]");
  const heroPreviewSlot = root.querySelector("[data-hero-preview]");
  const supportSlot = root.querySelector("[data-support-panel]");
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
    !(heroPreviewSlot instanceof HTMLElement) ||
    !(supportSlot instanceof HTMLElement) ||
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
    heroPreviewSlot.innerHTML = renderHeroPreview(viewModel);
    previewSlot.innerHTML = renderPreviewMarkup(viewModel);
    supportSlot.innerHTML = renderSupportPanelMarkup(viewModel);
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
    recordHistoryFromState(state, storage);
    applyViewModel();
  });

  root.addEventListener("input", (event) => {
    if (event.target !== transactionsInput && event.target !== noteInput) {
      return;
    }

    syncDraftFromDom();
    state.hasGenerated = false;
    state.activeHistoryEntryId = null;
    applyViewModel();
  });

  root.addEventListener("click", (event) => {
    const actionTarget =
      event.target instanceof HTMLElement ? event.target.closest("[data-action]") : null;
    const action = actionTarget instanceof HTMLElement ? actionTarget.dataset.action : null;

    if (action === "fill-sample") {
      applySampleCase(state, getSampleCase(state.sampleIndex), { hasGenerated: false });
      state.activeHistoryEntryId = null;
      syncDomInputs(transactionsInput, noteInput, state);
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
      state.activeHistoryEntryId = null;
      syncDomInputs(transactionsInput, noteInput, state);
      applyViewModel();
      transactionsInput.focus();
    }

    if (action === "reroll-sample") {
      state.sampleIndex = normalizeSampleIndex(state.sampleIndex + 1);
      applySampleCase(state, getSampleCase(state.sampleIndex), { hasGenerated: true });
      recordHistoryFromState(state, storage);
      syncDomInputs(transactionsInput, noteInput, state);
      applyViewModel();
    }

    if (action === "open-history" && actionTarget instanceof HTMLElement) {
      const entry = findHistoryEntry(state.historyEntries, actionTarget.dataset.entryId);

      if (!entry) {
        return;
      }

      applyHistoryEntry(state, entry);
      syncDomInputs(transactionsInput, noteInput, state);
      applyViewModel();
    }
  });

  applyViewModel();
}

/**
 * @param {{
 *   transactionsInput?: string;
 *   note?: string;
 *   hasGenerated?: boolean;
 *   sampleIndex?: number;
 *   historyEntries?: object[];
 *   activeHistoryEntryId?: string | null;
 * }} [state]
 */
export function renderAppMarkup(state = createInitialAppState()) {
  const viewModel = buildAppViewModel(state);

  return `
    <main class="page-shell">
      <section class="hero-card">
        <div class="hero-copy">
          <span class="eyebrow">Paste-first spending character</span>
          <h1>붙여넣고 나면 결과 화면이 먼저 이해되는 소비 캐릭터 흐름</h1>
          <p>
            카드 문자, 메신저 메모, 가계부 메모를 그대로 붙여넣고 오늘 소비의 분위기를 읽습니다.
            생성 뒤에는 캐릭터명과 요약, 근거 소비, 내일의 한 수, 공유 카드, 최근 히스토리를 한
            흐름에서 다시 열 수 있도록 결과 우선 레이아웃으로 정리했습니다.
          </p>
          <ul class="hero-points">
            ${HERO_POINTS.map((point) => `<li>${escapeHtml(point)}</li>`).join("")}
          </ul>
        </div>

        <aside class="hero-preview" aria-label="결과 예시" data-hero-preview>
          ${renderHeroPreview(viewModel)}
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
            <p class="panel-kicker">Result flow</p>
            <h2 id="insight-title">생성 전 기대감과 생성 후 결과 화면</h2>
          </div>

          <div class="preview-stack" data-preview-panel aria-live="polite">
            ${renderPreviewMarkup(viewModel)}
          </div>
        </section>
      </section>

      <section class="panel support-panel" data-support-panel>
        ${renderSupportPanelMarkup(viewModel)}
      </section>
    </main>
  `;
}

/**
 * @param {{
 *   transactionsInput?: string;
 *   note?: string;
 *   hasGenerated?: boolean;
 *   sampleIndex?: number;
 *   historyEntries?: object[];
 *   activeHistoryEntryId?: string | null;
 * }} state
 */
export function buildAppViewModel(state) {
  const transactionsInput = state.transactionsInput ?? "";
  const note = state.note ?? "";
  const hasGenerated = Boolean(state.hasGenerated);
  const historyEntries = Array.isArray(state.historyEntries) ? state.historyEntries : [];
  const activeHistoryEntry = hasGenerated
    ? findHistoryEntry(historyEntries, state.activeHistoryEntryId)
    : null;
  const hasHistory = historyEntries.length > 0;
  const hasInput = transactionsInput.trim().length > 0;
  const rawLines = splitInputLines(transactionsInput);
  const parsedTransactions = parseTransactions(transactionsInput);
  const samplePreview = getSamplePreviewModel(state.sampleIndex ?? 0);
  const sampleCase = samplePreview.previewCase;
  const isCurrentSample = matchesSampleInput(transactionsInput, note, sampleCase);

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
      footerCopy: "예시를 눌러 바로 체험하거나, 카드 문자와 메모를 그대로 붙여넣어 보세요.",
      previewState: "example",
      rawLines,
      rawLineCount: rawLines.length,
      parsedTransactionCount: parsedTransactions.length,
      ignoredLineCount: Math.max(rawLines.length - parsedTransactions.length, 0),
      parsedTransactions,
      totalAmountText: null,
      sourceEntries: [],
      result: samplePreview.result,
      samplePreview,
      isCurrentSample,
      noteSummary: "메모 없이도 소비 패턴만으로 요약을 만들 수 있습니다.",
      shareCardBadge: samplePreview.previewCase.label,
      shareCardTitle: samplePreview.previewCase.title,
      historyEntries,
      activeHistoryEntry,
      hasHistory,
      historyPanelCopy: HISTORY_PANEL_COPY
    };
  }

  const result = activeHistoryEntry
    ? activeHistoryEntry.result
    : generateCharacterResult(transactionsInput, { note });
  const sourceRawInput = activeHistoryEntry ? activeHistoryEntry.rawInput : transactionsInput;
  const sourceNote = activeHistoryEntry ? activeHistoryEntry.note : note;
  const sourceRawLines = splitInputLines(sourceRawInput);
  const sourceParsedTransactions = parseTransactions(sourceRawInput);
  const sourceRawLineCount = sourceRawLines.length;
  const sourceParsedTransactionCount = sourceParsedTransactions.length;
  const sourceIgnoredLineCount = Math.max(sourceRawLineCount - sourceParsedTransactionCount, 0);
  const totalAmount = sourceParsedTransactions.reduce((sum, transaction) => sum + transaction.amount, 0);
  const noteSummary = sourceNote.trim()
    ? "메모 문장도 함께 읽어 말투와 하루의 맥락을 조금 더 부드럽게 보정합니다."
    : "메모 없이도 소비 패턴만으로 요약을 만들 수 있습니다.";

  return {
    transactionsInput,
    note,
    hasGenerated,
    hasInput,
    canGenerate: true,
    canClear: hasInput || note.trim().length > 0,
    buttonLabel: hasGenerated ? "이 입력으로 다시 생성" : "오늘의 소비 캐릭터 보기",
    sampleButtonLabel: "샘플 하루 채우기",
    footerCopy: getFooterCopy(hasGenerated, result.status, activeHistoryEntry),
    previewState: getPreviewState(hasGenerated, result.status),
    rawLines: sourceRawLines,
    rawLineCount: sourceRawLineCount,
    parsedTransactionCount: sourceParsedTransactionCount,
    ignoredLineCount: sourceIgnoredLineCount,
    parsedTransactions: sourceParsedTransactions,
    totalAmountText: sourceParsedTransactionCount > 0 ? formatCurrency(totalAmount) : null,
    sourceEntries: buildSourceEntries(sourceRawLines, sourceParsedTransactions),
    result,
    samplePreview,
    isCurrentSample,
    noteSummary,
    shareCardBadge: activeHistoryEntry
      ? activeHistoryEntry.createdAt
      : isCurrentSample
        ? samplePreview.previewCase.label
        : `${sourceParsedTransactionCount}건 소비 로그`,
    shareCardTitle: activeHistoryEntry
      ? isCurrentSample
        ? samplePreview.previewCase.title
        : sourceNote.trim() || "최근 다시 꺼낸 소비 흐름"
      : isCurrentSample
        ? samplePreview.previewCase.title
        : note.trim() || "오늘의 소비 흐름에서 읽은 캐릭터",
    historyEntries,
    activeHistoryEntry,
    hasHistory,
    historyPanelCopy: HISTORY_PANEL_COPY
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
    return renderExamplePreview(viewModel.samplePreview);
  }

  if (viewModel.result.status === CHARACTER_RESULT_STATUS.SUCCESS) {
    return renderSuccessPreview(viewModel);
  }

  return renderFeedbackPreview(viewModel);
}

/**
 * @param {ReturnType<typeof buildAppViewModel>} viewModel
 * @returns {string}
 */
function renderHeroPreview(viewModel) {
  const heroModel = getHeroPreviewModel(viewModel);

  return `
    <span class="preview-label">${escapeHtml(heroModel.label)}</span>
    <p class="preview-context">${escapeHtml(heroModel.context)}</p>
    <strong class="preview-title">${escapeHtml(heroModel.result.characterName)}</strong>
    <p class="preview-summary">${escapeHtml(heroModel.result.summary)}</p>
    <div class="tag-list">
      ${heroModel.result.tags
        .map((tag) => `<span class="tag-pill">${escapeHtml(tag)}</span>`)
        .join("")}
    </div>
    <div class="meta-pills">
      ${heroModel.meta.map((item) => `<span class="meta-pill">${escapeHtml(item)}</span>`).join("")}
    </div>
    <div class="hero-actions">
      ${
        heroModel.showReroll
          ? `
            <button type="button" class="ghost-button reroll-button" data-action="reroll-sample">
              ${escapeHtml(heroModel.buttonLabel)}
            </button>
          `
          : ""
      }
      <p class="action-note" aria-live="polite">${escapeHtml(heroModel.actionNote)}</p>
    </div>
  `;
}

/**
 * @param {ReturnType<typeof getSamplePreviewModel>} samplePreview
 * @returns {string}
 */
function renderExamplePreview(samplePreview) {
  return `
    <div class="status-banner">
      <p class="status-label">결과 예시</p>
      <h3>${escapeHtml(samplePreview.result.characterName)}</h3>
      <p>${escapeHtml(samplePreview.result.summary)}</p>
    </div>

    <div class="tag-list">
      ${samplePreview.result.tags
        .map((tag) => `<span class="tag-pill">${escapeHtml(tag)}</span>`)
        .join("")}
    </div>

    <p class="preview-caption">
      입력 전에도 이 서비스가 어떤 톤의 캐릭터와 결과 화면을 보여주는지 바로 감을 잡을 수
      있도록 샘플 결과를 먼저 보여줍니다.
    </p>

    <div class="inline-hint">
      카드 문자처럼 보이는 소비 줄을 2개 이상 붙여넣으면 근거 카드, 내일의 한 수,
      저장/공유 카드, 최근 히스토리까지 바로 열립니다.
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
    <div class="status-banner result-banner">
      <p class="status-label">${isGenerated ? "생성 완료" : "생성 전 미리보기"}</p>
      <h3>${escapeHtml(result.characterName)}</h3>
      <p>${escapeHtml(result.summary)}</p>
    </div>

    <div class="summary-strip result-meta">
      ${renderResultMetaMarkup(viewModel)}
    </div>

    <p class="pattern-note">${escapeHtml(result.patternObservation)}</p>

    ${
      isGenerated
        ? `
          <div class="result-flow-grid">
            <section class="result-section evidence-section">
              <div class="result-head">
                <p class="panel-kicker">Evidence card</p>
                <h3>왜 이런 캐릭터로 읽혔는지</h3>
              </div>

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
                        <small>${escapeHtml(evidence.rawText)}</small>
                      </li>
                    `
                  )
                  .join("")}
              </ul>
            </section>

            <div class="side-stack">
              <section class="result-section action-panel">
                <div class="result-head">
                  <p class="panel-kicker">Action hint</p>
                  <h3>내일의 한 수</h3>
                </div>

                <div class="next-move">
                  <span>짧고 바로 실행 가능한 한 가지</span>
                  <strong>${escapeHtml(result.nextMove)}</strong>
                </div>

                <p class="result-disclaimer">${escapeHtml(result.disclaimer)}</p>
              </section>

              <section class="result-section share-panel">
                <div class="result-head">
                  <p class="panel-kicker">Share card</p>
                  <h3>저장/공유 카드</h3>
                </div>

                <article class="share-card" aria-label="공유 카드 미리보기">
                  <span class="share-card-badge">${escapeHtml(viewModel.shareCardBadge)}</span>
                  <p class="share-card-title">${escapeHtml(viewModel.shareCardTitle)}</p>
                  <strong class="share-card-character">${escapeHtml(result.characterName)}</strong>
                  <p class="share-card-summary">${escapeHtml(result.summary)}</p>
                  <div class="tag-list share-tag-list">
                    ${result.tags
                      .map((tag) => `<span class="tag-pill">${escapeHtml(tag)}</span>`)
                      .join("")}
                  </div>
                  <div class="share-card-rule"></div>
                  <p class="share-card-caption">내일의 한 수</p>
                  <p class="share-card-move">${escapeHtml(result.nextMove)}</p>
                </article>

                ${
                  viewModel.isCurrentSample
                    ? `
                      <button type="button" class="ghost-button reroll-button" data-action="reroll-sample">
                        다른 하루로 다시 생성
                      </button>
                      <p class="action-note">다음 샘플: ${escapeHtml(viewModel.samplePreview.nextPreviewLabel)}</p>
                    `
                    : `
                      <p class="action-note">
                        입력을 수정하거나 다시 생성하면 공유 카드도 같은 톤으로 함께 갱신됩니다.
                      </p>
                    `
                }
              </section>
            </div>
          </div>
        `
        : `
          ${renderParsedTransactionMarkup(viewModel.parsedTransactions)}
          <div class="inline-hint">
            버튼을 누르면 근거 카드와 내일의 한 수, 저장/공유 카드, 최근 히스토리까지 같은 톤으로 이어서 펼쳐집니다.
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
 * @param {ReturnType<typeof buildAppViewModel>} viewModel
 * @returns {string}
 */
function renderSupportPanelMarkup(viewModel) {
  if (viewModel.previewState === "generated-success") {
    return renderSupportSectionsMarkup([
      renderSourcePanelMarkup(viewModel),
      viewModel.hasHistory ? renderHistoryPanelMarkup(viewModel) : ""
    ]);
  }

  if (viewModel.hasHistory) {
    return renderSupportSectionsMarkup([
      renderHistoryPanelMarkup(viewModel),
      renderRoadmapPanelMarkup()
    ]);
  }

  return renderRoadmapPanelMarkup();
}

/**
 * @param {string[]} sections
 * @returns {string}
 */
function renderSupportSectionsMarkup(sections) {
  return `
    <div class="support-sections">
      ${sections
        .filter(Boolean)
        .map(
          (sectionMarkup) => `
            <section class="support-section">
              ${sectionMarkup}
            </section>
          `
        )
        .join("")}
    </div>
  `;
}

/**
 * @param {ReturnType<typeof buildAppViewModel>} viewModel
 * @returns {string}
 */
function renderSourcePanelMarkup(viewModel) {
  return `
    <div class="panel-head">
      <p class="panel-kicker">Source snapshot</p>
      <h2>해석에 쓰인 소비 로그</h2>
    </div>

    <p class="source-intro">
      ${
        viewModel.activeHistoryEntry
          ? "최근 히스토리에서 다시 연 결과도 아래 입력 원문을 바탕으로 그대로 복원됩니다."
          : "결과 카드와 공유 카드는 아래 입력 원문을 바탕으로 만들어집니다."
      }
      금액이 읽힌 줄은 근거 소비 후보가 되고, 선택 메모는 설명 톤과 하루의 맥락을 보정하는 데 함께 쓰입니다.
    </p>

    <div class="source-grid">
      <ol class="source-list">
        ${viewModel.sourceEntries
          .map(
            (entry, index) => `
              <li class="source-item ${entry.isParsed ? "is-parsed" : "is-ignored"}">
                <span class="source-index">${String(index + 1).padStart(2, "0")}</span>
                <div class="source-copy">
                  <span class="source-text">${escapeHtml(entry.text)}</span>
                  <span class="source-badge">${entry.isParsed ? "읽힘" : "참고"}</span>
                </div>
              </li>
            `
          )
          .join("")}
      </ol>

      <aside class="source-note-card">
        <span>선택 메모</span>
        <strong>${escapeHtml(viewModel.note.trim() || "입력된 메모 없음")}</strong>
        <p>${escapeHtml(viewModel.noteSummary)}</p>
        <div class="summary-strip">
          <span class="summary-pill">
            ${escapeHtml(viewModel.isCurrentSample ? viewModel.samplePreview.previewCase.label : "직접 입력 결과")}
          </span>
          ${
            viewModel.totalAmountText
              ? `<span class="summary-pill">${escapeHtml(viewModel.totalAmountText)}</span>`
              : ""
          }
          ${
            viewModel.activeHistoryEntry
              ? `<span class="summary-pill">${escapeHtml(viewModel.activeHistoryEntry.createdAt)}</span>`
              : ""
          }
        </div>
      </aside>
    </div>
  `;
}

/**
 * @param {ReturnType<typeof buildAppViewModel>} viewModel
 * @returns {string}
 */
function renderHistoryPanelMarkup(viewModel) {
  return `
    <div class="panel-head">
      <p class="panel-kicker">Recent history</p>
      <h2>최근 캐릭터 히스토리</h2>
    </div>

    <p class="history-intro">${escapeHtml(viewModel.historyPanelCopy)}</p>

    <ol class="history-list">
      ${viewModel.historyEntries
        .map((entry, index) =>
          renderHistoryItemMarkup(entry, index, viewModel.activeHistoryEntry?.id ?? null)
        )
        .join("")}
    </ol>
  `;
}

/**
 * @param {object} entry
 * @param {number} index
 * @param {string | null} activeHistoryEntryId
 * @returns {string}
 */
function renderHistoryItemMarkup(entry, index, activeHistoryEntryId) {
  const isSelected = entry.id === activeHistoryEntryId;
  const parsedTransactions = parseTransactions(entry.rawInput);
  const detailLabel = entry.note || parsedTransactions[0]?.rawText || "저장된 소비 로그";

  return `
    <li>
      <button
        type="button"
        class="history-item${isSelected ? " is-selected" : ""}"
        data-action="open-history"
        data-entry-id="${escapeHtml(entry.id)}"
        aria-pressed="${isSelected ? "true" : "false"}"
      >
        <span class="history-meta">
          <span class="history-rank">${index === 0 ? "가장 최근" : `최근 ${index + 1}`}</span>
          <time datetime="${escapeHtml(entry.createdAt)}">${escapeHtml(entry.createdAt)}</time>
        </span>
        <strong>${escapeHtml(entry.result.characterName)}</strong>
        <p>${escapeHtml(entry.result.summary)}</p>
        <small>${escapeHtml(detailLabel)}</small>
      </button>
    </li>
  `;
}

function renderRoadmapPanelMarkup() {
  return `
    <div class="panel-head">
      <p class="panel-kicker">Delivery path</p>
      <h2>이 셸 위에 이어질 다음 단계</h2>
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
 * @param {ReturnType<typeof buildAppViewModel>} viewModel
 * @returns {string}
 */
function renderResultMetaMarkup(viewModel) {
  return [
    `${viewModel.parsedTransactionCount}건 분석`,
    viewModel.totalAmountText || "금액 합계 없음",
    viewModel.ignoredLineCount > 0 ? `건너뜀 ${viewModel.ignoredLineCount}줄` : "모든 줄 읽힘"
  ]
    .map((item) => `<span class="summary-pill">${escapeHtml(item)}</span>`)
    .join("");
}

/**
 * @param {ReturnType<typeof buildAppViewModel>} viewModel
 * @returns {{
 *   label: string;
 *   context: string;
 *   result: ReturnType<typeof getSamplePreviewModel>["result"];
 *   meta: string[];
 *   showReroll: boolean;
 *   buttonLabel: string;
 *   actionNote: string;
 * }}
 */
function getHeroPreviewModel(viewModel) {
  if (viewModel.previewState === "generated-success" || viewModel.previewState === "anticipation") {
    if (viewModel.previewState === "generated-success" && viewModel.activeHistoryEntry) {
      return {
        label: "최근 다시 연 결과",
        context: viewModel.shareCardTitle,
        result: viewModel.result,
        meta: [
          viewModel.activeHistoryEntry.createdAt,
          `${viewModel.parsedTransactionCount}건 분석`,
          viewModel.totalAmountText || "금액 합계 없음"
        ],
        showReroll: viewModel.isCurrentSample,
        buttonLabel: "다른 하루로 다시 생성",
        actionNote: viewModel.isCurrentSample
          ? `다음 샘플: ${viewModel.samplePreview.nextPreviewLabel}`
          : HISTORY_PANEL_COPY
      };
    }

    return {
      label: viewModel.previewState === "generated-success" ? "생성된 결과" : "곧 생성될 결과",
      context: viewModel.isCurrentSample
        ? viewModel.samplePreview.previewCase.title
        : "붙여넣은 소비 흐름에서 읽힌 캐릭터",
      result: viewModel.result,
      meta: [
        `${viewModel.parsedTransactionCount}건 분석`,
        viewModel.totalAmountText || "금액 합계 없음",
        viewModel.note.trim() ? "메모 반영" : "메모 없이 해석"
      ],
      showReroll: viewModel.isCurrentSample,
      buttonLabel: "다른 하루로 다시 생성",
      actionNote: viewModel.isCurrentSample
        ? `다음 샘플: ${viewModel.samplePreview.nextPreviewLabel}`
        : "입력을 수정하면 결과 미리보기 상태로 돌아갑니다."
    };
  }

  return {
    label: "샘플 결과",
    context: viewModel.samplePreview.previewCase.title,
    result: viewModel.samplePreview.result,
    meta: [
      viewModel.samplePreview.previewCase.label,
      viewModel.samplePreview.transactionSummary,
      viewModel.samplePreview.totalAmountText
    ],
    showReroll: true,
    buttonLabel: "다른 샘플 보기",
    actionNote:
      viewModel.previewState === "example"
        ? `다음 샘플: ${viewModel.samplePreview.nextPreviewLabel}`
        : "현재 입력이 충분해지면 이 자리가 실제 결과로 교체됩니다."
  };
}

/**
 * @param {boolean} hasGenerated
 * @param {string} status
 * @param {object | null} activeHistoryEntry
 * @returns {string}
 */
function getFooterCopy(hasGenerated, status, activeHistoryEntry) {
  if (activeHistoryEntry) {
    return "최근 결과를 다시 열어 둔 상태예요. 입력을 바꾸면 미리보기로 돌아가고 현재 내용으로 다시 생성할 수 있어요.";
  }

  if (hasGenerated) {
    return "입력을 바꾸면 다시 미리보기 상태로 돌아가고, 현재 내용으로 곧바로 다시 생성할 수 있어요.";
  }

  if (status === CHARACTER_RESULT_STATUS.SUCCESS) {
    return "지금도 분위기는 읽히고 있어요. 버튼을 누르면 근거 카드, 내일의 한 수, 저장/공유 카드, 최근 히스토리까지 펼쳐집니다.";
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

/**
 * @param {number} [sampleIndex]
 */
export function getSampleCase(sampleIndex = 0) {
  const normalizedIndex = normalizeSampleIndex(sampleIndex);

  return PREVIEW_CASES[normalizedIndex] ?? {
    label: "기본 미리보기",
    title: "샘플 하루",
    note: SAMPLE_NOTE,
    transactions: SAMPLE_TRANSACTIONS
  };
}

/**
 * @param {number} [sampleIndex]
 */
export function getSamplePreviewModel(sampleIndex = 0) {
  const previewCase = getSampleCase(sampleIndex);
  const result = generateCharacterResult(previewCase.transactions.join("\n"), {
    note: previewCase.note
  });
  const parsedTransactions = parseTransactions(previewCase.transactions.join("\n"));
  const totalAmount = parsedTransactions.reduce((sum, transaction) => sum + transaction.amount, 0);

  if (result.status !== CHARACTER_RESULT_STATUS.SUCCESS) {
    throw new Error("Sample preview must generate a success result");
  }

  return {
    previewCase,
    result,
    totalAmountText: formatCurrency(totalAmount),
    transactionSummary: `${result.parsedTransactionCount}건 분석`,
    nextPreviewLabel: getSampleCase(sampleIndex + 1).label
  };
}

/**
 * @param {ReturnType<typeof createInitialAppState>} state
 * @param {ReturnType<typeof getSampleCase>} sampleCase
 * @param {{ hasGenerated?: boolean }} [options]
 */
function applySampleCase(state, sampleCase, options = {}) {
  state.transactionsInput = sampleCase.transactions.join("\n");
  state.note = sampleCase.note ?? "";
  state.hasGenerated = Boolean(options.hasGenerated);
}

/**
 * @param {string} transactionsInput
 * @param {string} note
 * @param {ReturnType<typeof getSampleCase>} sampleCase
 * @returns {boolean}
 */
function matchesSampleInput(transactionsInput, note, sampleCase) {
  return (
    splitInputLines(transactionsInput).join("\n") === sampleCase.transactions.join("\n") &&
    note.trim() === (sampleCase.note ?? "").trim()
  );
}

/**
 * @param {string[]} rawLines
 * @param {ReturnType<typeof parseTransactions>} parsedTransactions
 */
function buildSourceEntries(rawLines, parsedTransactions) {
  const parsedLookup = new Set(parsedTransactions.map((transaction) => transaction.rawText.trim()));

  return rawLines.map((line) => ({
    text: line,
    isParsed: parsedLookup.has(line)
  }));
}

/**
 * @param {number} value
 * @returns {number}
 */
function normalizeSampleIndex(value) {
  if (PREVIEW_CASES.length === 0) {
    return 0;
  }

  return ((value % PREVIEW_CASES.length) + PREVIEW_CASES.length) % PREVIEW_CASES.length;
}
