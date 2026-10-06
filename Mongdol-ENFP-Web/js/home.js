// 홈 — HomeView.swift · DayBlock.swift · CompactDayRow.swift 를 따른다.
// 열린 하루들이 세로로 이어진다(격자·가로 스크롤 없음). 오늘은 맨 위 진행 중 블록 — 색은 숨긴다.
import { h, pickOne } from './dom.js';
import { store } from './store.js';
import { pebbleNode, dashedPebbleNode } from './pebble-gl.js';
import { photoImg } from './images.js';
import { wobbleSeed, byteAt } from './hash.js';
import { nameFor } from './naming.js';
import * as D from './day.js';
import { T, COMPLIMENTS, PEBBLE_CHEERS } from './copy.js';
import { bloomAround, burst, flowerSVG } from './flowers.js';
import { now } from './clock.js';
import { animateSpring } from './motion.js';

const BASE_W = 334;
const BASE_H = 388;

function wobble(key) {
  const hh = wobbleSeed(key);
  const pick = (s, a, b) => a + byteAt(hh, s) * (b - a);
  return { back: pick(8, 2, 3), mid: -pick(16, 1.5, 2) };
}

/** 조약돌을 톡 — 흔들리며 칭찬 한마디, 꽃이 톡 핀다. */
export function cheerPebble(spot, e) {
  e?.stopPropagation();
  const peb = spot.querySelector('.pebble');
  peb?.animate([
    { transform: 'rotate(0deg) scale(1)' }, { transform: 'rotate(-9deg) scale(1.08)' },
    { transform: 'rotate(7deg) scale(1.1)' }, { transform: 'rotate(-4deg) scale(1.04)' }, { transform: 'rotate(0deg) scale(1)' },
  ], { duration: 620, easing: 'cubic-bezier(.3,1.4,.5,1)' });
  spot.querySelector('.cheer')?.remove();
  // 말풍선이 화면 밖으로 나가지 않게 — 조약돌이 오른쪽에 있으면 오른쪽 끝에 맞춘다.
  const r = spot.getBoundingClientRect();
  const s = document.getElementById('stage').getBoundingClientRect();
  const cx = (r.left + r.width / 2 - s.left) / s.width;
  const side = cx > 0.62 ? 'to-right' : cx < 0.38 ? 'to-left' : 'to-center';
  const bubble = h('div', { class: `cheer ${side}`, role: 'status' }, pickOne(PEBBLE_CHEERS));
  spot.append(bubble);
  animateSpring(bubble, (p) => ({ transform: `translateY(${(1 - p) * 10}px) scale(${0.6 + 0.4 * p})`, opacity: Math.min(1, p * 1.4) }), { response: 0.42, damping: 0.55 });
  setTimeout(() => { bubble.classList.add('out'); setTimeout(() => bubble.remove(), 400); }, 1500);
  burst(spot, r.width / 2, r.height * 0.45, { count: 8, distance: 58 });
}

/** 하루 블록 — 겹친 사진 더미 + 우측 하단 조약돌 + 이름·날짜·개수 */
export function dayBlock({ key, moments, pebbleMoments, width, sealed = true, onOpen }) {
  const k = width / BASE_W;
  const el = h('article', { class: `day-block${sealed ? '' : ' in-progress'}`, 'data-key': key });
  const stack = h('div', { class: 'stack', style: { width: `${width}px`, height: `${BASE_H * k}px` } });
  const photos = [...moments].reverse();
  const wob = wobble(moments[0]?.dayKey || key);
  const slots = [
    { w: 314, h: 320, x: 10, y: 36, r: 14, a: 0 },
    { w: 290, h: 312, x: 20, y: 18, r: 13, a: wob.mid },
    { w: 274, h: 300, x: 32, y: 2, r: 12, a: wob.back },
  ];
  let cycle = 0;
  const cards = new Map();

  const cardFor = (m) => {
    let c = cards.get(m.id);
    if (!c) {
      c = h('div', { class: 'card' }, photoImg(m.id, 'thumb', 'card-img'), h('div', { class: 'card-shade' }));
      cards.set(m.id, c);
      stack.prepend(c);
    }
    return c;
  };

  const layout = () => {
    const visible = [];
    for (let s = 0; s < Math.min(3, photos.length); s++) visible.push(photos[(cycle + s) % photos.length]);
    for (const [id, c] of cards) if (!visible.some((m) => m.id === id)) { c.remove(); cards.delete(id); }
    visible.forEach((m, s) => {
      const g = slots[s];
      const c = cardFor(m);
      Object.assign(c.style, {
        width: `${g.w * k}px`, height: `${g.h * k}px`, left: `${g.x * k}px`, top: `${g.y * k}px`,
        borderRadius: `${g.r * k}px`, transform: `rotate(${g.a}deg)`, zIndex: String(3 - s),
        // 원본은 어둠 위라 0.66 / 0.42 로 가라앉혔다 — 밝은 바탕에선 그만큼 빼면 바래 보여서 얕게만.
        opacity: String([1, 0.92, 0.8][s]),
      });
      c.classList.toggle('front', s === 0);
      c.classList.toggle('back', s > 0);
    });
  };
  layout();

  // 앞장을 왼쪽으로 튕기면 다음 사진 — 원본 DayBlock 의 카드 넘기기
  let drag = null;
  let suppressClick = false;
  stack.addEventListener('pointerdown', (e) => {
    if (photos.length < 2) return;
    const front = stack.querySelector('.card.front');
    if (!front || !front.contains(e.target)) return;
    drag = { x: e.clientX, y: e.clientY, id: e.pointerId, active: false, front, lastX: 0, lastT: performance.now(), vx: 0 };
  });
  stack.addEventListener('pointermove', (e) => {
    if (!drag || e.pointerId !== drag.id) return;
    const dx = e.clientX - drag.x, dy = e.clientY - drag.y;
    if (!drag.active) {
      if (dx < -8 && Math.abs(dx) > Math.abs(dy) * 1.3) {
        drag.active = true;
        stack.setPointerCapture(e.pointerId);
        drag.front.style.transition = 'none';
      } else if (Math.abs(dy) > 10 || dx > 10) { drag = null; return; }
    }
    if (drag.active) {
      const x = Math.min(0, dx);
      const t = performance.now();
      drag.vx = ((x - drag.lastX) / Math.max(1, t - drag.lastT)) * 1000;
      drag.lastX = x; drag.lastT = t;
      drag.front.style.transform = `translateX(${x}px) rotate(${x / 46}deg)`;
    }
  });
  const endDrag = (e) => {
    if (!drag || e.pointerId !== drag.id) return;
    const d = drag;
    drag = null;
    if (!d.active) return;
    suppressClick = true;
    setTimeout(() => { suppressClick = false; }, 60);
    const front = d.front;
    front.style.transition = '';
    if (d.lastX < -60 || d.vx < -700) {
      const fly = front.animate([
        { transform: `translateX(${d.lastX}px) rotate(${d.lastX / 46}deg)`, opacity: 1 },
        { transform: `translateX(${-width * 1.3}px) rotate(${(-width * 1.3) / 46}deg)`, opacity: 0.6 },
      ], { duration: 280, easing: 'ease-out' });
      fly.onfinish = () => { front.style.transform = ''; cycle++; layout(); };
    } else {
      front.style.transform = 'rotate(0deg)';
    }
  };
  stack.addEventListener('pointerup', endDrag);
  stack.addEventListener('pointercancel', endDrag);

  const spot = h('div', { class: 'pebble-spot', style: { left: `${268 * k}px`, top: `${322 * k}px` } });
  if (sealed) {
    spot.append(pebbleNode({ moments: pebbleMoments, dayKey: key, height: 84 * k, glow: 'photo' }));
    bloomAround(spot, `bloom:${key}`, { count: 3 });
    spot.setAttribute('role', 'button');
    spot.setAttribute('aria-label', '조약돌 톡 건드리기');
    spot.addEventListener('click', (e) => cheerPebble(spot, e));
  } else {
    spot.append(dashedPebbleNode(84 * k));
  }
  stack.append(spot);
  el.append(stack, h('div', { style: { height: `${26 * k}px` } }));

  if (sealed) {
    const named = nameFor(pebbleMoments);
    if (named) el.append(h('h3', { class: 'day-name' }, named.name), h('div', { style: { height: `${9 * k}px` } }));
    el.append(h('p', { class: 'day-sub num' }, `${D.keyDateText(key)} · ${moments.length}개`));
  } else {
    el.append(h('p', { class: 'two-tone' }, h('span', { class: 'ink1' }, T.inProgress(moments.length)), h('span', { class: 'ink3' }, `  ·  ${T.colorLocked}`)));
  }
  el.addEventListener('click', () => { if (!suppressClick) onOpen(key); });
  return el;
}

/** 30일 지난 하루 — 조약돌 + 이름/날짜·개수 한 줄 */
export function compactRow({ key, moments, pebbleMoments, onOpen }) {
  const named = nameFor(pebbleMoments);
  const spot = h('div', { class: 'compact-spot' }, pebbleNode({ moments: pebbleMoments, dayKey: key, height: 52, glow: 'grid' }));
  spot.addEventListener('click', (e) => cheerPebble(spot, e));
  const el = h('article', { class: 'compact-row', 'data-key': key },
    spot,
    h('div', { class: 'compact-text' },
      named ? h('span', { class: 'compact-name' }, named.name) : null,
      h('span', { class: 'day-sub num' }, `${D.keyDateText(key)} · ${moments.length}개`)));
  el.addEventListener('click', () => onOpen(key));
  return el;
}

export function emptyDayBlock(width, onSample) {
  const k = width / BASE_W;
  const stack = h('div', { class: 'stack empty', style: { width: `${width}px`, height: `${BASE_H * k}px` } },
    h('div', { class: 'empty-card', style: { width: `${314 * k}px`, height: `${320 * k}px`, left: `${10 * k}px`, top: '0px', borderRadius: `${14 * k}px` } },
      h('span', { class: 'empty-flower', html: flowerSVG({ size: 46, kind: 'daisy', color: '#FFD6E4', center: '#FFE58A' }) })),
    h('div', { class: 'pebble-spot', style: { left: `${272 * k}px`, top: `${300 * k}px` } }, dashedPebbleNode(84 * k)));
  return h('div', { class: 'empty-block' },
    stack,
    h('div', { style: { height: `${26 * k}px` } }),
    h('p', { class: 'guide' }, T.firstDayLine),
    onSample ? h('button', { class: 'link-line', onClick: onSample }, T.sampleOffer) : null);
}

// ── 홈 전체 ─────────────────────────────────

export function createHome(app) {
  const scroller = document.getElementById('home');
  const pill = document.getElementById('month-pill');
  const bdA = document.getElementById('bd-a'), bdB = document.getElementById('bd-b');
  let bdFront = bdA;
  let topKey = null;
  let pillTimer = 0;
  let compliment = pickOne(COMPLIMENTS);

  const setBackdrop = (key) => {
    if (!key || key === topKey) return;
    topKey = key;
    const back = bdFront === bdA ? bdB : bdA;
    back.style.background = D.cssGradient(store.pebbleMoments(key));
    back.classList.add('on');
    bdFront.classList.remove('on');
    bdFront = back;
  };

  const visIO = new IntersectionObserver((entries) => {
    for (const e of entries) {
      e.target.classList.toggle('dim', e.intersectionRatio < 0.92);
      // 진행 중인 오늘은 색이 비밀이라 배경을 물들이지 않는다.
      if (e.intersectionRatio >= 0.6 && e.target.dataset.key && !e.target.classList.contains('in-progress')) setBackdrop(e.target.dataset.key);
    }
  }, { root: scroller, threshold: [0, 0.3, 0.6, 0.92, 1] });

  scroller.addEventListener('scroll', () => {
    if (!topKey) return;
    pill.textContent = D.monthLabel(topKey.slice(0, 7));
    pill.classList.add('show');
    clearTimeout(pillTimer);
    pillTimer = setTimeout(() => pill.classList.remove('show'), 1200);
  }, { passive: true });

  function render() {
    const keep = scroller.scrollTop;
    visIO.disconnect();
    const width = Math.max(0, scroller.clientWidth - 56);
    const today = store.todayKey;
    const todayMoments = store.today;
    const todayInProgress = todayMoments.length > 0 && !store.isFinished(today);
    const todayClosed = todayMoments.length > 0 && store.isFinished(today);
    const days = store.finishedDayKeys;
    const gifted = days.filter((d) => store.isGifted(d));
    const handful = new Set(D.handfulMonths(gifted, today));
    const cutoff = D.compactCutoff(now());
    const lastYearKey = D.lastYear(today, gifted);

    const col = h('div', { class: 'home-col' });
    const head = h('header', { class: 'home-head' },
      h('h1', { class: 'wordmark' }, '몽돌', h('span', { class: 'wordmark-flower', html: flowerSVG({ size: 26, kind: 'five', color: '#FF8FB1', center: '#FFD84D', rot: 12 }) })));
    const praise = h('button', { class: 'praise', 'aria-label': '칭찬 한마디, 누르면 다른 칭찬' },
      h('span', { class: 'praise-tag' }, '칭찬 한마디'), h('span', { class: 'praise-text' }, compliment));
    praise.addEventListener('click', () => {
      let next = compliment;
      while (next === compliment) next = pickOne(COMPLIMENTS);
      compliment = next;
      praise.querySelector('.praise-text').textContent = next;
      praise.animate([{ transform: 'scale(1)' }, { transform: 'scale(1.06) rotate(-1deg)' }, { transform: 'scale(1)' }], { duration: 380, easing: 'cubic-bezier(.3,1.5,.5,1)' });
      burst(praise, praise.clientWidth - 18, 14, { count: 5, distance: 34, sizes: [9, 15] });
    });
    col.append(head, praise, h('div', { style: { height: '20px' } }));

    if (todayInProgress) {
      col.append(dayBlock({ key: today, moments: todayMoments, pebbleMoments: [], width, sealed: false, onOpen: app.openDay }));
      col.append(h('button', { class: 'finish-pill', onClick: (e) => { e.stopPropagation(); app.finishToday(today); } },
        h('span', { html: flowerSVG({ size: 18, kind: 'five', color: '#FF8FB1' }) }), T.finishToday));
    } else if (!todayClosed) {
      col.append(h('button', { class: 'two-tone today-line', onClick: app.openCamera },
        h('span', { class: 'ink1' }, T.todayEmpty), h('span', { class: 'ink3' }, `  ·  ${T.todayEmptyHint}`)));
    }

    if (lastYearKey) {
      const named = nameFor(store.pebbleMoments(lastYearKey));
      if (named) {
        col.append(h('button', { class: 'last-year', onClick: () => app.openDay(lastYearKey) },
          h('span', { class: 'ink2' }, T.lastYear), h('span', { class: 'compact-name' }, named.name)));
      }
    }
    col.append(h('div', { style: { height: '38px' } }));

    if (!days.length) {
      if (!todayInProgress && store.loaded) col.append(emptyDayBlock(width, store.isEmpty ? app.fillSample : null));
    } else {
      const firstOfMonth = new Set();
      days.forEach((key, index) => {
        const month = key.slice(0, 7);
        const monthStart = !firstOfMonth.has(month);
        firstOfMonth.add(month);
        const hasHeader = monthStart && handful.has(month);
        if (hasHeader) {
          const header = h('button', { class: 'month-head', style: { marginTop: index === 0 ? '0' : '56px' }, onClick: () => app.openHandful(month) },
            h('span', { class: 'mini-handful', html: flowerSVG({ size: 20, kind: 'daisy', color: '#FFD0DF', center: '#FFD84D' }) }),
            h('span', null, D.handfulTitle(month, today)), h('span', { class: 'ink3 arrow' }, '열어 보기'));
          col.append(header);
        }
        const moments = store.momentsOn(key);
        const pebbleMoments = store.pebbleMoments(key);
        const row = key < cutoff
          ? compactRow({ key, moments, pebbleMoments, onOpen: app.openDay })
          : dayBlock({ key, moments, pebbleMoments, width, onOpen: app.openDay });
        row.style.marginTop = hasHeader ? '16px' : index === 0 ? '0' : key < cutoff ? '20px' : '64px';
        col.append(row);
        visIO.observe(row);
      });
    }
    col.append(h('div', { style: { height: '140px' } }));
    scroller.replaceChildren(col);
    scroller.scrollTop = keep;
    if (!days.length) { bdA.classList.remove('on'); bdB.classList.remove('on'); topKey = null; }
    else if (!topKey || !days.includes(topKey)) { topKey = null; setBackdrop(days[0]); }
    if (todayInProgress) visIO.observe(col.querySelector('.day-block.in-progress'));
  }

  return { render, scrollToTop: () => scroller.scrollTo({ top: 0, behavior: 'smooth' }) };
}
