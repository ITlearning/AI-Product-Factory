const replyOptionSchema = {
  type: "object",
  additionalProperties: false,
  required: ["text", "toneLabel", "whyItWorks"],
  properties: {
    text: { type: "string" },
    toneLabel: { type: "string" },
    whyItWorks: { type: "string" }
  }
};

export const REPLY_JSON_SCHEMA = {
  name: "ibad_reply_set",
  schema: {
    type: "object",
    additionalProperties: false,
    required: [
      "replyOptions",
      "avoidPhrases",
      "openDoorRisk",
      "alternativeDifference"
    ],
    properties: {
      replyOptions: {
        type: "array",
        minItems: 3,
        maxItems: 3,
        items: replyOptionSchema
      },
      avoidPhrases: {
        type: "array",
        items: { type: "string" }
      },
      openDoorRisk: { type: "string" },
      alternativeDifference: { type: "string" }
    }
  }
};

/**
 * @param {unknown} payload
 * @returns {{
 *   replyOptions: { text: string, toneLabel: string, whyItWorks: string }[],
 *   avoidPhrases: string[],
 *   openDoorRisk: string,
 *   alternativeDifference: string
 * } | null}
 */
export function normalizeReplyResult(payload) {
  if (!payload || typeof payload !== "object") {
    return null;
  }

  const replyOptions = Array.isArray(payload.replyOptions) ? payload.replyOptions : null;

  if (!replyOptions || replyOptions.length !== 3) {
    return null;
  }

  const normalizedReplyOptions = replyOptions.map((option) => {
    if (!option || typeof option !== "object") {
      return null;
    }

    const text = normalizeText(option.text);
    const toneLabel = normalizeText(option.toneLabel);
    const whyItWorks = normalizeText(option.whyItWorks);

    if (!text || !toneLabel || !whyItWorks) {
      return null;
    }

    return { text, toneLabel, whyItWorks };
  });

  if (normalizedReplyOptions.some((option) => option === null)) {
    return null;
  }

  const texts = new Set(normalizedReplyOptions.map((option) => option.text));

  if (texts.size !== 3) {
    return null;
  }

  const avoidPhrases = Array.isArray(payload.avoidPhrases)
    ? payload.avoidPhrases.map(normalizeText).filter(Boolean)
    : [];
  const openDoorRisk = normalizeText(payload.openDoorRisk);
  const alternativeDifference = normalizeText(payload.alternativeDifference);

  if (!openDoorRisk || !alternativeDifference) {
    return null;
  }

  return {
    replyOptions: /** @type {{ text: string, toneLabel: string, whyItWorks: string }[]} */ (
      normalizedReplyOptions
    ),
    avoidPhrases,
    openDoorRisk,
    alternativeDifference
  };
}

/**
 * @param {unknown} value
 * @returns {string}
 */
function normalizeText(value) {
  return typeof value === "string" ? value.replace(/\s+/g, " ").trim() : "";
}
