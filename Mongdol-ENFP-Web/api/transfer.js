/**
 * POST /api/transfer  {action, …} — 기록 옮기기(_lib/transfer.js)
 *   보내는 쪽: start {id, size, count, salt} → chunk {id, token, index, data} × count → finish {id, token}
 *   받는 쪽:   info {id} → get {id, claim, index} × count(마지막 조각을 주면 전부 지운다) → done {id, claim}
 *
 * 받는 건 암호문 조각과 그 개수·크기·salt 뿐이다. 레이트리밋 IP 당 분당 300(조각 단위라 넉넉히).
 */
import { TransferSchema, BODY_LIMIT, run } from "./_lib/transfer.js";
import { sendJSON, clientIp, readJSON, redisFromEnv } from "./_lib/push.js";

export const config = { runtime: "nodejs", maxDuration: 30 };

export function makeHandler({ getRedis, getLimiter }) {
  return async function handler(req, res) {
    if (req.method !== "POST") {
      res.setHeader("allow", "POST");
      return sendJSON(res, 405, { message: "POST 만 받아요." });
    }
    const redis = await getRedis();
    const ip = clientIp(req);
    try {
      const limiter = await getLimiter(redis);
      const { success } = await limiter.limit(`xfer:${ip}`);
      if (!success) return sendJSON(res, 429, { message: "잠시 뒤에 다시 해 주세요." });
    } catch {
      // 레이트리밋 장애면 그냥 통과 — 틀린 코드 횟수 제한은 따로 센다.
    }
    let body;
    try {
      body = await readJSON(req, BODY_LIMIT);
    } catch (err) {
      const big = /too large/.test(String(err?.message));
      return sendJSON(res, big ? 413 : 400, { message: big ? "본문이 너무 커요." : "JSON 이 아니에요." });
    }
    const parsed = TransferSchema.safeParse(body);
    if (!parsed.success) return sendJSON(res, 400, { message: "형식이 맞지 않아요.", issues: parsed.error.issues.map((i) => i.path.join(".")) });
    try {
      const { status, body: out } = await run(redis, parsed.data, { ip });
      return sendJSON(res, status, out);
    } catch {
      return sendJSON(res, 500, { message: "잠시 뒤에 다시 해 주세요." });
    }
  };
}

let redisP = null;
let limiterP = null;
export default makeHandler({
  getRedis: () => (redisP ??= redisFromEnv()),
  getLimiter: (redis) => (limiterP ??= import("@upstash/ratelimit").then(({ Ratelimit }) => new Ratelimit({
    redis,
    limiter: Ratelimit.slidingWindow(300, "60 s"),
    analytics: false,
    prefix: "mongdol:xfer:rl",
  }))),
});
