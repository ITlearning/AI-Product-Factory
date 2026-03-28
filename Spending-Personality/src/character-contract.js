export const CHARACTER_RESULT_STATUS = {
  SUCCESS: "success",
  NEEDS_MORE_DATA: "needs-more-data",
  PARSE_FAILED: "parse-failed"
};

export const OBSERVATIONAL_DISCLAIMER =
  "입력된 소비 문장을 바탕으로 한 가벼운 해석이며, 실제 성향을 단정하지 않아요.";

/**
 * @param {unknown} value
 * @returns {value is string}
 */
function isNonEmptyString(value) {
  return typeof value === "string" && value.trim().length > 0;
}

/**
 * @param {unknown} value
 * @returns {value is number}
 */
function isNonNegativeInteger(value) {
  return Number.isInteger(value) && value >= 0;
}

/**
 * @param {unknown} evidence
 */
function assertEvidence(evidence) {
  if (!Array.isArray(evidence) || evidence.length < 2 || evidence.length > 3) {
    throw new Error("Success results must include 2 to 3 evidence items");
  }

  for (const item of evidence) {
    if (!item || typeof item !== "object") {
      throw new Error("Evidence items must be objects");
    }

    if (!isNonEmptyString(item.label)) {
      throw new Error("Evidence items must include a label");
    }

    if (!isNonEmptyString(item.amountText)) {
      throw new Error("Evidence items must include amount text");
    }

    if (!isNonEmptyString(item.reason)) {
      throw new Error("Evidence items must include a reason");
    }

    if (!isNonEmptyString(item.rawText)) {
      throw new Error("Evidence items must include raw text");
    }
  }
}

/**
 * @param {unknown} tags
 */
function assertTags(tags) {
  if (!Array.isArray(tags) || tags.length !== 3 || !tags.every(isNonEmptyString)) {
    throw new Error("Success results must include exactly three tags");
  }
}

/**
 * @param {unknown} result
 */
export function assertCharacterResult(result) {
  if (!result || typeof result !== "object") {
    throw new Error("Character result must be an object");
  }

  if (!Object.values(CHARACTER_RESULT_STATUS).includes(result.status)) {
    throw new Error("Character result status is invalid");
  }

  if (!isNonEmptyString(result.disclaimer)) {
    throw new Error("Character result must include a disclaimer");
  }

  if (!isNonNegativeInteger(result.rawLineCount)) {
    throw new Error("Character result must include a rawLineCount");
  }

  if (!isNonNegativeInteger(result.parsedTransactionCount)) {
    throw new Error("Character result must include a parsedTransactionCount");
  }

  if (!isNonNegativeInteger(result.ignoredLineCount)) {
    throw new Error("Character result must include an ignoredLineCount");
  }

  if (result.disclaimer !== OBSERVATIONAL_DISCLAIMER) {
    throw new Error("Character result disclaimer must match the observational disclaimer");
  }

  if (result.rawLineCount !== result.parsedTransactionCount + result.ignoredLineCount) {
    throw new Error(
      "Character result counts inconsistent: rawLineCount must equal parsedTransactionCount + ignoredLineCount"
    );
  }

  if (result.status === CHARACTER_RESULT_STATUS.SUCCESS) {
    if (!isNonEmptyString(result.characterName)) {
      throw new Error("Success results must include a characterName");
    }

    if (!isNonEmptyString(result.summary)) {
      throw new Error("Success results must include a summary");
    }

    if (!isNonEmptyString(result.patternObservation)) {
      throw new Error("Success results must include a patternObservation");
    }

    if (!isNonEmptyString(result.nextMove)) {
      throw new Error("Success results must include a nextMove");
    }

    assertTags(result.tags);
    assertEvidence(result.evidence);
    return;
  }

  if (!isNonEmptyString(result.message)) {
    throw new Error("Error results must include a message");
  }

  if (!isNonEmptyString(result.hint)) {
    throw new Error("Error results must include a hint");
  }
}

/**
 * @param {unknown} result
 * @returns {boolean}
 */
export function isCharacterResult(result) {
  try {
    assertCharacterResult(result);
    return true;
  } catch {
    return false;
  }
}
