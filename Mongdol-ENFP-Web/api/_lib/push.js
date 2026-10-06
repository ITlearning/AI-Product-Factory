/**
 * 몽돌 웹 푸시 — 서버엔 알림 「시각·종류」 일정만 둔다(사진·색·기록은 없다).
 *
 * 키(모두 mongdol:):
 * - mongdol:sub:<id>    구독 JSON {subscription, tz} — TTL 30일, 동기화마다 연장
 * - mongdol:items:<id>  그 구독이 걸어 둔 ZSET member 들(SET) — 교체·삭제 때 옛 일정을 찾는다
 * - mongdol:due         ZSET score=보낼 시각(ms), member=`<id>|<kind>|<key>`
 *
 * redis·webpush·ratelimit 는 바꿔 끼울 수 있다(tests/ 가 메모리 가짜를 넣는다).
 */
import { createHash, timingSafeEqual } from "node:crypto";
import { z } from "zod";

export const DUE = "mongdol:due";
export const subKey = (id) => `mongdol:sub:${id}`;
export const itemsKey = (id) => `mongdol:items:${id}`;
export const SUB_TTL = 60 * 60 * 24 * 30;
export const MAX_AHEAD = 8 * 24 * 3600e3;
export const LATE_LIMIT = 45 * 60e3;
export const SEND_BATCH = 500;
export const BODY_LIMIT = 16 * 1024;
export const SITE = "https://mongdol-enfp.vercel.app";

export const TITLE = "몽돌";
// iOS ArrivalNotice / MomentReminder 문구 그대로 — 도착 소식엔 조약돌 이름·색을 넣지 않는다(증정에서 처음 열려야 한다).
export const BODY = {
  arrival: "어제의 조약돌이 도착했어요.",
  morning: "오늘은 어떤 색을 만나게 될까요.",
  evening: "노을 지는 시간이에요. 순간을 남겨 보는 건 어때요?",
};

const PUSH_HOSTS = ["web.push.apple.com", "fcm.googleapis.com", "updates.push.services.mozilla.com"];

export function isPushEndpoint(raw) {
  let u;
  try { u = new URL(raw); } catch { return false; }
  if (u.protocol !== "https:" || u.username || u.password || u.port) return false;
  const host = u.hostname.toLowerCase();
  return PUSH_HOSTS.includes(host) || /^[a-z0-9-]+(\.[a-z0-9-]+)*\.notify\.windows\.com$/.test(host);
}

const endpoint = z.string().max(1024).refine(isPushEndpoint, "알 수 없는 푸시 주소");
const b64url = z.string().min(8).max(256).regex(/^[A-Za-z0-9_-]+=*$/);
const dayKey = z.string().regex(/^\d{4}-\d{2}-\d{2}$/);

export const ScheduleSchema = z.object({
  subscription: z.object({
    endpoint,
    expirationTime: z.number().nullable().optional(),
    keys: z.object({ p256dh: b64url, auth: b64url }),
  }),
  items: z.array(z.object({
    at: z.number().int().nonnegative(),
    kind: z.enum(["arrival", "morning", "evening"]),
    key: dayKey,
  })).max(30),
  tz: z.string().max(64).optional(),
});

export const DeleteSchema = z.object({ endpoint });

export const subId = (ep) => createHash("sha256").update(ep).digest("hex").slice(0, 32);

const parseJSON = (v) => (typeof v === "string" ? JSON.parse(v) : v);

async function dropItems(redis, id) {
  const members = (await redis.smembers(itemsKey(id))) ?? [];
  if (members.length) await redis.zrem(DUE, ...members);
  await redis.del(itemsKey(id));
}

/** 그 구독의 옛 일정을 지우고 새 일정으로 바꾼다. 지금~8일 밖의 항목은 조용히 뺀다(기기 시계가 틀린 경우). */
export async function saveSchedule(redis, input, nowMs) {
  const id = subId(input.subscription.endpoint);
  const items = input.items.filter((i) => i.at > nowMs && i.at <= nowMs + MAX_AHEAD);
  const members = [...new Set(items.map((i) => `${id}|${i.kind}|${i.key}`))];
  await dropItems(redis, id);
  await redis.set(subKey(id), JSON.stringify({ subscription: input.subscription, tz: input.tz ?? null }), { ex: SUB_TTL });
  if (members.length) {
    const byMember = new Map(items.map((i) => [`${id}|${i.kind}|${i.key}`, i.at]));
    const [first, ...rest] = members.map((member) => ({ score: byMember.get(member), member }));
    await redis.zadd(DUE, first, ...rest);
    await redis.sadd(itemsKey(id), ...members);
    await redis.expire(itemsKey(id), SUB_TTL);
  }
  return { id, stored: members.length };
}

export async function deleteSubscription(redis, ep) {
  const id = subId(ep);
  await dropItems(redis, id);
  await redis.del(subKey(id));
  return { id };
}

export function payloadFor(kind, key) {
  const tag = kind === "arrival" ? `arrival-${key}` : `reminder-${key}-${kind}`;
  return {
    web_push: 8030,
    notification: { title: TITLE, body: BODY[kind], navigate: `${SITE}/`, silent: false, tag, lang: "ko" },
  };
}

/** 기한 된 알림을 보낸다. 45분 넘게 늦은 건 보내지 않고 버린다. */
export async function sendDue({ redis, webpush, vapid, nowMs }) {
  const out = { due: 0, sent: 0, late: 0, gone: 0, missing: 0, failed: 0 };
  const flat = (await redis.zrange(DUE, 0, nowMs, { byScore: true, offset: 0, count: SEND_BATCH, withScores: true })) ?? [];
  const subs = new Map();
  const goneIds = new Set();
  for (let i = 0; i < flat.length; i += 2) {
    const member = String(flat[i]);
    const at = Number(flat[i + 1]);
    out.due++;
    // 먼저 지운 쪽만 보낸다 — 크론이 겹쳐 돌아도 두 번 가지 않게.
    if (!(await redis.zrem(DUE, member))) continue;
    const [id, kind, key] = member.split("|");
    await redis.srem(itemsKey(id), member);
    if (nowMs - at > LATE_LIMIT) { out.late++; continue; }
    if (goneIds.has(id) || !BODY[kind]) { out.missing++; continue; }
    if (!subs.has(id)) {
      const raw = await redis.get(subKey(id));
      subs.set(id, raw ? parseJSON(raw) : null);
    }
    const rec = subs.get(id);
    if (!rec?.subscription) { out.missing++; continue; }
    try {
      await webpush.sendNotification(rec.subscription, JSON.stringify(payloadFor(kind, key)), {
        TTL: 3600,
        urgency: "normal",
        vapidDetails: vapid,
      });
      out.sent++;
    } catch (err) {
      const status = err?.statusCode;
      if (status === 404 || status === 410) {
        out.gone++;
        goneIds.add(id);
        await deleteSubscription(redis, rec.subscription.endpoint);
      } else {
        out.failed++;
        // 잠깐 막힌 것(5xx·429 등)은 다음 크론에 다시 — 45분이 넘으면 그때 버려진다.
        await redis.zadd(DUE, { score: at, member });
        await redis.sadd(itemsKey(id), member);
      }
    }
  }
  return out;
}

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
  res.end(JSON.stringify(body));
}

export function clientIp(req) {
  return req.headers["x-forwarded-for"]?.split(",")[0]?.trim() || req.socket?.remoteAddress || "unknown";
}

export async function readJSON(req, limit = BODY_LIMIT) {
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
