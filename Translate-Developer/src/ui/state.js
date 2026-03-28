import { translateWithFallback } from "../engine/index.js";
import { requestAiTranslation } from "../api/translate.js";
import { DEFAULT_AUDIENCE, normalizeAudience } from "../data/audiences.js";
import { validateInput } from "../utils/validation.js";

/**
 * @typedef {{ type: "warning" | "error", message: string } | null} Feedback
 */

/**
 * @typedef {{
 *   input: string,
 *   audience: import("../engine/types.js").AudienceId,
 *   feedback: Feedback,
 *   result: import("../engine/types.js").TranslationResult | null,
 *   engineSource: "ai" | "fallback" | null,
 *   isLoading: boolean
 * }} AppState
 */

/**
 * @returns {AppState}
 */
export function createInitialState() {
  return {
    input: "",
    audience: DEFAULT_AUDIENCE,
    feedback: null,
    result: null,
    engineSource: null,
    isLoading: false
  };
}

/**
 * @param {AppState} state
 * @param {string} input
 * @returns {AppState}
 */
export function updateInput(state, input) {
  return {
    ...state,
    input
  };
}

/**
 * @param {AppState} state
 * @param {import("../engine/types.js").AudienceId} audience
 * @returns {AppState}
 */
export function updateAudience(state, audience) {
  return {
    ...state,
    audience: normalizeAudience(audience)
  };
}

/**
 * @param {AppState} state
 * @param {string} example
 * @returns {AppState}
 */
export function applyExample(state, example) {
  return {
    ...state,
    input: example,
    feedback: null
  };
}

/**
 * @param {AppState} state
 * @returns {AppState}
 */
export function startTranslation(state) {
  return {
    ...state,
    isLoading: true,
    feedback: null
  };
}

/**
 * @param {AppState} state
 * @param {{
 *   requestTranslation?: typeof requestAiTranslation,
 *   fallbackEngine?: (input: string, audience: import("../engine/types.js").AudienceId) => import("../engine/types.js").TranslationResult
 * }} [options]
 * @returns {Promise<AppState>}
 */
export async function submitTranslationAsync(
  state,
  {
    requestTranslation = requestAiTranslation,
    fallbackEngine = translateWithFallback
  } = {}
) {
  const validation = validateInput(state.input);

  if (!validation.ok) {
    return {
      ...state,
      result: null,
      engineSource: null,
      isLoading: false,
      feedback: {
        type: "error",
        message: validation.reason
      }
    };
  }

  const baseState = {
    ...state,
    input: validation.normalized,
    isLoading: false
  };

  const aiResponse = await requestTranslation(validation.normalized, state.audience);

  if (aiResponse.ok) {
    return {
      ...baseState,
      result: aiResponse.result,
      engineSource: "ai",
      feedback:
        validation.level === "warning"
          ? {
              type: "warning",
              message: validation.reason
            }
          : null
    };
  }

  try {
    return {
      ...baseState,
      result: fallbackEngine(validation.normalized, state.audience),
      engineSource: "fallback",
      feedback: {
        type: "warning",
        message: buildFallbackFeedbackMessage(validation, aiResponse)
      }
    };
  } catch {
    return {
      ...baseState,
      result: null,
      engineSource: null,
      feedback: {
        type: "error",
        message: "번역에 실패했습니다. 잠시 후 다시 시도해 주세요."
      }
    };
  };
}

/**
 * @param {{ level: "warning" | null, reason: string }} validation
 * @param {{ ok: false, message: string, reason?: string }} aiResponse
 * @returns {string}
 */
function buildFallbackFeedbackMessage(validation, aiResponse) {
  const prefix = validation.level === "warning" ? `${validation.reason} ` : "";
  return `${prefix}${getFallbackReasonMessage(aiResponse)}`;
}

/**
 * @param {{ ok: false, message: string, reason?: string }} aiResponse
 * @returns {string}
 */
function getFallbackReasonMessage(aiResponse) {
  switch (aiResponse.reason) {
    case "missing_api_route":
      return "AI 서버 경로(/api/translate)를 찾지 못해 기본 설명 모드로 전환했습니다. 로컬에서는 vercel dev나 Vercel 배포에서 AI 설명이 동작합니다.";
    case "missing_api_key":
      return "OpenAI API 키가 설정되지 않아 기본 설명 모드로 전환했습니다.";
    case "auth_failed":
      return "OpenAI 인증에 실패해 기본 설명 모드로 전환했습니다.";
    case "rate_limited":
      return "OpenAI 요청 한도에 도달해 기본 설명 모드로 전환했습니다.";
    case "invalid_result":
      return "AI 응답 형식을 확인하지 못해 기본 설명 모드로 전환했습니다.";
    case "network_error":
      return "AI 서버에 연결하지 못해 기본 설명 모드로 전환했습니다.";
    default:
      return "AI 응답이 불안정해 기본 설명 모드로 전환했습니다.";
  }
}
