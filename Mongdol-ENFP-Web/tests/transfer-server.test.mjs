// 기록 옮기기 서버 — Redis(시계 달린 메모리 가짜)·레이트리밋을 바꿔 끼운다.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Readable } from 'node:stream';
import { makeHandler } from '../api/transfer.js';
import { CHUNK, SEAL, MAX_SIZE, TTL, FAIL_LIMIT, UP_LIMIT, metaKey, chunkKey, claimKey, expectedChunkBytes } from '../api/_lib/transfer.js';
import * as core from '../js/transfer-core.js';
import { ClockRedis } from './clock-redis.mjs';

function call(handler, body, { ip = '1.2.3.4', method = 'POST', raw } = {}) {
  const text = raw ?? JSON.stringify(body);
  const req = Readable.from(text ? [Buffer.from(text)] : []);
  Object.assign(req, { method, headers: { 'x-forwarded-for': ip }, socket: {} });
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
const handlerFor = (r, limiter = okLimiter) => makeHandler({ getRedis: async () => r, getLimiter: async () => limiter });
const ID = (n) => n.toString(16).padStart(64, 'a');
const SALT = Buffer.alloc(16, 7).toString('base64');
const chunk = (size, count, i) => Buffer.alloc(expectedChunkBytes(size, count, i), i + 1).toString('base64');

async function upload(h, id, size, ip) {
  const count = Math.ceil(size / CHUNK);
  const s = await call(h, { action: 'start', id, size, count, salt: SALT }, { ip });
  assert.equal(s.status, 200, JSON.stringify(s.json));
  for (let i = 0; i < count; i++) {
    const c = await call(h, { action: 'chunk', id, token: s.json.token, index: i, data: chunk(size, count, i) }, { ip });
    assert.equal(c.status, 200, JSON.stringify(c.json));
  }
  const f = await call(h, { action: 'finish', id, token: s.json.token }, { ip });
  return { token: s.json.token, count, finish: f };
}

test('서버 상수가 브라우저 쪽과 같다', () => {
  assert.equal(CHUNK, core.CHUNK);
  assert.equal(SEAL, core.SEAL);
  assert.equal(MAX_SIZE, core.MAX_SIZE);
});

test('시작 → 조각 → 마침 → 받기(info·get) → 마지막 조각에서 전부 지움, 같은 코드 두 번째는 실패', async () => {
  const r = new ClockRedis();
  const h = handlerFor(r);
  const size = CHUNK * 2 + 1000;
  const { count, finish } = await upload(h, ID(1), size);
  assert.equal(count, 3);
  assert.deepEqual(finish.json, { ok: true, ttl: TTL });
  assert.ok(r.keys().every((k) => k.startsWith('mongdol:xfer:')), r.keys().join());
  assert.equal(JSON.parse(r.kv.get(metaKey(ID(1)))).ready, true);

  const info = await call(h, { action: 'info', id: ID(1) }, { ip: '9.9.9.9' });
  assert.equal(info.status, 200);
  assert.equal(info.json.count, 3);
  assert.equal(info.json.size, size);
  assert.equal(info.json.salt, SALT);
  assert.match(info.json.claim, /^[0-9a-f]{32}$/);
  assert.equal(info.json.token, undefined, '올리는 표는 받는 쪽에 안 준다');

  for (let i = 0; i < 3; i++) {
    const g = await call(h, { action: 'get', id: ID(1), claim: info.json.claim, index: i }, { ip: '9.9.9.9' });
    assert.equal(g.status, 200);
    assert.equal(g.json.data, chunk(size, 3, i));
  }
  assert.deepEqual(r.keys().filter((k) => k.includes(ID(1)) || k.includes('fail')), [], '마지막 조각을 주고 나면 아무것도 안 남는다(실패 횟수도 없다)');
  const again = await call(h, { action: 'info', id: ID(1) }, { ip: '9.9.9.9' });
  assert.equal(again.status, 404);
});

test('누가 먼저 info 로 받아 가기 시작하면 두 번째 info 는 410, 표 없는 get 은 403', async () => {
  const r = new ClockRedis();
  const h = handlerFor(r);
  await upload(h, ID(2), 100);
  const first = await call(h, { action: 'info', id: ID(2) });
  assert.equal(first.status, 200);
  assert.equal((await call(h, { action: 'info', id: ID(2) })).status, 410);
  assert.equal((await call(h, { action: 'get', id: ID(2), claim: 'f'.repeat(32), index: 0 })).status, 403);
  // done 으로도 지운다
  assert.equal((await call(h, { action: 'done', id: ID(2), claim: first.json.claim })).status, 200);
  assert.equal(r.alive(metaKey(ID(2))) || r.alive(chunkKey(ID(2), 0)) || r.alive(claimKey(ID(2))), false);
  // 이미 지운 뒤의 done · 표 틀린 done 은 같은 답이고 실패로 세지 않는다
  assert.equal((await call(h, { action: 'done', id: ID(2), claim: first.json.claim })).status, 200);
  await upload(h, ID(12), 100);
  await call(h, { action: 'info', id: ID(12) });
  assert.equal((await call(h, { action: 'done', id: ID(12), claim: 'f'.repeat(32) })).status, 200);
  assert.ok(r.alive(metaKey(ID(12))), '표가 틀리면 안 지운다');
  assert.equal(r.kv.get('mongdol:xfer:fail:1.2.3.4'), 2, 'info 410 · get 403 두 번만 실패');
});

test('TTL — 다 올린 뒤 10분이 지나면 다 사라지고 받기는 404', async () => {
  const r = new ClockRedis();
  const h = handlerFor(r);
  await upload(h, ID(3), CHUNK + 5);
  r.tick(TTL - 1);
  assert.ok(r.alive(metaKey(ID(3))) && r.alive(chunkKey(ID(3), 1)));
  r.tick(2);
  assert.equal(r.keys().filter((k) => k.includes(ID(3))).length, 0);
  assert.equal((await call(h, { action: 'info', id: ID(3) })).status, 404);
});

test('올리는 중엔 조각마다 10분 연장, 끝내지 않은 묶음은 받을 수 없다(404)', async () => {
  const r = new ClockRedis();
  const h = handlerFor(r);
  const size = CHUNK + 5;
  const s = await call(h, { action: 'start', id: ID(4), size, count: 2, salt: SALT });
  r.tick(TTL - 10);
  assert.equal((await call(h, { action: 'chunk', id: ID(4), token: s.json.token, index: 0, data: chunk(size, 2, 0) })).status, 200);
  r.tick(TTL - 10);
  assert.ok(r.alive(metaKey(ID(4))), '조각이 오면 묶음 머리도 연장');
  assert.equal((await call(h, { action: 'info', id: ID(4) })).status, 404);
  assert.equal((await call(h, { action: 'finish', id: ID(4), token: s.json.token })).status, 409, '조각이 덜 왔다');
});

test('잘못된 id 레이트리밋 — IP 당 10번 틀리면 10분 동안 맞는 코드도 막힌다(다른 IP 는 그대로)', async () => {
  const r = new ClockRedis();
  const h = handlerFor(r);
  await upload(h, ID(5), 100);
  for (let i = 0; i < FAIL_LIMIT; i++) assert.equal((await call(h, { action: 'info', id: ID(100 + i) }, { ip: '6.6.6.6' })).status, 404);
  assert.equal((await call(h, { action: 'info', id: ID(5) }, { ip: '6.6.6.6' })).status, 429);
  assert.equal((await call(h, { action: 'info', id: ID(5) }, { ip: '7.7.7.7' })).status, 200);
  r.tick(601);
  await upload(h, ID(6), 100);
  assert.equal((await call(h, { action: 'info', id: ID(6) }, { ip: '6.6.6.6' })).status, 200, '10분 지나면 풀린다');
});

test('보내기 시작은 IP 당 시간당 10번', async () => {
  const r = new ClockRedis();
  const h = handlerFor(r);
  for (let i = 0; i < UP_LIMIT; i++) assert.equal((await call(h, { action: 'start', id: ID(200 + i), size: 10, count: 1, salt: SALT })).status, 200);
  assert.equal((await call(h, { action: 'start', id: ID(300), size: 10, count: 1, salt: SALT })).status, 429);
  assert.equal((await call(h, { action: 'start', id: ID(301), size: 10, count: 1, salt: SALT }, { ip: '8.8.8.8' })).status, 200);
});

test('거절 — 크기 초과 · 조각 수 틀림 · 같은 id · 잘못된 조각 번호 · 조각 크기 · 표 틀림 · 다 올린 뒤 · 형식 · GET · 레이트리밋', async () => {
  const r = new ClockRedis();
  const h = handlerFor(r);
  const big = MAX_SIZE + 1;
  assert.equal((await call(h, { action: 'start', id: ID(7), size: big, count: Math.ceil(big / CHUNK), salt: SALT })).status, 413);
  assert.equal((await call(h, { action: 'start', id: ID(7), size: CHUNK * 2, count: 3, salt: SALT })).status, 400);
  const size = CHUNK + 10;
  const s = await call(h, { action: 'start', id: ID(7), size, count: 2, salt: SALT });
  assert.equal(s.status, 200);
  assert.equal((await call(h, { action: 'start', id: ID(7), size, count: 2, salt: SALT })).status, 409);
  const token = s.json.token;
  assert.equal((await call(h, { action: 'chunk', id: ID(7), token, index: 2, data: chunk(size, 2, 1) })).status, 400, '범위 밖 번호');
  assert.equal((await call(h, { action: 'chunk', id: ID(7), token, index: -1, data: chunk(size, 2, 1) })).status, 400);
  assert.equal((await call(h, { action: 'chunk', id: ID(7), token, index: 0.5, data: chunk(size, 2, 1) })).status, 400);
  assert.equal((await call(h, { action: 'chunk', id: ID(7), token, index: 0, data: chunk(size, 2, 1) })).status, 400, '0번 자리에 마지막 조각 크기');
  assert.equal((await call(h, { action: 'chunk', id: ID(7), token, index: 1, data: 'not base64!!' })).status, 400);
  assert.equal((await call(h, { action: 'chunk', id: ID(7), token: 'e'.repeat(32), index: 0, data: chunk(size, 2, 0) })).status, 403);
  assert.equal((await call(h, { action: 'chunk', id: ID(8), token, index: 0, data: chunk(size, 2, 0) })).status, 404);
  for (const i of [0, 1]) assert.equal((await call(h, { action: 'chunk', id: ID(7), token, index: i, data: chunk(size, 2, i) })).status, 200);
  assert.equal((await call(h, { action: 'finish', id: ID(7), token })).status, 200);
  assert.equal((await call(h, { action: 'chunk', id: ID(7), token, index: 0, data: chunk(size, 2, 0) })).status, 409, '다 올린 뒤엔 못 바꾼다');
  const info = await call(h, { action: 'info', id: ID(7) });
  assert.equal((await call(h, { action: 'get', id: ID(7), claim: info.json.claim, index: 2 })).status, 400);

  assert.equal((await call(h, { action: 'info', id: 'zz' })).status, 400);
  assert.equal((await call(h, { action: 'nope', id: ID(7) })).status, 400);
  assert.equal((await call(h, null, { raw: '{oops' })).status, 400);
  assert.equal((await call(h, null, { raw: JSON.stringify({ pad: 'x'.repeat(800 * 1024) }) })).status, 413);
  assert.equal((await call(h, null, { method: 'GET', raw: '' })).status, 405);
  const limited = handlerFor(r, { limit: async () => ({ success: false }) });
  assert.equal((await call(limited, { action: 'info', id: ID(7) })).status, 429);
});

test('짧은 마지막 조각이 숫자처럼 보여도 문자열 그대로 돌아온다', async () => {
  const r = new ClockRedis();
  const h = handlerFor(r);
  await upload(h, ID(9), 1);
  const raw = r.kv.get(chunkKey(ID(9), 0));
  assert.ok(raw.startsWith('c:'));
  const info = await call(h, { action: 'info', id: ID(9) });
  const g = await call(h, { action: 'get', id: ID(9), claim: info.json.claim, index: 0 });
  assert.equal(Buffer.from(g.json.data, 'base64').length, 1 + SEAL);
});
