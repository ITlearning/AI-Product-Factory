import {
  HERO_POINTS,
  PREVIEW_CASES,
  SAMPLE_NOTE,
  SAMPLE_TRANSACTIONS
} from "./content.js";
import { CHARACTER_RESULT_STATUS } from "./character-contract.js";
import { formatCurrency, generateCharacterResult, parseTransactions } from "./character-engine.js";

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

/**
 * @param {HTMLElement} root
 */
export function createApp(root) {
  const state = { scenarioIndex: 0 };

  const render = () => {
    root.innerHTML = renderAppMarkup({ scenarioIndex: state.scenarioIndex });
  };

  render();
  root.addEventListener("click", (event) => {
    const trigger =
      event.target && typeof event.target.closest === "function"
        ? event.target.closest("[data-action]")
        : null;

    if (!trigger || trigger.dataset.action !== "reroll") {
      return;
    }

    state.scenarioIndex = (state.scenarioIndex + 1) % PREVIEW_CASES.length;
    render();
  });
}

/**
 * @param {{ scenarioIndex?: number }} [options]
 */
export function renderAppMarkup(options = {}) {
  const preview = getPreviewModel(options.scenarioIndex ?? 0);

  return `
    <main class="page-shell">
      <section class="hero-card">
        <div class="hero-copy">
          <span class="eyebrow">오늘의 소비 캐릭터</span>
          <h1>오늘 나는 어떤 소비 캐릭터였는지 10초 안에 이해하는 결과 화면</h1>
          <p>
            캐릭터명과 한 줄 요약을 먼저 보여주고, 왜 이런 해석이 나왔는지와 내일의 한 수를
            바로 이어서 읽게 만드는 결과 우선 화면입니다. 저장이나 공유를 염두에 둔 카드는
            본문과 분리해 시선 흐름을 더 단순하게 잡았습니다.
          </p>
          <ul class="hero-points">
            ${HERO_POINTS.map((point) => `<li>${escapeHtml(point)}</li>`).join("")}
          </ul>
          <div class="meta-pills">
            <span class="meta-pill">${escapeHtml(preview.previewCase.label)}</span>
            <span class="meta-pill">${escapeHtml(preview.transactionSummary)}</span>
            <span class="meta-pill">${escapeHtml(preview.totalAmountText)}</span>
          </div>
        </div>

        <aside class="hero-preview" aria-label="결과 예시">
          <span class="preview-label">이번 미리보기</span>
          <p class="preview-context">${escapeHtml(preview.previewCase.title)}</p>
          <strong class="preview-title">${escapeHtml(preview.result.characterName)}</strong>
          <p class="preview-summary">${escapeHtml(preview.result.summary)}</p>
          <div class="tag-list">
            ${preview.result.tags
              .map((tag) => `<span class="tag-pill">${escapeHtml(tag)}</span>`)
              .join("")}
          </div>
          <div class="hero-actions">
            <button type="button" class="reroll-button" data-action="reroll">다른 하루로 다시 생성</button>
            <p class="action-note" aria-live="polite">
              다음 미리보기: ${escapeHtml(preview.nextPreviewLabel)}
            </p>
          </div>
        </aside>
      </section>

      <section class="workspace-grid">
        <section class="panel insight-panel" aria-labelledby="insight-title">
          <div class="panel-head">
            <p class="panel-kicker">Evidence card</p>
            <h2 id="insight-title">왜 이런 캐릭터로 읽혔는지</h2>
          </div>

          <p class="pattern-note">${escapeHtml(preview.result.patternObservation)}</p>

          <ul class="evidence-grid">
            ${preview.result.evidence
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
          <section class="panel action-panel" aria-labelledby="action-title">
            <div class="panel-head">
              <p class="panel-kicker">Action hint</p>
              <h2 id="action-title">내일의 한 수</h2>
            </div>

            <div class="next-move">
              <span>짧고 바로 실행 가능한 한 가지</span>
              <strong>${escapeHtml(preview.result.nextMove)}</strong>
            </div>

            <p class="result-disclaimer">${escapeHtml(preview.result.disclaimer)}</p>
          </section>

          <section class="panel share-panel" aria-labelledby="share-title">
            <div class="panel-head">
              <p class="panel-kicker">Share card</p>
              <h2 id="share-title">저장/공유 카드</h2>
            </div>

            <article class="share-card" aria-label="공유 카드 미리보기">
              <span class="share-card-badge">${escapeHtml(preview.previewCase.label)}</span>
              <p class="share-card-title">${escapeHtml(preview.previewCase.title)}</p>
              <strong class="share-card-character">${escapeHtml(preview.result.characterName)}</strong>
              <p class="share-card-summary">${escapeHtml(preview.result.summary)}</p>
              <div class="tag-list share-tag-list">
                ${preview.result.tags
                  .map((tag) => `<span class="tag-pill">${escapeHtml(tag)}</span>`)
                  .join("")}
              </div>
              <div class="share-card-rule"></div>
              <p class="share-card-caption">내일의 한 수</p>
              <p class="share-card-move">${escapeHtml(preview.result.nextMove)}</p>
            </article>
          </section>
        </div>
      </section>

      <section class="panel source-panel" aria-labelledby="source-title">
        <div class="panel-head">
          <p class="panel-kicker">Source snapshot</p>
          <h2 id="source-title">해석에 쓰인 소비 로그</h2>
        </div>

        <p class="source-intro">
          이 결과 화면은 아래 샘플 하루를 읽어 생성됩니다. 현재 <code>다시 생성</code> 버튼은 준비된
          다른 샘플 하루를 순환하고, 실제 붙여넣기 상호작용은 별도 입력 화면 task 에서
          이어서 연결됩니다.
        </p>

        <div class="source-grid">
          <ol class="source-list">
            ${preview.previewCase.transactions
              .map(
                (transaction, index) => `
                  <li class="source-item">
                    <span class="source-index">${String(index + 1).padStart(2, "0")}</span>
                    <span class="source-text">${escapeHtml(transaction)}</span>
                  </li>
                `
              )
              .join("")}
          </ol>

          <aside class="source-note-card">
            <span>선택 메모</span>
            <strong>${escapeHtml(preview.previewCase.note || SAMPLE_NOTE)}</strong>
            <p>${escapeHtml(preview.noteSummary)}</p>
          </aside>
        </div>
      </section>
    </main>
  `;
}

/**
 * @param {number} [scenarioIndex]
 */
export function getPreviewModel(scenarioIndex = 0) {
  const normalizedIndex = ((scenarioIndex % PREVIEW_CASES.length) + PREVIEW_CASES.length) % PREVIEW_CASES.length;
  const previewCase = PREVIEW_CASES[normalizedIndex] ?? {
    label: "기본 미리보기",
    title: "샘플 하루",
    note: SAMPLE_NOTE,
    transactions: SAMPLE_TRANSACTIONS
  };
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
    nextPreviewLabel: PREVIEW_CASES[(normalizedIndex + 1) % PREVIEW_CASES.length].label,
    noteSummary: previewCase.note
      ? "메모 문장도 함께 읽어 말투와 하루의 맥락을 조금 더 부드럽게 보정합니다."
      : "메모 없이도 소비 패턴만으로 요약을 만들 수 있습니다."
  };
}
