/** @typedef {"soft" | "polite-firm" | "short"} ReplyTone */

export const BLOCKER_COACHING = {
  guilt: {
    recommendedTone: "soft",
    coachNote: "미안함을 길게 풀어주기보다 결론 한 번, 감사 한 번이면 충분해요."
  },
  "tone-anxiety": {
    recommendedTone: "polite-firm",
    coachNote: "예의는 유지하되 결론을 먼저 두면 차갑기보다 분명하게 읽혀요."
  },
  overexplaining: {
    recommendedTone: "short",
    coachNote: "설명이 길어질수록 다시 붙잡힐 수 있어요. 한 문장으로 먼저 끝내세요."
  }
};

const DEFAULT_BLOCKER_TYPE = "tone-anxiety";
const REPLY_TONE_ORDER = ["soft", "polite-firm", "short"];

/**
 * @param {string} blockerType
 * @returns {{ recommendedTone: ReplyTone, coachNote: string }}
 */
export function getCoachingForBlocker(blockerType) {
  return BLOCKER_COACHING[blockerType] ?? BLOCKER_COACHING[DEFAULT_BLOCKER_TYPE];
}

/**
 * @param {ReplyTone} recommendedTone
 * @returns {number}
 */
export function getRecommendedOptionIndex(recommendedTone) {
  return REPLY_TONE_ORDER.indexOf(recommendedTone);
}

/**
 * @param {number} optionIndex
 * @returns {ReplyTone | null}
 */
export function getReplyToneByIndex(optionIndex) {
  return REPLY_TONE_ORDER[optionIndex] ?? null;
}
