// 기록 옮기기의 순수 부분 — 코드·묶기·풀기·암호화. 브라우저와 node(webcrypto) 둘 다에서 돈다(tests/transfer-core.test.mjs).
//
// 묶음(평문): "MDX1" · u32(머리 길이, big-endian) · 머리 JSON · 사진 바이트들을 이어 붙인 것
//   머리 = { v:1, moments:[…], meta:{…}, photos:[{ id, full:{type, off, len}|null, thumb:… }] } — off 는 머리 뒤부터 센다.
// 암호화: key = PBKDF2(코드, 무작위 salt 16바이트, SHA-256, 200,000번) → AES-GCM 256.
//   묶음을 512KB 씩 잘라 조각마다 따로 잠근다(iv 12바이트 + 암호문·태그). AAD 에 조각 번호·개수를 넣어 순서를 못 바꾸게.
// 서버 조회 id = hex(SHA-256("mongdol-transfer-id:" + 코드)) — 키와 다른 길로 만든다.

export const CHUNK = 512 * 1024;
export const SEAL = 28;
export const MAX_SIZE = 200 * 1024 * 1024;
export const ITERATIONS = 200_000;
export const CODE_LENGTH = 8;

const MAGIC = [0x4d, 0x44, 0x58, 0x31];
const enc = new TextEncoder();
const dec = new TextDecoder();
const subtle = () => globalThis.crypto.subtle;

export class TransferError extends Error {
  constructor(kind, message = kind) { super(message); this.kind = kind; }
}

export function makeCode() {
  const a = new Uint32Array(1);
  // 4,200,000,000 이상은 버린다 — 1억으로 나눈 나머지가 고르게 나오게.
  for (;;) {
    globalThis.crypto.getRandomValues(a);
    if (a[0] < 4_200_000_000) return String(a[0] % 100_000_000).padStart(CODE_LENGTH, '0');
  }
}

export const cleanCode = (s) => String(s ?? '').replace(/\D/g, '').slice(0, CODE_LENGTH);
export const formatCode = (code) => (code.length > 4 ? `${code.slice(0, 4)} ${code.slice(4)}` : code);
export const isCode = (s) => /^\d{8}$/.test(s);

const hex = (buf) => [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, '0')).join('');

export async function idFor(code) {
  return hex(await subtle().digest('SHA-256', enc.encode(`mongdol-transfer-id:${code}`)));
}

export async function deriveKey(code, salt) {
  const base = await subtle().importKey('raw', enc.encode(code), 'PBKDF2', false, ['deriveKey']);
  return subtle().deriveKey(
    { name: 'PBKDF2', salt, iterations: ITERATIONS, hash: 'SHA-256' },
    base, { name: 'AES-GCM', length: 256 }, false, ['encrypt', 'decrypt']);
}

export const randomBytes = (n) => globalThis.crypto.getRandomValues(new Uint8Array(n));
export const chunkCount = (size) => Math.ceil(size / CHUNK);
const aad = (i, n) => enc.encode(`mongdol-xfer|${i}|${n}`);

export async function sealChunk(key, plain, index, count) {
  const iv = randomBytes(12);
  const ct = new Uint8Array(await subtle().encrypt({ name: 'AES-GCM', iv, additionalData: aad(index, count) }, key, plain));
  const out = new Uint8Array(12 + ct.length);
  out.set(iv, 0);
  out.set(ct, 12);
  return out;
}

export async function openChunk(key, sealed, index, count) {
  if (sealed.length < SEAL) throw new TransferError('bad-code');
  try {
    return new Uint8Array(await subtle().decrypt(
      { name: 'AES-GCM', iv: sealed.subarray(0, 12), additionalData: aad(index, count) }, key, sealed.subarray(12)));
  } catch {
    throw new TransferError('bad-code');
  }
}

export function toB64(bytes) {
  let s = '';
  for (let i = 0; i < bytes.length; i += 0x8000) s += String.fromCharCode.apply(null, bytes.subarray(i, i + 0x8000));
  return btoa(s);
}

export function fromB64(str) {
  const s = atob(str);
  const out = new Uint8Array(s.length);
  for (let i = 0; i < s.length; i++) out[i] = s.charCodeAt(i);
  return out;
}

/**
 * bundle = { moments, meta, photos:[{ id, full:{bytes:Uint8Array, type}|null, thumb:… }] }
 * 큰 버퍼 하나로 합치지 않고 조각을 그때그때 잘라 읽는다(사진이 많으면 폰 메모리가 빠듯하다).
 */
export function pack(bundle) {
  const parts = [];
  let off = 0;
  const place = (p) => {
    if (!p?.bytes) return null;
    const at = { type: p.type || '', off, len: p.bytes.length };
    parts.push(p.bytes);
    off += p.bytes.length;
    return at;
  };
  const photos = bundle.photos.map((p) => ({ id: p.id, full: place(p.full), thumb: place(p.thumb) }));
  const head = enc.encode(JSON.stringify({ v: 1, moments: bundle.moments, meta: bundle.meta ?? {}, photos }));
  const prefix = new Uint8Array(8 + head.length);
  prefix.set(MAGIC, 0);
  new DataView(prefix.buffer).setUint32(4, head.length);
  prefix.set(head, 8);
  parts.unshift(prefix);
  const starts = [];
  let size = 0;
  for (const p of parts) { starts.push(size); size += p.length; }

  function slice(from, to) {
    const out = new Uint8Array(to - from);
    for (let k = 0; k < parts.length; k++) {
      const s = starts[k], e = s + parts[k].length;
      if (e <= from || s >= to) continue;
      const a = Math.max(from, s), b = Math.min(to, e);
      out.set(parts[k].subarray(a - s, b - s), a - from);
    }
    return out;
  }
  return { size, slice };
}

export function unpack(bytes) {
  if (bytes.length < 8 || MAGIC.some((b, i) => bytes[i] !== b)) throw new TransferError('bad-bundle');
  const headLen = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength).getUint32(4);
  if (8 + headLen > bytes.length) throw new TransferError('bad-bundle');
  let head;
  try { head = JSON.parse(dec.decode(bytes.subarray(8, 8 + headLen))); } catch { throw new TransferError('bad-bundle'); }
  if (head?.v !== 1 || !Array.isArray(head.moments) || !Array.isArray(head.photos)) throw new TransferError('bad-bundle');
  const base = 8 + headLen;
  const take = (at) => {
    if (!at) return null;
    const s = base + at.off;
    if (!(at.off >= 0 && at.len >= 0 && s + at.len <= bytes.length)) throw new TransferError('bad-bundle');
    // db.js 의 사진 형식 그대로 — 따로 떼어 낸 ArrayBuffer.
    return { buf: bytes.buffer.slice(bytes.byteOffset + s, bytes.byteOffset + s + at.len), type: String(at.type || '') };
  };
  return {
    moments: head.moments,
    meta: head.meta && typeof head.meta === 'object' ? head.meta : {},
    photos: head.photos.map((p) => ({ id: p.id, full: take(p.full), thumb: take(p.thumb) })),
  };
}
