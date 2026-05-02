/**
 * 폼 진척 임시 저장 (sessionStorage 기반).
 *
 * 새로고침/실수 닫기 대비. 결과 페이지 진입 시 호출 측에서 clearDraft() 호출.
 * sessionStorage 접근 자체가 throw하는 환경(시크릿 모드 일부, SSR 등) 대비 try/catch 래핑.
 */

const KEY = "checker-form-draft";

/**
 * @param {object} state
 */
export function saveDraft(state) {
  try {
    sessionStorage.setItem(KEY, JSON.stringify(state));
  } catch {
    /* noop — quota / privacy mode */
  }
}

/**
 * @returns {object | null}
 */
export function loadDraft() {
  try {
    const raw = sessionStorage.getItem(KEY);
    return raw ? JSON.parse(raw) : null;
  } catch {
    return null;
  }
}

export function clearDraft() {
  try {
    sessionStorage.removeItem(KEY);
  } catch {
    /* noop */
  }
}
