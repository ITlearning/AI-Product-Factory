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
        message:
          validation.level === "warning"
            ? `${validation.reason} AI 응답이 불안정해 기본 설명 모드로 전환했습니다.`
            : "AI 응답이 불안정해 기본 설명 모드로 전환했습니다."
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
