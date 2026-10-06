/**
 * GET|POST /api/push-send — QStash 스케줄이 10분마다 부른다(Authorization: Bearer <CRON_SECRET>).
 * 기한 된 알림을 Declarative Web Push 형식으로 보낸다. 45분 넘게 늦은 건 버린다.
 */
import { sendDue, authorized, sendJSON, redisFromEnv, SITE } from "./_lib/push.js";

export const config = { runtime: "nodejs", maxDuration: 60 };

export function makeHandler({ getRedis, getWebpush, env = process.env, now = () => Date.now() }) {
  return async function handler(req, res) {
    if (req.method !== "GET" && req.method !== "POST") return sendJSON(res, 405, { message: "GET·POST 만 받아요." });
    if (!authorized(req.headers.authorization, env.CRON_SECRET)) return sendJSON(res, 401, { message: "unauthorized" });
    if (!env.VAPID_PUBLIC_KEY || !env.VAPID_PRIVATE_KEY) return sendJSON(res, 500, { message: "VAPID 키가 없어요." });
    try {
      const result = await sendDue({
        redis: await getRedis(),
        webpush: await getWebpush(),
        vapid: { subject: SITE, publicKey: env.VAPID_PUBLIC_KEY, privateKey: env.VAPID_PRIVATE_KEY },
        nowMs: now(),
      });
      return sendJSON(res, 200, { ok: true, ...result });
    } catch (err) {
      return sendJSON(res, 500, { message: "보내기 실패", detail: String(err?.message ?? err) });
    }
  };
}

let redisP = null;
export default makeHandler({
  getRedis: () => (redisP ??= redisFromEnv()),
  getWebpush: () => import("web-push").then((m) => m.default ?? m),
});
