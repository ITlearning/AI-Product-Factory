const REQUIRED_STRING_FIELDS = ["summary", "easyExplanation", "importantNow", "actionForReader"];

/**
 * @param {unknown} value
 * @returns {value is { original: string, simplified: string }}
 */
export function isValidTermPair(value) {
  if (!value || typeof value !== "object") {
    return false;
  }

  return (
    typeof value.original === "string" &&
    typeof value.simplified === "string" &&
    value.original.trim().length > 0 &&
    value.simplified.trim().length > 0
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

  return Array.isArray(value.termPairs) && value.termPairs.every(isValidTermPair);
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
    summary: value.summary.trim(),
    easyExplanation: value.easyExplanation.trim(),
    importantNow: value.importantNow.trim(),
    actionForReader: value.actionForReader.trim(),
    termPairs: value.termPairs.map((pair) => ({
      original: pair.original.trim(),
      simplified: pair.simplified.trim()
    }))
  };
}

export const TRANSLATION_JSON_SCHEMA = {
  name: "developer_translation",
  schema: {
    type: "object",
    additionalProperties: false,
    required: ["summary", "easyExplanation", "importantNow", "actionForReader", "termPairs"],
    properties: {
      summary: { type: "string" },
      easyExplanation: { type: "string" },
      importantNow: { type: "string" },
      actionForReader: { type: "string" },
      termPairs: {
        type: "array",
        items: {
          type: "object",
          additionalProperties: false,
          required: ["original", "simplified"],
          properties: {
            original: { type: "string" },
            simplified: { type: "string" }
          }
        }
      }
    }
  }
};
