// 건의하기 · 관리 API — Redis(시계 달린 메모리 가짜)·레이트리밋을 바꿔 끼운다(실제 Redis 는 안 쓴다).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Readable } from 'node:stream';
import { makeHandler as makeFeedback } from '../api/feedback.js';
import { makeHandler as makeAdmin } from '../api/admin/feedback.js';
import { INDEX, itemKey, cidKey, ipHash, TEXT_MAX, MAX_ITEMS } from '../api/_lib/feedback.js';
import { AUTH_FAIL_LIMIT, AUTH_FAIL_WINDOW, authFailKey } from '../api/_lib/admin.js';
import { ClockRedis } from './clock-redis.mjs';

function call(handler, { method = 'POST', body, raw, ip = '1.2.3.4', headers = {}, url = '/' } = {}) {
  const text = raw ?? (body === undefined ? '' : JSON.stringify(body));
  const req = Readable.from(text ? [Buffer.from(text)] : []);
  Object.assign(req, { method, url, headers: { 'x-forwarded-for': ip, ...headers }, socket: {} });
  return new Promise((resolve) => {
    const res = {
      statusCode: 200, headers: {},
      setHeader(k, v) { this.headers[k] = v; },
      end(s) { resolve({ status: this.statusCode, json: s ? JSON.parse(s) : null }); },
    };
    handler(req, res);
  });
}

const NOW = Date.UTC(2026, 9, 8, 3, 0);
const okLimiter = { limit: async () => ({ success: true }) };
const send = (r, { limiter = okLimiter, now = () => NOW } = {}) => makeFeedback({ getRedis: async () => r, getLimiter: async () => limiter, now });
const TOKEN = 'a'.repeat(48);
const admin = (r, env = { ADMIN_TOKEN: TOKEN }) => makeAdmin({ getRedis: async () => r, env });
const auth = { authorization: `Bearer ${TOKEN}` };
const good = { kind: 'bug', text: '  조약돌이 안 떠요  ', contact: 'me@example.com', v: '1.1.1', b: '4', d: 'iPhone17,1', website: '' };
const stored = (r) => r.keys().filter((k) => /^mongdol:fb:f/.test(k)).map((k) => JSON.parse(r.kv.get(k)));

test('저장 형태 — 값 JSON 하나 + 최신순 색인, IP 는 어디에도 없다', async () => {
  const r = new ClockRedis();
  const res = await call(send(r), { body: good });
  assert.equal(res.status, 200);
  assert.deepEqual(res.json, { ok: true });
  const [rec] = stored(r);
  assert.match(rec.id, /^f[0-9a-z]+$/);
  assert.deepEqual({ ...rec, id: 'x' }, { id: 'x', kind: 'bug', text: '조약돌이 안 떠요', contact: 'me@example.com', v: '1.1.1', b: '4', d: 'iPhone17,1', at: NOW, read: false });
  assert.equal(r.z.get(INDEX).get(rec.id), NOW);
  assert.equal(r.exp.has(itemKey(rec.id)), false, '지울 때까지 남는다');
  const dump = JSON.stringify([...r.kv.entries()]) + r.keys().join();
  assert.ok(!dump.includes('1.2.3.4'), 'IP 원문이 남지 않는다');
  assert.ok(r.keys().every((k) => k.startsWith('mongdol:fb:')), r.keys().join());
});

test('쿼리가 없을 때 — 연락처·버전·빌드·기종은 빈 값으로', async () => {
  const r = new ClockRedis();
  assert.equal((await call(send(r), { body: { kind: 'etc', text: '좋아요' } })).status, 200);
  const [rec] = stored(r);
  assert.deepEqual([rec.contact, rec.v, rec.b, rec.d], ['', '', '', '']);
});

test('검증 실패 — 종류 · 빈 내용 · 2000자 넘김 · 연락처 200자 넘김 · 버전·기종 모양 · JSON 아님 · 너무 큼 · GET', async () => {
  const r = new ClockRedis();
  const h = send(r);
  const bad = [
    { ...good, kind: 'love' },
    { ...good, kind: undefined },
    { ...good, text: '   ' },
    { ...good, text: '가'.repeat(TEXT_MAX + 1) },
    { ...good, contact: 'a'.repeat(201) },
    { ...good, v: '1.1.1<script>' },
    { ...good, d: 'iPhone17,1"' },
    { ...good, b: '4'.repeat(21) },
    { ...good, cid: 'NOTHEX' },
  ];
  for (const body of bad) assert.equal((await call(h, { body })).status, 400, JSON.stringify(body).slice(0, 80));
  assert.equal((await call(h, { body: { ...good, text: '가'.repeat(TEXT_MAX) } })).status, 200, '2000자 꼭 맞으면 받는다');
  assert.equal((await call(h, { raw: '{oops' })).status, 400);
  assert.equal((await call(h, { raw: JSON.stringify({ ...good, text: 'x'.repeat(20000) }) })).status, 413);
  assert.equal((await call(h, { method: 'GET' })).status, 405);
  assert.equal(stored(r).length, 1);
});

test('허니팟 — website 가 차 있으면 성공처럼 답하고 저장하지 않는다', async () => {
  const r = new ClockRedis();
  const res = await call(send(r), { body: { ...good, website: 'http://spam.example' } });
  assert.equal(res.status, 200);
  assert.equal(stored(r).length, 0);
  assert.equal(await r.zcard(INDEX), 0);
});

test('같은 cid 로 다시 오면(응답 못 받고 다시 누름) 한 번만 저장', async () => {
  const r = new ClockRedis();
  const h = send(r);
  const cid = 'ab'.repeat(16);
  assert.equal((await call(h, { body: { ...good, cid } })).status, 200);
  assert.equal((await call(h, { body: { ...good, cid } })).status, 200);
  assert.equal(stored(r).length, 1);
  assert.ok(r.alive(cidKey(cid)));
  assert.equal((await call(h, { body: { ...good, cid: 'cd'.repeat(16) } })).status, 200);
  assert.equal(stored(r).length, 2);
});

test('레이트리밋 — IP 해시로 묻고, 막히면 429 · 장애면 통과', async () => {
  const r = new ClockRedis();
  const seen = [];
  const limiter = { limit: async (k) => { seen.push(k); return { success: seen.length <= 5 }; } };
  const h = send(r, { limiter });
  for (let i = 0; i < 5; i++) assert.equal((await call(h, { body: good })).status, 200);
  assert.equal((await call(h, { body: good })).status, 429);
  assert.equal(seen[0], `fb:${ipHash('1.2.3.4')}`);
  assert.ok(!seen[0].includes('1.2.3.4'));
  const broken = { limit: async () => { throw new Error('down'); } };
  assert.equal((await call(send(r, { limiter: broken }), { body: good })).status, 200);
});

test('색인이 가득 차면(5000) 503 으로 더 받지 않는다', async () => {
  const r = new ClockRedis();
  const z = new Map(Array.from({ length: MAX_ITEMS }, (_, i) => [`f${i}aaaaaaaa`, i]));
  r.z.set(INDEX, z);
  assert.equal((await call(send(r), { body: good })).status, 503);
});

test('관리 API 인증 — 환경변수 없으면 503, 토큰 없음·틀림 401, 맞으면 200', async () => {
  const r = new ClockRedis();
  assert.equal((await call(admin(r, {}), { method: 'GET', headers: auth })).status, 503);
  assert.equal((await call(admin(r), { method: 'GET' })).status, 401);
  assert.equal((await call(admin(r), { method: 'GET', headers: { authorization: `Bearer ${'b'.repeat(48)}` } })).status, 401);
  assert.equal((await call(admin(r), { method: 'GET', headers: { authorization: TOKEN } })).status, 401, 'Bearer 없이는 안 된다');
  const ok = await call(admin(r), { method: 'GET', headers: auth });
  assert.equal(ok.status, 200);
  assert.deepEqual(ok.json, { ok: true, total: 0, items: [] });
  assert.equal((await call(admin(r), { method: 'POST', headers: auth, body: {} })).status, 405);
});

test('관리 API — 토큰을 15분에 10번 틀리면 맞는 토큰도 429(다른 IP 는 그대로), 지나면 풀린다', async () => {
  const r = new ClockRedis();
  const h = admin(r);
  for (let i = 0; i < AUTH_FAIL_LIMIT; i++) assert.equal((await call(h, { method: 'GET', ip: '6.6.6.6', headers: { authorization: 'Bearer nope' } })).status, 401);
  assert.equal((await call(h, { method: 'GET', ip: '6.6.6.6', headers: auth })).status, 429);
  assert.equal((await call(h, { method: 'GET', ip: '7.7.7.7', headers: auth })).status, 200);
  assert.equal(r.kv.get(authFailKey(ipHash('6.6.6.6'))), AUTH_FAIL_LIMIT);
  assert.ok(r.keys().every((k) => !k.includes('6.6.6.6')), '실패 횟수 키에도 IP 원문은 없다');
  r.tick(AUTH_FAIL_WINDOW + 1);
  assert.equal((await call(h, { method: 'GET', ip: '6.6.6.6', headers: auth })).status, 200);
});

test('관리 API — 최신순 목록 · 쪽 나누기 · 읽음 표시 · 지우기', async () => {
  const r = new ClockRedis();
  let t = NOW;
  const h = send(r, { now: () => (t += 1000) });
  for (const [kind, text] of [['bug', '하나'], ['wish', '둘'], ['etc', '셋']]) await call(h, { body: { kind, text } });
  const a = admin(r);
  const list = await call(a, { method: 'GET', headers: auth, url: '/api/admin/feedback?offset=0&limit=2' });
  assert.equal(list.json.total, 3);
  assert.deepEqual(list.json.items.map((i) => i.text), ['셋', '둘']);
  const rest = await call(a, { method: 'GET', headers: auth, url: '/api/admin/feedback?offset=2&limit=2' });
  assert.deepEqual(rest.json.items.map((i) => i.text), ['하나']);

  const [newest] = list.json.items;
  assert.equal((await call(a, { method: 'PATCH', headers: auth, body: { id: newest.id, read: true } })).status, 200);
  assert.equal(JSON.parse(r.kv.get(itemKey(newest.id))).read, true);
  assert.equal((await call(a, { method: 'PATCH', headers: auth, body: { id: 'fnothere00', read: true } })).status, 404);
  assert.equal((await call(a, { method: 'PATCH', headers: auth, body: { id: '../x', read: true } })).status, 400);
  assert.equal((await call(a, { method: 'PATCH', body: { id: newest.id, read: false } })).status, 401, '인증 없이 못 바꾼다');

  assert.equal((await call(a, { method: 'DELETE', headers: auth, body: { id: newest.id } })).status, 200);
  assert.equal(r.alive(itemKey(newest.id)), false);
  assert.equal(r.z.get(INDEX).has(newest.id), false);
  assert.equal((await call(a, { method: 'DELETE', body: { id: list.json.items[1].id } })).status, 401, '인증 없이 못 지운다');
  const after = await call(a, { method: 'GET', headers: auth });
  assert.deepEqual(after.json.items.map((i) => i.text), ['둘', '하나']);
});

test('색인에만 남은 id 는 목록에서 걷어 낸다', async () => {
  const r = new ClockRedis();
  await call(send(r), { body: good });
  const [rec] = stored(r);
  await r.del(itemKey(rec.id));
  const res = await call(admin(r), { method: 'GET', headers: auth });
  assert.deepEqual(res.json, { ok: true, total: 0, items: [] });
  assert.equal(await r.zcard(INDEX), 0);
});
