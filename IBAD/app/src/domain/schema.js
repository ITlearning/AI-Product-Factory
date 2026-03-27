import { SUPPORTED_REPLY_TONE_VALUES } from "./options.js";

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
    required: ["replyOptions", "recommendedTone", "coachNote", "avoidPhrase"],
    properties: {
      replyOptions: {
        type: "array",
        minItems: 3,
        maxItems: 3,
        items: replyOptionSchema
      },
      recommendedTone: {
        type: "string",
        enum: ["soft", "polite-firm", "short"]
      },
      coachNote: { type: "string" },
      avoidPhrase: { type: "string" }
    }
  }
};

/**
 * @param {unknown} payload
 * @returns {{
 *   replyOptions: { text: string, toneLabel: string, whyItWorks: string }[]
 *   recommendedTone: string,
 *   coachNote: string,
 *   avoidPhrase: string
 * } | null}
 */
export function normalizeReplyResult(payload) {
  if (!payload || typeof payload !== "object") {
    return null;
  }

  const replyOptions = Array.isArray(payload.replyOptions) ? payload.replyOptions : null;
  const recommendedTone = normalizeText(payload.recommendedTone);
  const coachNote = normalizeText(payload.coachNote);
  const avoidPhrase = normalizeText(payload.avoidPhrase);

  if (
    !replyOptions ||
    replyOptions.length !== 3 ||
    !SUPPORTED_REPLY_TONE_VALUES.has(recommendedTone) ||
    !coachNote ||
    !avoidPhrase
  ) {
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

  return {
    replyOptions: /** @type {{ text: string, toneLabel: string, whyItWorks: string }[]} */ (
      normalizedReplyOptions
    ),
    recommendedTone,
    coachNote,
    avoidPhrase
  };
}

/**
 * @param {unknown} value
 * @returns {string}
 */
function normalizeText(value) {
  return typeof value === "string" ? value.replace(/\s+/g, " ").trim() : "";
}
