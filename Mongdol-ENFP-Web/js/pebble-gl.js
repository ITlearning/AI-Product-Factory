// 조약돌 렌더러 — Shared/Design/SoftPebble.metal 을 GLSL 로 옮겼다.
// WebGL 컨텍스트는 하나만 쓰고, 그린 결과는 2D 캔버스로 구워 캐시한다(조약돌마다 컨텍스트를 만들지 않는다).
import { shapeFor, PLACEHOLDER, uniformsFor, lutTable, toShaderStops, outline, outlinePath, ramp, LUT_N } from './shape.js';
import { stops as dayStops } from './day.js';

export const PEBBLE_RATIO = 0.70;   // Shape2.pebbleRatio — 바깥 프레임 폭 = 높이 × 0.70
export const SOFT_DIAMETER = 0.76;  // Shape2.softDiameter — 돌 지름 = 높이 × 0.76

// SoftPebbleView.Glow — halo·floor·contact·canvas 는 원본 채택값 그대로
export const GLOW = {
  hero: { halo: 0.6, floor: 0.65, contact: 1, canvas: 1 / 0.54, shadow: 0 },
  grid: { halo: 0.25, floor: 0.45, contact: 1, canvas: 1 / 0.66, shadow: 0 },
  photo: { halo: 0.2, floor: 0, contact: 0, canvas: 1 / 0.66, shadow: 0.35 },
};

// 밝은 배경 합성 — 원본 후광은 어두운 배경에 「더하는」 빛이라 크림색 위에선 하얗게 날아간다.
// 그래서 바깥(후광·바닥 번짐·접지 그림자)만 보통 알파 합성으로 바꾼다. 돌 표면 계산은 원본 그대로.
export const LIGHT_BG = { mode: 1, contact: 0.55, glowGain: 1.35 };

const VERT = `attribute vec2 p; void main(){ gl_Position = vec4(p, 0.0, 1.0); }`;

const FRAG = `
precision highp float;
uniform vec2 uSize;
uniform float uScale;
uniform vec4 uFrame;   // cos 기울기, sin 기울기, 달걀꼴, 돌 반지름(pt)
uniform vec4 uWob23;   // cos φ2, sin φ2, cos φ3, sin φ3
uniform vec4 uWob5;    // cos φ5, sin φ5, 바닥 x, 바닥 y
uniform vec4 uLook;    // 후광 세기, 바닥 번짐 세기, 픽셀 배율, 접지 그림자 세기
uniform vec4 uSheen;   // 반짝임 띠 중심, 반짝임 세기
uniform vec4 uBg;      // 1=밝은 배경(알파 합성) 0=원본(더하는 빛), 접지 그림자 배율, 후광 배율
uniform sampler2D uLut;

vec3 lut(float row, float t) {
  float x = clamp(t, 0.0, 1.0) * ${(LUT_N - 1).toFixed(1)};
  return texture2D(uLut, vec2((x + 0.5) / ${LUT_N.toFixed(1)}, (row + 0.5) / 3.0)).rgb;
}

float hash21(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

void main() {
  vec2 size = uSize;
  vec2 position = vec2(gl_FragCoord.x, size.y * uScale - gl_FragCoord.y) / uScale;
  vec2 fromCenter = (position - size * 0.5) / (size * 0.5);
  float window = 1.0 - smoothstep(0.72, 1.0, length(fromCenter));
  if (window <= 0.0) { gl_FragColor = vec4(0.0); return; }

  float ct = uFrame.x, st = uFrame.y, egg = uFrame.z, radius = uFrame.w;
  float haloK = uLook.x, floorK = uLook.y, px = uLook.z;
  vec2 X = (position - size * 0.5) / radius;

  float u = X.x * ct + X.y * st;
  float v = -X.x * st + X.y * ct;
  float den = 1.0 + egg * u;
  float vs = v / den;
  float ue = u / 1.04;
  float r0 = sqrt(ue * ue + vs * vs);
  float ra = sqrt(u * u + vs * vs) + 1e-6;
  float c1 = u / ra, s1 = vs / ra;
  float c2 = c1 * c1 - s1 * s1, s2 = 2.0 * s1 * c1;
  float c3 = c1 * (4.0 * c1 * c1 - 3.0), s3 = s1 * (3.0 - 4.0 * s1 * s1);
  float c5 = c2 * c3 - s2 * s3, s5 = s2 * c3 + c2 * s3;
  float wob = 1.0 + 0.012 * (c3 * uWob23.z - s3 * uWob23.w)
                  + 0.006 * (c5 * uWob5.x - s5 * uWob5.y)
                  + 0.012 * (c2 * uWob23.x - s2 * uWob23.y);
  float rho = r0 / wob;

  float alpha = clamp((1.0 - rho) * radius * px / 1.5, 0.0, 1.0);
  vec2 pix = floor(position * px);

  vec3 rgb = vec3(0.0);
  float a = 0.0;

  if (alpha < 1.0) {
    float d = max(rho - 1.0, 0.0);
    float halo = (0.34 * exp(-d * 5.0) + 0.30 * exp(-d * 1.7)) * haloK * window;
    float fx = X.x - uWob5.z, fy = X.y - uWob5.w;
    float fyn = fy / 0.22;
    float floorGlow = exp(-(fx * fx + fyn * fyn)) * 0.32 * floorK * window;
    float cx = fx / 0.55, cy = (fy + 0.02) / 0.07;
    float contact = exp(-(cx * cx + cy * cy)) * 0.85 * uLook.w;
    vec3 hc = lut(1.0, X.y * 0.45 + 0.5);
    vec3 fc = lut(0.0, 1.0);
    if (uBg.x < 0.5) {
      vec3 glow = hc * halo + fc * floorGlow;
      rgb = glow * (1.0 - contact) * (1.0 - alpha);
      a = contact * (1.0 - alpha);
    } else {
      // 밝은 바탕에서 중간 톤 후광을 그대로 얹으면 탁해진다 — 채도를 올리고 살짝 밝혀 파스텔 빛으로.
      float hl = dot(hc, vec3(0.299, 0.587, 0.114));
      vec3 hcL = mix(clamp(mix(vec3(hl), hc, 1.6), 0.0, 1.0), vec3(1.0), 0.22);
      float fl = dot(fc, vec3(0.299, 0.587, 0.114));
      vec3 fcL = clamp(mix(vec3(fl), fc, 1.3), 0.0, 1.0);
      float gh = clamp(halo * uBg.z, 0.0, 1.0);
      float gf = clamp(floorGlow * uBg.z, 0.0, 1.0);
      vec3 prem = hcL * gh * (1.0 - gf) + fcL * gf;
      float ga = 1.0 - (1.0 - gh) * (1.0 - gf);
      float ca = contact * uBg.y;
      prem = prem * (1.0 - ca) + fc * 0.22 * ca;
      ga = ga * (1.0 - ca) + ca;
      rgb = prem * (1.0 - alpha);
      a = ga * (1.0 - alpha);
    }
  }

  if (alpha > 0.0) {
    float rp = pow(max(rho, 1e-4), 1.2);
    float z = sqrt(max(1.0 - rp * rho, 0.0));

    float dvs_du = -v * egg / (den * den);
    float inv = 1.0 / (r0 * wob + 1e-6);
    float dr_du = (ue / 1.04 + vs * dvs_du) * inv;
    float dr_dv = (vs / den) * inv;
    float dz_dr = -1.1 * rp / max(z, 1e-3);
    float gx = clamp(dz_dr * (dr_du * ct - dr_dv * st), -3.0, 3.0);
    float gy = clamp(dz_dr * (dr_du * st + dr_dv * ct), -3.0, 3.0);
    vec3 n = normalize(vec3(-gx, -gy, 1.0));
    vec3 L = vec3(0.35221, -0.55347, 0.75473);
    float wrap = clamp((dot(n, L) + 0.45) / 1.45, 0.0, 1.0);

    float along = X.x * 0.309017 + X.y * 0.951057;
    vec3 col = lut(0.0, along * 0.5 + 0.5 - 0.07 * (z - 0.7));

    float lowY = clamp((X.y - 0.1) / 0.9, 0.0, 1.0);
    col *= (0.70 + 0.38 * wrap) * (1.0 - 0.20 * lowY * lowY);

    float om = max(1.0 - n.z, 0.0);
    float fres = om * om * sqrt(om);
    col += lut(2.0, X.y * 0.45 + 0.5) * (fres * clamp(wrap * 1.4 - 0.2, 0.0, 1.0) * 0.26);
    col *= 1.0 + (hash21(pix) - 0.5) * 0.055;

    if (uSheen.y > 0.0) {
      float dq = X.x * 0.93969 + X.y * 0.34202 - uSheen.x;
      col += (0.30 * exp(-dq * dq / 0.0324) + 0.07 * exp(-dq * dq / 0.25)) * uSheen.y;
    }
    if (uBg.x > 0.5) col = clamp(col, 0.0, 1.0);

    rgb += col * alpha;
    a += alpha;
  }

  float dither = (hash21(pix + 17.0) - 0.5) * (1.5 / 255.0);
  if (uBg.x > 0.5) {
    rgb = clamp(rgb + dither * a, vec3(0.0), vec3(a));
  } else {
    rgb = max(rgb + dither, vec3(0.0));
  }
  gl_FragColor = vec4(rgb, a);
}`;

class Renderer {
  constructor() {
    const canvas = document.createElement('canvas');
    canvas.width = 512; canvas.height = 512;
    const opts = { premultipliedAlpha: true, preserveDrawingBuffer: true, antialias: false, alpha: true, depth: false, stencil: false };
    const gl = canvas.getContext('webgl2', opts) || canvas.getContext('webgl', opts);
    if (!gl) throw new Error('WebGL 없음');
    this.canvas = canvas;
    this.gl = gl;
    this.version = typeof WebGL2RenderingContext !== 'undefined' && gl instanceof WebGL2RenderingContext ? 2 : 1;
    const prog = gl.createProgram();
    for (const [type, src] of [[gl.VERTEX_SHADER, VERT], [gl.FRAGMENT_SHADER, FRAG]]) {
      const sh = gl.createShader(type);
      gl.shaderSource(sh, src);
      gl.compileShader(sh);
      if (!gl.getShaderParameter(sh, gl.COMPILE_STATUS)) throw new Error('셰이더 컴파일 실패: ' + gl.getShaderInfoLog(sh));
      gl.attachShader(prog, sh);
    }
    gl.linkProgram(prog);
    if (!gl.getProgramParameter(prog, gl.LINK_STATUS)) throw new Error('셰이더 링크 실패: ' + gl.getProgramInfoLog(prog));
    gl.useProgram(prog);
    const buf = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, buf);
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 1, -1, -1, 1, 1, 1]), gl.STATIC_DRAW);
    const loc = gl.getAttribLocation(prog, 'p');
    gl.enableVertexAttribArray(loc);
    gl.vertexAttribPointer(loc, 2, gl.FLOAT, false, 0, 0);
    this.u = {};
    for (const n of ['uSize', 'uScale', 'uFrame', 'uWob23', 'uWob5', 'uLook', 'uSheen', 'uBg', 'uLut']) this.u[n] = gl.getUniformLocation(prog, n);
    const tex = gl.createTexture();
    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, tex);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    gl.pixelStorei(gl.UNPACK_ALIGNMENT, 1);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, LUT_N, 3, 0, gl.RGBA, gl.UNSIGNED_BYTE, new Uint8Array(LUT_N * 3 * 4));
    gl.uniform1i(this.u.uLut, 0);
    gl.disable(gl.BLEND);
    this.lastLut = null;
    this.lost = false;
    canvas.addEventListener('webglcontextlost', (e) => { e.preventDefault(); this.lost = true; });
  }

  /** 그린 영역: 캔버스 왼쪽 아래 w×h 픽셀. drawImage 소스 사각형을 돌려준다. */
  draw(spec) {
    const { gl } = this;
    const g = GLOW[spec.glow];
    const side = spec.diameter * g.canvas;
    const w = Math.max(2, Math.round(side * spec.scale));
    const scale = w / side;
    if (w > this.canvas.width || w > this.canvas.height) {
      const n = Math.min(4096, Math.max(w, this.canvas.width));
      this.canvas.width = n; this.canvas.height = n;
    }
    if (this.lastLut !== spec.lutKey) {
      gl.texSubImage2D(gl.TEXTURE_2D, 0, 0, 0, LUT_N, 3, gl.RGBA, gl.UNSIGNED_BYTE, spec.lut);
      this.lastLut = spec.lutKey;
    }
    const un = uniformsFor(spec.shape, spec.diameter / 2);
    gl.viewport(0, 0, w, w);
    gl.clearColor(0, 0, 0, 0);
    gl.clear(gl.COLOR_BUFFER_BIT);
    gl.uniform2f(this.u.uSize, side, side);
    gl.uniform1f(this.u.uScale, scale);
    gl.uniform4fv(this.u.uFrame, un.frame);
    gl.uniform4fv(this.u.uWob23, un.wob23);
    gl.uniform4fv(this.u.uWob5, un.wob5);
    gl.uniform4f(this.u.uLook, g.halo, g.floor, scale, g.contact);
    const s = spec.sheen || 0;
    const amount = s > 0 && s < 1 ? Math.min(1, Math.min(s, 1 - s) / 0.2) : 0;
    gl.uniform4f(this.u.uSheen, -1.3 + 2.6 * s, amount, 0, 0);
    const bg = spec.bg || LIGHT_BG;
    gl.uniform4f(this.u.uBg, bg.mode, bg.contact, bg.glowGain, 0);
    gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
    return { src: this.canvas, sx: 0, sy: this.canvas.height - w, w, h: w, side };
  }
}

let renderer = null;
let rendererFailed = false;
let failedAt = 0;
const RETRY_MS = 5000; // 컨텍스트를 잃은 직후엔 새로 못 만들 수 있다 — 영원히 2D 로 두지 말고 잠시 뒤 다시 본다.
export function getRenderer() {
  if (renderer && !renderer.lost) return renderer;
  if (rendererFailed && performance.now() - failedAt < RETRY_MS) return null;
  try {
    renderer = new Renderer();
    rendererFailed = false;
  } catch (e) {
    if (!rendererFailed) console.warn('[몽돌] WebGL 조약돌을 못 켜서 2D 로 그려요:', e.message);
    rendererFailed = true; failedAt = performance.now(); renderer = null;
  }
  return renderer;
}
export const rendererInfo = () => (renderer ? `webgl${renderer.version}` : rendererFailed ? '2d-fallback' : 'not-started');

const lutCache = new Map();
function lutFor(shaderStops) {
  const key = shaderStops.map((s) => `${s.loc.toFixed(4)}:${s.rgb.map((v) => v.toFixed(3)).join(',')}`).join('|');
  let lut = lutCache.get(key);
  if (!lut) {
    lut = lutTable(shaderStops);
    if (lutCache.size > 300) lutCache.clear();
    lutCache.set(key, lut);
  }
  return { lut, key };
}

export const pixelScale = () => Math.min(3, Math.max(1, window.devicePixelRatio || 1));

/** moments(그날 조약돌에 든 순간들) + dayKey → 그리기 명세 */
export function specFor({ moments, dayKey, height, glow = 'grid', shape }) {
  const st = toShaderStops(dayStops(moments || []));
  const { lut, key } = lutFor(st);
  return {
    shape: shape || shapeFor(dayKey || (moments && moments[0]?.dayKey) || '2026-01-01'),
    shaderStops: st,
    lut, lutKey: key,
    diameter: height * SOFT_DIAMETER,
    glow,
    scale: pixelScale(),
    dayKey,
  };
}

const bakeCache = new Map();
function cacheKey(spec) {
  const s = spec.shape;
  return `${s.tilt.toFixed(5)}|${s.egg.toFixed(5)}|${s.wa}|${s.wb}|${s.wc}|${spec.lutKey}|${spec.diameter.toFixed(2)}|${spec.glow}|${spec.scale}`;
}

function blit(spec, sheen) {
  const r = getRenderer();
  const g = GLOW[spec.glow];
  const side = spec.diameter * g.canvas;
  const w = Math.max(2, Math.round(side * spec.scale));
  const out = document.createElement('canvas');
  out.width = w; out.height = w;
  const ctx = out.getContext('2d');
  if (r) {
    const d = r.draw({ ...spec, sheen });
    if (g.shadow > 0) {
      ctx.shadowColor = `rgba(70, 36, 50, ${g.shadow})`;
      ctx.shadowBlur = 6 * spec.scale;
      ctx.shadowOffsetY = 3 * spec.scale;
    }
    ctx.drawImage(d.src, d.sx, d.sy, d.w, d.h, 0, 0, w, w);
  } else {
    paint2D(ctx, spec, w);
  }
  return out;
}

/** 캐시된 조약돌(2D 캔버스). 같은 날·같은 크기는 한 번만 그린다. */
export function bakedPebble(spec) {
  const key = cacheKey(spec);
  let c = bakeCache.get(key);
  if (c) { bakeCache.delete(key); bakeCache.set(key, c); return c; }
  c = blit(spec, 0);
  bakeCache.set(key, c);
  if (bakeCache.size > 180) bakeCache.delete(bakeCache.keys().next().value);
  return c;
}

/** 증정 세리머니처럼 반짝임 띠가 움직이는 동안 — 캐시 없이 매 프레임 그 자리에 그린다. */
export function drawLive(targetCanvas, spec, sheen) {
  const r = getRenderer();
  const g = GLOW[spec.glow];
  const w = Math.max(2, Math.round(spec.diameter * g.canvas * spec.scale));
  if (targetCanvas.width !== w) { targetCanvas.width = w; targetCanvas.height = w; }
  const ctx = targetCanvas.getContext('2d');
  ctx.clearRect(0, 0, w, w);
  if (!r) { paint2D(ctx, spec, w); return; }
  const d = r.draw({ ...spec, sheen });
  ctx.drawImage(d.src, d.sx, d.sy, d.w, d.h, 0, 0, w, w);
}

/** WebGL 이 없을 때 — 윤곽·띠·빛만 흉내 낸다. */
function paint2D(ctx, spec, w) {
  const g = GLOW[spec.glow];
  const side = spec.diameter * g.canvas;
  const k = w / side;
  const r = (spec.diameter / 2) * k;
  const c = w / 2;
  const st = spec.shaderStops;
  const rgb = (t) => ramp(st, t).map((v) => Math.round(v * 255)).join(',');
  const halo = ctx.createRadialGradient(c, c, r * 0.8, c, c, r * 1.6);
  halo.addColorStop(0, `rgba(${rgb(0.5)},${0.4 * g.halo * 1.35})`);
  halo.addColorStop(1, `rgba(${rgb(0.5)},0)`);
  ctx.fillStyle = halo;
  ctx.fillRect(0, 0, w, w);
  const pts = outline(spec.shape, 96);
  ctx.save();
  ctx.beginPath();
  pts.forEach(([x, y], i) => (i ? ctx.lineTo(c + x * r, c + y * r) : ctx.moveTo(c + x * r, c + y * r)));
  ctx.closePath();
  ctx.clip();
  const lin = ctx.createLinearGradient(c - r * 0.31, c - r * 0.95, c + r * 0.31, c + r * 0.95);
  for (let i = 0; i <= 8; i++) lin.addColorStop(i / 8, `rgb(${rgb(i / 8)})`);
  ctx.fillStyle = lin;
  ctx.fillRect(0, 0, w, w);
  const hi = ctx.createRadialGradient(c - r * 0.3, c - r * 0.45, 0, c - r * 0.3, c - r * 0.45, r * 1.1);
  hi.addColorStop(0, 'rgba(255,255,255,0.28)');
  hi.addColorStop(1, 'rgba(255,255,255,0)');
  ctx.fillStyle = hi;
  ctx.fillRect(0, 0, w, w);
  const lo = ctx.createRadialGradient(c, c + r * 1.1, 0, c, c + r * 1.1, r * 1.2);
  lo.addColorStop(0, 'rgba(0,0,0,0.3)');
  lo.addColorStop(1, 'rgba(0,0,0,0)');
  ctx.fillStyle = lo;
  ctx.fillRect(0, 0, w, w);
  ctx.restore();
}

// ── DOM ──────────────────────────────────────────────

const queue = [];
let pumping = false;
function pump() {
  pumping = true;
  const t0 = performance.now();
  while (queue.length && performance.now() - t0 < 10) {
    const job = queue.shift();
    if (job.el.isConnected) paintInto(job.el, job.spec);
  }
  if (queue.length) requestAnimationFrame(pump); else pumping = false;
}

function paintInto(el, spec) {
  const baked = bakedPebble(spec);
  const cv = el.querySelector('canvas');
  if (!cv) return;
  cv.width = baked.width; cv.height = baked.height;
  cv.getContext('2d').drawImage(baked, 0, 0);
  el.classList.add('painted');
}

const io = typeof IntersectionObserver !== 'undefined'
  ? new IntersectionObserver((entries) => {
    for (const e of entries) {
      if (!e.isIntersecting) continue;
      io.unobserve(e.target);
      const spec = e.target._spec;
      if (!spec) continue;
      queue.push({ el: e.target, spec });
    }
    if (queue.length && !pumping) requestAnimationFrame(pump);
  }, { rootMargin: '700px 0px' })
  : null;

/**
 * PebbleView 와 같은 바깥 프레임(폭 H×0.70, 높이 H×1.16) — 캔버스는 가운데서 후광 자리만큼 넘친다.
 * lazy=false 면 바로 그린다(증정·상세처럼 한 개뿐일 때).
 */
export function pebbleNode({ moments, dayKey, height, glow = 'grid', lazy = true, className = '' }) {
  const spec = specFor({ moments, dayKey, height, glow });
  const side = spec.diameter * GLOW[glow].canvas;
  const el = document.createElement('div');
  el.className = `pebble ${className}`.trim();
  el.style.width = `${height * PEBBLE_RATIO}px`;
  el.style.height = `${height * 1.16}px`;
  const cv = document.createElement('canvas');
  cv.className = 'pebble-canvas';
  cv.style.width = `${side}px`;
  cv.style.height = `${side}px`;
  cv.setAttribute('aria-hidden', 'true');
  el.append(cv);
  el._spec = spec;
  if (!lazy || !io) paintInto(el, spec);
  else io.observe(el);
  return el;
}

/** 점선 조약돌 — 아직 색이 없는 자리. */
export function dashedPebbleNode(height, { className = '' } = {}) {
  const d = height * SOFT_DIAMETER;
  const el = document.createElement('div');
  el.className = `pebble dashed ${className}`.trim();
  el.style.width = `${height * PEBBLE_RATIO}px`;
  el.style.height = `${height * 1.16}px`;
  const pad = 2;
  const path = outlinePath(PLACEHOLDER, d / 2 - 1, d / 2 + pad, d / 2 + pad);
  // 윤곽은 반지름의 최대 1.13배까지 나간다(원본 SoftPebbleOutline 도 프레임 밖으로 그린다) — 잘리지 않게 overflow 를 연다.
  const sp = Math.max(5, d * 0.09);
  el.innerHTML = `<svg class="dashed-svg" width="${d + pad * 2}" height="${d + pad * 2}" viewBox="0 0 ${d + pad * 2} ${d + pad * 2}" overflow="visible" aria-hidden="true">
    <path d="${path}" fill="rgba(255,255,255,0.45)" stroke="currentColor" stroke-width="1.4" stroke-dasharray="5 5" stroke-linecap="round"/>
    <g transform="translate(${d / 2 + pad} ${d / 2 + pad})"><g class="dashed-spark">
      <path d="M0 ${-sp} C${sp * 0.15} ${-sp * 0.3} ${sp * 0.3} ${-sp * 0.15} ${sp} 0 C${sp * 0.3} ${sp * 0.15} ${sp * 0.15} ${sp * 0.3} 0 ${sp} C${-sp * 0.15} ${sp * 0.3} ${-sp * 0.3} ${sp * 0.15} ${-sp} 0 C${-sp * 0.3} ${-sp * 0.15} ${-sp * 0.15} ${-sp * 0.3} 0 ${-sp}Z" fill="currentColor" opacity="0.55"/>
    </g></g>
  </svg>`;
  return el;
}

/** 로드 시 셰이더를 한 번 구워 둔다 — 첫 조약돌에서 컴파일로 끊기지 않게. */
export function warmUp() {
  const r = getRenderer();
  if (r) r.draw({ ...specFor({ moments: [], dayKey: '2026-01-01', height: 10 }), sheen: 0 });
}
