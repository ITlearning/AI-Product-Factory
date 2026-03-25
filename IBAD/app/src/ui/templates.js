import { EXAMPLE_CASES } from "../domain/examples.js";
import {
  RELATIONSHIP_OPTIONS,
  SITUATION_OPTIONS,
  STRENGTH_OPTIONS
} from "../domain/options.js";
import { escapeHtml } from "../utils/text.js";

/**
 * @param {import("./state.js").AppState} state
 * @returns {string}
 */
export function renderAppMarkup(state) {
  return `
    <main class="page-shell">
      <section class="hero-card">
        <div class="hero-copy">
          <span class="eyebrow">IBAD MVP</span>
          <h1>이번엔 안 돼</h1>
          <p>
            받은 메시지와 관계를 바탕으로, 안 상하게 하지만 애매한 여지를 남기지 않는
            거절 답장을 바로 만듭니다.
          </p>
          <div class="hero-pills">
            <span>답장 3개</span>
            <span>톤 설명 포함</span>
            <span>복붙 가능한 길이</span>
          </div>
        </div>
        <div class="hero-preview">
          <div class="preview-card">
            <span>정중한 버전</span>
            <strong>이번엔 일정이 어려워서 같이하긴 힘들 것 같아.</strong>
          </div>
          <div class="preview-card">
            <span>여지 남김 여부</span>
            <strong>낮음</strong>
          </div>
        </div>
      </section>

      <section class="workspace">
        <div class="workspace-head">
          <div>
            <h2>거절 답장 만들기</h2>
            <p>친구나 지인 관계의 약속·부탁 거절을 먼저 지원합니다.</p>
          </div>
          <span class="mono-badge">ai-first:v1</span>
        </div>

        <div class="workspace-grid">
          <form class="composer" data-role="composer">
            <label class="field-label" for="input-message">
              받은 메시지 또는 상황 설명
            </label>
            <textarea
              id="input-message"
              name="input-message"
              placeholder="예: 친구가 오늘 저녁에 보자고 했는데 쉬고 싶어서 거절하고 싶어."
            >${escapeHtml(state.input)}</textarea>

            <div class="form-grid">
              ${renderSelect(
                "relationship-type",
                "관계 타입",
                RELATIONSHIP_OPTIONS,
                state.relationshipType
              )}
              ${renderSelect(
                "situation-type",
                "상황 타입",
                SITUATION_OPTIONS,
                state.situationType
              )}
              ${renderSelect(
                "rejection-strength",
                "거절 강도",
                STRENGTH_OPTIONS,
                state.rejectionStrength
              )}
              <label class="toggle-card" for="include-alternative">
                <span>대안 제시</span>
                <input
                  id="include-alternative"
                  name="include-alternative"
                  type="checkbox"
                  ${state.includeAlternative ? "checked" : ""}
                />
                <strong>${state.includeAlternative ? "한다" : "안 한다"}</strong>
              </label>
            </div>

            <div class="composer-actions">
              <button class="button button-secondary" type="button" data-action="example">
                예시 넣기
              </button>
              <button class="button button-primary" type="submit" ${state.isLoading ? "disabled" : ""}>
                ${state.isLoading ? "답장 만드는 중..." : "답장 만들기"}
              </button>
            </div>
          </form>

          <aside class="helper-panel">
            <div class="helper-block">
              <h3>빠른 예시</h3>
              <div class="example-list">
                ${EXAMPLE_CASES.map(
                  (example, index) => `
                    <button class="example-chip" type="button" data-example-index="${index}">
                      ${escapeHtml(example)}
                    </button>
                  `
                ).join("")}
              </div>
            </div>

            <div class="helper-block helper-block-accent">
              <h3>지원 범위</h3>
              <ul class="helper-list">
                <li>친구/지인 대상의 약속 거절</li>
                <li>친구/지인 대상의 부탁 거절</li>
                <li>장황한 변명보다 짧은 경계 설정</li>
              </ul>
            </div>
          </aside>
        </div>

        <div class="feedback-slot">${renderFeedback(state.feedback)}</div>
      </section>

      <section class="results-shell" id="results">
        <div class="results-head">
          <div>
            <h2>결과</h2>
            <p>바로 보낼 수 있는 답장과 함께, 왜 무난한지 같이 보여줍니다.</p>
          </div>
        </div>

        <div class="results-grid">
          ${renderReplyCards(state.result)}
          ${renderGuidancePanel(state.result)}
        </div>
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
  if (!result) {
    return `
      <div class="reply-grid reply-grid-placeholder">
        ${renderPlaceholderCard("정중한 버전", "짧지만 차갑지 않은 표현으로 선을 긋습니다.")}
        ${renderPlaceholderCard("자연스러운 버전", "평소 말투에 가깝게 무난하게 거절합니다.")}
        ${renderPlaceholderCard("단호한 버전", "재요청 여지를 더 줄이는 쪽에 가깝습니다.")}
      </div>
    `;
  }

  return `
    <div class="reply-grid">
      ${result.replyOptions
        .map(
          (option, index) => `
            <article class="reply-card">
              <div class="reply-card-head">
                <span class="reply-index">옵션 ${index + 1}</span>
                <h3>${escapeHtml(option.toneLabel)}</h3>
              </div>
              <p class="reply-text">${escapeHtml(option.text)}</p>
              <p class="reply-why">${escapeHtml(option.whyItWorks)}</p>
              <button class="button button-copy" type="button" data-copy-reply="${escapeHtml(
                option.text
              )}">
                복사
              </button>
            </article>
          `
        )
        .join("")}
    </div>
  `;
}

function renderGuidancePanel(result) {
  if (!result) {
    return `
      <aside class="guidance-panel guidance-panel-placeholder">
        <h3>피해야 할 표현</h3>
        <p>다음에 보자, 나중에 보자처럼 다시 잡히기 쉬운 문장을 줄입니다.</p>
        <h3>여지 남김 여부</h3>
        <p>낮음</p>
        <h3>대안을 넣었을 때 / 안 넣었을 때</h3>
        <p>대안은 부드럽지만 여지가 될 수 있어 상황에 따라 선택합니다.</p>
      </aside>
    `;
  }

  return `
    <aside class="guidance-panel">
      <h3>피해야 할 표현</h3>
      <ul class="helper-list">
        ${result.avoidPhrases.map((phrase) => `<li>${escapeHtml(phrase)}</li>`).join("")}
      </ul>
      <h3>여지 남김 여부</h3>
      <p>${escapeHtml(result.openDoorRisk)}</p>
      <h3>대안을 넣었을 때 / 안 넣었을 때</h3>
      <p>${escapeHtml(result.alternativeDifference)}</p>
    </aside>
  `;
}

function renderPlaceholderCard(title, body) {
  return `
    <article class="reply-card reply-card-placeholder">
      <h3>${escapeHtml(title)}</h3>
      <p>${escapeHtml(body)}</p>
    </article>
  `;
}
