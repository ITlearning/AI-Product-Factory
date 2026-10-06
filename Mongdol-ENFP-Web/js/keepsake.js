// 건네기(KeepsakeShareSheet · HandfulShareSheet) — 사용자가 누를 때만 연다. 받은 하루만, 장소·단어 없이.
// 좌우로 넘겨 그날 사진 한 장을 고르고, 고른 장으로 카드를 다시 그려 PNG 로 건넨다(공유 문구가 몽돌 주소를 겸한다).
import { h, layers, layerRoot, closePill, toast } from './dom.js';
import { store } from './store.js';
import { objectParticle, nameFor } from './naming.js';
import * as D from './day.js';
import { CANVAS, paintPebbleCard, paintHandfulCard, toPNG } from './card.js';

export const PACKING = '건네기 좋게 포장하고 있어요…';
const FAILED = '앗, 카드를 만들 수 없어요';

const appURL = () => `${location.origin}${location.pathname}`;
export const shareText = (what) => `${what}${objectParticle(what)} 건네요! 나도 몽돌 받아 보기 → ${appURL()}`;

/** 공유 시트가 처음 보여 줄 사진 — 하루 상세에서 보던 사진이면 그것, 아니면 그날 첫 사진. */
export function initialIndex(photos, viewingID) {
  const i = photos.findIndex((m) => m.id === viewingID);
  return i >= 0 ? i : 0;
}

export function shareIcon() {
  return h('span', { class: 'share-icon', 'aria-hidden': 'true', html: '<svg width="20" height="20" viewBox="0 0 24 24"><path d="M12 3.5v11M8 7.2 12 3.5l4 3.7" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/><path d="M8.5 10.5H7A2.5 2.5 0 0 0 4.5 13v5A2.5 2.5 0 0 0 7 20.5h10a2.5 2.5 0 0 0 2.5-2.5v-5a2.5 2.5 0 0 0-2.5-2.5h-1.5" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>' });
}

export function openDayKeepsake(dayKey, viewingID) {
  if (!store.isGifted(dayKey)) return;
  const pebbleMoments = store.pebbleMoments(dayKey);
  if (!pebbleMoments.length) return;
  const photos = store.momentsOn(dayKey);
  const faces = photos.length ? photos : [null];
  const name = nameFor(pebbleMoments)?.name || '몽돌';
  openSheet({
    layer: `keepsake:${dayKey}`,
    label: `${D.keyDateText(dayKey)} 조약돌 카드`,
    hint: faces.length > 1 ? '어떤 사진이랑 건넬까요? 옆으로 넘겨 골라요' : null,
    count: faces.length,
    initial: initialIndex(photos, viewingID),
    paint: (i, k) => paintPebbleCard({ dayKey, pebbleMoments, face: faces[i], k }),
    fileName: `mongdol-${dayKey}.png`,
    text: shareText(name),
  });
}

export function openHandfulKeepsake(month) {
  const groups = store.finishedDayKeys.filter((k) => k.startsWith(month) && store.isGifted(k))
    .map((k) => ({ key: k, moments: store.pebbleMoments(k) })).filter((g) => g.moments.length);
  if (!groups.length) return;
  const today = store.todayKey;
  openSheet({
    layer: `keepsake:${month}`,
    label: `${D.handfulTitle(month, today)} 카드`,
    hint: null,
    count: 1,
    initial: 0,
    paint: (_, k) => paintHandfulCard({ month, groups, today, k }),
    fileName: `mongdol-${month}.png`,
    text: shareText(D.handfulTitle(month, today)),
  });
}

function openSheet({ layer, label, hint, count, initial, paint, fileName, text }) {
  if (layers.has(layer)) return;
  layers.add(layer);
  let index = initial;
  let packed = null; // { index, file?, failed? }
  let token = 0;
  const urls = new Set();

  const action = h('div', { class: 'ks-action' });
  const counter = h('p', { class: 'ks-count num', 'aria-live': 'polite' });
  const prev = h('button', { class: 'ks-arrow', 'aria-label': '이전 사진', onClick: () => go(index - 1) }, '‹');
  const next = h('button', { class: 'ks-arrow', 'aria-label': '다음 사진', onClick: () => go(index + 1) }, '›');
  const pages = h('div', { class: 'ks-pages' });
  const cards = Array.from({ length: count }, (_, i) => {
    const card = h('div', { class: 'ks-card', role: 'img', 'aria-label': count > 1 ? `${label} ${i + 1}번째 사진` : label });
    pages.append(h('div', { class: 'ks-page' }, card));
    return card;
  });
  const view = h('section', { class: 'keepsake', role: 'dialog', 'aria-modal': 'true', 'aria-label': label },
    h('div', { class: 'ks-top' }, closePill(() => close())),
    h('p', { class: 'ks-hint' }, hint || '건네기 좋게 한 장으로 담았어요!'),
    pages,
    count > 1 ? h('div', { class: 'ks-nav' }, prev, counter, next) : null,
    action);
  layerRoot().append(view);

  const close = () => {
    token++;
    view.classList.remove('in');
    setTimeout(() => {
      view.remove();
      layers.remove(layer);
      for (const u of urls) URL.revokeObjectURL(u);
    }, 260);
  };

  const size = () => {
    const w = pages.clientWidth, hh = pages.clientHeight;
    const cardH = Math.max(160, Math.min(hh - 64, ((w - 88) * CANVAS.h) / CANVAS.w));
    return { w: (cardH * CANVAS.w) / CANVAS.h, h: cardH };
  };

  const shown = new Map(); // i → canvas
  async function preview(i) {
    if (i < 0 || i >= count || shown.has(i)) return;
    shown.set(i, null);
    const s = size();
    const k = (s.w / CANVAS.w) * Math.min(2, Math.max(1, window.devicePixelRatio || 1));
    try {
      const c = await paint(i, k);
      if (!view.isConnected || !shown.has(i)) return;
      c.className = 'ks-canvas';
      shown.set(i, c);
      cards[i].replaceChildren(c);
      requestAnimationFrame(() => c.classList.add('in'));
    } catch (e) {
      console.warn('[몽돌] 카드 미리보기를 못 그렸어요:', e);
      shown.delete(i);
      cards[i].replaceChildren(h('p', { class: 'ks-fail' }, FAILED));
    }
  }
  // 넘길 때마다 멀리 있는 장은 놓는다 — 사진이 많은 날 캔버스가 쌓이면 iOS 가 메모리로 죽인다.
  function keepNear(i) {
    for (const j of [...shown.keys()]) {
      if (Math.abs(j - i) <= 1) continue;
      const c = shown.get(j);
      if (c) { c.width = 0; c.height = 0; }
      shown.delete(j);
      cards[j].replaceChildren();
    }
    preview(i); preview(i + 1); preview(i - 1);
  }

  function renderAction() {
    action.replaceChildren();
    if (packed?.index === index && packed.failed) {
      action.append(h('p', { class: 'ks-status' }, FAILED));
    } else if (packed?.index === index && packed.file) {
      action.append(h('button', { class: 'btn primary ks-give', onClick: give }, shareIcon(), '건네기'));
    } else {
      action.append(h('p', { class: 'ks-status' }, PACKING));
    }
  }

  // 건네기 직전에 구우면 Safari 가 「사용자가 누른 직후」를 놓쳐 공유 시트를 막는다 — 고른 장은 미리 싸 둔다.
  async function pack(i) {
    const my = ++token;
    packed = { index: i };
    renderAction();
    try {
      await new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r)));
      if (my !== token) return;
      const c = await paint(i, 3);
      if (my !== token) return;
      const file = await toPNG(c, fileName);
      c.width = 0; c.height = 0;
      if (my !== token) return;
      packed = { index: i, file };
    } catch (e) {
      if (my !== token) return;
      console.warn('[몽돌] 카드를 못 만들었어요:', e);
      packed = { index: i, failed: true };
    }
    renderAction();
  }

  async function give() {
    const file = packed?.file;
    if (!file) return;
    if (navigator.canShare?.({ files: [file] })) {
      try {
        await navigator.share({ files: [file], text });
        return;
      } catch (e) {
        if (e?.name === 'AbortError') return;
      }
    }
    showSave(file);
  }

  function showSave(file) {
    const url = URL.createObjectURL(file);
    urls.add(url);
    const done = () => { box.classList.remove('in'); setTimeout(() => box.remove(), 220); };
    const copy = async () => {
      try {
        await navigator.clipboard.writeText(text);
        toast('문구를 복사했어요! 이미지랑 같이 보내 주세요');
      } catch {
        toast('복사가 막혔어요. 이미지만 건네도 충분해요!');
      }
    };
    const box = h('div', { class: 'ks-save', role: 'dialog', 'aria-modal': 'true', 'aria-label': '카드 저장하기' },
      h('div', { class: 'ks-top' }, closePill(done, '돌아가기')),
      h('div', { class: 'ks-save-frame' }, h('img', { class: 'ks-save-img', src: url, alt: label })),
      h('p', { class: 'ks-hint' }, '이미지를 길게 눌러 저장해요'),
      h('a', { class: 'btn primary ks-give', href: url, download: file.name }, '이미지 저장하기'),
      h('button', { class: 'btn ghost', onClick: copy }, '건넬 문구 복사하기'));
    view.append(box);
    requestAnimationFrame(() => box.classList.add('in'));
  }

  function settle(i) {
    i = Math.max(0, Math.min(count - 1, i));
    if (i === index && packed?.index === i) return;
    index = i;
    counter.textContent = `${i + 1} / ${count}`;
    prev.disabled = i === 0;
    next.disabled = i === count - 1;
    keepNear(i);
    pack(i);
  }

  function go(i) {
    i = Math.max(0, Math.min(count - 1, i));
    pages.scrollTo({ left: i * pages.clientWidth, behavior: 'smooth' });
  }

  let scrollTimer = 0;
  pages.addEventListener('scroll', () => {
    clearTimeout(scrollTimer);
    scrollTimer = setTimeout(() => settle(Math.round(pages.scrollLeft / Math.max(1, pages.clientWidth))), 120);
  }, { passive: true });

  requestAnimationFrame(() => {
    const s = size();
    for (const c of cards) { c.style.width = `${s.w}px`; c.style.height = `${s.h}px`; }
    pages.scrollLeft = index * pages.clientWidth;
    view.classList.add('in');
    packed = null;
    settle(index);
  });
}
