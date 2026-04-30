/**
 * POST /api/notify-signup
 *
 * 옵트인된 이메일을 KV Sorted Set에 저장.
 * - Key: `notify:seoul-youth-rent-2026` (program-scoped)
 * - Score: signedUpAt (Unix ms) — 시간순 정렬, 중복 자동 제거
 * - Member: email
 *
 * v1.5에서 cron job이 ZRANGE로 가져와서 마감 임박 (D-3, D-1) 자동 발송.
 *
 * 보안: Upstash Ratelimit 5 req/min/IP (이메일 옵트인은 자주 안 누르니 빡빡하게)
 */

import { Redis } from "@upstash/redis";
import { Ratelimit } from "@upstash/ratelimit";
import { z } from "zod";

export const config = { runtime: "nodejs" };

const redis = new Redis({
  url: process.env.UPSTASH_REDIS_REST_URL ?? process.env.KV_REST_API_URL,
  token: process.env.UPSTASH_REDIS_REST_TOKEN ?? process.env.KV_REST_API_TOKEN,
});

const ratelimit = new Ratelimit({
  redis,
  limiter: Ratelimit.slidingWindow(5, "60 s"),
  analytics: false,
  prefix: "rl:notify",
});

const SignupSchema = z.object({
  email: z.string().email().max(254).trim().toLowerCase(),
  programId: z.string().default("seoul-youth-rent-2026"),
});

const NOTIFY_KEY = "notify:seoul-youth-rent-2026";

/**
 * @param {import("http").IncomingMessage} req
 * @returns {Promise<string>}
 */
function readBody(req) {
  return new Promise((resolve, reject) => {
    let data = "";
    req.on("data", (chunk) => {
      data += chunk;
      if (data.length > 1024) {
        reject(new Error("Body too large"));
      }
    });
    req.on("end", () => resolve(data));
    req.on("error", reject);
  });
}

export default async function handler(req, res) {
  if (req.method !== "POST") {
    res.statusCode = 405;
    res.setHeader("content-type", "application/json");
    res.end(JSON.stringify({ message: "POST only" }));
    return;
  }

  // Rate limit
  const ip =
    req.headers["x-forwarded-for"]?.split(",")[0]?.trim() ||
    req.socket?.remoteAddress ||
    "unknown";
  try {
    const { success } = await ratelimit.limit(`notify:${ip}`);
    if (!success) {
      res.statusCode = 429;
      res.setHeader("content-type", "application/json");
      res.end(
        JSON.stringify({
          message: "너무 많은 요청. 1분 후 다시 시도해주세요.",
        }),
      );
      return;
    }
  } catch {
    // Rate limit 장애 시 fail-open (옵트인 끊기지 않게)
  }

  // Parse body
  let parsed;
  try {
    const raw =
      typeof req.body === "string"
        ? req.body
        : req.body
          ? JSON.stringify(req.body)
          : await readBody(req);
    const json = typeof raw === "string" && raw.length ? JSON.parse(raw) : raw;
    parsed = SignupSchema.parse(json);
  } catch (err) {
    res.statusCode = 400;
    res.setHeader("content-type", "application/json");
    res.end(
      JSON.stringify({
        message: "이메일 형식이 잘못됐어요.",
        detail: err?.message,
      }),
    );
    return;
  }

  // KV Sorted Set 저장 (중복 옵트인은 자동으로 score만 갱신)
  try {
    await redis.zadd(NOTIFY_KEY, {
      score: Date.now(),
      member: parsed.email,
    });
  } catch (err) {
    res.statusCode = 500;
    res.setHeader("content-type", "application/json");
    res.end(
      JSON.stringify({
        message: "잠시 후 다시 시도해주세요.",
        detail: err?.message,
      }),
    );
    return;
  }

  res.statusCode = 200;
  res.setHeader("content-type", "application/json");
  res.end(JSON.stringify({ success: true, email: parsed.email }));
}
