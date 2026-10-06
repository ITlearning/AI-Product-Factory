// 원본 Swift 의 UInt64 해시를 그대로 옮긴다 — 같은 날짜는 iOS 앱과 같은 모양·같은 기울기가 나온다.
const M64 = (1n << 64n) - 1n;
const enc = new TextEncoder();

function djb2(s) {
  let h = 5381n;
  for (const b of enc.encode(s)) h = (h * 33n + BigInt(b)) & M64;
  return h;
}

// PebbleSilhouette(dayKey:).seed
export function silhouetteSeed(dayKey) {
  let h = djb2(dayKey);
  h ^= h >> 33n; h = (h * 0xff51afd7ed558ccdn) & M64;
  h ^= h >> 33n; h = (h * 0xc4ceb9fe1a85ec53n) & M64;
  h ^= h >> 33n;
  return h;
}

// DayBlock.wobble — 한 번만 섞는다(원본이 그렇다).
export function wobbleSeed(dayKey) {
  let h = djb2(dayKey);
  h ^= h >> 33n; h = (h * 0xff51afd7ed558ccdn) & M64; h ^= h >> 33n;
  return h;
}

export function byteAt(h, shift) {
  return Number((h >> BigInt(shift)) & 0xffn) / 255;
}

export function fnv1a(s) {
  let h = 0xcbf29ce484222325n;
  for (const b of enc.encode(s)) { h ^= BigInt(b); h = (h * 0x100000001b3n) & M64; }
  return h;
}

// Memories.mix — splitmix64 마무리 단계
export function splitmix(seed, index) {
  let h = (seed + ((BigInt(index) * 0x9e3779b97f4a7c15n) & M64)) & M64;
  h ^= h >> 30n; h = (h * 0xbf58476d1ce4e5b9n) & M64;
  h ^= h >> 27n; h = (h * 0x94d049bb133111ebn) & M64;
  h ^= h >> 31n;
  return h;
}

export function bits16(h, shift) {
  return Number((h >> BigInt(shift)) & 0xffffn) / 0xffff;
}

// 문자열 → 0…1 난수열(꽃 위치처럼 원본에 없는 장식용). 결정론적이라 다시 그려도 같은 자리에 핀다.
export function rng(seedText) {
  let s = Number(fnv1a(seedText) & 0xffffffffn) || 1;
  return () => {
    s ^= s << 13; s >>>= 0;
    s ^= s >>> 17;
    s ^= s << 5; s >>>= 0;
    return s / 4294967296;
  };
}
