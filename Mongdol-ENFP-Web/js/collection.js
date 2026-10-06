// 모은 조약돌(PebbleCollectionView.swift) — 받은 조약돌만 빈틈없이, 최신순, 달별로 묶는다. 4열, 날짜만.
// 달력 칸·빈칸·개수는 두지 않는다 — SPEC §1-2: 빈 날이 구멍으로 보이면 그 순간 스트릭이 된다.
import { h } from './dom.js';
import { store } from './store.js';
import { pebbleNode } from './pebble-gl.js';
import * as D from './day.js';
import { T } from './copy.js';
import { flowerSVG } from './flowers.js';

export function createCollection(app) {
  const scroller = document.getElementById('collection');

  function months() {
    const keys = store.finishedDayKeys
      .filter((k) => store.isGifted(k) && store.pebbleMoments(k).length)
      .sort()
      .reverse();
    const out = [];
    for (const key of keys) {
      const month = key.slice(0, 7);
      if (out.at(-1)?.month === month) out.at(-1).days.push(key);
      else out.push({ month, days: [key] });
    }
    return out;
  }

  function cell(key) {
    return h('button', { class: 'coll-cell', 'aria-label': `${D.keyDateText(key)} 조약돌`, onClick: () => app.openDay(key) },
      h('span', { class: 'coll-pebble' }, pebbleNode({ moments: store.pebbleMoments(key), dayKey: key, height: 62, glow: 'grid' })),
      h('span', { class: 'coll-date num' }, D.keyDateText(key)));
  }

  function render() {
    const keep = scroller.scrollTop;
    const list = months();
    const today = store.todayKey;
    const col = h('div', { class: 'coll-col' },
      h('h1', { class: 'coll-title' }, T.collectionTitle));
    if (!list.length) {
      col.append(h('div', { class: 'coll-empty' },
        h('span', { class: 'empty-flower', html: flowerSVG({ size: 40, kind: 'daisy', color: '#FFD6E4', center: '#FFE58A' }) }),
        h('p', { class: 'coll-empty-title' }, T.collectionEmpty),
        h('p', { class: 'guide' }, T.collectionEmptyHint)));
    }
    for (const m of list) {
      col.append(h('section', { class: 'coll-month' },
        h('h2', { class: 'coll-month-title' }, D.handfulTitle(m.month, today)),
        h('div', { class: 'coll-grid' }, m.days.map(cell))));
    }
    scroller.replaceChildren(col);
    scroller.scrollTop = keep;
  }

  return { render, scrollToTop: () => scroller.scrollTo({ top: 0, behavior: 'smooth' }) };
}
