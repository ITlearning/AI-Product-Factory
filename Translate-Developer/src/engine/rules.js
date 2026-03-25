import {
  CAUSE_PATTERNS,
  DELAY_KEYWORDS,
  INVESTIGATING_KEYWORDS,
  PHRASE_REPLACEMENTS,
  TERM_DICTIONARY,
  TOPIC_KEYWORDS,
  URGENCY_KEYWORDS,
  USER_IMPACT_KEYWORDS
} from "./dictionary.js";

/**
 * @param {string} input
 * @returns {{ term: string, explanation: string }[]}
 */
export function extractTermExplanations(input) {
  return TERM_DICTIONARY
    .filter(([term]) => input.includes(term))
    .map(([term, explanation]) => ({ term, explanation }));
}

/**
 * @param {string} input
 * @returns {string}
 */
export function applyTermSimplifications(input) {
  return TERM_DICTIONARY.reduce((accumulator, [term, simplified]) => {
    return accumulator.split(term).join(simplified);
  }, input);
}

/**
 * @param {string} input
 * @returns {string}
 */
export function applyPhraseReplacements(input) {
  return PHRASE_REPLACEMENTS.reduce((accumulator, [source, target]) => {
    return accumulator.split(source).join(target);
  }, input);
}

/**
 * @param {string} input
 * @returns {{
 *   issueLike: boolean,
 *   urgent: boolean,
 *   investigating: boolean,
 *   delayed: boolean,
 *   deployRelated: boolean
 * }}
 */
export function detectSignals(input) {
  const issueLike = /(에러|오류|실패|장애|불안정|타임아웃|문제)/.test(input);

  return {
    issueLike,
    urgent: URGENCY_KEYWORDS.some((keyword) => input.includes(keyword)),
    investigating: INVESTIGATING_KEYWORDS.some((keyword) => input.includes(keyword)),
    delayed: DELAY_KEYWORDS.some((keyword) => input.includes(keyword)),
    deployRelated: input.includes("배포")
  };
}

/**
 * @param {string} input
 * @returns {string}
 */
export function extractTopic(input) {
  return TOPIC_KEYWORDS.find((keyword) => input.includes(keyword)) ?? "서비스";
}

/**
 * @param {string} input
 * @returns {string}
 */
export function extractAudienceImpact(input) {
  if (input.includes("일부 사용자")) {
    return "일부 사용자가 바로 영향을 받고 있습니다";
  }

  if (USER_IMPACT_KEYWORDS.some((keyword) => input.includes(keyword))) {
    return "사용자가 실제 이용 중에 불편을 겪을 수 있습니다";
  }

  return "관련 기능을 쓰는 사람이 불편을 겪을 수 있습니다";
}

/**
 * @param {string} input
 * @returns {string}
 */
export function extractCauseLabel(input) {
  const match = CAUSE_PATTERNS.find((item) => item.pattern.test(input));
  return match?.label ?? "기술적인 문제가 발생한 상태";
}

/**
 * @param {string} input
 * @returns {string}
 */
export function extractStatusLabel(input) {
  if (/긴급 대응 중/.test(input)) {
    return "지금 급하게 대응하고 있어요";
  }

  if (/확인 중|조사 중|살펴보고/.test(input)) {
    return "지금 원인을 확인하고 있어요";
  }

  if (/지연|밀려/.test(input)) {
    return "지금 처리 흐름을 살펴보고 있어요";
  }

  return "지금 상황을 파악하고 있어요";
}
