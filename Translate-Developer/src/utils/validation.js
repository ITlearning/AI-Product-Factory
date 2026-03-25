import { normalizeInput } from "./text.js";

const RECOMMENDED_MAX_LENGTH = 1200;

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
      reason:
        "맥락을 함께 넣는 건 좋지만, 너무 길면 핵심이 흐려질 수 있어요. 관련 있는 앞뒤 대화만 남기면 더 정확하게 풀어드릴 수 있어요."
    };
  }

  return {
    ok: true,
    normalized,
    level: null,
    reason: ""
  };
}
