import { SITUATION_OPTIONS } from "../domain/options.js";
import { escapeHtml } from "../utils/text.js";

/**
 * @param {import("./state.js").AppState} state
 * @returns {string}
 */
export function renderAppMarkup(state) {
  return `
    <main class="page-shell">
      <section class="workspace">
        <div class="workspace-head">
          <span class="eyebrow">IBAD</span>
          <h1>답장을 못 보내고 있다면, 여기서 시작하세요</h1>
          <p class="intro-copy">
            받은 메시지를 붙여넣고, 지금 필요한 시작 문장을 3가지 톤으로 받아보세요.
          </p>
        </div>

        <div class="workspace-grid${state.result ? " has-result" : ""}">
          <form class="composer" data-role="composer">
            <label class="field-label" for="input-message">
              받은 메시지를 붙여넣어 주세요
            </label>
            <textarea
              id="input-message"
              name="input-message"
              placeholder="예: 친구가 오늘 저녁에 보자고 했는데 쉬고 싶어서 답장을 미루고 있어."
            >${escapeHtml(state.input)}</textarea>

            ${renderSelect(
              "situation-type",
              "이건 어떤 요청인가요?",
              SITUATION_OPTIONS,
              state.situationType
            )}

            <div class="composer-actions">
              <button class="button button-primary" type="submit" ${state.isLoading ? "disabled" : ""}>
                ${state.isLoading ? "답장 만드는 중..." : "답장 만들기"}
              </button>
            </div>
          </form>

          ${
            state.result
              ? `
                <section class="results-shell" id="results">
                  <div class="results-head">
                    <h2>바로 시작할 수 있는 답장</h2>
                    <p>길게 고민하기 전에, 지금 보내기 쉬운 문장부터 고르세요.</p>
                  </div>
                  ${renderReplyCards(state.result)}
                </section>
              `
              : ""
          }
        </div>

        <div class="feedback-slot">${renderFeedback(state.feedback)}</div>
      </section>
    </main>
  `;
}

function renderSelect(id, label, options, selectedValue) {
  return `
    <label class="select-card" for="${id}">
      <span>${label}</span>
      <select id="${id}" name="${id}">
        ${options
          .map(
            (option) => `
              <option value="${option.value}" ${option.value === selectedValue ? "selected" : ""}>
                ${option.label}
              </option>
            `
          )
          .join("")}
      </select>
    </label>
  `;
}

function renderFeedback(feedback) {
  if (!feedback) {
    return "";
  }

  return `
    <div class="feedback feedback-${feedback.type}" role="status">
      ${escapeHtml(feedback.message)}
    </div>
  `;
}

function renderReplyCards(result) {
  return `
    <div class="reply-grid">
      ${result.replyOptions
        .map(
          (option) => `
            <article class="reply-card">
              <span class="reply-label">${escapeHtml(option.toneLabel)}</span>
              <p class="reply-text">${escapeHtml(option.text)}</p>
              <p class="reply-why">${escapeHtml(option.whyItWorks)}</p>
              <button class="button button-copy" type="button" data-copy-reply="${escapeHtml(
                option.text
              )}">
                복사하기
              </button>
            </article>
          `
        )
        .join("")}
      </div>
    `;
}
