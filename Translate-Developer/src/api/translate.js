/**
 * @param {string} input
 * @param {import("../engine/types.js").AudienceId} audience
 * @returns {Promise<{ ok: true, result: import("../engine/types.js").TranslationResult } | { ok: false, message: string }>}
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

    if (!response.ok || !payload || !payload.result) {
      return {
        ok: false,
        message: payload?.error ?? "AI 설명 요청에 실패했습니다."
      };
    }

    return {
      ok: true,
      result: payload.result
    };
  } catch {
    return {
      ok: false,
      message: "AI 설명 요청에 실패했습니다."
    };
  }
}
