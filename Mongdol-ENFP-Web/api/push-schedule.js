/**
 * POST   /api/push-schedule  {subscription, items:[{at, kind, key}], tz}  — 그 구독의 일정을 통째로 바꾼다
 * DELETE /api/push-schedule  {endpoint}                                  — 구독과 일정을 다 지운다
 *
 * 받는 건 알림 시각·종류·dayKey 와 푸시 구독뿐이다. 레이트리밋 IP 당 분당 30.
 */
import { ScheduleSchema, DeleteSchema, saveSchedule, deleteSubscription, sendJSON, clientIp, readJSON, redisFromEnv } from "./_lib/push.js";

export const config = { runtime: "nodejs" };

export function makeHandler({ getRedis, getLimiter, now = () => Date.now() }) {
  return async function handler(req, res) {
    if (req.method !== "POST" && req.method !== "DELETE") {
      res.setHeader("allow", "POST, DELETE");
      return sendJSON(res, 405, { message: "POST·DELETE 만 받아요." });
    }
    const redis = await getRedis();
    try {
      const limiter = await getLimiter(redis);
      const { success } = await limiter.limit(`push:${clientIp(req)}`);
      if (!success) return sendJSON(res, 429, { message: "잠시 뒤에 다시 해 주세요." });
    } catch {
      // 레이트리밋 장애면 그냥 통과(알림 맞추기가 끊기지 않게)
    }
    let body;
    try {
      body = await readJSON(req);
    } catch (err) {
      const big = /too large/.test(String(err?.message));
      return sendJSON(res, big ? 413 : 400, { message: big ? "본문이 너무 커요." : "JSON 이 아니에요." });
    }
    const schema = req.method === "POST" ? ScheduleSchema : DeleteSchema;
    const parsed = schema.safeParse(body);
    if (!parsed.success) return sendJSON(res, 400, { message: "형식이 맞지 않아요.", issues: parsed.error.issues.map((i) => i.path.join(".")) });
    try {
      if (req.method === "POST") {
        const { stored } = await saveSchedule(redis, parsed.data, now());
        return sendJSON(res, 200, { ok: true, stored });
      }
      await deleteSubscription(redis, parsed.data.endpoint);
      return sendJSON(res, 200, { ok: true });
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
    limiter: Ratelimit.slidingWindow(30, "60 s"),
    analytics: false,
    prefix: "mongdol:rl",
  }))),
});
