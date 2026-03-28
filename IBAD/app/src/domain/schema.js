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

const RESULT_TONE_VALUES = new Set(["soft", "polite-firm", "short"]);

export const REPLY_JSON_SCHEMA = {
  name: "ibad_reply_set",
  schema: {
    type: "object",
    additionalProperties: false,
    required: ["replyOptions", "avoidPhrase"],
    properties: {
      replyOptions: {
        type: "array",
        minItems: 3,
        maxItems: 3,
        items: replyOptionSchema
      },
      avoidPhrase: { type: "string" }
    }
  }
};

/**
 * @param {unknown} payload
 * @returns {{
 *   replyOptions: { text: string, toneLabel: string, whyItWorks: string }[]
 *   avoidPhrase: string
 * } | null}
 */
export function normalizeAiReplyDraft(payload) {
  if (!payload || typeof payload !== "object") {
    return null;
  }

  const normalizedReplyOptions = normalizeReplyOptions(payload.replyOptions);
  const avoidPhrase = normalizeText(payload.avoidPhrase);

  if (!normalizedReplyOptions || !avoidPhrase) {
    return null;
  }

  return {
    replyOptions: normalizedReplyOptions,
    avoidPhrase
  };
}

/**
 * @param {unknown} payload
 * @returns {{
 *   replyOptions: { text: string, toneLabel: string, whyItWorks: string }[],
 *   recommendedTone: "soft" | "polite-firm" | "short",
 *   coachNote: string,
 *   avoidPhrase: string
 * } | null}
 */
export function normalizeReplyResult(payload) {
  if (!payload || typeof payload !== "object") {
    return null;
  }

  const draft = normalizeAiReplyDraft(payload);
  const recommendedTone = normalizeTone(payload.recommendedTone);
  const coachNote = normalizeText(payload.coachNote);

  if (!draft || !recommendedTone || !coachNote) {
    return null;
  }

  return {
    ...draft,
    recommendedTone,
    coachNote
  };
}

/**
 * @param {{
 *   replyOptions: { text: string, toneLabel: string, whyItWorks: string }[],
 *   avoidPhrase: string
 * }} draft
 * @param {{ recommendedTone: "soft" | "polite-firm" | "short", coachNote: string }} coaching
 * @returns {{
 *   replyOptions: { text: string, toneLabel: string, whyItWorks: string }[],
 *   recommendedTone: "soft" | "polite-firm" | "short",
 *   coachNote: string,
 *   avoidPhrase: string
 * }}
 */
export function buildReplyResult(draft, coaching) {
  return {
    replyOptions: draft.replyOptions,
    recommendedTone: coaching.recommendedTone,
    coachNote: coaching.coachNote,
    avoidPhrase: draft.avoidPhrase
  };
}

/**
 * @param {unknown} replyOptions
 * @returns {{ text: string, toneLabel: string, whyItWorks: string }[] | null}
 */
function normalizeReplyOptions(replyOptions) {
  if (!Array.isArray(replyOptions) || replyOptions.length !== 3) {
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

  const normalized = /** @type {{ text: string, toneLabel: string, whyItWorks: string }[]} */ (
    normalizedReplyOptions
  );
  const texts = new Set(normalized.map((option) => option.text));

  if (texts.size !== 3) {
    return null;
  }

  return normalized;
}

/**
 * @param {unknown} value
 * @returns {"soft" | "polite-firm" | "short" | ""}
 */
function normalizeTone(value) {
  return typeof value === "string" && RESULT_TONE_VALUES.has(value) ? value : "";
}

/**
 * @param {unknown} value
 * @returns {string}
 */
function normalizeText(value) {
  return typeof value === "string" ? value.replace(/\s+/g, " ").trim() : "";
}
