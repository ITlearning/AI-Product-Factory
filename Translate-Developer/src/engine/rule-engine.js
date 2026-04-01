import { createEmptyTranslationResult } from "./types.js";
import {
  detectSignals,
  extractCauseLabel,
  extractStatusLabel,
  extractTopic
} from "./rules.js";
import { ensureSentence, normalizeInput } from "../utils/text.js";
import { getDictionary } from "./dictionaries/index.js";

/**
 * @param {string} input
 * @param {ReturnType<typeof getDictionary>} dict
 * @returns {string}
 */
function applyTermSimplifications(input, dict) {
  return dict.TERM_DICTIONARY.reduce((acc, [term, simplified]) => {
    return acc.split(term).join(simplified);
  }, input);
}

/**
 * @param {string} input
 * @param {ReturnType<typeof getDictionary>} dict
 * @returns {string}
 */
function applyPhraseReplacements(input, dict) {
  return dict.PHRASE_REPLACEMENTS.reduce((acc, [source, target]) => {
    return acc.split(source).join(target);
  }, input);
}

/**
 * @param {string} input
 * @param {ReturnType<typeof getDictionary>} dict
 * @returns {{ term: string, explanation: string }[]}
 */
function extractTermExplanations(input, dict) {
  return dict.TERM_DICTIONARY
    .filter(([term]) => input.includes(term))
    .map(([term, explanation]) => ({ term, explanation }));
}

/**
 * @param {string} topic
 * @param {import("./types.js").AudienceId} audience
 * @param {{ issueLike: boolean, urgent: boolean, investigating: boolean, delayed: boolean, deployRelated: boolean }} signals
 * @returns {string}
 */
function buildRewrittenMessage(input, topic, audience, signals, dict) {
  const simplified = ensureSentence(applyPhraseReplacements(applyTermSimplifications(input, dict), dict));
  const cause = extractCauseLabel(input);
  const status = extractStatusLabel(input);
  const topicLabel = topic === "서비스" ? "이 내용" : `${topic} 관련 내용`;

  if (signals.issueLike || signals.delayed) {
    if (audience === "designer") {
      return `${topicLabel} 쪽 이슈를 확인하는 대화이고, ${status}. 화면이나 사용 흐름에 어디까지 영향이 있는지는 아직 더 봐야 해요.`;
    }

    if (audience === "non-developer") {
      return `${topicLabel}이 평소처럼 잘 안 될 수 있어서, ${status}. 지금은 ${cause}로 보이는 부분을 먼저 살펴보는 단계예요.`;
    }

    return `${topicLabel}에서 ${cause}가 보여서, ${status}. 지금 단계에서는 확실한 내용과 아직 확인 중인 내용이 함께 섞여 있는 상태예요.`;
  }

  return simplified;
}

/**
 * @param {string} input
 * @param {import("./types.js").AudienceId} audience
 * @param {{ issueLike: boolean, urgent: boolean, investigating: boolean, delayed: boolean, deployRelated: boolean }} signals
 * @returns {string}
 */
function buildConfirmedImpact(input, audience, signals) {
  if (/일부 사용자/.test(input) && /접속을 못|영향|불편/.test(input)) {
    return getAudienceImpactMessage(
      audience,
      "일부 사용자가 바로 영향을 받고 있다는 점은 대화에서 확인돼요.",
      "일부 사용자가 실제 이용 중에 영향을 받고 있다는 점은 보여요.",
      "일부 사용자가 바로 불편을 겪고 있다는 점은 보여요."
    );
  }

  if (/접속을 못/.test(input)) {
    return getAudienceImpactMessage(
      audience,
      "접속이 잘 되지 않는 사용자가 있다는 점은 확인돼요.",
      "사용자가 정상적으로 들어오지 못하는 상황이 보인다는 점은 확인돼요.",
      "서비스에 들어가지 못하는 사람이 있다는 점은 보여요."
    );
  }

  if (/늦어지고 있습니다|지연되고 있습니다/.test(input)) {
    return getAudienceImpactMessage(
      audience,
      "처리가 평소보다 늦어지고 있다는 점은 확인돼요.",
      "사용 흐름 어딘가에서 처리 속도가 늦어지고 있다는 점은 보여요.",
      "일이 평소보다 늦게 처리되고 있다는 점은 보여요."
    );
  }

  if (/실패하고 있습니다|실패 중/.test(input)) {
    return getAudienceImpactMessage(
      audience,
      "어떤 작업이 정상적으로 끝나지 않고 있다는 점은 확인돼요.",
      "사용 흐름 안에서 어떤 단계가 정상적으로 끝나지 않는다는 점은 보여요.",
      "어떤 작업이 제대로 끝나지 않고 있다는 점은 보여요."
    );
  }

  if (signals.issueLike && signals.urgent) {
    return getAudienceImpactMessage(
      audience,
      "문제를 빠르게 확인하고 있다는 점은 보이지만, 실제 사용자나 일정 영향 범위까지는 아직 직접 드러나지 않아요.",
      "이슈를 빠르게 확인하고 있다는 점은 보이지만, 어느 화면이나 흐름까지 흔들렸는지는 아직 직접 드러나지 않아요.",
      "문제를 급하게 보고 있다는 점은 보이지만, 실제로 누가 얼마나 불편한지는 아직 바로 보이지 않아요."
    );
  }

  return getAudienceImpactMessage(
    audience,
    "이 대화에는 사용자나 일정에 대한 영향이 직접적으로 적혀 있지 않아요.",
    "이 대화에는 어떤 화면이나 작업 흐름이 직접 영향을 받았는지가 아직 적혀 있지 않아요.",
    "이 대화에는 실제로 누가 얼마나 불편한지가 아직 직접 적혀 있지 않아요."
  );
}

/**
 * @param {string} input
 * @param {string} topic
 * @param {import("./types.js").AudienceId} audience
 * @param {{ issueLike: boolean, urgent: boolean, investigating: boolean, delayed: boolean, deployRelated: boolean }} signals
 * @returns {string}
 */
function buildNeedsMoreContext(input, topic, audience, signals) {
  const pieces = [];

  if (!/일부 사용자|접속을 못|실패하고 있습니다|늦어지고 있습니다|지연되고 있습니다/.test(input)) {
    pieces.push(getMissingImpactMessage(topic, audience));
  }

  if (!/왜|원인|때문/.test(input)) {
    pieces.push(getMissingCauseMessage(audience));
  }

  if (!/확인 중|조사 중|대응 중|긴급 대응 중|살펴보고/.test(input) && (signals.issueLike || signals.delayed)) {
    pieces.push(getMissingStatusMessage(audience));
  }

  if (pieces.length === 0) {
    if (audience === "designer") {
      return "앞뒤 대화가 조금 더 있으면 어떤 화면과 흐름까지 영향이 있는지 더 정확하게 풀어드릴 수 있어요.";
    }

    if (audience === "non-developer") {
      return "앞뒤 대화가 조금 더 있으면 왜 이런 일이 생겼는지와 실제 영향 범위를 더 쉽게 풀어드릴 수 있어요.";
    }

    return "앞뒤 대화가 조금 더 있으면 원인과 영향 범위를 더 정확하게 풀어드릴 수 있어요.";
  }

  return formatNeedsMoreContext(audience, pieces);
}

/**
 * @param {string} input
 * @param {import("./types.js").AudienceId} [audience]
 * @param {string} [categoryId]
 * @returns {import("./types.js").TranslationResult}
 */
export function translateWithRules(input, audience = "pm-planner", categoryId = "developer") {
  const normalized = normalizeInput(input);

  if (!normalized) {
    return createEmptyTranslationResult();
  }

  const dict = getDictionary(categoryId);
  const signals = detectSignals(normalized);
  const topic = extractTopic(normalized);
  const termExplanations = extractTermExplanations(normalized, dict);

  return {
    rewrittenMessage: buildRewrittenMessage(normalized, topic, audience, signals, dict),
    context: buildConfirmedImpact(normalized, audience, signals),
    caveat: buildNeedsMoreContext(normalized, topic, audience, signals),
    termExplanations
  };
}

/**
 * @param {import("./types.js").AudienceId} audience
 * @param {string} pmMessage
 * @param {string} designerMessage
 * @param {string} nonDeveloperMessage
 * @returns {string}
 */
function getAudienceImpactMessage(audience, pmMessage, designerMessage, nonDeveloperMessage) {
  if (audience === "designer") {
    return designerMessage;
  }

  if (audience === "non-developer") {
    return nonDeveloperMessage;
  }

  return pmMessage;
}

/**
 * @param {string} topic
 * @param {import("./types.js").AudienceId} audience
 * @returns {string}
 */
function getMissingImpactMessage(topic, audience) {
  if (audience === "designer") {
    return `이 대화만으로는 ${topic === "서비스" ? "어느 화면이나 사용 흐름" : `${topic} 관련 화면이나 흐름`}이 직접 흔들렸는지까지는 아직 잘 보이지 않아요.`;
  }

  if (audience === "non-developer") {
    return "이 대화만으로는 실제로 누가 얼마나 불편한지까지는 아직 잘 보이지 않아요.";
  }

  return `이 대화만으로는 ${topic === "서비스" ? "실제 사용자 영향" : `${topic} 기능이 실제로 어디까지 영향받는지`}까지는 아직 잘 보이지 않아요.`;
}

/**
 * @param {import("./types.js").AudienceId} audience
 * @returns {string}
 */
function getMissingCauseMessage(audience) {
  if (audience === "designer") {
    return "문제가 어느 단계에서 시작됐는지에 대한 설명은 아직 나오지 않았어요.";
  }

  if (audience === "non-developer") {
    return "왜 이런 일이 생겼는지에 대한 쉬운 설명은 아직 더 필요해요.";
  }

  return "왜 이런 일이 생겼는지에 대한 설명은 아직 나오지 않았어요.";
}

/**
 * @param {import("./types.js").AudienceId} audience
 * @returns {string}
 */
function getMissingStatusMessage(audience) {
  if (audience === "designer") {
    return "지금 어떤 확인이나 대응을 하고 있는지도 더 있으면 좋아요.";
  }

  if (audience === "non-developer") {
    return "지금 어디까지 확인했고 어떻게 해결하려는지도 더 있으면 좋아요.";
  }

  return "지금 어디까지 확인했는지나 어떤 대응을 하고 있는지도 더 있으면 좋아요.";
}

/**
 * @param {import("./types.js").AudienceId} audience
 * @param {string[]} pieces
 * @returns {string}
 */
function formatNeedsMoreContext(audience, pieces) {
  const title =
    audience === "designer"
      ? "디자인/화면 관점에서 더 보면 좋은 점:"
      : audience === "non-developer"
        ? "조금 더 알면 이해가 쉬운 점:"
        : "PM 관점에서 더 확인되면 좋은 점:";

  return [title, ...pieces.map((piece) => `- ${piece}`)].join("\n");
}
