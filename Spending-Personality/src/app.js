import {
  HERO_POINTS,
  PREVIEW_RESULT,
  SAMPLE_TRANSACTIONS,
  SHELL_MILESTONES
} from "./content.js";

/**
 * @param {HTMLElement} root
 */
export function createApp(root) {
  root.innerHTML = renderAppMarkup();
}

export function renderAppMarkup() {
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
            ${HERO_POINTS.map((point) => `<li>${point}</li>`).join("")}
          </ul>
        </div>

        <aside class="hero-preview" aria-label="결과 예시">
          <span class="preview-label">Preview</span>
          <strong class="preview-title">${PREVIEW_RESULT.title}</strong>
          <p class="preview-summary">${PREVIEW_RESULT.summary}</p>
          <div class="tag-list">
            ${PREVIEW_RESULT.tags.map((tag) => `<span class="tag-pill">${tag}</span>`).join("")}
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
            <textarea readonly>${SAMPLE_TRANSACTIONS.join("\n")}</textarea>
          </label>

          <label class="field">
            <span>선택 메모</span>
            <input value="야근하고 돌아오는 길, 오늘은 조금 지친 날" readonly />
          </label>

          <div class="composer-footer">
            <button type="button" disabled>캐릭터 만들기 준비 중</button>
            <p>다음 child task 에서 입력 검증, 예시 주입, 버튼 상태를 연결합니다.</p>
          </div>
        </section>

        <section class="panel insight-panel" aria-labelledby="insight-title">
          <div class="panel-head">
            <p class="panel-kicker">Result shell</p>
            <h2 id="insight-title">결과 카드 구조 미리보기</h2>
          </div>

          <ol class="reason-list">
            ${PREVIEW_RESULT.reasons.map((reason) => `<li>${reason}</li>`).join("")}
          </ol>

          <div class="next-move">
            <span>내일의 한 수</span>
            <strong>${PREVIEW_RESULT.nextMove}</strong>
          </div>
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
                <span>${item.label}</span>
                <strong>${item.title}</strong>
                <p>${item.copy}</p>
              </article>
            `
          ).join("")}
        </div>
      </section>
    </main>
  `;
}
