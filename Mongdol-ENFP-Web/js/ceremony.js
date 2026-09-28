// 증정(BadgeCeremony.swift) — 이 앱의 유일한 보상. 타이밍은 원본 그대로(SPEC §6), 그 위에 꽃·컨페티를 얹었다.
//  0.15s 떠오름(자리는 스프링 0.80/0.90, 투명도는 easeOut 0.80 — 곡선을 나눈다)
//  0.95s 안착 → 표면을 빛이 한 번 훑는다(0.95s) · 1.30s 이름이 뒤따른다 · 1.90s~ 배경이 9초 주기로 숨쉰다
import { h, layers, layerRoot } from './dom.js';
import { store } from './store.js';
import { specFor, drawLive, GLOW, PEBBLE_RATIO } from './pebble-gl.js';
import { nameFor } from './naming.js';
import * as D from './day.js';
import { T } from './copy.js';
import { flowerEl, PETAL_COLORS, confetti, petalRain, reduceMotion } from './flowers.js';
import { animateSpring } from './motion.js';
import { now } from './clock.js';

const BEAT = { rise: 0.15, riseFade: 0.8, land: 0.95, sheen: 0.95, text: 1.3 };
const easeInOut = (t) => (t < 0.5 ? 2 * t * t : 1 - (-2 * t + 2) ** 2 / 2);

export function showCeremony(key, onDone) {
  layers.add('ceremony');
  const moments = store.pebbleMoments(key);
  const named = nameFor(moments);
  const H = 180; // DayBadgeView(size: 150) → PebbleView 높이 150 × 1.2
  const spec = specFor({ moments, dayKey: key, height: H, glow: 'hero' });
  const side = spec.diameter * GLOW.hero.canvas;
  const canvas = h('canvas', { class: 'pebble-canvas', style: { width: `${side}px`, height: `${side}px` } });
  drawLive(canvas, spec, 0);
  const pebble = h('div', { class: 'pebble', style: { width: `${H * PEBBLE_RATIO}px`, height: `${H * 1.16}px` } }, canvas);
  const rise = h('div', { class: 'cer-rise' }, pebble);
  const fade = h('div', { class: 'cer-fade' }, rise);
  const ring = h('div', { class: 'cer-ring', 'aria-hidden': 'true' });
  const stageEl = h('div', { class: 'cer-stage' }, ring, fade);

  const sp = D.span(moments);
  const opening = h('p', { class: 'cer-open' }, D.openingLine(key, now()));
  const text = h('div', { class: 'cer-text' },
    named ? h('h2', { class: 'cer-name' }, named.name) : null,
    named ? h('p', { class: 'cer-line' }, named.line) : null,
    h('p', { class: 'caption' }, sp ? D.dateText(sp.from) : D.keyDateText(key)),
    sp ? h('p', { class: 'caption num' }, `${D.timeText(sp.from) === D.timeText(sp.to) ? D.timeText(sp.from) : `${D.timeText(sp.from)} – ${D.timeText(sp.to)}`} · ${moments.length}개`) : null);
  const closeBtn = h('button', { class: 'btn primary cer-close' }, T.ceremonyClose);
  const glow = h('div', { class: 'cer-glow', style: { background: D.softGlow(moments) } });
  const confettiCanvas = h('canvas', { class: 'cer-confetti', 'aria-hidden': 'true' });
  const petals = h('div', { class: 'cer-petals', 'aria-hidden': 'true' });
  const root = h('div', { class: 'ceremony', role: 'dialog', 'aria-modal': 'true', 'aria-label': '조약돌이 도착했어요' },
    glow, petals, confettiCanvas,
    h('div', { class: 'cer-body' }, opening, stageEl, text),
    closeBtn);
  layerRoot().append(root);
  requestAnimationFrame(() => root.classList.add('in'));

  const timers = [];
  const at = (s, fn) => timers.push(setTimeout(fn, s * 1000));
  const rm = reduceMotion();

  // 떠오름 — 자리와 투명도를 다른 곡선으로
  animateSpring(rise, (p) => ({ transform: `translateY(${(1 - p) * 40}px) scale(${0.5 + 0.5 * p})` }), { response: 0.8, damping: 0.9, delay: BEAT.rise });
  fade.animate([{ opacity: 0 }, { opacity: 1 }], { duration: BEAT.riseFade * 1000, delay: BEAT.rise * 1000, easing: 'ease-out', fill: 'both' });
  glow.animate([{ opacity: 0 }, { opacity: 0.5 }], { duration: BEAT.riseFade * 1000, delay: BEAT.rise * 1000, easing: 'ease-out', fill: 'both' });
  opening.animate([{ opacity: 0 }, { opacity: 1 }], { duration: BEAT.riseFade * 1000, delay: BEAT.rise * 1000, easing: 'ease-out', fill: 'both' });
  animateSpring(opening, (p) => ({ transform: `translateY(${(1 - p) * 8}px)` }), { response: 0.8, damping: 0.9, delay: BEAT.rise });

  let stopConfetti = () => {};
  let stopPetals = () => {};
  let raf = 0;
  at(BEAT.land, () => {
    // 안착 촉감 — 사용자가 한 번도 누르지 않은 창에서 부르면 브라우저가 막고 콘솔에 에러를 남긴다.
    if (navigator.userActivation?.hasBeenActive) { try { navigator.vibrate?.(18); } catch { /* 없으면 그만 */ } }
    stopConfetti = confetti(confettiCanvas, { originY: 0.4 });
    bloomRing(ring, key, rm);
    // 반짝임 띠 — 매 프레임 셰이더로 다시 그린다
    const t0 = performance.now();
    const tick = (t) => {
      const p = Math.min(1, (t - t0) / (BEAT.sheen * 1000));
      drawLive(canvas, spec, easeInOut(p));
      if (p < 1) raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
  });
  text.animate([{ opacity: 0, transform: 'translateY(10px)' }, { opacity: 1, transform: 'translateY(0)' }],
    { duration: 550, delay: BEAT.text * 1000, easing: 'ease-out', fill: 'both' });
  closeBtn.animate([{ opacity: 0 }, { opacity: 1 }], { duration: 550, delay: BEAT.text * 1000, easing: 'ease-out', fill: 'both' });
  at(BEAT.land + BEAT.sheen, () => {
    if (!rm) glow.classList.add('drift');
    stopPetals = petalRain(petals, { count: 12, seed: `cer:${key}` });
  });

  let closing = false;
  closeBtn.addEventListener('click', () => {
    if (closing) return;
    closing = true;
    timers.forEach(clearTimeout);
    cancelAnimationFrame(raf);
    root.classList.remove('in');
    root.classList.add('out');
    setTimeout(() => {
      stopConfetti(); stopPetals();
      root.remove();
      onDone?.(key);
      layers.remove('ceremony');
    }, 380);
  });
  setTimeout(() => closeBtn.focus({ preventScroll: true }), (BEAT.text + 0.2) * 1000);
}

function bloomRing(ring, key, rm) {
  const n = 9;
  for (let i = 0; i < n; i++) {
    const a = -Math.PI / 2 + (i / n) * Math.PI * 2 + 0.2;
    const rx = 128, ry = 112;
    const size = 20 + (i % 3) * 6;
    const kind = i % 3 === 0 ? 'spark' : i % 3 === 1 ? 'five' : 'daisy';
    const f = flowerEl({ size, kind, color: kind === 'spark' ? '#FFD84D' : PETAL_COLORS[(i * 3) % 7], rot: i * 23 });
    f.style.left = `calc(50% + ${Math.cos(a) * rx - size / 2}px)`;
    f.style.top = `calc(50% + ${Math.sin(a) * ry - size / 2}px)`;
    ring.append(f);
    if (rm) continue;
    animateSpring(f, (p) => ({ transform: `scale(${p}) rotate(${(1 - p) * -90}deg)`, opacity: Math.min(1, p * 2) }),
      { response: 0.5, damping: 0.55, delay: 0.05 * i });
    setTimeout(() => f.classList.add('sway'), 900 + 50 * i);
  }
}
