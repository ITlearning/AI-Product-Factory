/**
 * POST /api/check
 *
 * 폼 데이터 받아 자격 평가 → KV 저장 (UUID + 6개월 TTL) → cookie set → uuid 반환.
 *
 * 학습 적용:
 * - vercel-legacy-handler-hangs: App Router named exports로 hang 발생하던 패턴 대신
 *   Pages-style `export default async function handler(req, res)` 사용. Vercel Node Serverless에서
 *   가장 안정적. (req, res) signature는 Connect/Express 스타일로 res.status().json() 패턴 그대로.
 * - vercel-middleware-non-nextjs: 이건 middleware 쪽 학습 (여기는 무관).
 *
 * 보안:
 * - Cookie httpOnly + Secure + SameSite=Lax + Path=/ + 6개월 (180일)
 * - Rate limit: IP 기준 1분에 10회. Upstash sliding window.
 */

import { Redis } from "@upstash/redis";
import { Ratelimit } from "@upstash/ratelimit";
import { nanoid } from "nanoid";
import { z } from "zod";
import { evaluateSeoulYouthRent2026 } from "../src/eligibility/evaluator.js";

export const config = { runtime: "nodejs" };

const redis = Redis.fromEnv();
const ratelimit = new Ratelimit({
  redis,
  limiter: Ratelimit.slidingWindow(10, "60 s"),
  analytics: false,
  prefix: "rl:check",
});

const TTL_SECONDS = 60 * 60 * 24 * 180; // 6개월

// --- Zod schema (EligibilityInput과 1:1 매칭, evaluator의 type comment 따름) -------------

const dateString = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}$/, "생년월일은 YYYY-MM-DD 형식이어야 해요.");

const baseSchema = z.object({
  birthDate: dateString,
  isVeteran: z.boolean(),
  militaryMonths: z.number().int().min(0).max(120),
  residence: z.string().min(1).max(20),
  householdType: z.enum([
    "single",
    "single-parent",
    "fraud-victim",
    "young-newlywed",
    "youth-safe-housing",
  ]),
  hasNewlywedChildren: z.boolean(),
  hasSinglParentCert: z.boolean(),
  hasFraudVictimCert: z.boolean(),
  youthSafeHousingType: z.enum(["public", "private"]).nullable(),
  householdSize: z.number().int().min(1).max(20),
  monthlyIncomeWon: z.number().int().min(0).max(1_000_000_000),
  depositWon: z.number().int().min(0).max(10_000_000_000),
  monthlyRentWon: z.number().int().min(0).max(100_000_000),
  generalAssetWon: z.number().int().min(0).max(10_000_000_000),
  vehicleValueWon: z.number().int().min(0).max(1_000_000_000),
  ownsHome: z.boolean(),
  landlordRelation: z.enum(["spouse", "parent", "other", "none"]),
  allCotenantsApplying: z.boolean(),
  receivingNationalYouthRent: z.boolean(),
  previouslyReceivedSeoulRent: z.boolean(),
  basicLivingRecipient: z.boolean(),
  nationalityStatus: z.enum(["korean", "foreigner", "overseas-korean"]),
  spouseNationalityStatus: z.enum(["korean", "foreigner", "overseas-korean"]).optional(),
  spouseInFamilyRegistry: z.boolean().optional(),
  spouseSameAddress: z.boolean().optional(),
  spouseBirthDate: dateString.optional(),
  spouseIsVeteran: z.boolean().optional(),
  spouseMilitaryMonths: z.number().int().min(0).max(120).optional(),
  receivingDistrictRent: z.boolean(),
  receivingSeoulYouthAllowance: z.boolean(),
  receivingTransitionYouthSupport: z.boolean(),
  receivingSeoulHousingVoucher: z.boolean(),
});

// 가구형태별 conditional required (신혼은 배우자 정보가 있어야 자격 검사가 의미 있음).
const inputSchema = baseSchema.superRefine((val, ctx) => {
  if (val.householdType === "young-newlywed") {
    if (!val.spouseBirthDate) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["spouseBirthDate"],
        message: "신혼부부는 배우자 출생일이 필요해요.",
      });
    }
    if (val.spouseIsVeteran === undefined) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["spouseIsVeteran"],
        message: "신혼부부는 배우자 제대군인 여부가 필요해요.",
      });
    }
    if (val.spouseMilitaryMonths === undefined) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["spouseMilitaryMonths"],
        message: "신혼부부는 배우자 군복무 개월이 필요해요.",
      });
    }
  }
  if (val.householdType === "youth-safe-housing" && val.youthSafeHousingType === null) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      path: ["youthSafeHousingType"],
      message: "청년안심주택 거주자는 공공/민간 구분이 필요해요.",
    });
  }
});

// --- helpers ----------------------------------------------------------------

/** Vercel Node 서버리스에서는 보통 req.body가 자동 파싱되지만, 안전을 위해 raw fallback. */
async function readJsonBody(req) {
  if (req.body && typeof req.body === "object") return req.body;
  if (typeof req.body === "string" && req.body.length > 0) {
    return JSON.parse(req.body);
  }
  // raw stream fallback
  return await new Promise((resolve, reject) => {
    let raw = "";
    req.setEncoding("utf8");
    req.on("data", (chunk) => {
      raw += chunk;
      if (raw.length > 1_000_000) {
        reject(new Error("payload too large"));
        req.destroy();
      }
    });
    req.on("end", () => {
      try {
        resolve(raw.length === 0 ? {} : JSON.parse(raw));
      } catch (e) {
        reject(e);
      }
    });
    req.on("error", reject);
  });
}

function getClientIp(req) {
  const fwd = req.headers["x-forwarded-for"];
  if (typeof fwd === "string" && fwd.length > 0) {
    return fwd.split(",")[0].trim();
  }
  return req.socket?.remoteAddress || "unknown";
}

// --- handler ----------------------------------------------------------------

/**
 * @param {import("http").IncomingMessage & {body?: any}} req
 * @param {import("http").ServerResponse & {status?: Function, json?: Function}} res
 */
export default async function handler(req, res) {
  if (req.method !== "POST") {
    res.statusCode = 405;
    res.setHeader("content-type", "application/json; charset=utf-8");
    res.setHeader("allow", "POST");
    res.end(JSON.stringify({ message: "POST만 허용돼요." }));
    return;
  }

  // 1. Rate limit
  try {
    const ip = getClientIp(req);
    const { success } = await ratelimit.limit(ip);
    if (!success) {
      res.statusCode = 429;
      res.setHeader("content-type", "application/json; charset=utf-8");
      res.end(
        JSON.stringify({
          message: "너무 많은 요청이에요. 1분 후 다시 시도해주세요.",
        }),
      );
      return;
    }
  } catch (err) {
    // Redis 연결 실패 시 rate limit 우회 (서비스 가용성 우선). 운영에서는 알림.
    console.warn("[check] ratelimit error, allowing request:", err?.message || err);
  }

  // 2. Parse body
  let raw;
  try {
    raw = await readJsonBody(req);
  } catch {
    res.statusCode = 400;
    res.setHeader("content-type", "application/json; charset=utf-8");
    res.end(JSON.stringify({ message: "잘못된 요청이에요. JSON 형식이 아니거나 너무 커요." }));
    return;
  }

  // 3. Validate
  const parsed = inputSchema.safeParse(raw);
  if (!parsed.success) {
    const first = parsed.error.issues[0];
    res.statusCode = 400;
    res.setHeader("content-type", "application/json; charset=utf-8");
    res.end(
      JSON.stringify({
        message: "입력값이 올바르지 않아요.",
        field: first?.path?.join(".") || null,
        detail: first?.message || null,
      }),
    );
    return;
  }
  const input = parsed.data;

  // 4. Evaluate
  let result;
  try {
    result = evaluateSeoulYouthRent2026(input);
  } catch (err) {
    console.error("[check] evaluator error:", err);
    res.statusCode = 500;
    res.setHeader("content-type", "application/json; charset=utf-8");
    res.end(
      JSON.stringify({ message: "자격 평가 중 오류가 발생했어요. 잠시 후 다시 시도해주세요." }),
    );
    return;
  }

  // 5. UUID + KV 저장
  const uuid = nanoid(12);
  try {
    await redis.set(
      `r:${uuid}`,
      JSON.stringify({ input, result, createdAt: Date.now() }),
      { ex: TTL_SECONDS },
    );
  } catch (err) {
    console.error("[check] redis set error:", err);
    res.statusCode = 500;
    res.setHeader("content-type", "application/json; charset=utf-8");
    res.end(
      JSON.stringify({ message: "결과 저장 중 오류가 발생했어요. 잠시 후 다시 시도해주세요." }),
    );
    return;
  }

  // 6. Cookie set + uuid 반환
  const cookie = [
    `cuuid=${uuid}`,
    "HttpOnly",
    "Secure",
    "SameSite=Lax",
    "Path=/",
    `Max-Age=${TTL_SECONDS}`,
  ].join("; ");

  res.statusCode = 200;
  res.setHeader("content-type", "application/json; charset=utf-8");
  res.setHeader("set-cookie", cookie);
  res.end(JSON.stringify({ uuid }));
}
