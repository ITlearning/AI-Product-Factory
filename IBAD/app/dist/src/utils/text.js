/**
 * @param {string} value
 * @returns {string}
 */
export function normalizeInput(value) {
  return value.replace(/\s+/g, " ").trim();
}

/**
 * @param {string} value
 * @returns {string}
 */
export function ensureSentence(value) {
  const trimmed = normalizeInput(value);

  if (!trimmed) {
    return "";
  }

  return /[.!?。]$/.test(trimmed) ? trimmed : `${trimmed}.`;
}

/**
 * @param {string} value
 * @returns {string}
 */
export function escapeHtml(value) {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}
