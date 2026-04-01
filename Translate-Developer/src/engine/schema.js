const REQUIRED_STRING_FIELDS = ["rewrittenMessage", "context", "caveat"];

/**
 * @param {unknown} value
 * @returns {value is { term: string, explanation: string }}
 */
export function isValidTermExplanation(value) {
  if (!value || typeof value !== "object") {
    return false;
  }

  return (
    typeof value.term === "string" &&
    typeof value.explanation === "string" &&
    value.term.trim().length > 0 &&
    value.explanation.trim().length > 0
  );
}

/**
 * @param {unknown} value
 * @returns {value is import("./types.js").TranslationResult}
 */
export function isValidTranslationResult(value) {
  if (!value || typeof value !== "object") {
    return false;
  }

  for (const key of REQUIRED_STRING_FIELDS) {
    if (typeof value[key] !== "string" || value[key].trim().length === 0) {
      return false;
    }
  }

  return Array.isArray(value.termExplanations) && value.termExplanations.every(isValidTermExplanation);
}

/**
 * @param {unknown} value
 * @returns {import("./types.js").TranslationResult | null}
 */
export function normalizeTranslationResult(value) {
  if (!isValidTranslationResult(value)) {
    return null;
  }

  return {
    rewrittenMessage: value.rewrittenMessage.trim(),
    context: value.context.trim(),
    caveat: value.caveat.trim(),
    termExplanations: value.termExplanations.map((item) => ({
      term: item.term.trim(),
      explanation: item.explanation.trim()
    }))
  };
}

export const TRANSLATION_JSON_SCHEMA = {
  name: "developer_translation",
  schema: {
    type: "object",
    additionalProperties: false,
    required: ["rewrittenMessage", "context", "caveat", "termExplanations"],
    properties: {
      rewrittenMessage: { type: "string" },
      context: { type: "string" },
      caveat: { type: "string" },
      termExplanations: {
        type: "array",
        items: {
          type: "object",
          additionalProperties: false,
          required: ["term", "explanation"],
          properties: {
            term: { type: "string" },
            explanation: { type: "string" }
          }
        }
      }
    }
  }
};
