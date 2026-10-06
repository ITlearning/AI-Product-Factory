// SoftPebbleShape · SoftPebbleUniforms (Shared/Design/SoftPebbleView.swift) 포팅.
// 윤곽 식을 바꾸면 pebble-gl.js 의 셰이더도 같이 바꾼다.
import { silhouetteSeed, byteAt } from './hash.js';

export const LUT_N = 128;

export function shapeFor(dayKey) {
  const h = silhouetteSeed(dayKey);
  const pick = (s) => byteAt(h, s);
  // 넓은 쪽이 아래로 오게 — 오른쪽 아래 또는 왼쪽 아래
  const mirrored = ((h >> 32n) & 1n) === 1n;
  const deg = mirrored ? 125 + pick(40) * 70 : -15 + pick(40) * 70;
  return { tilt: (deg * Math.PI) / 180, egg: 0.12 + pick(48) * 0.16, wa: pick(8), wb: pick(16), wc: pick(24) };
}

/** 색 없는 자리(점선 조약돌) — 아이콘과 같은 기울기. */
export const PLACEHOLDER = { tilt: (32 * Math.PI) / 180, egg: 0.22, wa: 0.3, wb: 0.6, wc: 0.4 };

export function rho(s, x, y) {
  const u = x * Math.cos(s.tilt) + y * Math.sin(s.tilt);
  const v = -x * Math.sin(s.tilt) + y * Math.cos(s.tilt);
  const vs = v / (1 + s.egg * u);
  const th = Math.atan2(vs, u);
  const wob = 1 + 0.012 * Math.cos(3 * th + s.wa * 6.3) + 0.006 * Math.cos(5 * th + s.wb * 6.3)
    + 0.012 * Math.cos(2 * th + s.wc * 6.3);
  return Math.sqrt((u / 1.04) ** 2 + vs * vs) / wob;
}

/** 반지름 1 좌표계의 윤곽 점들(각도 순서). */
export function outline(s, n = 120) {
  const pts = [];
  for (let i = 0; i < n; i++) {
    const phi = (i / n) * 2 * Math.PI;
    const dx = Math.cos(phi), dy = Math.sin(phi);
    let lo = 0, hi = 2;
    for (let k = 0; k < 22; k++) {
      const mid = (lo + hi) / 2;
      if (rho(s, dx * mid, dy * mid) < 1) lo = mid; else hi = mid;
    }
    pts.push([dx * lo, dy * lo]);
  }
  return pts;
}

/** 윤곽의 가장 낮은 점(y)과 면적 중심(x) — 바닥 번짐·접지 그림자가 여기 붙는다. */
export function floorAnchor(s) {
  const pts = outline(s, 180);
  let area = 0, cx = 0, bottom = -Infinity;
  for (let i = 0; i < pts.length; i++) {
    const [x0, y0] = pts[i], [x1, y1] = pts[(i + 1) % pts.length];
    const cross = x0 * y1 - x1 * y0;
    area += cross;
    cx += (x0 + x1) * cross;
    bottom = Math.max(bottom, y0);
  }
  return { x: area === 0 ? 0 : cx / (3 * area), y: bottom };
}

/** 윤곽을 SVG path 로 — 반지름 r, 중심 (cx, cy). */
export function outlinePath(s, r, cx, cy) {
  const pts = outline(s, 96);
  return pts.map(([x, y], i) => `${i ? 'L' : 'M'}${(cx + x * r).toFixed(2)} ${(cy + y * r).toFixed(2)}`).join('') + 'Z';
}

const anchorCache = new Map();
export function uniformsFor(s, radius) {
  const key = `${s.tilt}|${s.egg}|${s.wa}|${s.wb}|${s.wc}`;
  let a = anchorCache.get(key);
  if (!a) { a = floorAnchor(s); anchorCache.set(key, a); }
  const p2 = s.wc * 6.3, p3 = s.wa * 6.3, p5 = s.wb * 6.3;
  return {
    frame: [Math.cos(s.tilt), Math.sin(s.tilt), s.egg, radius],
    wob23: [Math.cos(p2), Math.sin(p2), Math.cos(p3), Math.sin(p3)],
    wob5: [Math.cos(p5), Math.sin(p5), a.x, a.y],
  };
}

/** stops: [{ loc, rgb:[r,g,b] }] — 정지점 사이는 smoothstep 으로(레퍼런스와 같게). */
export function ramp(stops, t) {
  t = Math.min(1, Math.max(0, t));
  if (stops.length < 2 || t <= stops[0].loc) return stops[0].rgb;
  for (let i = 0; i < stops.length - 1; i++) {
    if (t <= stops[i + 1].loc) {
      let u = (t - stops[i].loc) / Math.max(1e-5, stops[i + 1].loc - stops[i].loc);
      u = u * u * (3 - 2 * u);
      const a = stops[i].rgb, b = stops[i + 1].rgb;
      return [a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u, a[2] + (b[2] - a[2]) * u];
    }
  }
  return stops[stops.length - 1].rgb;
}

const lighten = (c, k) => c.map((v) => v + (1 - v) * k);

/** 3줄 × LUT_N × RGBA8 — 0 띠 색, 1 후광 색(넓게 흐리고 10% 밝게), 2 테두리 빛 색(35% 밝게). */
export function lutTable(stops) {
  const out = new Uint8Array(3 * LUT_N * 4);
  const put = (row, i, c) => {
    const k = (row * LUT_N + i) * 4;
    out[k] = Math.round(Math.min(1, Math.max(0, c[0])) * 255);
    out[k + 1] = Math.round(Math.min(1, Math.max(0, c[1])) * 255);
    out[k + 2] = Math.round(Math.min(1, Math.max(0, c[2])) * 255);
    out[k + 3] = 255;
  };
  for (let i = 0; i < LUT_N; i++) {
    const t = i / (LUT_N - 1);
    const acc = [0, 0, 0];
    let wsum = 0;
    for (let j = -3; j <= 3; j++) {
      const o = j * 0.1;
      const w = Math.exp(-(o * o) / (2 * 0.2 * 0.2));
      const c = ramp(stops, t + o);
      acc[0] += c[0] * w; acc[1] += c[1] * w; acc[2] += c[2] * w;
      wsum += w;
    }
    put(0, i, ramp(stops, t));
    put(1, i, lighten(acc.map((v) => v / wsum), 0.1));
    put(2, i, lighten(ramp(stops, t), 0.35));
  }
  return out;
}

export function hexToRgb(hex) {
  const t = hex.replace('#', '');
  if (t.length !== 6) return [0.5, 0.5, 0.5];
  const v = parseInt(t, 16);
  return [((v >> 16) & 255) / 255, ((v >> 8) & 255) / 255, (v & 255) / 255];
}

/** DayGradient.Stop[] → 셰이더용. 비면 원본처럼 중성 회색 하나. */
export function toShaderStops(stops) {
  if (!stops.length) return [{ loc: 0, rgb: [0.35, 0.35, 0.36] }];
  return stops.map((s) => ({ loc: s.loc, rgb: hexToRgb(s.hex) }));
}
