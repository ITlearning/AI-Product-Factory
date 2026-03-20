import { normalizeInput } from "./text.js";

const RECOMMENDED_MAX_LENGTH = 280;

/**
 * @param {string} input
 * @returns {{ ok: boolean, normalized: string, level: "warning" | null, reason: string }}
 */
export function validateInput(input) {
  const normalized = normalizeInput(input);

  if (!normalized) {
    return {
      ok: false,
      normalized,
      level: null,
      reason: "개발자 메시지를 먼저 입력해 주세요."
    };
  }

  if (normalized.length > RECOMMENDED_MAX_LENGTH) {
    return {
      ok: true,
      normalized,
      level: "warning",
      reason: "짧은 메시지에 가장 잘 맞습니다. 가능하면 1~5문장 안으로 줄여 주세요."
    };
  }

  return {
    ok: true,
    normalized,
    level: null,
    reason: ""
  };
}
