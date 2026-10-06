// ColorExtractor (Shared/ColorExtractor.swift) 포팅 — 어둠컷 25% + 12단계 히스토그램(채도 가중) + 이웃 합산.
const DARK_CUT = 0.25;
const SAMPLE = 96;
const L = 12;
const R = 1;

const value = (p) => Math.max(p[0], p[1], p[2]);
const saturation = (p) => {
  const mx = value(p), mn = Math.min(p[0], p[1], p[2]);
  return mx <= 0 ? 0 : (mx - mn) / mx;
};

/** 이미지(ImageBitmap·canvas·img)에서 96px 안으로 줄여 픽셀을 뽑는다. */
export function samplePixels(source, w, h) {
  const s = Math.min(SAMPLE / w, SAMPLE / h);
  const sw = Math.max(1, Math.floor(w * s)), sh = Math.max(1, Math.floor(h * s));
  const c = document.createElement('canvas');
  c.width = sw; c.height = sh;
  const ctx = c.getContext('2d', { willReadFrequently: true });
  ctx.drawImage(source, 0, 0, sw, sh);
  const d = ctx.getImageData(0, 0, sw, sh).data;
  const px = [];
  for (let i = 0; i < d.length; i += 4) px.push([d[i] / 255, d[i + 1] / 255, d[i + 2] / 255]);
  return px;
}

export function afterDarkCut(px) {
  const sorted = [...px].sort((a, b) => value(a) - value(b));
  const start = Math.floor(sorted.length * DARK_CUT);
  return sorted.slice(Math.min(start, sorted.length - 1));
}

export function histogramColors(px, count) {
  if (!px.length || count <= 0) return [];
  const bin = (p) => [Math.min(L - 1, Math.floor(p[0] * L)), Math.min(L - 1, Math.floor(p[1] * L)), Math.min(L - 1, Math.floor(p[2] * L))];
  const idx = (r, g, b) => (r * L + g) * L + b;
  const w = new Float64Array(L * L * L);
  for (const p of px) {
    const [r, g, b] = bin(p);
    w[idx(r, g, b)] += 0.35 + saturation(p);
  }
  const scored = [];
  for (let r = 0; r < L; r++) for (let g = 0; g < L; g++) for (let b = 0; b < L; b++) {
    let s = 0;
    for (let dr = -R; dr <= R; dr++) for (let dg = -R; dg <= R; dg++) for (let db = -R; db <= R; db++) {
      const rr = r + dr, gg = g + dg, bb = b + db;
      if (rr < 0 || gg < 0 || bb < 0 || rr >= L || gg >= L || bb >= L) continue;
      s += w[idx(rr, gg, bb)];
    }
    if (s > 0) scored.push({ i: idx(r, g, b), s });
  }
  scored.sort((a, b) => (a.s !== b.s ? b.s - a.s : a.i - b.i));
  const picked = [];
  const used = new Set();
  for (const cand of scored) {
    if (picked.length >= count) break;
    if (used.has(cand.i)) continue;
    const br = Math.floor(cand.i / (L * L)), bg = Math.floor(cand.i / L) % L, bb = cand.i % L;
    let n = 0, sr = 0, sg = 0, sb = 0;
    for (const p of px) {
      const [r, g, b] = bin(p);
      if (Math.abs(r - br) > R || Math.abs(g - bg) > R || Math.abs(b - bb) > R) continue;
      const k = 0.35 + saturation(p);
      sr += p[0] * k; sg += p[1] * k; sb += p[2] * k; n += k;
      used.add(idx(r, g, b));
    }
    if (n > 0) picked.push([sr / n, sg / n, sb / n]);
  }
  return picked;
}

export const toHex = (c) => '#' + c.map((v) => Math.round(v * 255).toString(16).padStart(2, '0')).join('').toUpperCase();

export function symbolicColor(source, w, h) {
  const kept = afterDarkCut(samplePixels(source, w, h));
  if (!kept.length) return '#808080';
  const c = histogramColors(kept, 1)[0];
  return c ? toHex(c) : '#808080';
}
