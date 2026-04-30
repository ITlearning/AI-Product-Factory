/**
 * GET /api/result/[uuid]
 *
 * Cookie의 cuuid와 URL의 uuid가 일치할 때만 KV에서 결과 반환.
 * 본인-only 접근 (다른 기기/다른 사람 차단). 공유는 도구 OG로만 (결과 OG X — DESIGN.md).
 *
 * 학습 적용:
 * - vercel-legacy-handler-hangs: Pages-style (req, res) signature 사용.
 *   App Router named export로 hang나는 패턴 회피.
 *
 * 응답 코드:
 * - 200: { input, result, createdAt }
 * - 403: 쿠키 미일치 (forbidden)
 * - 404: KV 없음 (expired)
 * - 405: GET 외 메소드
 * - 500: Redis 장애
 */

import { Redis } from "@upstash/redis";

export const config = { runtime: "nodejs" };

const redis = Redis.fromEnv();

const UUID_PATTERN = /^[A-Za-z0-9_-]{8,32}$/;

function parseCookies(header) {
  /** @type {Record<string, string>} */
  const out = {};
  if (!header) return out;
  for (const part of header.split(";")) {
    const trimmed = part.trim();
    if (!trimmed) continue;
    const eq = trimmed.indexOf("=");
    if (eq === -1) continue;
    const k = trimmed.slice(0, eq).trim();
    const v = trimmed.slice(eq + 1).trim();
    if (k) out[k] = v;
  }
  return out;
}

function extractUuidFromUrl(req) {
  // Vercel dynamic route는 보통 req.query.uuid 제공. 없을 때 URL 직접 파싱.
  if (req.query && typeof req.query.uuid === "string") return req.query.uuid;
  try {
    const url = new URL(req.url, "http://localhost");
    const segments = url.pathname.split("/").filter(Boolean);
    return segments[segments.length - 1] || "";
  } catch {
    return "";
  }
}

/**
 * @param {import("http").IncomingMessage & {query?: any}} req
 * @param {import("http").ServerResponse} res
 */
export default async function handler(req, res) {
  if (req.method !== "GET") {
    res.statusCode = 405;
    res.setHeader("content-type", "application/json; charset=utf-8");
    res.setHeader("allow", "GET");
    res.end(JSON.stringify({ error: "method", message: "GET만 허용돼요." }));
    return;
  }

  const uuid = extractUuidFromUrl(req);
  if (!UUID_PATTERN.test(uuid)) {
    res.statusCode = 400;
    res.setHeader("content-type", "application/json; charset=utf-8");
    res.end(
      JSON.stringify({
        error: "bad_request",
        message: "잘못된 결과 ID예요.",
      }),
    );
    return;
  }

  const cookies = parseCookies(req.headers.cookie || "");
  const cookieUuid = cookies.cuuid;

  if (!cookieUuid || cookieUuid !== uuid) {
    res.statusCode = 403;
    res.setHeader("content-type", "application/json; charset=utf-8");
    res.end(
      JSON.stringify({
        error: "forbidden",
        message:
          "본인만 볼 수 있는 결과예요. 같은 기기에서 진단을 마친 분만 열 수 있어요.",
      }),
    );
    return;
  }

  let raw;
  try {
    raw = await redis.get(`r:${uuid}`);
  } catch (err) {
    console.error("[result] redis get error:", err);
    res.statusCode = 500;
    res.setHeader("content-type", "application/json; charset=utf-8");
    res.end(
      JSON.stringify({
        error: "server",
        message: "결과를 불러오는 중 오류가 발생했어요. 잠시 후 다시 시도해주세요.",
      }),
    );
    return;
  }

  if (!raw) {
    res.statusCode = 404;
    res.setHeader("content-type", "application/json; charset=utf-8");
    res.end(
      JSON.stringify({
        error: "expired",
        message:
          "결과가 만료됐거나 존재하지 않아요. 다시 진단해주세요. (보관 기간: 6개월)",
      }),
    );
    return;
  }

  // Upstash redis는 자동으로 JSON 파싱하기도 함. 둘 다 대응.
  let data;
  try {
    data = typeof raw === "string" ? JSON.parse(raw) : raw;
  } catch (err) {
    console.error("[result] parse error:", err);
    res.statusCode = 500;
    res.setHeader("content-type", "application/json; charset=utf-8");
    res.end(
      JSON.stringify({
        error: "server",
        message: "저장된 결과를 읽는 중 오류가 발생했어요.",
      }),
    );
    return;
  }

  res.statusCode = 200;
  res.setHeader("content-type", "application/json; charset=utf-8");
  // 결과 페이지는 항상 신선해야 함 (공유 OG도 없으므로 캐시 X)
  res.setHeader("cache-control", "no-store, max-age=0");
  res.end(JSON.stringify(data));
}
