/**
 * @typedef {{ original: string, simplified: string }} TermPair
 */

/**
 * @typedef {{
 *   summary: string,
 *   easyExplanation: string,
 *   importantNow: string,
 *   actionForReader: string,
 *   termPairs: TermPair[]
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
    summary: "",
    easyExplanation: "",
    importantNow: "",
    actionForReader: "",
    termPairs: []
  };
}
