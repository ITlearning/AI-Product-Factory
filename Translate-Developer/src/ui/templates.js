import { AUDIENCE_OPTIONS, getAudienceOption } from "../data/audiences.js";
import { escapeHtml } from "../utils/text.js";

/**
 * @param {import("./state.js").AppState} state
 * @param {{ defaultExample: string, examples: string[] }} options
 * @returns {string}
 */
export function renderAppMarkup(state, options) {
  const { defaultExample, examples } = options;
  const selectedAudience = getAudienceOption(state.audience);

  return `
    <main class="page-shell">
      <section class="hero-card">
        <span class="eyebrow">Translate-Developer Role-Aware</span>
        <div class="hero-grid">
          <div class="hero-copy">
            <h1>개발자 설명을 함께 일하는 비개발자가 이해하게 풀어줍니다</h1>
            <p>
              한 줄만 번역하는 대신, 앞뒤 대화와 맥락까지 함께 읽고
              쉬운 설명, 전문 용어 풀이, 확인된 영향, 더 필요한 맥락을 나눠서 정리합니다.
            </p>
            <div class="hero-stats" aria-label="핵심 특징">
              <div class="stat-card">
                <strong>3 roles</strong>
                <span>PM/기획자, 디자이너, 비개발자</span>
              </div>
              <div class="stat-card">
                <strong>4 blocks</strong>
                <span>번역, 용어 풀이, 영향, 추가 맥락</span>
              </div>
              <div class="stat-card">
                <strong>gpt-5.4</strong>
                <span>정확한 설명 우선, 실패 시 기본 설명 모드</span>
              </div>
            </div>
          </div>
          <div class="hero-preview" aria-label="결과 미리보기">
            <div class="preview-label">설명 결과 미리보기</div>
            <div class="preview-card">
              <span>쉽게 다시 쓴 내용</span>
              <strong>배포 뒤 결제 연결이 자주 늦어지거나 끊겨서, 지금 원인을 확인하고 있어요.</strong>
            </div>
            <div class="preview-card">
              <span>전문 용어 풀이</span>
              <strong>타임아웃은 응답이 너무 늦어서 요청이 멈춘 상태예요.</strong>
            </div>
            <div class="preview-card preview-card-accent">
              <span>더 알려주면 정확해지는 부분</span>
              <strong>실제 결제 실패가 얼마나 발생했는지는 앞뒤 대화가 더 있으면 명확해져요.</strong>
            </div>
          </div>
        </div>
      </section>

      <section class="workspace" aria-labelledby="translator-title">
        <div class="workspace-head">
          <div>
            <h2 id="translator-title">개발자 메시지 해설기</h2>
            <p>한 줄만 넣기보다, 앞뒤 슬랙 대화와 맥락을 함께 넣을수록 더 정확하게 풀어드립니다.</p>
          </div>
          <span class="mono-badge">pm-first:v2</span>
        </div>

        <div class="workspace-grid">
          <form class="composer" data-role="composer">
            <section class="audience-picker" aria-labelledby="audience-title">
              <div class="field-label">
                <span id="audience-title">이 설명을 누가 이해해야 하나요?</span>
                <span class="field-help">지금은 ${escapeHtml(selectedAudience.label)} 관점으로 가장 먼저 풀어드립니다.</span>
              </div>
              <div class="audience-list" role="group" aria-label="독자 선택">
                ${AUDIENCE_OPTIONS.map((option) =>
                  `
                    <button
                      class="audience-button ${option.id === state.audience ? "audience-button-active" : ""}"
                      type="button"
                      data-audience="${option.id}"
                      aria-pressed="${String(option.id === state.audience)}"
                    >
                      <span>${escapeHtml(option.label)}</span>
                    </button>
                  `
                ).join("")}
              </div>
              <p class="audience-help">${escapeHtml(selectedAudience.description)}</p>
            </section>

            <label class="field-label" for="developer-message">
              원문 또는 대화 내용
              <span class="field-help">
                한 줄만 넣지 말고, 문제 설명과 앞뒤 맥락까지 함께 넣어 주세요.
              </span>
            </label>
            <textarea
              id="developer-message"
              name="developer-message"
              placeholder="예: 개발자: 배포 후 결제 API에서 타임아웃이 반복돼서 확인 중입니다.&#10;PM: 지금 실제 결제 실패도 발생하고 있나요?&#10;개발자: 그건 아직 로그를 보고 있습니다."
            >${escapeHtml(state.input)}</textarea>

            <div class="composer-actions">
              <button class="button button-secondary" type="button" data-action="example">
                예시 넣기
              </button>
              <button class="button button-primary" type="submit" ${state.isLoading ? "disabled" : ""}>
                ${state.isLoading ? "AI 설명 정리 중..." : "쉽게 풀어보기"}
              </button>
            </div>
          </form>

          <aside class="helper-panel" aria-label="빠른 예시와 가이드">
            <div class="helper-block">
              <h3>빠른 예시</h3>
              <p>앞뒤 맥락이 조금 붙은 대화형 예시로 바로 확인할 수 있습니다.</p>
              <div class="example-list">
                ${examples
                  .map(
                    (example, index) => `
                      <button class="example-chip" type="button" data-example-index="${index}">
                        ${escapeHtml(example)}
                      </button>
                    `
                  )
                  .join("")}
              </div>
            </div>

            <div class="helper-block helper-block-accent">
              <h3>이렇게 넣으면 더 정확해져요</h3>
              <ul class="helper-list">
                <li>원문 한 줄보다 앞뒤 대화를 같이 넣기</li>
                <li>누가 영향을 받는지 언급된 문장 함께 넣기</li>
                <li>아직 모르는 부분도 그대로 두기</li>
              </ul>
            </div>
          </aside>
        </div>

        <div class="feedback-slot">
          ${renderFeedback(state.feedback)}
        </div>
      </section>

      <section class="results-shell" id="results" aria-label="번역 결과">
        <div class="results-intro">
          <div class="results-head">
            <div>
              <h2>결과</h2>
              <p>${escapeHtml(selectedAudience.label)}가 먼저 이해할 수 있게 다시 풀어썼습니다.</p>
            </div>
            <span class="mono-badge ${renderSourceBadgeClass(state.engineSource)}">${renderSourceBadgeLabel(state.engineSource)}</span>
          </div>
          <div class="results-rail">
            <span class="meta-chip">쉽게 다시 쓴 내용</span>
            <span class="meta-chip">전문 용어 풀이</span>
            <span class="meta-chip">이 대화에서 보이는 영향</span>
            <span class="meta-chip">더 알려주면 정확해지는 부분</span>
          </div>
        </div>

        <div class="results-grid">
          ${renderResultPanels(state.result)}
          ${renderGlossaryPanel(state.result)}
        </div>
      </section>
    </main>
  `;
}

/**
 * @param {import("./state.js").Feedback} feedback
 * @returns {string}
 */
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

/**
 * @param {import("../engine/types.js").TranslationResult | null} result
 * @returns {string}
 */
function renderResultPanels(result) {
  if (!result) {
    return `
      <div class="result-grid result-grid-placeholder">
        ${renderPlaceholderPanel("쉽게 다시 쓴 내용", "입력한 메시지를 쉬운 한국어로 전체 다시 풀어씁니다.", "result-panel-primary")}
        ${renderPlaceholderPanel("이 대화에서 보이는 영향", "입력에 직접 나온 영향만 정리합니다.")}
        ${renderPlaceholderPanel("더 알려주면 정확해지는 부분", "추정 대신, 더 필요한 맥락을 부드럽게 알려줍니다.")}
      </div>
    `;
  }

  return `
    <div class="result-grid">
      ${renderResultPanel("쉽게 다시 쓴 내용", result.rewrittenMessage, "result-panel-primary")}
      ${renderResultPanel("이 대화에서 보이는 영향", result.confirmedImpact)}
      ${renderResultPanel("더 알려주면 정확해지는 부분", result.needsMoreContext)}
    </div>
  `;
}

/**
 * @param {string} label
 * @param {string} value
 * @param {string} [extraClass]
 * @returns {string}
 */
function renderResultPanel(label, value, extraClass = "") {
  return `
    <article class="result-panel ${extraClass}">
      <h3>${escapeHtml(label)}</h3>
      <p>${escapeHtml(value)}</p>
    </article>
  `;
}

/**
 * @param {string} label
 * @param {string} value
 * @param {string} [extraClass]
 * @returns {string}
 */
function renderPlaceholderPanel(label, value, extraClass = "") {
  return `
    <article class="result-panel result-panel-placeholder ${extraClass}">
      <h3>${escapeHtml(label)}</h3>
      <p>${escapeHtml(value)}</p>
    </article>
  `;
}

/**
 * @param {import("../engine/types.js").TranslationResult | null} result
 * @returns {string}
 */
function renderGlossaryPanel(result) {
  return `
    <aside class="compare-panel compare-panel-strong">
      <h2>전문 용어 풀이</h2>
      <p>어려운 표현을 없애기보다, 어떤 뜻인지 바로 이해할 수 있게 풀어드립니다.</p>
      ${
        !result || result.termExplanations.length === 0
          ? '<p class="compare-empty">지금 문장에는 따로 풀어야 할 전문 용어가 많지 않아요.</p>'
          : `
            <table class="compare-table">
              <thead>
                <tr>
                  <th scope="col">원문 표현</th>
                  <th scope="col">쉽게 풀면</th>
                </tr>
              </thead>
              <tbody>
                ${result.termExplanations
                  .map(
                    (item) => `
                      <tr>
                        <td>${escapeHtml(item.term)}</td>
                        <td>${escapeHtml(item.explanation)}</td>
                      </tr>
                    `
                  )
                  .join("")}
              </tbody>
            </table>
          `
      }
      <p class="footer-note">
        AI 설명이 우선 적용되고, 실패하면 기본 설명 모드로 자동 전환됩니다.
      </p>
    </aside>
  `;
}

/**
 * @param {"ai" | "fallback" | null} source
 * @returns {string}
 */
function renderSourceBadgeLabel(source) {
  if (source === "ai") {
    return "AI 설명";
  }

  if (source === "fallback") {
    return "기본 설명 모드";
  }

  return "ready";
}

/**
 * @param {"ai" | "fallback" | null} source
 * @returns {string}
 */
function renderSourceBadgeClass(source) {
  if (source === "ai") {
    return "mono-badge-ai";
  }

  if (source === "fallback") {
    return "mono-badge-fallback";
  }

  return "";
}
