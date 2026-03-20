import { escapeHtml } from "../utils/text.js";

/**
 * @param {import("./state.js").AppState} state
 * @param {{ defaultExample: string, examples: string[] }} options
 * @returns {string}
 */
export function renderAppMarkup(state, options) {
  const { defaultExample, examples } = options;

  return `
    <main class="page-shell">
      <section class="hero-card">
        <span class="eyebrow">Translate-Developer MVP</span>
        <div class="hero-grid">
          <div class="hero-copy">
            <h1>개발자 설명을 비전공자 언어로 바꿉니다</h1>
            <p>
              짧은 개발자 설명이나 슬랙 메시지를 붙여 넣으면,
              비전공자도 따라올 수 있게 핵심 요약과 쉬운 설명으로 다시 풀어줍니다.
            </p>
            <div class="hero-stats" aria-label="핵심 특징">
              <div class="stat-card">
                <strong>1 step</strong>
                <span>붙여 넣고 바로 번역</span>
              </div>
              <div class="stat-card">
                <strong>4 blocks</strong>
                <span>요약, 설명, 영향, 액션</span>
              </div>
              <div class="stat-card">
                <strong>gpt-4.1-mini</strong>
                <span>AI 우선, 실패 시 기본 번역 모드</span>
              </div>
            </div>
          </div>
          <div class="hero-preview" aria-label="결과 미리보기">
            <div class="preview-label">번역 결과 미리보기</div>
            <div class="preview-card">
              <span>한 줄 요약</span>
              <strong>결제 기능에 문제가 있어 확인 중</strong>
            </div>
            <div class="preview-card">
              <span>쉬운 설명</span>
              <strong>시스템 연결 응답이 늦거나 멈춰서 결제가 불안정할 수 있음</strong>
            </div>
            <div class="preview-card preview-card-accent">
              <span>상대방 액션</span>
              <strong>급한 결제는 잠시 뒤 다시 시도하도록 안내</strong>
            </div>
          </div>
        </div>
      </section>

      <section class="workspace" aria-labelledby="translator-title">
        <div class="workspace-head">
          <div>
            <h2 id="translator-title">개발자 메시지 번역기</h2>
            <p>1~5문장 정도의 짧은 기술 설명이 가장 잘 맞습니다.</p>
          </div>
          <span class="mono-badge">ai-first:v1</span>
        </div>

        <div class="workspace-grid">
          <form class="composer" data-role="composer">
            <label class="field-label" for="developer-message">
              개발자 메시지
              <span class="field-help">
                예시: ${escapeHtml(defaultExample)}
              </span>
            </label>
            <textarea
              id="developer-message"
              name="developer-message"
              placeholder="예: 배포 후 결제 API에서 타임아웃이 반복돼서 확인 중입니다."
            >${escapeHtml(state.input)}</textarea>

            <div class="composer-actions">
              <button class="button button-secondary" type="button" data-action="example">
                예시 넣기
              </button>
              <button class="button button-primary" type="submit" ${state.isLoading ? "disabled" : ""}>
                ${state.isLoading ? "AI 번역 중..." : "번역하기"}
              </button>
            </div>
          </form>

          <aside class="helper-panel" aria-label="빠른 예시와 가이드">
            <div class="helper-block">
              <h3>빠른 예시</h3>
              <p>실제로 자주 나오는 개발자 메시지 톤으로 바로 확인할 수 있습니다.</p>
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
              <h3>이 버전이 잘하는 것</h3>
              <ul class="helper-list">
                <li>짧은 슬랙 메시지 정리</li>
                <li>장애나 지연 상황 설명</li>
                <li>비전공자에게 전달할 핵심 분리</li>
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
              <p>같은 내용을 비전공자 관점에서 다시 정리했습니다.</p>
            </div>
            <span class="mono-badge ${renderSourceBadgeClass(state.engineSource)}">${renderSourceBadgeLabel(state.engineSource)}</span>
          </div>
          <div class="results-rail">
            <span class="meta-chip">한 줄 요약</span>
            <span class="meta-chip">쉬운 설명</span>
            <span class="meta-chip">지금 중요한 것</span>
            <span class="meta-chip">상대방 액션</span>
          </div>
        </div>

        <div class="results-grid">
          ${renderResultPanels(state.result)}
          ${renderComparisonPanel(state.result)}
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
        ${renderPlaceholderPanel("한 줄 요약", "무슨 상황인지 한 문장으로 정리합니다.")}
        ${renderPlaceholderPanel("쉬운 설명", "기술 표현을 일반적인 말로 풀어 설명합니다.")}
        ${renderPlaceholderPanel("지금 중요한 것", "지금 사용자나 팀에 어떤 영향이 있는지 보여줍니다.")}
        ${renderPlaceholderPanel("상대방 액션", "지금 무엇을 이해하거나 안내해야 하는지 정리합니다.")}
      </div>
    `;
  }

  return `
    <div class="result-grid">
      ${renderResultPanel("한 줄 요약", result.summary)}
      ${renderResultPanel("쉬운 설명", result.easyExplanation)}
      ${renderResultPanel("지금 중요한 것", result.importantNow)}
      ${renderResultPanel("상대방 액션", result.actionForReader)}
    </div>
  `;
}

/**
 * @param {string} label
 * @param {string} value
 * @returns {string}
 */
function renderResultPanel(label, value) {
  return `
    <article class="result-panel">
      <h3>${escapeHtml(label)}</h3>
      <p>${escapeHtml(value)}</p>
    </article>
  `;
}

/**
 * @param {string} label
 * @param {string} value
 * @returns {string}
 */
function renderPlaceholderPanel(label, value) {
  return `
    <article class="result-panel result-panel-placeholder">
      <h3>${escapeHtml(label)}</h3>
      <p>${escapeHtml(value)}</p>
    </article>
  `;
}

/**
 * @param {import("../engine/types.js").TranslationResult | null} result
 * @returns {string}
 */
function renderComparisonPanel(result) {
  return `
    <aside class="compare-panel compare-panel-strong">
      <h2>원문 대비</h2>
      <p>기술 용어를 없애기보다, 이해 가능한 말로 풀어쓴 부분을 보여줍니다.</p>
      ${
        !result || result.termPairs.length === 0
          ? '<p class="compare-empty">감지된 핵심 기술 용어가 아직 없습니다.</p>'
          : `
            <table class="compare-table">
              <thead>
                <tr>
                  <th scope="col">원문 표현</th>
                  <th scope="col">쉽게 바꾼 말</th>
                </tr>
              </thead>
              <tbody>
                ${result.termPairs
                  .map(
                    (pair) => `
                      <tr>
                        <td>${escapeHtml(pair.original)}</td>
                        <td>${escapeHtml(pair.simplified)}</td>
                      </tr>
                    `
                  )
                  .join("")}
              </tbody>
            </table>
          `
      }
      <p class="footer-note">
        AI 번역이 우선 적용되고, 실패하면 기본 번역 모드로 자동 전환됩니다.
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
    return "AI 번역";
  }

  if (source === "fallback") {
    return "기본 번역 모드";
  }

  return "translation-ready";
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
