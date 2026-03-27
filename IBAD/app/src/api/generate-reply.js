/**
 * @param {{
 *   input: string,
 *   situationType: string,
 *   blockerType: string
 * }} payload
 * @returns {Promise<
 *   | { ok: true, result: import("../domain/schema.js").normalizeReplyResult extends (...args: any[]) => infer R ? NonNullable<R> : never }
 *   | { ok: false, code: string, message: string }
 * >}
 */
export async function requestReplySet(payload) {
  try {
    const response = await fetch("/api/generate-reply", {
      method: "POST",
      headers: {
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        input: payload.input,
        situationType: payload.situationType,
        blockerType: payload.blockerType
      })
    });

    const body = await response.json().catch(() => null);

    if (!response.ok || !body) {
      return {
        ok: false,
        code: body?.code ?? "REQUEST_FAILED",
        message: body?.error ?? "답장 생성 요청에 실패했습니다."
      };
    }

    return {
      ok: true,
      result: body.result
    };
  } catch {
    return {
      ok: false,
      code: "REQUEST_FAILED",
      message: "답장 생성 요청에 실패했습니다."
    };
  }
}
