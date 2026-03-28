import { BLOCKER_OPTIONS, SITUATION_OPTIONS } from "../domain/options.js";
import { requestReplySet } from "../api/generate-reply.js";
import { validateInput } from "../utils/validation.js";

/**
 * @typedef {{ type: "warning" | "error", message: string } | null} Feedback
 */

/**
 * @typedef {{
 *   input: string,
 *   situationType: string,
 *   blockerType: string,
 *   result: {
 *     replyOptions: { text: string, toneLabel: string, whyItWorks: string }[],
 *     recommendedTone: "soft" | "polite-firm" | "short",
 *     coachNote: string,
 *     avoidPhrase: string
 *   } | null,
 *   feedback: Feedback,
 *   isLoading: boolean
 * }} AppState
 */

/**
 * @returns {AppState}
 */
export function createInitialState() {
  return {
    input: "",
    situationType: SITUATION_OPTIONS[0].value,
    blockerType: BLOCKER_OPTIONS[1].value,
    result: null,
    feedback: null,
    isLoading: false
  };
}

/**
 * @template {keyof AppState} K
 * @param {AppState} state
 * @param {K} field
 * @param {AppState[K]} value
 * @returns {AppState}
 */
export function updateField(state, field, value) {
  return {
    ...state,
    [field]: value
  };
}

/**
 * @param {AppState} state
 * @returns {AppState}
 */
export function startRequest(state) {
  return {
    ...state,
    isLoading: true,
    feedback: null
  };
}

/**
 * @param {AppState} state
 * @param {{ requestReplySet?: typeof requestReplySet }} [options]
 * @returns {Promise<AppState>}
 */
export async function submitReplyRequest(
  state,
  {
    requestReplySet: requestReplySetImpl = requestReplySet
  } = {}
) {
  const validation = validateInput(state.input);

  if (!validation.ok) {
    return {
      ...state,
      result: null,
      isLoading: false,
      feedback: {
        type: "error",
        message: validation.reason
      }
    };
  }

  const nextState = {
    ...state,
    input: validation.normalized,
    isLoading: false
  };

  const response = await requestReplySetImpl({
    input: validation.normalized,
    situationType: state.situationType,
    blockerType: state.blockerType
  });

  if (response.ok) {
    return {
      ...nextState,
      result: response.result,
      feedback:
        validation.level === "warning"
          ? {
              type: "warning",
              message: validation.reason
            }
          : null
    };
  }

  return {
    ...nextState,
    result: null,
    feedback: {
      type: response.code === "UNSUPPORTED_SCOPE" ? "warning" : "error",
      message: response.message
    }
  };
}
