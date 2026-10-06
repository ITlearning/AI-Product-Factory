// 하루 상세(DayMomentsView) · 사진 크게 보기(DayPhotoView)
// 앨범이 아니다 — 한 하루만, 사진을 촬영 시각 자리에 건다. 정규화는 DayGradient.positions 한 벌.
import { h, layers, layerRoot, closePill } from './dom.js';
import { store } from './store.js';
import { pebbleNode, dashedPebbleNode } from './pebble-gl.js';
import { photoImg } from './images.js';
import { nameFor } from './naming.js';
import * as D from './day.js';
import { T } from './copy.js';
import { bloomAround } from './flowers.js';
import { cheerPebble } from './home.js';
import { animateSpring } from './motion.js';
import { loadWords, contextFor, fits, choose, toPhotoWord, rejectedFor, hasRejected, avoided, recordReject } from './words.js';
import { meta } from './db.js';

const PHOTO = { w: 190, h: 127 };
const LABEL_W = 36, BAND_X = 44, PHOTO_X = 66, SHIFT = 28, MAX_SHIFT = 3, TICK = 13;

function caption(key, moments) {
  const sp = D.span(moments);
  if (!sp) return key;
  const from = D.timeText(sp.from), to = D.timeText(sp.to);
  return `${D.dateText(sp.from)} · ${from === to ? from : `${from}–${to}`} · ${moments.length}개`;
}

function timeline(moments, width, locked, onPhoto) {
  const room = width - PHOTO_X - PHOTO.w;
  const step = Math.max(0, Math.min(SHIFT, room / MAX_SHIFT));
  const axisH = D.axisHeight(moments.length, PHOTO.h);
  const places = D.placeTimeline(moments, axisH, PHOTO.h, MAX_SHIFT);
  const box = h('div', { class: 'timeline', style: { width: `${width}px`, height: `${axisH + PHOTO.h}px` } });
  if (axisH > 0 && !locked) {
    box.append(h('div', { class: 'tl-band', style: { left: `${BAND_X}px`, height: `${axisH}px`, background: D.cssGradient(moments) } }));
  } else if (axisH > 0) {
    box.append(h('div', { class: 'tl-band locked', style: { left: `${BAND_X}px`, height: `${axisH}px` } }));
  }
  places.forEach((p, i) => {
    if (p.showsTime) {
      box.append(h('span', { class: 'tl-time num', style: { left: '-6px', top: `${p.y - TICK / 2}px`, width: `${LABEL_W}px` } }, D.timeText(p.moment.capturedAt)));
    }
    box.append(h('span', {
      class: `tl-tick${locked ? ' locked' : ''}`,
      style: { left: `${BAND_X + 1.5 - TICK / 2}px`, top: `${p.y - TICK / 2}px`, background: locked ? '' : p.moment.colorHex, zIndex: String(places.length + i) },
    }));
    const card = h('button', {
      class: 'tl-photo', 'aria-label': `${D.timeText(p.moment.capturedAt)} 사진 크게 보기`,
      style: { left: `${PHOTO_X + p.shift * step}px`, top: `${p.y - TICK / 2}px`, zIndex: String(i) },
      onClick: () => onPhoto(p.moment),
    }, photoImg(p.moment.id, 'thumb', 'tl-img'), locked ? null : h('span', { class: 'tl-dot', style: { background: p.moment.colorHex } }));
    box.append(card);
  });
  return box;
}

export function openDay(key, { onFinish } = {}) {
  const name = `day:${key}`;
  if (layers.has(name)) return;
  layers.add(name);
  const moments = store.momentsOn(key);
  const pebbleMoments = store.pebbleMoments(key);
  const locked = key === store.todayKey && !store.isFinished(key);

  const wrap = h('div', { class: 'sheet-wrap' });
  const sheet = h('section', { class: 'sheet', role: 'dialog', 'aria-modal': 'true', 'aria-label': `${D.keyDateText(key)} 하루` });
  if (!locked) sheet.append(h('div', { class: 'sheet-glow', style: { background: D.cssGradient(pebbleMoments) } }));
  const scroll = h('div', { class: 'sheet-scroll' });
  const close = () => {
    sheet.style.transition = 'transform .32s cubic-bezier(.4,0,.6,1)';
    sheet.style.transform = 'translateY(105%)';
    wrap.classList.remove('in');
    setTimeout(() => { wrap.remove(); layers.remove(name); }, 330);
  };
  scroll.append(h('div', { class: 'topbar' }, closePill(close)));

  const width = Math.min(430, layerRoot().clientWidth) - 56;
  if (locked) {
    scroll.append(h('div', { class: 'detail-head locked' },
      h('div', { class: 'detail-spot' }, dashedPebbleNode(130)),
      h('div', { class: 'detail-words' },
        h('p', { class: 'detail-line' }, T.openTodayHint),
        h('p', { class: 'caption num' }, caption(key, moments)))));
  } else {
    const named = nameFor(pebbleMoments);
    const spot = h('div', { class: 'detail-spot' }, pebbleNode({ moments: pebbleMoments, dayKey: key, height: 130, glow: 'hero', lazy: false }));
    bloomAround(spot, `detail:${key}`, { count: 4, size: [14, 24] });
    spot.addEventListener('click', (e) => cheerPebble(spot, e));
    scroll.append(h('div', { class: 'detail-head' },
      spot,
      h('div', { class: 'detail-words' },
        named ? h('h2', { class: 'detail-name' }, named.name) : null,
        named ? h('p', { class: 'detail-line' }, named.line) : null,
        h('p', { class: 'caption num' }, caption(key, moments)))));
  }
  scroll.append(h('div', { style: { height: '30px' } }));
  scroll.append(timeline(moments, width, locked, (m) => openPhoto(m, locked)));
  scroll.append(h('p', { class: 'guide center' }, T.detailHint));
  if (store.canClose(key)) {
    scroll.append(h('button', { class: 'btn primary finish', onClick: async () => { if (await onFinish?.(key)) close(); } }, T.finishToday));
  }
  scroll.append(h('div', { style: { height: '40px' } }));
  sheet.append(scroll);
  wrap.append(sheet);
  wrap.addEventListener('click', (e) => { if (e.target === wrap) close(); });
  layerRoot().append(wrap);

  // 아래로 쓸어 닫기(맨 위에서만)
  let sy = null;
  sheet.addEventListener('touchstart', (e) => { sy = scroll.scrollTop <= 0 ? e.touches[0].clientY : null; }, { passive: true });
  sheet.addEventListener('touchmove', (e) => {
    if (sy == null) return;
    const dy = e.touches[0].clientY - sy;
    if (dy > 0) { sheet.style.transition = 'none'; sheet.style.transform = `translateY(${dy}px)`; }
  }, { passive: true });
  sheet.addEventListener('touchend', (e) => {
    if (sy == null) return;
    const dy = e.changedTouches[0].clientY - sy;
    sy = null;
    sheet.style.transition = '';
    if (dy > 120) close(); else sheet.style.transform = '';
  });

  requestAnimationFrame(() => wrap.classList.add('in'));
  const rise = animateSpring(sheet, (p) => ({ transform: `translateY(${(1 - p) * 100}%)` }), { response: 0.42, damping: 0.86 });
  // fill 이 남아 있으면 닫힐 때 인라인 transform 이 안 먹는다 — 끝나면 걷어낸다.
  rise.onfinish = () => { sheet.style.transform = ''; rise.cancel(); };
  return close;
}

export function openPhoto(moment, locked) {
  const name = `photo:${moment.id}`;
  layers.add(name);
  const words = h('div', { class: 'photo-words' });
  const view = h('section', { class: 'photo-view', role: 'dialog', 'aria-modal': 'true', 'aria-label': '사진 크게 보기' },
    h('div', { class: 'photo-scroll' },
      h('div', { class: 'photo-frame' }, photoImg(moment.id, 'full', 'photo-img')),
      words),
    h('div', { class: 'photo-top' }, closePill(() => close())));
  const close = () => {
    view.classList.remove('in');
    setTimeout(() => { view.remove(); layers.remove(name); }, 260);
  };
  const meta = h('p', { class: 'photo-meta num' },
    locked ? null : h('span', { class: 'photo-dot', style: { background: moment.colorHex } }),
    D.timeText(moment.capturedAt));
  words.append(meta);
  showWord(moment, words, view);
  layerRoot().append(view);
  requestAnimationFrame(() => view.classList.add('in'));
}

/**
 * 사진 한 단어(DayPhotoView.words) — 붙은 단어가 아직 맞으면 그대로, 아는 사실이 뒤집었거나
 * 예전 목록의 단어(wordID 없음)면 새로 골라 붙인다. ↻ 는 사진마다 한 번, 다른 갈래 단어로.
 */
async function showWord(moment, box, view) {
  const list = await loadWords();
  if (!list.length || !view.isConnected) return;
  const byID = new Map(list.map((w) => [w.id, w]));
  const ctx = contextFor(moment.capturedAt);
  const pebbleName = nameFor(store.momentsOn(moment.dayKey))?.name;
  const pick = (banned, skipGroup) => choose(ctx, list, {
    recent: new Set([...store.recentWordIDs(moment.id), ...avoided()]), banned, seed: moment.id, pebbleName, skipGroup,
  });
  const stamp = (w) => { moment.word = w; store.updateMoment(moment); };

  let current = moment.word;
  const entry = current?.wordID && byID.get(current.wordID);
  if (!entry || !fits(entry, ctx)) {
    const w = pick(rejectedFor(moment.id));
    if (!w) return;
    current = toPhotoWord(w);
    stamp(current);
  }

  const word = h('span', { class: 'photo-word' }, current.word);
  const meaning = h('p', { class: 'photo-meaning' }, current.meaning);
  const line = h('div', { class: 'photo-word-line' }, word);
  box.prepend(h('p', { class: 'photo-tag' }, '이 순간에 어울리는 우리말!'), line, meaning);

  const old = byID.get(current.wordID);
  const alt = !hasRejected(moment.id) && pick(new Set([current.wordID]), old?.group);
  if (!alt) return;
  const learned = meta.get('didLearnWordReject', false);
  const reroll = h('button', { class: `word-reroll${learned ? '' : ' open'}`, 'aria-label': '이 단어는 아니에요' },
    h('span', { class: 'word-reroll-icon', 'aria-hidden': 'true' }, '↻'),
    h('span', { class: 'word-reroll-text' }, '이 단어는 아니에요'));
  if (!learned) setTimeout(() => { reroll.classList.remove('open'); meta.set('didLearnWordReject', true); }, 2600);
  reroll.addEventListener('click', () => {
    const next = toPhotoWord(alt);
    recordReject({ momentID: moment.id, wordID: current.wordID, replacedBy: alt.id, partOfDay: ctx.timeBand });
    stamp(next);
    reroll.remove();
    for (const [el, text] of [[word, next.word], [meaning, next.meaning]]) {
      el.animate([{ opacity: 1, transform: 'none' }, { opacity: 0, transform: 'translateY(-8px)' }], { duration: 160, easing: 'ease-in' })
        .onfinish = () => {
          el.textContent = text;
          el.animate([{ opacity: 0, transform: 'translateY(8px)' }, { opacity: 1, transform: 'none' }], { duration: 240, easing: 'cubic-bezier(.3,1.3,.5,1)' });
        };
    }
  });
  line.append(reroll);
}
