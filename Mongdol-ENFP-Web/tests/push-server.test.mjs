// 서버 함수 — Redis·web-push·레이트리밋을 메모리 가짜로 바꿔 끼운다(실제 Redis 는 안 쓴다).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Readable } from 'node:stream';
import { makeHandler as makeSchedule } from '../api/push-schedule.js';
import { makeHandler as makeSend } from '../api/push-send.js';
import { DUE, subKey, itemsKey, subId, isPushEndpoint, payloadFor, SUB_TTL } from '../api/_lib/push.js';

class FakeRedis {
  constructor() { this.kv = new Map(); this.ttl = new Map(); this.sets = new Map(); this.z = new Map(); }
  async get(k) { return this.kv.get(k) ?? null; }
  async set(k, v, o) { this.kv.set(k, v); if (o?.ex) this.ttl.set(k, o.ex); return 'OK'; }
  async del(...ks) { let n = 0; for (const k of ks) n += +(this.kv.delete(k) | this.sets.delete(k) | this.z.delete(k)); return n; }
  async expire(k, s) { this.ttl.set(k, s); return 1; }
  async sadd(k, ...ms) { const s = this.sets.get(k) ?? new Set(); this.sets.set(k, s); let n = 0; for (const m of ms) if (!s.has(m)) { s.add(m); n++; } return n; }
  async srem(k, ...ms) { const s = this.sets.get(k); let n = 0; for (const m of ms) n += +(s?.delete(m) ?? 0); return n; }
  async smembers(k) { return [...(this.sets.get(k) ?? [])]; }
  async zadd(k, ...entries) { const z = this.z.get(k) ?? new Map(); this.z.set(k, z); for (const { score, member } of entries) z.set(member, score); return entries.length; }
  async zrem(k, ...ms) { const z = this.z.get(k); let n = 0; for (const m of ms) n += +(z?.delete(m) ?? 0); return n; }
  async zrange(k, min, max, o) {
    assert.ok(o?.byScore && o.withScores, 'byScore·withScores 로 부른다');
    const rows = [...(this.z.get(k) ?? new Map())].filter(([, s]) => s >= min && s <= max).sort((a, b) => a[1] - b[1]);
    return rows.slice(o.offset ?? 0, (o.offset ?? 0) + (o.count ?? rows.length)).flat();
  }
  zcard(k) { return this.z.get(k)?.size ?? 0; }
}

const NOW = Date.UTC(2026, 9, 6, 3, 0); // 서울 12:00
const H = 3600e3;
const sub = (n = 1, host = 'web.push.apple.com') => ({ endpoint: `https://${host}/QGabc${n}`, keys: { p256dh: 'BPp256dhKeyAAAAAAAAAA', auth: 'authKeyAAAA' } });

function call(handler, { method = 'POST', body, headers = {}, raw } = {}) {
  const text = raw ?? (body === undefined ? '' : JSON.stringify(body));
  const req = Readable.from(text ? [Buffer.from(text)] : []);
  Object.assign(req, { method, headers: { 'x-forwarded-for': '1.2.3.4', ...headers }, socket: {} });
  return new Promise((resolve) => {
    const res = {
      statusCode: 200, headers: {},
      setHeader(k, v) { this.headers[k] = v; },
      end(s) { resolve({ status: this.statusCode, json: s ? JSON.parse(s) : null }); },
    };
    handler(req, res);
  });
}

const okLimiter = { limit: async () => ({ success: true }) };
const scheduleHandler = (redis, limiter = okLimiter) => makeSchedule({ getRedis: async () => redis, getLimiter: async () => limiter, now: () => NOW });

test('잘 알려진 푸시 호스트만 받는다', () => {
  assert.ok(isPushEndpoint('https://web.push.apple.com/abc'));
  assert.ok(isPushEndpoint('https://fcm.googleapis.com/fcm/send/abc'));
  assert.ok(isPushEndpoint('https://updates.push.services.mozilla.com/wpush/v2/abc'));
  assert.ok(isPushEndpoint('https://wns2-par02p.notify.windows.com/w/?token=abc'));
  for (const bad of ['http://web.push.apple.com/abc', 'https://evil.com/abc', 'https://web.push.apple.com.evil.com/x',
    'https://notify.windows.com.evil.com/x', 'https://evilnotify.windows.com/x', 'https://u:p@fcm.googleapis.com/x', 'https://fcm.googleapis.com:8443/x', 'not a url']) {
    assert.equal(isPushEndpoint(bad), false, bad);
  }
});

test('일정 저장 — 구독(TTL 30일) · ZSET · 항목 SET, 8일 밖·지난 것은 뺀다', async () => {
  const r = new FakeRedis();
  const s = sub();
  const items = [
    { at: NOW + 1 * H, kind: 'evening', key: '2026-10-06' },
    { at: NOW + 20 * H, kind: 'arrival', key: '2026-10-06' },
    { at: NOW - 1 * H, kind: 'morning', key: '2026-10-06' },
    { at: NOW + 9 * 24 * H, kind: 'morning', key: '2026-10-15' },
  ];
  const res = await call(scheduleHandler(r), { body: { subscription: s, items, tz: 'Asia/Seoul' } });
  assert.equal(res.status, 200);
  assert.equal(res.json.stored, 2);
  const id = subId(s.endpoint);
  assert.equal(id.length, 32);
  assert.deepEqual(JSON.parse(r.kv.get(subKey(id))), { subscription: s, tz: 'Asia/Seoul' });
  assert.equal(r.ttl.get(subKey(id)), SUB_TTL);
  assert.deepEqual([...r.z.get(DUE)].sort(), [[`${id}|arrival|2026-10-06`, NOW + 20 * H], [`${id}|evening|2026-10-06`, NOW + H]].sort());
  assert.equal((await r.smembers(itemsKey(id))).length, 2);
  assert.ok([...r.kv.keys(), ...r.sets.keys(), ...r.z.keys()].every((k) => k.startsWith('mongdol:')));
});

test('다시 보내면 옛 일정은 지우고 새 일정으로 바꾼다(다른 구독 것은 그대로)', async () => {
  const r = new FakeRedis();
  const h = scheduleHandler(r);
  await call(h, { body: { subscription: sub(1), items: [{ at: NOW + H, kind: 'evening', key: '2026-10-06' }, { at: NOW + 2 * H, kind: 'morning', key: '2026-10-07' }] } });
  await call(h, { body: { subscription: sub(2), items: [{ at: NOW + H, kind: 'evening', key: '2026-10-06' }] } });
  await call(h, { body: { subscription: sub(1), items: [{ at: NOW + 3 * H, kind: 'arrival', key: '2026-10-06' }] } });
  const id1 = subId(sub(1).endpoint), id2 = subId(sub(2).endpoint);
  assert.deepEqual([...r.z.get(DUE).keys()].sort(), [`${id1}|arrival|2026-10-06`, `${id2}|evening|2026-10-06`].sort());
  assert.deepEqual(await r.smembers(itemsKey(id1)), [`${id1}|arrival|2026-10-06`]);
  // 빈 일정이면 구독만 남고 항목은 비운다
  await call(h, { body: { subscription: sub(1), items: [] } });
  assert.deepEqual([...r.z.get(DUE).keys()], [`${id2}|evening|2026-10-06`]);
  assert.ok(r.kv.has(subKey(id1)));
});

test('DELETE 는 구독과 일정을 다 지운다', async () => {
  const r = new FakeRedis();
  const h = scheduleHandler(r);
  await call(h, { body: { subscription: sub(1), items: [{ at: NOW + H, kind: 'evening', key: '2026-10-06' }] } });
  const res = await call(h, { method: 'DELETE', body: { endpoint: sub(1).endpoint } });
  assert.equal(res.status, 200);
  const id = subId(sub(1).endpoint);
  assert.equal(r.kv.has(subKey(id)), false);
  assert.equal(r.sets.has(itemsKey(id)), false);
  assert.equal(r.zcard(DUE), 0);
});

test('거절 — 모르는 endpoint · http · 잘못된 kind/key · 31개 · JSON 아님 · 너무 큼 · GET · 레이트리밋', async () => {
  const r = new FakeRedis();
  const h = scheduleHandler(r);
  const item = { at: NOW + H, kind: 'evening', key: '2026-10-06' };
  const bad = [
    { subscription: { ...sub(), endpoint: 'https://evil.example.com/x' }, items: [item] },
    { subscription: { ...sub(), endpoint: 'http://web.push.apple.com/x' }, items: [item] },
    { subscription: sub(), items: [{ ...item, kind: 'photo' }] },
    { subscription: sub(), items: [{ ...item, key: '2026-10-06|x' }] },
    { subscription: sub(), items: Array.from({ length: 31 }, () => item) },
    { subscription: { endpoint: sub().endpoint }, items: [item] },
  ];
  for (const body of bad) assert.equal((await call(h, { body })).status, 400, JSON.stringify(body).slice(0, 80));
  assert.equal((await call(h, { method: 'DELETE', body: { endpoint: 'https://evil.example.com/x' } })).status, 400);
  assert.equal((await call(h, { raw: '{oops' })).status, 400);
  assert.equal((await call(h, { raw: JSON.stringify({ pad: 'x'.repeat(20000) }) })).status, 413);
  assert.equal((await call(h, { method: 'GET' })).status, 405);
  const limited = scheduleHandler(r, { limit: async () => ({ success: false }) });
  assert.equal((await call(limited, { body: { subscription: sub(), items: [item] } })).status, 429);
  assert.equal(r.zcard(DUE), 0);
});

// ── 보내기 ──
function fakeWebpush(statusFor = () => 201) {
  const sent = [];
  return {
    sent,
    async sendNotification(subscription, payload, opts) {
      sent.push({ endpoint: subscription.endpoint, payload: JSON.parse(payload), opts });
      const status = statusFor(subscription.endpoint);
      if (status >= 400) { const e = new Error('push'); e.statusCode = status; throw e; }
      return { statusCode: status };
    },
  };
}
const ENV = { CRON_SECRET: 's3cret', VAPID_PUBLIC_KEY: 'pub', VAPID_PRIVATE_KEY: 'priv' };
const auth = { authorization: 'Bearer s3cret' };
const sendHandler = (r, wp, nowMs = NOW) => makeSend({ getRedis: async () => r, getWebpush: async () => wp, env: ENV, now: () => nowMs });

async function seed(r, n, items) {
  await call(scheduleHandler(r), { body: { subscription: sub(n), items } });
}

test('인증 — 헤더 없음·틀림·CRON_SECRET 없음이면 401, 아무것도 안 보냄', async () => {
  const r = new FakeRedis();
  const wp = fakeWebpush();
  assert.equal((await call(sendHandler(r, wp), { method: 'GET' })).status, 401);
  assert.equal((await call(sendHandler(r, wp), { method: 'GET', headers: { authorization: 'Bearer nope' } })).status, 401);
  const noSecret = makeSend({ getRedis: async () => r, getWebpush: async () => wp, env: { ...ENV, CRON_SECRET: '' } });
  assert.equal((await call(noSecret, { method: 'GET', headers: { authorization: 'Bearer ' } })).status, 401);
  assert.equal(wp.sent.length, 0);
});

test('기한 지난 것만 보내고 지운다 — 문구·tag·Declarative 형식·TTL', async () => {
  const r = new FakeRedis();
  await seed(r, 1, [
    { at: NOW + 10 * 60e3, kind: 'arrival', key: '2026-10-06' },
    { at: NOW + 2 * H, kind: 'evening', key: '2026-10-06' },
  ]);
  const wp = fakeWebpush();
  const later = NOW + 15 * 60e3;
  const res = await call(sendHandler(r, wp, later), { method: 'GET', headers: auth });
  assert.equal(res.status, 200);
  assert.equal(res.json.sent, 1);
  assert.equal(wp.sent.length, 1);
  const { payload, opts } = wp.sent[0];
  assert.deepEqual(payload, {
    web_push: 8030,
    notification: { title: '몽돌', body: '어제의 조약돌이 도착했어요.', navigate: 'https://mongdol-enfp.vercel.app/', silent: false, tag: 'arrival-2026-10-06', lang: 'ko' },
  });
  assert.equal(opts.TTL, 3600);
  assert.deepEqual(opts.vapidDetails, { subject: 'https://mongdol-enfp.vercel.app', publicKey: 'pub', privateKey: 'priv' });
  const id = subId(sub(1).endpoint);
  assert.deepEqual([...r.z.get(DUE).keys()], [`${id}|evening|2026-10-06`]);
  // 한 번 더 돌려도 다시 안 간다
  await call(sendHandler(r, wp, later), { method: 'POST', headers: auth });
  assert.equal(wp.sent.length, 1);
});

test('45분 넘게 늦은 건 보내지 않고 버린다', async () => {
  const r = new FakeRedis();
  await seed(r, 1, [
    { at: NOW + 10 * 60e3, kind: 'morning', key: '2026-10-06' },
    { at: NOW + 60 * 60e3, kind: 'evening', key: '2026-10-06' },
  ]);
  const wp = fakeWebpush();
  const res = await call(sendHandler(r, wp, NOW + 60 * 60e3 + 30 * 60e3), { method: 'GET', headers: auth });
  assert.equal(res.json.late, 1);
  assert.equal(res.json.sent, 1);
  assert.equal(wp.sent[0].payload.notification.body, '노을 지는 시간이에요. 순간을 남겨 보는 건 어때요?');
  assert.equal(wp.sent[0].payload.notification.tag, 'reminder-2026-10-06-evening');
  assert.equal(r.zcard(DUE), 0);
});

test('410/404 면 그 구독을 통째로 지운다, 5xx 는 다음에 다시', async () => {
  const r = new FakeRedis();
  await seed(r, 1, [{ at: NOW + 60e3, kind: 'morning', key: '2026-10-06' }, { at: NOW + 3 * H, kind: 'evening', key: '2026-10-06' }]);
  await seed(r, 2, [{ at: NOW + 60e3, kind: 'morning', key: '2026-10-06' }]);
  await seed(r, 3, [{ at: NOW + 60e3, kind: 'morning', key: '2026-10-06' }]);
  const status = { [sub(1).endpoint]: 410, [sub(2).endpoint]: 404, [sub(3).endpoint]: 503 };
  const wp = fakeWebpush((ep) => status[ep]);
  const res = await call(sendHandler(r, wp, NOW + 5 * 60e3), { method: 'GET', headers: auth });
  assert.deepEqual({ gone: res.json.gone, failed: res.json.failed, sent: res.json.sent }, { gone: 2, failed: 1, sent: 0 });
  for (const n of [1, 2]) {
    const id = subId(sub(n).endpoint);
    assert.equal(r.kv.has(subKey(id)), false);
    assert.equal(r.sets.has(itemsKey(id)), false);
  }
  const id3 = subId(sub(3).endpoint);
  assert.deepEqual([...r.z.get(DUE).keys()], [`${id3}|morning|2026-10-06`]);
  assert.ok(r.kv.has(subKey(id3)));
});

test('구독이 사라진(TTL 만료) 항목은 조용히 버린다', async () => {
  const r = new FakeRedis();
  await seed(r, 1, [{ at: NOW + 60e3, kind: 'morning', key: '2026-10-06' }]);
  r.kv.clear();
  const wp = fakeWebpush();
  const res = await call(sendHandler(r, wp, NOW + 5 * 60e3), { method: 'GET', headers: auth });
  assert.equal(res.json.missing, 1);
  assert.equal(wp.sent.length, 0);
  assert.equal(r.zcard(DUE), 0);
});

test('한 번에 최대 500개', async () => {
  const r = new FakeRedis();
  for (let i = 0; i < 520; i++) await r.zadd(DUE, { score: NOW - 1000 + i, member: `x${i}|morning|2026-10-06` });
  const wp = fakeWebpush();
  const res = await call(sendHandler(r, wp), { method: 'GET', headers: auth });
  assert.equal(res.json.due, 500);
  assert.equal(r.zcard(DUE), 20);
});

test('payloadFor 문구는 iOS 와 같다', () => {
  assert.equal(payloadFor('morning', '2026-10-06').notification.body, '오늘은 어떤 색을 만나게 될까요.');
  assert.equal(payloadFor('morning', '2026-10-06').notification.app_badge, undefined);
});
