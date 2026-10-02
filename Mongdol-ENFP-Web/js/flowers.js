// 꽃·꽃잎·반짝이·컨페티 — 전부 SVG/캔버스로 그린다(이미지 파일 없음).
import { rng } from './hash.js';

export const PETAL_COLORS = ['#FF8FB1', '#FFB38A', '#FFD84D', '#B9A6FF', '#8FD9B6', '#8CCBFF', '#FF9EC7', '#FFF4D6'];
const CENTERS = ['#FFD84D', '#FFB84D', '#FFF1A8', '#FF9E7A'];

export const reduceMotion = () => {
  try { return matchMedia('(prefers-reduced-motion: reduce)').matches; } catch { return false; }
};

export function flowerSVG({ size = 22, kind = 'five', color = '#FF8FB1', center = '#FFD84D', rot = 0 } = {}) {
  const c = size / 2;
  if (kind === 'spark') {
    const r = c * 0.95, k = r * 0.22;
    return `<svg width="${size}" height="${size}" viewBox="0 0 ${size} ${size}" aria-hidden="true"><path transform="rotate(${rot} ${c} ${c})" d="M${c} ${c - r} C${c + k} ${c - k} ${c + k} ${c - k} ${c + r} ${c} C${c + k} ${c + k} ${c + k} ${c + k} ${c} ${c + r} C${c - k} ${c + k} ${c - k} ${c + k} ${c - r} ${c} C${c - k} ${c - k} ${c - k} ${c - k} ${c} ${c - r}Z" fill="${color}"/></svg>`;
  }
  const n = kind === 'daisy' ? 9 : 5;
  const pr = kind === 'daisy' ? size * 0.13 : size * 0.21;
  const pl = kind === 'daisy' ? size * 0.25 : size * 0.22;
  const dist = kind === 'daisy' ? size * 0.25 : size * 0.22;
  let petals = '';
  for (let i = 0; i < n; i++) {
    const a = rot + (360 / n) * i;
    petals += `<ellipse cx="${c}" cy="${c - dist}" rx="${pr}" ry="${pl}" transform="rotate(${a} ${c} ${c})" fill="${color}"/>`;
  }
  return `<svg width="${size}" height="${size}" viewBox="0 0 ${size} ${size}" aria-hidden="true">${petals}<circle cx="${c}" cy="${c}" r="${size * 0.14}" fill="${center}"/><circle cx="${c - size * 0.04}" cy="${c - size * 0.04}" r="${size * 0.05}" fill="#fff" opacity="0.7"/></svg>`;
}

export function flowerEl(opts = {}) {
  const el = document.createElement('span');
  el.className = `flower ${opts.className || ''}`.trim();
  el.innerHTML = flowerSVG(opts);
  return el;
}

/** 조약돌 둘레에 꽃이 피어 있다 — 날짜로 자리를 정해서 다시 그려도 같은 자리에 핀다. */
export function bloomAround(host, seedText, { count = 3, spread = 1, size = [14, 22] } = {}) {
  const rand = rng(seedText);
  const spots = [[-0.18, 0.86], [0.98, 0.72], [0.9, 0.08], [0.02, 0.1], [0.5, 1.02], [1.08, 0.4]];
  const order = spots.map((s, i) => [s, rand()]).sort((a, b) => a[1] - b[1]).slice(0, count);
  order.forEach(([[x, y]], i) => {
    const s = size[0] + rand() * (size[1] - size[0]);
    const kind = rand() < 0.3 ? 'spark' : rand() < 0.5 ? 'daisy' : 'five';
    const color = kind === 'spark' ? '#FFD84D' : PETAL_COLORS[Math.floor(rand() * PETAL_COLORS.length)];
    const f = flowerEl({ size: s, kind, color, center: CENTERS[Math.floor(rand() * CENTERS.length)], rot: rand() * 70 });
    f.classList.add('bloom');
    f.style.left = `${(x * spread + (1 - spread) / 2) * 100}%`;
    f.style.top = `${y * 100}%`;
    f.style.setProperty('--d', `${0.08 + i * 0.12}s`);
    f.style.setProperty('--sway', `${2.6 + rand() * 1.8}s`);
    host.append(f);
  });
}

/** 톡 — 한 점에서 꽃과 반짝이가 튀어 오른다. */
export function burst(host, x, y, { count = 9, distance = 70, sizes = [12, 22] } = {}) {
  if (reduceMotion()) count = Math.min(count, 4);
  for (let i = 0; i < count; i++) {
    const a = (Math.PI * 2 * i) / count + Math.random() * 0.5;
    const d = distance * (0.6 + Math.random() * 0.6);
    const s = sizes[0] + Math.random() * (sizes[1] - sizes[0]);
    const kind = i % 3 === 0 ? 'spark' : i % 3 === 1 ? 'five' : 'daisy';
    const color = kind === 'spark' ? '#FFD84D' : PETAL_COLORS[i % PETAL_COLORS.length];
    const f = flowerEl({ size: s, kind, color, rot: Math.random() * 90 });
    f.classList.add('burst');
    f.style.left = `${x - s / 2}px`;
    f.style.top = `${y - s / 2}px`;
    host.append(f);
    const dx = Math.cos(a) * d, dy = Math.sin(a) * d - 18;
    const spin = (Math.random() - 0.5) * 240;
    const anim = f.animate([
      { transform: 'translate(0,0) scale(0.2) rotate(0deg)', opacity: 0 },
      { transform: `translate(${dx * 0.7}px, ${dy * 0.7}px) scale(1.15) rotate(${spin * 0.6}deg)`, opacity: 1, offset: 0.35 },
      { transform: `translate(${dx}px, ${dy + 26}px) scale(0.9) rotate(${spin}deg)`, opacity: 0 },
    ], { duration: 900 + Math.random() * 400, easing: 'cubic-bezier(.2,.8,.3,1)' });
    anim.onfinish = () => f.remove();
  }
}

/** 꽃잎이 천천히 흩날린다 — 멈추는 함수를 돌려준다. */
export function petalRain(host, { count = 10, seed = 'petals' } = {}) {
  if (reduceMotion()) count = 0;
  const rand = rng(seed);
  const els = [];
  for (let i = 0; i < count; i++) {
    const p = document.createElement('span');
    p.className = 'petal';
    const s = 9 + rand() * 9;
    const color = PETAL_COLORS[Math.floor(rand() * 7)];
    p.innerHTML = `<svg width="${s}" height="${s}" viewBox="0 0 10 10" aria-hidden="true"><path d="M5 0 C8.5 2 9 6.5 5 10 C1 6.5 1.5 2 5 0Z" fill="${color}"/></svg>`;
    p.style.left = `${rand() * 100}%`;
    p.style.setProperty('--dur', `${9 + rand() * 9}s`);
    p.style.setProperty('--delay', `${-rand() * 16}s`);
    p.style.setProperty('--drift', `${(rand() - 0.5) * 120}px`);
    p.style.setProperty('--spin', `${(rand() < 0.5 ? -1 : 1) * (180 + rand() * 360)}deg`);
    host.append(p);
    els.push(p);
  }
  return () => els.forEach((e) => e.remove());
}

/** 증정 컨페티 — 가운데서 터져 중력으로 떨어진다. */
export function confetti(canvas, { originY = 0.42, count = 90 } = {}) {
  if (reduceMotion()) return () => {};
  const dpr = Math.min(2, window.devicePixelRatio || 1);
  const W = canvas.clientWidth, H = canvas.clientHeight;
  canvas.width = W * dpr; canvas.height = H * dpr;
  const ctx = canvas.getContext('2d');
  ctx.scale(dpr, dpr);
  const parts = Array.from({ length: count }, (_, i) => {
    const a = -Math.PI / 2 + (Math.random() - 0.5) * Math.PI * 1.5;
    const v = 260 + Math.random() * 380;
    return {
      x: W / 2 + (Math.random() - 0.5) * 30, y: H * originY,
      vx: Math.cos(a) * v, vy: Math.sin(a) * v,
      r: 3 + Math.random() * 4, rot: Math.random() * 6, vr: (Math.random() - 0.5) * 10,
      color: PETAL_COLORS[i % PETAL_COLORS.length], shape: i % 4, life: 0,
    };
  });
  let last = performance.now(), raf = 0, alive = true;
  const step = (t) => {
    const dt = Math.min(0.033, (t - last) / 1000); last = t;
    ctx.clearRect(0, 0, W, H);
    let any = false;
    for (const p of parts) {
      p.life += dt;
      p.vy += 520 * dt; p.vx *= 0.985; p.vy *= 0.985;
      p.x += p.vx * dt; p.y += p.vy * dt; p.rot += p.vr * dt;
      if (p.y > H + 20) continue;
      any = true;
      ctx.save();
      ctx.globalAlpha = Math.max(0, 1 - Math.max(0, p.life - 2.2) / 0.8);
      ctx.translate(p.x, p.y); ctx.rotate(p.rot);
      ctx.fillStyle = p.color;
      if (p.shape === 0) ctx.fillRect(-p.r, -p.r * 0.5, p.r * 2, p.r);
      else if (p.shape === 1) { ctx.beginPath(); ctx.arc(0, 0, p.r * 0.8, 0, Math.PI * 2); ctx.fill(); }
      else if (p.shape === 2) { ctx.beginPath(); ctx.ellipse(0, 0, p.r * 0.55, p.r * 1.1, 0, 0, Math.PI * 2); ctx.fill(); }
      else { ctx.beginPath(); for (let k = 0; k < 5; k++) { const aa = (k / 5) * Math.PI * 2; ctx.ellipse(Math.cos(aa) * p.r * 0.6, Math.sin(aa) * p.r * 0.6, p.r * 0.45, p.r * 0.45, 0, 0, Math.PI * 2); } ctx.fill(); }
      ctx.restore();
    }
    if (any && alive) raf = requestAnimationFrame(step); else ctx.clearRect(0, 0, W, H);
  };
  raf = requestAnimationFrame(step);
  return () => { alive = false; cancelAnimationFrame(raf); ctx.clearRect(0, 0, W, H); };
}

/** 배경에 흩뿌린 작은 꽃 무늬(고정) */
export function sprinkle(host, seed, count = 14) {
  const rand = rng(seed);
  for (let i = 0; i < count; i++) {
    const s = 10 + rand() * 14;
    const kind = rand() < 0.35 ? 'spark' : rand() < 0.5 ? 'daisy' : 'five';
    const f = flowerEl({ size: s, kind, color: kind === 'spark' ? '#FFD84D' : PETAL_COLORS[Math.floor(rand() * 7)], rot: rand() * 90 });
    f.classList.add('sprinkle');
    f.style.left = `${rand() * 100}%`;
    f.style.top = `${rand() * 100}%`;
    f.style.setProperty('--tw', `${3 + rand() * 4}s`);
    f.style.setProperty('--td', `${-rand() * 6}s`);
    host.append(f);
  }
}
