import { createEmptyTranslationResult } from "./types.js";
import {
  applyPhraseReplacements,
  applyTermSimplifications,
  detectSignals,
  extractCauseLabel,
  extractStatusLabel,
  extractTermExplanations,
  extractTopic
} from "./rules.js";
import { ensureSentence, normalizeInput } from "../utils/text.js";

/**
 * @param {string} topic
 * @param {{ issueLike: boolean, urgent: boolean, investigating: boolean, delayed: boolean, deployRelated: boolean }} signals
 * @returns {string}
 */
function buildRewrittenMessage(input, topic, signals) {
  const simplified = ensureSentence(applyPhraseReplacements(applyTermSimplifications(input)));
  const cause = extractCauseLabel(input);
  const status = extractStatusLabel(input);
  const topicLabel = topic === "서비스" ? "이 내용" : `${topic} 관련 내용`;

  if (signals.issueLike || signals.delayed) {
    return `${topicLabel}은 ${cause}가 보여서, ${status}.`;
  }

  return simplified;
}

/**
 * @param {string} input
 * @param {string} topic
 * @param {{ issueLike: boolean, urgent: boolean, investigating: boolean, delayed: boolean, deployRelated: boolean }} signals
 * @returns {string}
 */
function buildConfirmedImpact(input, topic, signals) {
  if (/일부 사용자/.test(input) && /접속을 못|영향|불편/.test(input)) {
    return "일부 사용자가 바로 영향을 받고 있다는 점이 메시지에 직접 나와 있어요.";
  }

  if (/접속을 못/.test(input)) {
    return "접속이 잘 되지 않는 사용자가 있다는 점이 메시지에 직접 드러나 있어요.";
  }

  if (/늦어지고 있습니다|지연되고 있습니다/.test(input)) {
    return "처리가 평소보다 늦어지고 있다는 점이 메시지에 직접 나와 있어요.";
  }

  if (/실패하고 있습니다|실패 중/.test(input)) {
    return "어떤 작업이 정상적으로 끝나지 않고 있다는 점은 분명해 보여요.";
  }

  if (signals.issueLike && signals.urgent) {
    return `${topic === "서비스" ? "문제가" : `${topic} 관련 문제가`} 빠르게 확인되고 있다는 점은 보이지만, 실제 영향 범위까지는 아직 직접 드러나지 않아요.`;
  }

  return "이 대화에는 사용자나 일정에 대한 영향이 직접적으로 적혀 있지 않아요.";
}

/**
 * @param {string} input
 * @param {string} topic
 * @param {{ issueLike: boolean, urgent: boolean, investigating: boolean, delayed: boolean, deployRelated: boolean }} signals
 * @returns {string}
 */
function buildNeedsMoreContext(input, topic, signals) {
  const pieces = [];

  if (!/일부 사용자|접속을 못|실패하고 있습니다|늦어지고 있습니다|지연되고 있습니다/.test(input)) {
    pieces.push(
      `이 대화만으로는 ${topic === "서비스" ? "실제 사용자 영향" : `${topic} 기능이 실제로 어디까지 영향받는지`}까지는 아직 잘 보이지 않아요.`
    );
  }

  if (!/왜|원인|때문/.test(input)) {
    pieces.push("왜 이런 일이 생겼는지에 대한 설명은 아직 나오지 않았어요.");
  }

  if (!/확인 중|조사 중|대응 중|긴급 대응 중|살펴보고/.test(input) && (signals.issueLike || signals.delayed)) {
    pieces.push("지금 어디까지 확인했는지나 어떤 대응을 하고 있는지도 더 있으면 좋아요.");
  }

  if (pieces.length === 0) {
    return "앞뒤 대화가 조금 더 있으면 원인과 영향 범위를 더 정확하게 풀어드릴 수 있어요.";
  }

  return pieces.join(" ");
}

/**
 * @param {string} input
 * @param {import("./types.js").AudienceId} [_audience]
 * @returns {import("./types.js").TranslationResult}
 */
export function translateWithRules(input, _audience = "pm-planner") {
  const normalized = normalizeInput(input);

  if (!normalized) {
    return createEmptyTranslationResult();
  }

  const signals = detectSignals(normalized);
  const topic = extractTopic(normalized);
  const termExplanations = extractTermExplanations(normalized);

  return {
    rewrittenMessage: buildRewrittenMessage(normalized, topic, signals),
    confirmedImpact: buildConfirmedImpact(normalized, topic, signals),
    needsMoreContext: buildNeedsMoreContext(normalized, topic, signals),
    termExplanations
  };
}
