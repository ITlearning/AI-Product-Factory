/**
 * /api/admin/feedback — 받은 건의 읽기·읽음 표시·지우기. Authorization: Bearer <ADMIN_TOKEN>.
 *   GET    ?offset=0&limit=50   최신순 목록 {total, items}
 *   PATCH  {id, read}           읽음 표시
 *   DELETE {id}                 지우기
 *
 * 환경변수가 없으면 503 으로 닫힌다. 토큰이 틀리면 401, IP(해시) 당 15분에 10번 틀리면 맞는 토큰도 429.
 */
import { ReadSchema, DeleteSchema, PAGE_MAX, listFeedback, markRead, deleteFeedback } from "../_lib/feedback.js";
import { checkAdmin } from "../_lib/admin.js";
import { sendJSON, clientIp, readJSON, redisFromEnv } from "../_lib/http.js";

export const config = { runtime: "nodejs" };

const int = (v, fallback, max) => {
  const n = Number.parseInt(v ?? "", 10);
  return Number.isFinite(n) && n >= 0 ? Math.min(n, max) : fallback;
};

export function makeHandler({ getRedis, env = process.env }) {
  return async function handler(req, res) {
    if (!["GET", "PATCH", "DELETE"].includes(req.method)) {
      res.setHeader("allow", "GET, PATCH, DELETE");
      return sendJSON(res, 405, { message: "GET·PATCH·DELETE 만 받아요." });
    }
    const redis = env.ADMIN_TOKEN ? await getRedis() : null;
    try {
      const denied = await checkAdmin(redis, { header: req.headers.authorization, ip: clientIp(req), env });
      if (denied) return sendJSON(res, denied.status, { message: denied.message });
    } catch {
      return sendJSON(res, 500, { message: "잠시 뒤에 다시 해 주세요." });
    }

    if (req.method === "GET") {
      const q = new URL(req.url ?? "/", "http://x").searchParams;
      try {
        const out = await listFeedback(redis, { offset: int(q.get("offset"), 0, 1e6), limit: int(q.get("limit"), 50, PAGE_MAX) || 1 });
        return sendJSON(res, 200, { ok: true, ...out });
      } catch {
        return sendJSON(res, 500, { message: "잠시 뒤에 다시 해 주세요." });
      }
    }

    let body;
    try {
      body = await readJSON(req, 2048);
    } catch (err) {
      const big = /too large/.test(String(err?.message));
      return sendJSON(res, big ? 413 : 400, { message: big ? "본문이 너무 커요." : "JSON 이 아니에요." });
    }
    const parsed = (req.method === "PATCH" ? ReadSchema : DeleteSchema).safeParse(body);
    if (!parsed.success) return sendJSON(res, 400, { message: "형식이 맞지 않아요.", issues: parsed.error.issues.map((i) => i.path.join(".")) });
    try {
      const { status, body: out } = await (req.method === "PATCH" ? markRead : deleteFeedback)(redis, parsed.data);
      return sendJSON(res, status, out);
    } catch {
      return sendJSON(res, 500, { message: "잠시 뒤에 다시 해 주세요." });
    }
  };
}

let redisP = null;
export default makeHandler({ getRedis: () => (redisP ??= redisFromEnv()) });
