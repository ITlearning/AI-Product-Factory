/**
 * 건의하기 — iOS 앱 설정 「건의하기」가 여는 /feedback 이 보낸 글을 모아 두고, /admin 에서 읽는다.
 *
 * 키(모두 mongdol:fb:):
 * - mongdol:fb:<id>            {id, kind, text, contact, v, b, d, at, read} JSON — TTL 없음(관리 페이지에서 지울 때까지)
 * - mongdol:fb:index           ZSET score=받은 시각(ms), member=id
 * - mongdol:fb:cid:<cid>       같은 글을 두 번 받지 않게 — 브라우저가 글마다 만든 표, TTL 1일
 * - mongdol:fb:rl:*            보내기 레이트리밋(@upstash/ratelimit, IP 해시 기준 시간당 5)
 *
 * IP 는 어디에도 그대로 두지 않는다 — 레이트리밋 키에만 sha256 앞 16자로.
 */
import { createHash, randomBytes } from "node:crypto";
import { z } from "zod";

export const KINDS = ["bug", "wish", "etc"];
export const TEXT_MAX = 2000;
export const CONTACT_MAX = 200;
export const MAX_ITEMS = 5000;
export const CID_TTL = 60 * 60 * 24;
export const SEND_LIMIT = 5;
export const PAGE_MAX = 100;
export const BODY_LIMIT = 16 * 1024;

export const INDEX = "mongdol:fb:index";
export const itemKey = (id) => `mongdol:fb:${id}`;
export const cidKey = (cid) => `mongdol:fb:cid:${cid}`;

export const ipHash = (ip) => createHash("sha256").update(String(ip)).digest("hex").slice(0, 16);

// 앱이 쿼리로 넘기는 값 — 비어도 된다. 기종은 `iPhone17,1` 처럼 쉼표가 들어간다.
const tag = (max, re) => z.string().max(max).regex(re).optional().default("");
// @upstash/redis 는 ZSET member 도 JSON 처럼 생기면 풀어 버린다 — 숫자로만 된 id 가 안 나오게 앞에 f 를 붙인다.
const itemId = z.string().regex(/^f[0-9a-z]{8,40}$/);

export const FeedbackSchema = z.object({
  kind: z.enum(KINDS),
  text: z.string().trim().min(1).max(TEXT_MAX),
  contact: z.string().trim().max(CONTACT_MAX).optional().default(""),
  v: tag(20, /^[0-9A-Za-z._-]*$/),
  b: tag(20, /^[0-9A-Za-z._-]*$/),
  d: tag(40, /^[0-9A-Za-z,._ -]*$/),
  cid: z.string().regex(/^[0-9a-f]{16,64}$/).optional(),
  website: z.string().max(500).optional().default(""),
});

export const ReadSchema = z.object({ id: itemId, read: z.boolean() });
export const DeleteSchema = z.object({ id: itemId });

const parseJSON = (v) => (typeof v === "string" ? JSON.parse(v) : v);
const reply = (status, body) => ({ status, body });
const newId = (nowMs) => `f${nowMs.toString(36)}${randomBytes(5).toString("hex")}`;

/** 받은 글 하나를 저장한다. 허니팟(website)이 차 있으면 저장하지 않고 성공처럼 답한다. */
export async function saveFeedback(redis, input, nowMs) {
  if (input.website) return reply(200, { ok: true });
  if ((await redis.zcard(INDEX)) >= MAX_ITEMS) return reply(503, { message: "지금은 받을 수 없어요. 조금 뒤에 다시 보내 주세요." });
  // 응답을 못 받은 브라우저가 같은 글을 다시 보내면 이미 받은 것으로 답한다.
  if (input.cid && !(await redis.set(cidKey(input.cid), "1", { ex: CID_TTL, nx: true }))) return reply(200, { ok: true });
  const id = newId(nowMs);
  const record = { id, kind: input.kind, text: input.text, contact: input.contact, v: input.v, b: input.b, d: input.d, at: nowMs, read: false };
  try {
    await redis.set(itemKey(id), JSON.stringify(record));
    await redis.zadd(INDEX, { score: nowMs, member: id });
  } catch (err) {
    if (input.cid) await redis.del(cidKey(input.cid)).catch(() => {});
    throw err;
  }
  return reply(200, { ok: true });
}

/** 최신순으로 offset 부터 limit 개. 색인에만 남은 id(값이 사라진 것)는 걷어 낸다. */
export async function listFeedback(redis, { offset = 0, limit = 50 } = {}) {
  const total = await redis.zcard(INDEX);
  const ids = ((await redis.zrange(INDEX, offset, offset + limit - 1, { rev: true })) ?? []).map(String);
  const raws = ids.length ? await redis.mget(...ids.map(itemKey)) : [];
  const items = [];
  const orphans = [];
  ids.forEach((id, i) => (raws[i] ? items.push(parseJSON(raws[i])) : orphans.push(id)));
  if (orphans.length) await redis.zrem(INDEX, ...orphans);
  return { total: total - orphans.length, items };
}

export async function markRead(redis, { id, read }) {
  const raw = await redis.get(itemKey(id));
  if (!raw) return reply(404, { message: "없는 글이에요." });
  await redis.set(itemKey(id), JSON.stringify({ ...parseJSON(raw), read }));
  return reply(200, { ok: true });
}

export async function deleteFeedback(redis, { id }) {
  await redis.del(itemKey(id));
  await redis.zrem(INDEX, id);
  return reply(200, { ok: true });
}
