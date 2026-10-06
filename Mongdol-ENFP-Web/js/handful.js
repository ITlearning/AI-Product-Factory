// 한 달 한 줌(HandfulView.swift) — 그 달 받은 돌들이 한 손 안에 모인다. 격자가 아니다.
import { h, layers, layerRoot, closePill } from './dom.js';
import { store } from './store.js';
import { pebbleNode } from './pebble-gl.js';
import * as D from './day.js';
import { T } from './copy.js';
import { flowerEl, PETAL_COLORS, petalRain } from './flowers.js';
import { cheerPebble } from './home.js';
import { animateSpring } from './motion.js';
import { openHandfulKeepsake, shareIcon } from './keepsake.js';

// 돌마다 제 색으로 은은하게 — 여러 색을 한 원에 섞으면 가운데가 잿빛이 된다.
function glowOf(groups, placements, side, w, hh) {
  if (!groups.length) return 'transparent';
  return groups.map((g, i) => {
    const p = placements[i];
    const hex = g.moments[g.moments.length - 1]?.colorHex || '#FFD6E4';
    const x = w / 2 + (p.x * side) / 2, y = hh / 2 + (p.y * side) / 2;
    return `radial-gradient(${side * 0.42}px ${side * 0.36}px at ${x}px ${y}px, ${hex}55, ${hex}00)`;
  }).join(', ');
}

export function openHandful(month) {
  const name = `handful:${month}`;
  layers.add(name);
  const today = store.todayKey;
  const days = store.finishedDayKeys.filter((k) => k.startsWith(month) && store.isGifted(k));
  const groups = days.map((k) => ({ key: k, moments: store.pebbleMoments(k) }));
  const placements = D.handfulLayout(groups.length, D.monthSeed(month));

  const hand = h('div', { class: 'handful-hand' });
  const glow = h('div', { class: 'handful-glow' });
  const petals = h('div', { class: 'cer-petals', 'aria-hidden': 'true' });
  const view = h('section', { class: 'handful', role: 'dialog', 'aria-modal': 'true', 'aria-label': D.handfulTitle(month, today) },
    glow,
    petals,
    hand,
    h('div', { class: 'handful-top' }, closePill(() => close())),
    groups.length ? h('button', { class: 'share-btn handful-share', 'aria-label': '한 줌 카드 건네기', onClick: () => openHandfulKeepsake(month) }, shareIcon(), '건네기') : null,
    h('div', { class: 'handful-words' },
      h('p', { class: 'handful-title' }, D.handfulTitle(month, today)),
      h('p', { class: 'handful-line' }, T.handfulOpen)));
  layerRoot().append(view);
  const stopPetals = petalRain(petals, { count: 8, seed: `hand:${month}` });

  const layout = () => {
    hand.replaceChildren();
    const w = view.clientWidth, hh = view.clientHeight;
    const side = Math.min(w, hh) * 0.62;
    glow.style.background = glowOf(groups, placements, side, w, hh);
    // 꽃 화관 — 한 손 둘레
    const n = 14;
    for (let i = 0; i < n; i++) {
      const a = (i / n) * Math.PI * 2;
      const r = side / 2 + 46;
      const size = 16 + (i % 3) * 5;
      const kind = i % 4 === 0 ? 'spark' : i % 2 ? 'five' : 'daisy';
      const f = flowerEl({ size, kind, color: kind === 'spark' ? '#FFD84D' : PETAL_COLORS[i % 7], rot: i * 17 });
      f.classList.add('wreath');
      f.style.left = `calc(50% + ${Math.cos(a) * r - size / 2}px)`;
      f.style.top = `calc(50% + ${Math.sin(a) * r - size / 2}px)`;
      hand.append(f);
      animateSpring(f, (p) => ({ transform: `scale(${p})`, opacity: Math.min(1, p * 2) }), { response: 0.5, damping: 0.6, delay: 0.25 + i * 0.03 });
    }
    placements.forEach((p, i) => {
      const g = groups[i];
      const spot = h('div', { class: 'handful-spot', style: { left: `calc(50% + ${(p.x * side) / 2}px)`, top: `calc(50% + ${(p.y * side) / 2}px)` } },
        pebbleNode({ moments: g.moments, dayKey: g.key, height: 100 * p.scale, glow: 'grid', lazy: false }));
      spot.addEventListener('click', (e) => cheerPebble(spot, e));
      hand.append(spot);
      animateSpring(spot, (q) => ({ transform: `translate(-50%, -50%) translateY(${(1 - q) * -60}px) scale(${0.4 + 0.6 * q})`, opacity: Math.min(1, q * 1.5) }),
        { response: 0.6, damping: 0.72, delay: 0.05 + i * 0.05 });
    });
  };
  const close = () => {
    view.classList.remove('in');
    setTimeout(() => { stopPetals(); view.remove(); layers.remove(name); }, 300);
  };
  requestAnimationFrame(() => { view.classList.add('in'); layout(); });
}
