// 건넬 카드(PebbleCard · HandfulCard) — 360×640 판형을 캔버스에 다시 그린다. 3배면 1080×1920.
// 원본 구성(사진·조약돌 자리·글자 위계)은 그대로, 색·글꼴·꽃은 웹판 것. 장소·단어·시각은 넣지 않는다.
import { specFor, bakedPebble, GLOW, PEBBLE_RATIO } from './pebble-gl.js';
import { loadPhoto } from './db.js';
import { nameFor } from './naming.js';
import * as D from './day.js';
import { rng } from './hash.js';

export const CANVAS = { w: 360, h: 640 };
const PHOTO_AREA = { x: 28, y: 60, w: 304, h: 400 };
const FACE_ASPECT = 3 / 4;
const PEBBLE_H = 84;
const PEBBLE_INSET = { x: 56, y: 34 };
const TEXT_TOP = PHOTO_AREA.y + PHOTO_AREA.h + 20;
const PHOTO_RADIUS = 16;
const BORDER = 5;

const BASE = '#FFF4EC';
const INK1 = '#3A2830', INK2 = '#5E4652', INK3 = '#7A6170';
const SERIF = "'Nanum Myeongjo', 'AppleMyungjo', 'Batang', serif";
const SANS = "'Gowun Dodum', -apple-system, 'Apple SD Gothic Neo', 'Noto Sans KR', sans-serif";

/** 원본 비율 그대로 사진 영역 안에 가장 크게 — PebbleCardLayout.photoFrame */
export function photoFrame(aspect) {
  const a = aspect > 0 ? aspect : FACE_ASPECT;
  const w = Math.min(PHOTO_AREA.w, PHOTO_AREA.h * a);
  const h = w / a;
  return { x: PHOTO_AREA.x + (PHOTO_AREA.w - w) / 2, y: PHOTO_AREA.y + (PHOTO_AREA.h - h) / 2, w, h };
}

const photoCache = new Map();
/** 카드용 사진 — 저장된 full(긴 변 1280). 없으면 null(색 면으로). */
export function cardPhoto(id) {
  if (photoCache.has(id)) return photoCache.get(id);
  const p = loadPhoto(id).then(async (rec) => {
    const blob = rec && (rec.full || rec.thumb);
    if (!blob) return null;
    if ('createImageBitmap' in window) {
      try { return await createImageBitmap(blob); } catch { /* img 로 */ }
    }
    const url = URL.createObjectURL(blob);
    try {
      const img = new Image();
      img.src = url;
      await img.decode();
      return img;
    } finally { URL.revokeObjectURL(url); }
  }).catch(() => null);
  photoCache.set(id, p);
  while (photoCache.size > 6) photoCache.delete(photoCache.keys().next().value);
  return p;
}

// Google Fonts 한글은 글자 범위마다 나뉘어 있다 — 그릴 글자를 넘겨야 그 조각까지 받는다.
async function fontsFor(parts) {
  if (!document.fonts?.load) return;
  const jobs = parts.filter(([, text]) => text).map(([font, text]) => document.fonts.load(font, text).catch(() => null));
  await Promise.race([Promise.all(jobs), new Promise((r) => setTimeout(r, 4000))]);
}

function newCanvas(k) {
  const c = document.createElement('canvas');
  c.width = Math.round(CANVAS.w * k);
  c.height = Math.round(CANVAS.h * k);
  const ctx = c.getContext('2d');
  ctx.scale(k, k);
  ctx.imageSmoothingQuality = 'high';
  return { c, ctx };
}

function hexA(hex, a) {
  const n = parseInt(hex.slice(1), 16);
  return `rgba(${(n >> 16) & 255},${(n >> 8) & 255},${n & 255},${a})`;
}

function ellipseGlow(ctx, x, y, rx, ry, hex, a) {
  ctx.save();
  ctx.translate(x, y);
  ctx.scale(1, ry / rx);
  const g = ctx.createRadialGradient(0, 0, 0, 0, 0, rx);
  g.addColorStop(0, hexA(hex, a));
  g.addColorStop(0.55, hexA(hex, a * 0.45));
  g.addColorStop(1, hexA(hex, 0));
  ctx.fillStyle = g;
  ctx.fillRect(-rx, -rx, rx * 2, rx * 2);
  ctx.restore();
}

/** 바탕 + 그날 그라데이션 번짐(원본 blur 90 · 0.55) — 캔버스 filter 는 Safari 가 몰라 타원을 겹쳐 흉내 낸다. */
function background(ctx, moments) {
  ctx.fillStyle = BASE;
  ctx.fillRect(0, 0, CANVAS.w, CANVAS.h);
  const st = D.stops(moments);
  if (!st.length) return;
  const pick = st.length <= 5 ? st : [0, 1, 2, 3, 4].map((i) => st[Math.round((i / 4) * (st.length - 1))]);
  pick.forEach((s, i) => {
    const y = 40 + (pick.length > 1 ? s.loc : 0.5) * 560;
    const x = 180 + (i % 2 ? 70 : -70) * (pick.length > 1 ? 1 : 0);
    ellipseGlow(ctx, x, y, 300, 240, s.hex, 0.5);
  });
  // 위아래로 크림을 살짝 덮어 글자 자리가 맑게
  const veil = ctx.createLinearGradient(0, 0, 0, CANVAS.h);
  veil.addColorStop(0, 'rgba(255,244,236,0.25)');
  veil.addColorStop(0.7, 'rgba(255,244,236,0.35)');
  veil.addColorStop(1, 'rgba(255,244,236,0.6)');
  ctx.fillStyle = veil;
  ctx.fillRect(0, 0, CANVAS.w, CANVAS.h);
}

function roundRect(ctx, x, y, w, h, r) {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.arcTo(x + w, y, x + w, y + h, r);
  ctx.arcTo(x + w, y + h, x, y + h, r);
  ctx.arcTo(x, y + h, x, y, r);
  ctx.arcTo(x, y, x + w, y, r);
  ctx.closePath();
}

/** flowers.js flowerSVG 와 같은 꽃 — SVG 를 이미지로 얹으면 Safari 가 캔버스를 더럽힐 수 있어 길로 직접 그린다. */
function flower(ctx, x, y, size, { kind = 'five', color = '#FF8FB1', center = '#FFD84D', rot = 0 } = {}) {
  const c = size / 2;
  ctx.save();
  ctx.translate(x, y);
  ctx.rotate((rot * Math.PI) / 180);
  ctx.fillStyle = color;
  if (kind === 'spark') {
    const r = c * 0.95, k = r * 0.22;
    ctx.beginPath();
    ctx.moveTo(0, -r);
    ctx.bezierCurveTo(k, -k, k, -k, r, 0);
    ctx.bezierCurveTo(k, k, k, k, 0, r);
    ctx.bezierCurveTo(-k, k, -k, k, -r, 0);
    ctx.bezierCurveTo(-k, -k, -k, -k, 0, -r);
    ctx.fill();
    ctx.restore();
    return;
  }
  const n = kind === 'daisy' ? 9 : 5;
  const pr = kind === 'daisy' ? size * 0.13 : size * 0.21;
  const pl = kind === 'daisy' ? size * 0.25 : size * 0.22;
  const dist = kind === 'daisy' ? size * 0.25 : size * 0.22;
  for (let i = 0; i < n; i++) {
    ctx.save();
    ctx.rotate((Math.PI * 2 * i) / n);
    ctx.beginPath();
    ctx.ellipse(0, -dist, pr, pl, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  }
  ctx.fillStyle = center;
  ctx.beginPath(); ctx.arc(0, 0, size * 0.14, 0, Math.PI * 2); ctx.fill();
  ctx.fillStyle = 'rgba(255,255,255,0.7)';
  ctx.beginPath(); ctx.arc(-size * 0.04, -size * 0.04, size * 0.05, 0, Math.PI * 2); ctx.fill();
  ctx.restore();
}

/** PebbleView 프레임(폭 H×0.70, 높이 H×1.16)의 왼쪽 위 → 캔버스는 프레임 가운데. */
function pebble(ctx, moments, dayKey, { x, y, height, glow, k }) {
  const spec = { ...specFor({ moments, dayKey, height, glow }), scale: Math.min(4, Math.max(1, k)) };
  const baked = bakedPebble(spec);
  const side = spec.diameter * GLOW[glow].canvas;
  const cx = x + (height * PEBBLE_RATIO) / 2, cy = y + (height * 1.16) / 2;
  ctx.drawImage(baked, cx - side / 2, cy - side / 2, side, side);
}

/** 띄어쓰기 단위로 줄을 나눈다(keep-all). 넘치면 마지막 줄 끝을 … 로. */
function wrap(ctx, text, maxW, maxLines) {
  const words = text.split(/\s+/).filter(Boolean);
  const lines = [];
  let cur = '';
  for (const w of words) {
    const t = cur ? `${cur} ${w}` : w;
    if (ctx.measureText(t).width <= maxW || !cur) cur = t;
    else { lines.push(cur); cur = w; }
  }
  if (cur) lines.push(cur);
  if (lines.length <= maxLines) return lines;
  const kept = lines.slice(0, maxLines);
  let last = kept[maxLines - 1];
  while (last.length > 1 && ctx.measureText(`${last}…`).width > maxW) last = last.slice(0, -1);
  kept[maxLines - 1] = `${last}…`;
  return kept;
}

function signature(ctx, y) {
  ctx.font = `800 15px ${SERIF}`;
  ctx.fillStyle = INK3;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'alphabetic';
  ctx.fillText('몽돌', CANVAS.w / 2 + 7, y);
  const w = ctx.measureText('몽돌').width;
  flower(ctx, CANVAS.w / 2 - w / 2 - 5, y - 5.5, 11, { kind: 'five', color: '#FF8FB1', rot: 12 });
}

/**
 * 조약돌 카드 — 고른 사진 한 장 + 그날 번짐 + 사진 모서리에 걸친 조약돌, 이름·한 줄·날짜·작은 「몽돌」.
 * face 는 사진을 고른 순간. 사진이 없으면 그 순간의 색 면.
 */
export async function paintPebbleCard({ dayKey, pebbleMoments, face, k = 3 }) {
  const named = nameFor(pebbleMoments);
  const date = D.keyDateText(dayKey);
  const photo = face ? await cardPhoto(face.id) : null;
  await fontsFor([
    [`800 26px ${SERIF}`, `${named?.name || ''}몽돌`],
    [`15px ${SANS}`, `${named?.line || ''}${date}`],
  ]);
  const { c, ctx } = newCanvas(k);
  background(ctx, pebbleMoments);

  const aspect = photo ? (photo.width || photo.naturalWidth) / (photo.height || photo.naturalHeight) : FACE_ASPECT;
  const f = photoFrame(aspect);
  const rand = rng(`card:${dayKey}`);

  // 사진 — 흰 테두리 폴라로이드(웹판 사진 카드 말투) + 그림자
  ctx.save();
  ctx.shadowColor = 'rgba(140, 60, 90, 0.28)';
  ctx.shadowBlur = 28;
  ctx.shadowOffsetY = 12;
  roundRect(ctx, f.x - BORDER, f.y - BORDER, f.w + BORDER * 2, f.h + BORDER * 2, PHOTO_RADIUS + BORDER);
  ctx.fillStyle = '#FFFFFF';
  ctx.fill();
  ctx.restore();
  ctx.save();
  roundRect(ctx, f.x, f.y, f.w, f.h, PHOTO_RADIUS);
  ctx.clip();
  if (photo) ctx.drawImage(photo, f.x, f.y, f.w, f.h);
  else { ctx.fillStyle = (face || pebbleMoments[0])?.colorHex || '#FFE6DC'; ctx.fillRect(f.x, f.y, f.w, f.h); }
  ctx.restore();

  // 꽃 두 송이 — 사진 왼쪽 위 모서리에 살짝
  flower(ctx, f.x + 4, f.y + 2, 30, { kind: 'five', color: '#FF8FB1', center: '#FFD84D', rot: rand() * 60 });
  flower(ctx, f.x + 26, f.y - 9, 15, { kind: 'daisy', color: '#FFF4D6', center: '#FFB84D', rot: rand() * 60 });
  flower(ctx, f.x - 10, f.y + 26, 11, { kind: 'spark', color: '#FFD84D', rot: 8 });

  pebble(ctx, pebbleMoments, dayKey, { x: f.x + f.w - PEBBLE_INSET.x, y: f.y + f.h - PEBBLE_INSET.y, height: PEBBLE_H, glow: 'photo', k });

  ctx.textAlign = 'center';
  ctx.textBaseline = 'top';
  let y = TEXT_TOP;
  if (named) {
    ctx.font = `800 26px ${SERIF}`;
    ctx.fillStyle = INK1;
    ctx.fillText(named.name, CANVAS.w / 2, y);
    y += 26 + 10;
    ctx.font = `15px ${SANS}`;
    ctx.fillStyle = INK2;
    // 사진 모서리 아래로 삐져나온 조약돌을 비켜 가게 폭을 조금 좁힌다.
    for (const line of wrap(ctx, named.line, 240, 2)) {
      ctx.fillText(line, CANVAS.w / 2, y);
      y += 22;
    }
    y += 8;
  }
  ctx.font = `15px ${SANS}`;
  ctx.fillStyle = INK3;
  ctx.fillText(date, CANVAS.w / 2, y);

  signature(ctx, CANVAS.h - 30);
  return c;
}

/** 한 줌 카드 — 그 달 받은 돌만 한 손 안에. 사진·이름·날짜 없음. */
export async function paintHandfulCard({ month, groups, today, k = 3 }) {
  const label = D.handfulTitle(month, today);
  await fontsFor([[`700 22px ${SERIF}`, `${label}몽돌`]]);
  const { c, ctx } = newCanvas(k);
  ctx.fillStyle = BASE;
  ctx.fillRect(0, 0, CANVAS.w, CANVAS.h);
  const wash = ctx.createRadialGradient(180, 240, 20, 180, 240, 420);
  wash.addColorStop(0, '#FFFAF3');
  wash.addColorStop(0.7, '#FFEFE6');
  wash.addColorStop(1, '#FFE6EE');
  ctx.fillStyle = wash;
  ctx.fillRect(0, 0, CANVAS.w, CANVAS.h);

  const placements = D.handfulLayout(groups.length, D.monthSeed(month));
  const side = Math.min(CANVAS.w, CANVAS.h) * 0.64;
  const cx = CANVAS.w / 2, cy = 300;
  placements.forEach((p, i) => {
    const hex = groups[i].moments[groups[i].moments.length - 1]?.colorHex || '#FFD6E4';
    ellipseGlow(ctx, cx + (p.x * side) / 2, cy + (p.y * side) / 2, side * 0.42, side * 0.36, hex, 0.3);
  });

  // 꽃 화관을 다 두르지 않고 몇 송이만 — 한 손 둘레에
  const rand = rng(`handcard:${month}`);
  const kinds = [['five', '#FF8FB1'], ['daisy', '#FFF4D6'], ['spark', '#FFD84D'], ['five', '#B9A6FF'], ['spark', '#FFD84D']];
  kinds.forEach(([kind, color], i) => {
    const a = -Math.PI * 0.8 + i * 0.42 + rand() * 0.15;
    const r = side / 2 + 40;
    flower(ctx, cx + Math.cos(a) * r, cy + Math.sin(a) * r, kind === 'spark' ? 12 : 18 + rand() * 8, { kind, color, rot: rand() * 70 });
  });

  placements.forEach((p, i) => {
    const g = groups[i];
    const height = 96 * p.scale;
    pebble(ctx, g.moments, g.key, {
      x: cx + (p.x * side) / 2 - (height * PEBBLE_RATIO) / 2,
      y: cy + (p.y * side) / 2 - (height * 1.16) / 2,
      height, glow: 'grid', k,
    });
  });

  ctx.textAlign = 'center';
  ctx.textBaseline = 'alphabetic';
  ctx.font = `700 22px ${SERIF}`;
  ctx.fillStyle = INK1;
  ctx.fillText(label, CANVAS.w / 2, CANVAS.h - 30 - 15 - 34);
  signature(ctx, CANVAS.h - 30);
  return c;
}

/** canvas → PNG File. 다시 그린 그림이라 사진의 EXIF·GPS 는 따라오지 않는다. */
export function toPNG(canvas, name) {
  return new Promise((res, rej) => canvas.toBlob((b) => (b ? res(new File([b], name, { type: 'image/png' })) : rej(new Error('toBlob null'))), 'image/png'));
}
