/**
 * POST /api/feedback  {kind, text, contact?, v?, b?, d?, cid?, website?} — 건의 하나를 받는다(_lib/feedback.js)
 *
 * website 는 화면에 안 보이는 허니팟이다. 레이트리밋 IP(해시) 당 시간당 5.
 */
import { FeedbackSchema, BODY_LIMIT, SEND_LIMIT, saveFeedback, ipHash } from "./_lib/feedback.js";
import { sendJSON, clientIp, readJSON, redisFromEnv } from "./_lib/http.js";

export const config = { runtime: "nodejs" };

export function makeHandler({ getRedis, getLimiter, now = () => Date.now() }) {
  return async function handler(req, res) {
    if (req.method !== "POST") {
      res.setHeader("allow", "POST");
      return sendJSON(res, 405, { message: "POST 만 받아요." });
    }
    const redis = await getRedis();
    try {
      const limiter = await getLimiter(redis);
      const { success } = await limiter.limit(`fb:${ipHash(clientIp(req))}`);
      if (!success) return sendJSON(res, 429, { message: "잠시 뒤에 다시 보내 주세요." });
    } catch {
      // 레이트리밋 장애면 그냥 통과(건의가 막히지 않게)
    }
    let body;
    try {
      body = await readJSON(req, BODY_LIMIT);
    } catch (err) {
      const big = /too large/.test(String(err?.message));
      return sendJSON(res, big ? 413 : 400, { message: big ? "본문이 너무 커요." : "JSON 이 아니에요." });
    }
    const parsed = FeedbackSchema.safeParse(body);
    if (!parsed.success) return sendJSON(res, 400, { message: "형식이 맞지 않아요.", issues: parsed.error.issues.map((i) => i.path.join(".")) });
    try {
      const { status, body: out } = await saveFeedback(redis, parsed.data, now());
      return sendJSON(res, status, out);
    } catch {
      return sendJSON(res, 500, { message: "잠시 뒤에 다시 보내 주세요." });
    }
  };
}

let redisP = null;
let limiterP = null;
export default makeHandler({
  getRedis: () => (redisP ??= redisFromEnv()),
  getLimiter: (redis) => (limiterP ??= import("@upstash/ratelimit").then(({ Ratelimit }) => new Ratelimit({
    redis,
    limiter: Ratelimit.slidingWindow(SEND_LIMIT, "1 h"),
    analytics: false,
    prefix: "mongdol:fb:rl",
  }))),
});
