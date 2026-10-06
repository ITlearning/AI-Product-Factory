/**
 * 기록 옮기기 — 폰에서 잠근 암호문 조각만 10분 동안 둔다. 서버는 코드도 키도 모른다.
 *
 * 키(모두 mongdol:xfer:):
 * - mongdol:xfer:<id>         {size, count, salt, token, ready} — TTL 10분(올리는 동안은 조각마다 연장, 다 올리면 그때부터 10분)
 * - mongdol:xfer:<id>:<i>     i 번째 조각(base64)
 * - mongdol:xfer:<id>:claim   처음 받아 가는 쪽의 표 — 두 번째 받기는 막힌다
 * - mongdol:xfer:fail:<ip>    받기 실패 횟수(10분 창)
 * - mongdol:xfer:up:<ip>      보내기 시작 횟수(1시간 창)
 */
import { randomBytes, timingSafeEqual } from "node:crypto";
import { z } from "zod";

export const CHUNK = 512 * 1024;
export const SEAL = 28;
export const MAX_SIZE = 200 * 1024 * 1024;
export const MAX_COUNT = Math.ceil(MAX_SIZE / CHUNK);
export const TTL = 600;
export const FAIL_LIMIT = 10;
export const FAIL_WINDOW = 600;
export const UP_LIMIT = 10;
export const UP_WINDOW = 3600;
const CHUNK_B64 = Math.ceil((CHUNK + SEAL) / 3) * 4;
export const BODY_LIMIT = CHUNK_B64 + 2048;

export const metaKey = (id) => `mongdol:xfer:${id}`;
export const chunkKey = (id, i) => `mongdol:xfer:${id}:${i}`;
export const claimKey = (id) => `mongdol:xfer:${id}:claim`;
export const failKey = (ip) => `mongdol:xfer:fail:${ip}`;
export const upKey = (ip) => `mongdol:xfer:up:${ip}`;

const id = z.string().regex(/^[0-9a-f]{64}$/);
const ticket = z.string().regex(/^[0-9a-f]{32}$/);
const index = z.number().int().min(0).max(MAX_COUNT - 1);
const b64 = (max) => z.string().min(4).max(max).regex(/^[A-Za-z0-9+/]+={0,2}$/);

export const TransferSchema = z.discriminatedUnion("action", [
  z.object({ action: z.literal("start"), id, size: z.number().int().min(1), count: z.number().int().min(1), salt: b64(32) }),
  z.object({ action: z.literal("chunk"), id, token: ticket, index, data: b64(CHUNK_B64) }),
  z.object({ action: z.literal("finish"), id, token: ticket }),
  z.object({ action: z.literal("info"), id }),
  z.object({ action: z.literal("get"), id, claim: ticket, index }),
  z.object({ action: z.literal("done"), id, claim: ticket }),
]);

const parseJSON = (v) => (typeof v === "string" ? JSON.parse(v) : v);
const newTicket = () => randomBytes(16).toString("hex");
const same = (a, b) => typeof a === "string" && typeof b === "string" && a.length === b.length && timingSafeEqual(Buffer.from(a), Buffer.from(b));
const chunkKeys = (id, count) => Array.from({ length: count }, (_, i) => chunkKey(id, i));
// @upstash/redis 는 값이 JSON 처럼 생기면 풀어 버린다 — 짧은 base64 가 숫자로 바뀌지 않게 앞에 표시를 붙인다.
const wrap = (data) => `c:${data}`;
const unwrap = (v) => (typeof v === "string" && v.startsWith("c:") ? v.slice(2) : null);

const reply = (status, body) => ({ status, body });
const nope = (status, message) => reply(status, { message });

export const expectedChunkBytes = (size, count, i) => (i < count - 1 ? CHUNK : size - CHUNK * (count - 1)) + SEAL;

async function loadMeta(redis, id) {
  const raw = await redis.get(metaKey(id));
  return raw ? parseJSON(raw) : null;
}

async function wipe(redis, id, count) {
  await redis.del(metaKey(id), claimKey(id), ...chunkKeys(id, count));
}

async function bump(redis, key, window) {
  const n = await redis.incr(key);
  if (n === 1) await redis.expire(key, window);
  return n;
}

export async function failedTooOften(redis, ip) {
  return Number((await redis.get(failKey(ip))) ?? 0) >= FAIL_LIMIT;
}

export async function run(redis, input, { ip }) {
  const { action } = input;

  if (action === "start") {
    if (input.size > MAX_SIZE) return nope(413, "너무 커요.");
    if (input.count !== Math.ceil(input.size / CHUNK)) return nope(400, "조각 수가 맞지 않아요.");
    if ((await bump(redis, upKey(ip), UP_WINDOW)) > UP_LIMIT) return nope(429, "잠시 뒤에 다시 해 주세요.");
    const token = newTicket();
    const record = { size: input.size, count: input.count, salt: input.salt, token, ready: false };
    const ok = await redis.set(metaKey(input.id), JSON.stringify(record), { ex: TTL, nx: true });
    if (!ok) return nope(409, "이미 쓰고 있는 코드예요.");
    return reply(200, { ok: true, token });
  }

  if (action === "chunk" || action === "finish") {
    const meta = await loadMeta(redis, input.id);
    if (!meta) return nope(404, "시간이 지났어요.");
    if (!same(meta.token, input.token)) return nope(403, "표가 맞지 않아요.");
    if (meta.ready) return nope(409, "이미 다 올렸어요.");
    if (action === "chunk") {
      if (input.index >= meta.count) return nope(400, "조각 번호가 맞지 않아요.");
      if (Buffer.from(input.data, "base64").length !== expectedChunkBytes(meta.size, meta.count, input.index)) {
        return nope(400, "조각 크기가 맞지 않아요.");
      }
      await redis.set(chunkKey(input.id, input.index), wrap(input.data), { ex: TTL });
      await redis.expire(metaKey(input.id), TTL);
      return reply(200, { ok: true });
    }
    const keys = chunkKeys(input.id, meta.count);
    const have = await redis.exists(...keys);
    if (have !== meta.count) return nope(409, "조각이 덜 왔어요.");
    await redis.set(metaKey(input.id), JSON.stringify({ ...meta, ready: true }), { ex: TTL });
    await Promise.all(keys.map((k) => redis.expire(k, TTL)));
    return reply(200, { ok: true, ttl: TTL });
  }

  if (action === "done") {
    // 늘 같은 답 — 마지막 조각에서 이미 지운 뒤에 와도 실패로 세지 않는다.
    const meta = await loadMeta(redis, input.id);
    if (meta && same(await redis.get(claimKey(input.id)), input.claim)) await wipe(redis, input.id, meta.count);
    return reply(200, { ok: true });
  }

  // 받는 쪽 — 틀린 코드(없는 id)는 IP 당 10분에 10번까지.
  if (await failedTooOften(redis, ip)) return nope(429, "여러 번 틀렸어요. 10분 뒤에 다시 해 주세요.");
  const fail = async (status, message) => { await bump(redis, failKey(ip), FAIL_WINDOW); return nope(status, message); };
  const meta = await loadMeta(redis, input.id);
  if (!meta?.ready) return fail(404, "코드를 다시 확인해 주세요.");

  if (action === "info") {
    const claim = newTicket();
    const ok = await redis.set(claimKey(input.id), claim, { ex: TTL, nx: true });
    if (!ok) return fail(410, "이미 받아 간 코드예요.");
    return reply(200, { ok: true, size: meta.size, count: meta.count, salt: meta.salt, claim });
  }

  if (!same(await redis.get(claimKey(input.id)), input.claim)) return fail(403, "코드를 다시 확인해 주세요.");
  if (input.index >= meta.count) return nope(400, "조각 번호가 맞지 않아요.");
  const data = unwrap(await redis.get(chunkKey(input.id, input.index)));
  if (data == null) return nope(410, "조각이 사라졌어요.");
  if (input.index === meta.count - 1) await wipe(redis, input.id, meta.count);
  return reply(200, { ok: true, data });
}
