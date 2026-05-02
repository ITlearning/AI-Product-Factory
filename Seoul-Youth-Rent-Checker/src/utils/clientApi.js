/**
 * 결과 발급 API 클라이언트.
 *
 * `POST /api/check`에 input schema (evaluator EligibilityInput과 1:1)를 보내고
 * `{ uuid }`를 받아온다. 실패하면 에러 메시지를 throw.
 */

/**
 * @param {object} input
 * @returns {Promise<{uuid: string}>}
 */
export async function submitCheck(input) {
  const res = await fetch("/api/check", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(input),
    credentials: "include",
  });

  if (!res.ok) {
    let message = `요청 실패 (${res.status})`;
    try {
      const err = await res.json();
      if (err && typeof err.message === "string") message = err.message;
    } catch {
      /* keep default */
    }
    throw new Error(message);
  }

  return res.json();
}
