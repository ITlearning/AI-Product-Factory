/**
 * @typedef {"pm-planner" | "designer" | "non-developer"} AudienceId
 */

/**
 * @typedef {{ term: string, explanation: string }} TermExplanation
 */

/**
 * @typedef {{
 *   rewrittenMessage: string,
 *   context: string,
 *   caveat: string,
 *   termExplanations: TermExplanation[]
 * }} TranslationResult
 */

/**
 * @typedef {{
 *   translate: (input: string) => TranslationResult
 * }} TranslationEngine
 */

/**
 * @returns {TranslationResult}
 */
export function createEmptyTranslationResult() {
  return {
    rewrittenMessage: "",
    context: "",
    caveat: "",
    termExplanations: []
  };
}
