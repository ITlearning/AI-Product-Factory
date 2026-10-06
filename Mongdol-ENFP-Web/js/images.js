// 사진 다루기 — 줄여서 저장(원본 대신 긴 변 1280px), 썸네일, 색 추출, 촬영 시각(EXIF).
import { symbolicColor } from './color.js';
import { loadPhoto } from './db.js';

const FULL = 1280;
const THUMB = 560;

async function decode(blob) {
  if ('createImageBitmap' in window) {
    try { return await createImageBitmap(blob, { imageOrientation: 'from-image' }); } catch { /* img 로 */ }
  }
  const url = URL.createObjectURL(blob);
  try {
    const img = new Image();
    img.decoding = 'async';
    img.src = url;
    await img.decode();
    return img;
  } finally {
    URL.revokeObjectURL(url);
  }
}

const dims = (src) => ({ w: src.naturalWidth || src.width, h: src.naturalHeight || src.height });

function scaled(src, max, quality) {
  const { w, h } = dims(src);
  const k = Math.min(1, max / Math.max(w, h));
  const c = document.createElement('canvas');
  c.width = Math.round(w * k); c.height = Math.round(h * k);
  const ctx = c.getContext('2d');
  ctx.imageSmoothingQuality = 'high';
  ctx.drawImage(src, 0, 0, c.width, c.height);
  // 메모리가 모자라면 iOS 가 null 을 준다 — 저장하기 전에 실패로 세야 「못 담았어요」와 실제가 어긋나지 않는다.
  return new Promise((res, rej) => c.toBlob((b) => (b ? res(b) : rej(new Error('toBlob null'))), 'image/jpeg', quality));
}

/** 파일·캡처 한 장 → { full, thumb, colorHex } — 색은 원본 크기에서 뽑는다(찍을 때는 안 보여 준다). */
export async function prepare(blob) {
  const src = await decode(blob);
  const { w, h } = dims(src);
  const colorHex = symbolicColor(src, w, h);
  const [full, thumb] = await Promise.all([scaled(src, FULL, 0.86), scaled(src, THUMB, 0.82)]);
  if (src.close) src.close();
  return { full, thumb, colorHex, aspect: w / h };
}

/** 이미 캔버스에 있는 그림(카메라 프레임·견본 그림) — 디코드 없이 바로. */
export async function prepareCanvas(c) {
  const colorHex = symbolicColor(c, c.width, c.height);
  const [full, thumb] = await Promise.all([scaled(c, FULL, 0.86), scaled(c, THUMB, 0.82)]);
  return { full, thumb, colorHex, aspect: c.width / c.height };
}

/** JPEG EXIF DateTimeOriginal → ms. 없으면 null. */
export async function exifDate(file) {
  try {
    const buf = new DataView(await file.slice(0, 256 * 1024).arrayBuffer());
    if (buf.getUint16(0) !== 0xffd8) return null;
    let off = 2;
    while (off + 4 < buf.byteLength) {
      const marker = buf.getUint16(off);
      const len = buf.getUint16(off + 2);
      if (marker === 0xffe1 && buf.getUint32(off + 4) === 0x45786966) return readTiff(buf, off + 10);
      if ((marker & 0xff00) !== 0xff00) break;
      off += 2 + len;
    }
  } catch { /* 날짜 없이 */ }
  return null;
}

function readTiff(v, start) {
  const little = v.getUint16(start) === 0x4949;
  const u16 = (o) => v.getUint16(start + o, little);
  const u32 = (o) => v.getUint32(start + o, little);
  const findTag = (ifd, tag) => {
    const n = u16(ifd);
    for (let i = 0; i < n; i++) {
      const e = ifd + 2 + i * 12;
      if (u16(e) === tag) return e;
    }
    return -1;
  };
  const ifd0 = u32(4);
  const exifPtr = findTag(ifd0, 0x8769);
  const read = (ifd, tag) => {
    const e = findTag(ifd, tag);
    if (e < 0) return null;
    const count = u32(e + 4), at = u32(e + 8);
    let s = '';
    for (let i = 0; i < count - 1; i++) s += String.fromCharCode(v.getUint8(start + at + i));
    return s;
  };
  const text = (exifPtr >= 0 ? read(u32(exifPtr + 8), 0x9003) : null) || read(ifd0, 0x0132);
  const m = text && text.match(/(\d{4}):(\d{2}):(\d{2}) (\d{2}):(\d{2}):(\d{2})/);
  if (!m) return null;
  const t = new Date(+m[1], +m[2] - 1, +m[3], +m[4], +m[5], +m[6]).getTime();
  return Number.isNaN(t) ? null : t;
}

// 화면에 띄울 주소 — 한 번 만든 건 다시 쓴다. 상한을 넘으면 오래된 것부터 놓는다(떠 있는 <img> 는 이미 받아 둔 그림을 그대로 쓴다).
const URL_CAP = 240;
const urls = new Map();
export async function photoURL(id, kind = 'thumb') {
  const key = `${id}:${kind}`;
  if (urls.has(key)) {
    const p = urls.get(key);
    urls.delete(key); urls.set(key, p);
    return p;
  }
  const p = loadPhoto(id).then((rec) => {
    const blob = rec && (rec[kind] || rec.thumb || rec.full);
    return blob ? URL.createObjectURL(blob) : null;
  }).catch(() => null);
  urls.set(key, p);
  // 실패(아직 저장 전·지워짐)는 붙잡아 두지 않는다 — 다음에 다시 찾게.
  p.then((u) => { if (!u && urls.get(key) === p) urls.delete(key); });
  while (urls.size > URL_CAP) {
    const [oldKey, oldP] = urls.entries().next().value;
    urls.delete(oldKey);
    oldP.then((u) => u && setTimeout(() => URL.revokeObjectURL(u), 4000));
  }
  return p;
}

export function forgetURLs() {
  for (const p of urls.values()) p.then((u) => u && URL.revokeObjectURL(u));
  urls.clear();
}

/** <img> 를 만들고 사진이 오면 채운다. */
export function photoImg(id, kind = 'thumb', className = '') {
  const img = document.createElement('img');
  img.className = className;
  img.alt = '';
  img.decoding = 'async';
  img.draggable = false;
  photoURL(id, kind).then((u) => {
    if (!u) return;
    img.src = u;
    img.addEventListener('load', () => img.classList.add('loaded'), { once: true });
  });
  return img;
}
