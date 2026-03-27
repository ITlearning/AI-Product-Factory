import { normalizeInput } from "./text.js";
import {
  SUPPORTED_BLOCKER_VALUES,
  SUPPORTED_SITUATION_VALUES
} from "../domain/options.js";

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
      reason: "받은 메시지나 상황 설명을 먼저 입력해 주세요."
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

/**
 * @param {unknown} payload
 * @returns {{
 *   ok: true,
 *   value: {
 *     input: string,
 *     situationType: string,
 *     blockerType: string
 *   }
 * } | { ok: false, message: string }}
 */
export function validateRequestPayload(payload) {
  if (!payload || typeof payload !== "object") {
    return { ok: false, message: "잘못된 요청입니다." };
  }

  const inputCheck = validateInput(typeof payload.input === "string" ? payload.input : "");

  if (!inputCheck.ok) {
    return { ok: false, message: inputCheck.reason };
  }

  const situationType =
    typeof payload.situationType === "string" ? payload.situationType : "";
  const blockerType =
    typeof payload.blockerType === "string" ? payload.blockerType : "";

  if (!SUPPORTED_SITUATION_VALUES.has(situationType)) {
    return { ok: false, message: "지원하지 않는 상황 타입입니다." };
  }

  if (!SUPPORTED_BLOCKER_VALUES.has(blockerType)) {
    return { ok: false, message: "지원하지 않는 막힘 이유입니다." };
  }

  return {
    ok: true,
    value: {
      input: inputCheck.normalized,
      situationType,
      blockerType
    }
  };
}
