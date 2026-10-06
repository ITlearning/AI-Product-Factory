// 묶기·풀기·암호화 왕복 — node 의 webcrypto 로 브라우저 코드를 그대로 돌린다.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  CHUNK, SEAL, makeCode, cleanCode, formatCode, isCode, idFor, deriveKey, randomBytes, chunkCount,
  sealChunk, openChunk, toB64, fromB64, pack, unpack, TransferError,
} from '../js/transfer-core.js';

const bytes = (n, seed) => Uint8Array.from({ length: n }, (_, i) => (i * 31 + seed) & 255);

function bundle() {
  return {
    moments: [
      { id: 'a', capturedAt: 1, colorHex: '#FFE3A3', word: { wordID: 'w1', word: '아침' } },
      { id: 'b', capturedAt: 2, colorHex: '#BDE3C4' },
      { id: 'c', capturedAt: 3, colorHex: '#F7B7C8' },
    ],
    meta: { closures: { '2026-10-05': 123 }, gifted: ['2026-10-04'] },
    photos: [
      { id: 'a', full: { bytes: bytes(CHUNK + 777, 1), type: 'image/jpeg' }, thumb: { bytes: bytes(3000, 2), type: 'image/webp' } },
      { id: 'b', full: null, thumb: { bytes: bytes(10, 3), type: 'image/jpeg' } },
    ],
  };
}

async function roundTrip(src, sendCode, receiveCode) {
  const p = pack(src);
  const salt = randomBytes(16);
  const count = chunkCount(p.size);
  const kSend = await deriveKey(sendCode, salt);
  const wire = [];
  for (let i = 0; i < count; i++) {
    const sealed = await sealChunk(kSend, p.slice(i * CHUNK, Math.min(p.size, (i + 1) * CHUNK)), i, count);
    assert.equal(sealed.length, Math.min(CHUNK, p.size - i * CHUNK) + SEAL);
    wire.push(toB64(sealed));
  }
  const kRecv = await deriveKey(receiveCode, fromB64(toB64(salt)));
  const out = new Uint8Array(p.size);
  for (let i = 0; i < count; i++) out.set(await openChunk(kRecv, fromB64(wire[i]), i, count), i * CHUNK);
  return { got: unpack(out), count, wire, kRecv };
}

test('코드 — 8자리 숫자, 4+4 보기, 정리', () => {
  const seen = new Set();
  for (let i = 0; i < 2000; i++) { const c = makeCode(); assert.ok(isCode(c), c); seen.add(c); }
  assert.ok(seen.size > 1990);
  assert.equal(formatCode('12345678'), '1234 5678');
  assert.equal(cleanCode(' 1234-5678 9'), '12345678');
  assert.equal(isCode('1234567'), false);
});

test('id 는 코드마다 다르고 64자 hex, 키 파생과 다른 문자열에서 나온다', async () => {
  const a = await idFor('12345678');
  assert.match(a, /^[0-9a-f]{64}$/);
  assert.equal(a, await idFor('12345678'));
  assert.notEqual(a, await idFor('12345679'));
  const { pbkdf2Sync } = await import('node:crypto');
  assert.equal(a, pbkdf2Sync('12345678', 'mongdol-transfer-id-v1', 200_000, 32, 'sha256').toString('hex'));
});

test('묶기 → 잠그기 → 풀기: 기록·표시값·사진 바이트가 그대로 돌아온다', async () => {
  const src = bundle();
  const { got, count } = await roundTrip(src, '20261006', '20261006');
  assert.equal(count, 2, '512KB 넘는 사진 한 장 → 두 조각');
  assert.deepEqual(got.moments, src.moments);
  assert.deepEqual(got.meta, src.meta);
  assert.equal(got.photos.length, 2);
  const a = got.photos[0];
  assert.ok(a.full.buf instanceof ArrayBuffer, 'db.js 형식 — ArrayBuffer');
  assert.equal(a.full.type, 'image/jpeg');
  assert.deepEqual(new Uint8Array(a.full.buf), src.photos[0].full.bytes);
  assert.deepEqual(new Uint8Array(a.thumb.buf), src.photos[0].thumb.bytes);
  assert.equal(a.thumb.type, 'image/webp');
  assert.equal(got.photos[1].full, null);
  assert.deepEqual(new Uint8Array(got.photos[1].thumb.buf), src.photos[1].thumb.bytes);
});

test('틀린 코드면 첫 조각부터 풀리지 않는다(bad-code)', async () => {
  await assert.rejects(roundTrip(bundle(), '11112222', '11112223'), (e) => e instanceof TransferError && e.kind === 'bad-code');
});

test('조각 순서를 바꾸거나 한 바이트만 고쳐도 풀리지 않는다', async () => {
  const { wire, kRecv, count } = await roundTrip(bundle(), '55554444', '55554444');
  await assert.rejects(openChunk(kRecv, fromB64(wire[1]), 0, count), (e) => e.kind === 'bad-code');
  const bent = fromB64(wire[0]);
  bent[100] ^= 1;
  await assert.rejects(openChunk(kRecv, bent, 0, count), (e) => e.kind === 'bad-code');
});

test('빈 기록도 묶이고, 망가진 묶음은 bad-bundle', () => {
  const p = pack({ moments: [], meta: {}, photos: [] });
  assert.deepEqual(unpack(p.slice(0, p.size)), { moments: [], meta: {}, photos: [] });
  assert.throws(() => unpack(new Uint8Array([1, 2, 3, 4, 5, 6, 7, 8, 9])), (e) => e.kind === 'bad-bundle');
  const whole = pack(bundle());
  assert.throws(() => unpack(whole.slice(0, whole.size - 10)), (e) => e.kind === 'bad-bundle');
});
