import { createEmptyTranslationResult } from "./types.js";
import {
  applyPhraseReplacements,
  applyTermSimplifications,
  detectSignals,
  extractAudienceImpact,
  extractCauseLabel,
  extractStatusLabel,
  extractTermPairs,
  extractTopic
} from "./rules.js";
import { ensureSentence, normalizeInput } from "../utils/text.js";

const IMPACT_LABELS = {
  로그인: "로그인이 잘 되지 않거나 끊길 수 있습니다.",
  결제: "결제가 늦어지거나 실패할 수 있습니다.",
  주문: "주문 처리 속도가 느려질 수 있습니다.",
  정산: "정산 데이터 반영이 늦어질 수 있습니다.",
  회원가입: "회원가입 완료가 지연될 수 있습니다.",
  업로드: "파일 업로드가 늦거나 실패할 수 있습니다.",
  다운로드: "파일을 받는 속도가 느려질 수 있습니다.",
  알림: "알림이 바로 가지 않고 늦게 도착할 수 있습니다.",
  검색: "검색 결과가 느리거나 정확하지 않을 수 있습니다.",
  메시지: "메시지가 늦게 보이거나 전송이 끊길 수 있습니다.",
  앱: "앱 사용 중 일부 기능이 매끄럽지 않을 수 있습니다.",
  서버: "서비스 전반의 반응이 느려질 수 있습니다.",
  API: "연결된 기능 일부가 늦거나 실패할 수 있습니다.",
  서비스: "일부 기능이 평소처럼 동작하지 않을 수 있습니다."
};

const ACTION_LABELS = {
  로그인: "로그인이 급하면 잠시 후 다시 시도하고, 사용자 안내가 필요하면 접속 지연 가능성을 먼저 알려주면 됩니다.",
  결제: "급한 결제가 있다면 잠시 후 다시 시도하고, 안내가 필요하면 결제 지연 가능성을 먼저 공유하면 됩니다.",
  주문: "급한 주문은 처리 완료 여부를 다시 확인하고, 외부 안내가 필요하면 주문 지연 가능성을 먼저 전달하면 됩니다.",
  정산: "정산 수치가 바로 안 보일 수 있으니 확정 수치 전달 전 한 번 더 확인하면 됩니다.",
  회원가입: "신규 가입이 안 될 수 있으니 잠시 후 다시 시도하도록 안내하면 됩니다.",
  업로드: "중요한 파일은 업로드 완료 여부를 다시 확인하고, 실패하면 잠시 뒤 재시도하면 됩니다.",
  다운로드: "다운로드가 급하면 잠시 뒤 다시 시도하도록 안내하면 됩니다.",
  알림: "즉시 전달이 중요하면 다른 채널 안내도 함께 준비하면 됩니다.",
  검색: "검색 결과를 바로 믿기보다 필요한 항목은 직접 다시 확인하면 됩니다.",
  메시지: "중요한 전달은 상대가 실제로 받았는지 한 번 더 확인하면 됩니다.",
  앱: "사용자 공지가 필요하면 일부 기능 불안정 가능성을 먼저 알려주면 됩니다.",
  서버: "서비스 공지가 필요하면 일부 기능 지연 가능성을 먼저 공유하면 됩니다.",
  API: "연결된 기능을 쓰는 팀이 있다면 응답 지연 가능성을 먼저 알려주면 됩니다.",
  서비스: "추가 공지가 나올 때까지 현재 상황만 이해하고, 급한 작업은 잠시 뒤 다시 시도하면 됩니다."
};

/**
 * @param {string} topic
 * @param {{ issueLike: boolean, urgent: boolean, investigating: boolean, delayed: boolean, deployRelated: boolean }} signals
 * @returns {string}
 */
function buildSummary(topic, signals) {
  const topicLabel = topic === "서비스" ? "서비스" : `${topic} 기능`;

  if (signals.deployRelated && signals.issueLike) {
    return ensureSentence(`배포 이후 ${topicLabel}에서 문제가 발생했습니다`);
  }

  if (signals.issueLike && signals.urgent) {
    return ensureSentence(`${topicLabel}에 바로 대응이 필요한 문제가 있습니다`);
  }

  if (signals.issueLike) {
    return ensureSentence(`${topicLabel}에 문제가 있어 개발팀이 확인하고 있습니다`);
  }

  if (signals.delayed) {
    return ensureSentence(`${topicLabel} 응답이 평소보다 늦어지고 있습니다`);
  }

  return ensureSentence(`개발팀이 ${topicLabel} 관련 상황을 공유했습니다`);
}

/**
 * @param {string} input
 * @param {string} topic
 * @param {{ issueLike: boolean, urgent: boolean, investigating: boolean, delayed: boolean, deployRelated: boolean }} signals
 * @returns {string}
 */
function buildEasyExplanation(input, topic, signals) {
  const simplified = ensureSentence(applyPhraseReplacements(applyTermSimplifications(input)));
  const cause = extractCauseLabel(input);
  const status = extractStatusLabel(input);
  const impact = extractAudienceImpact(input);
  const topicLabel = topic === "서비스" ? "이 상황" : `${topic} 관련 상황`;

  if (signals.issueLike || signals.delayed) {
    return `${topicLabel}은 ${cause} 때문에 생긴 문제이고, ${status}. ${impact}.`;
  }

  return simplified;
}

/**
 * @param {string} topic
 * @param {{ issueLike: boolean, urgent: boolean, investigating: boolean, delayed: boolean, deployRelated: boolean }} signals
 * @returns {string}
 */
function buildImportantNow(topic, signals) {
  const impact = IMPACT_LABELS[topic] ?? IMPACT_LABELS.서비스;

  if (signals.issueLike || signals.delayed) {
    if (signals.urgent) {
      return `지금은 빠른 안내가 중요합니다. ${impact}`;
    }

    return `지금은 ${impact}`;
  }

  if (signals.investigating) {
    return "지금은 큰 조치보다 원인 파악 결과를 기다리는 단계입니다.";
  }

  return "지금은 상황을 이해하고 추가 안내를 기다리면 됩니다.";
}

/**
 * @param {string} topic
 * @param {{ issueLike: boolean, urgent: boolean, investigating: boolean, delayed: boolean, deployRelated: boolean }} signals
 * @returns {string}
 */
function buildActionForReader(topic, signals) {
  if (!signals.issueLike && !signals.delayed && !signals.investigating) {
    return "당장 따로 할 일은 많지 않고, 이후 공지가 나오면 그 내용만 따라가면 됩니다.";
  }

  return ACTION_LABELS[topic] ?? ACTION_LABELS.서비스;
}

/**
 * @param {string} input
 * @returns {import("./types.js").TranslationResult}
 */
export function translateWithRules(input) {
  const normalized = normalizeInput(input);

  if (!normalized) {
    return createEmptyTranslationResult();
  }

  const signals = detectSignals(normalized);
  const topic = extractTopic(normalized);
  const termPairs = extractTermPairs(normalized);

  return {
    summary: buildSummary(topic, signals),
    easyExplanation: buildEasyExplanation(normalized, topic, signals),
    importantNow: buildImportantNow(topic, signals),
    actionForReader: buildActionForReader(topic, signals),
    termPairs
  };
}
