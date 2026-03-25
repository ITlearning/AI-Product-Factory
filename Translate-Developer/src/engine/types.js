/**
 * @typedef {"pm-planner" | "designer" | "non-developer"} AudienceId
 */

/**
 * @typedef {{ term: string, explanation: string }} TermExplanation
 */

/**
 * @typedef {{
 *   rewrittenMessage: string,
 *   confirmedImpact: string,
 *   needsMoreContext: string,
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
    confirmedImpact: "",
    needsMoreContext: "",
    termExplanations: []
  };
}
