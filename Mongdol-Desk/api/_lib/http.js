/**
 * 서버리스 공용 — 몽돌 ENFP 웹(api/_lib/push.js)의 같은 이름 함수를 옮겨 왔다. 따로 배포되니 경로를 나눠 쓰지 않는다.
 */
import { timingSafeEqual } from "node:crypto";

export function authorized(header, secret) {
  if (!secret) return false;
  const want = Buffer.from(`Bearer ${secret}`);
  const got = Buffer.from(String(header ?? ""));
  return got.length === want.length && timingSafeEqual(got, want);
}

export function sendJSON(res, status, body) {
  res.statusCode = status;
  res.setHeader("content-type", "application/json");
  res.setHeader("cache-control", "no-store");
  res.setHeader("x-robots-tag", "noindex");
  res.end(JSON.stringify(body));
}

export function clientIp(req) {
  return req.headers["x-forwarded-for"]?.split(",")[0]?.trim() || req.socket?.remoteAddress || "unknown";
}

export async function readJSON(req, limit) {
  if (req.body != null && typeof req.body === "object" && !Buffer.isBuffer(req.body)) {
    if (JSON.stringify(req.body).length > limit) throw new Error("too large");
    return req.body;
  }
  let raw = typeof req.body === "string" ? req.body : Buffer.isBuffer(req.body) ? req.body.toString("utf8") : null;
  if (raw == null) {
    raw = await new Promise((resolve, reject) => {
      let data = "";
      req.on("data", (chunk) => {
        data += chunk;
        if (data.length > limit) { reject(new Error("too large")); req.destroy?.(); }
      });
      req.on("end", () => resolve(data));
      req.on("error", reject);
    });
  }
  if (raw.length > limit) throw new Error("too large");
  return raw.length ? JSON.parse(raw) : {};
}

export async function redisFromEnv() {
  const { Redis } = await import("@upstash/redis");
  return new Redis({
    url: process.env.UPSTASH_REDIS_REST_URL ?? process.env.KV_REST_API_URL,
    token: process.env.UPSTASH_REDIS_REST_TOKEN ?? process.env.KV_REST_API_TOKEN,
  });
}
