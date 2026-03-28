import {
  HERO_POINTS,
  SAMPLE_NOTE,
  SAMPLE_TRANSACTIONS,
  SHELL_MILESTONES
} from "./content.js";
import { CHARACTER_RESULT_STATUS } from "./character-contract.js";
import { generateCharacterResult } from "./character-engine.js";

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
  root.innerHTML = renderAppMarkup();
}

export function renderAppMarkup() {
  const previewResult = getPreviewResult();

  return `
    <main class="page-shell">
      <section class="hero-card">
        <div class="hero-copy">
          <span class="eyebrow">Spending-Personality MVP shell</span>
          <h1>오늘의 소비를 캐릭터처럼 읽어보는 첫 화면</h1>
          <p>
            소비 내역을 숫자 표가 아니라 별명, 태그, 한 줄 해석으로 읽어주는 서비스를 위한
            실행 가능한 앱 셸입니다. 지금 단계에서는 이후 task 들이 바로 얹힐 수 있도록
            스택, 레이아웃, 검증 경로를 먼저 고정합니다.
          </p>
          <ul class="hero-points">
            ${HERO_POINTS.map((point) => `<li>${escapeHtml(point)}</li>`).join("")}
          </ul>
        </div>

        <aside class="hero-preview" aria-label="결과 예시">
          <span class="preview-label">Preview</span>
          <strong class="preview-title">${escapeHtml(previewResult.characterName)}</strong>
          <p class="preview-summary">${escapeHtml(previewResult.summary)}</p>
          <div class="tag-list">
            ${previewResult.tags
              .map((tag) => `<span class="tag-pill">${escapeHtml(tag)}</span>`)
              .join("")}
          </div>
        </aside>
      </section>

      <section class="workspace-grid">
        <section class="panel composer-panel" aria-labelledby="composer-title">
          <div class="panel-head">
            <p class="panel-kicker">Input shell</p>
            <h2 id="composer-title">붙여넣기 중심 입력 구역</h2>
          </div>

          <label class="field">
            <span>하루 소비 내역</span>
            <textarea readonly>${escapeHtml(SAMPLE_TRANSACTIONS.join("\n"))}</textarea>
          </label>

          <label class="field">
            <span>선택 메모</span>
            <input value="${escapeHtml(SAMPLE_NOTE)}" readonly />
          </label>

          <div class="composer-footer">
            <button type="button" disabled>캐릭터 만들기 준비 중</button>
            <p>생성 엔진 계약은 준비됐고, 다음 child task 에서 입력 상태와 버튼 동작을 연결합니다.</p>
          </div>
        </section>

        <section class="panel insight-panel" aria-labelledby="insight-title">
          <div class="panel-head">
            <p class="panel-kicker">Result contract</p>
            <h2 id="insight-title">해석 엔진 샘플 결과</h2>
          </div>

          <p class="pattern-note">${escapeHtml(previewResult.patternObservation)}</p>

          <ul class="evidence-grid">
            ${previewResult.evidence
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
            <strong>${escapeHtml(previewResult.nextMove)}</strong>
          </div>

          <p class="result-disclaimer">${escapeHtml(previewResult.disclaimer)}</p>
        </section>
      </section>

      <section class="panel roadmap-panel" aria-labelledby="roadmap-title">
        <div class="panel-head">
          <p class="panel-kicker">Delivery path</p>
          <h2 id="roadmap-title">이 셸 위에 붙을 다음 작업</h2>
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

function getPreviewResult() {
  const result = generateCharacterResult(SAMPLE_TRANSACTIONS.join("\n"), { note: SAMPLE_NOTE });

  if (result.status !== CHARACTER_RESULT_STATUS.SUCCESS) {
    throw new Error("Sample preview must generate a success result");
  }

  return result;
}
