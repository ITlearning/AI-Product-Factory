/**
 * @typedef {"missing_api_route" | "missing_api_key" | "auth_failed" | "rate_limited" | "invalid_result" | "upstream_failure" | "network_error"} AiTranslationFailureReason
 */

/**
 * @param {string} input
 * @param {import("../engine/types.js").AudienceId} audience
 * @returns {Promise<
 *   | { ok: true, result: import("../engine/types.js").TranslationResult }
 *   | { ok: false, message: string, reason: AiTranslationFailureReason, status?: number }
 * >}
 */
export async function requestAiTranslation(input, audience) {
  try {
    const response = await fetch("/api/translate", {
      method: "POST",
      headers: {
        "Content-Type": "application/json"
      },
      body: JSON.stringify({ input, audience })
    });

    const payload = await response.json().catch(() => null);
    const failureStatus =
      typeof payload?.upstreamStatus === "number" ? payload.upstreamStatus : response.status;

    if (!response.ok || !payload || !payload.result) {
      const message = normalizeErrorMessage(payload?.error) ?? "AI 설명 요청에 실패했습니다.";

      return {
        ok: false,
        message,
        reason: classifyAiFailure(failureStatus, response, payload),
        status: failureStatus
      };
    }

    return {
      ok: true,
      result: payload.result
    };
  } catch {
    return {
      ok: false,
      message: "AI 설명 요청에 실패했습니다.",
      reason: "network_error"
    };
  }
}

/**
 * @param {number} status
 * @param {Response} response
 * @param {unknown} payload
 * @returns {AiTranslationFailureReason}
 */
function classifyAiFailure(status, response, payload) {
  const message = normalizeErrorMessage(payload?.error);
  const contentType = response.headers.get("content-type") ?? "";

  if (status === 404) {
    return "missing_api_route";
  }

  if (!contentType.includes("application/json") && !message) {
    return "missing_api_route";
  }

  if (message === "OPENAI_API_KEY is not configured.") {
    return "missing_api_key";
  }

  if (status === 401 || status === 403) {
    return "auth_failed";
  }

  if (status === 429) {
    return "rate_limited";
  }

  if (message === "AI returned an invalid result.") {
    return "invalid_result";
  }

  return "upstream_failure";
}

/**
 * @param {unknown} value
 * @returns {string | null}
 */
function normalizeErrorMessage(value) {
  if (typeof value !== "string") {
    return null;
  }

  const normalized = value.trim();
  return normalized.length > 0 ? normalized : null;
}
