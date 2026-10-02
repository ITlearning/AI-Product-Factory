// 작은 DOM 도우미 · 겹(시트·전체 화면) 관리 · 토스트 · 확인창
export function h(tag, props, ...kids) {
  const el = document.createElement(tag);
  if (props) {
    for (const [k, v] of Object.entries(props)) {
      if (v == null || v === false) continue;
      if (k === 'class') el.className = v;
      else if (k === 'style' && typeof v === 'object') Object.assign(el.style, v);
      else if (k === 'html') el.innerHTML = v;
      else if (k.startsWith('on') && typeof v === 'function') el.addEventListener(k.slice(2).toLowerCase(), v);
      else el.setAttribute(k, v === true ? '' : v);
    }
  }
  for (const kid of kids.flat(Infinity)) {
    if (kid == null || kid === false) continue;
    el.append(kid instanceof Node ? kid : document.createTextNode(String(kid)));
  }
  return el;
}

export const $ = (sel, root = document) => root.querySelector(sel);

export const stage = () => document.getElementById('stage');
export const layerRoot = () => document.getElementById('layers');

// 떠 있는 겹 — 하나라도 있으면 증정 세리머니는 기다린다(원본 DayGiftPresenter 의 blocksPresentation).
const open = new Set();
const listeners = new Set();
export const layers = {
  add(name) { open.add(name); },
  remove(name) {
    open.delete(name);
    for (const fn of listeners) fn(name);
  },
  has(name) { return open.has(name); },
  get blocking() { return open.size > 0; },
  onClose(fn) { listeners.add(fn); },
};

let toastTimer = 0;
export function toast(text, ms = 1900) {
  let el = document.getElementById('toast');
  if (!el) {
    el = h('div', { id: 'toast', role: 'status', 'aria-live': 'polite' });
    stage().append(el);
  }
  el.textContent = text;
  el.classList.add('show');
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => el.classList.remove('show'), ms);
}

export function confirmDialog({ title, body, yes, no }) {
  return new Promise((resolve) => {
    layers.add('confirm');
    const done = (v) => {
      wrap.classList.remove('in');
      setTimeout(() => { wrap.remove(); layers.remove('confirm'); resolve(v); }, 220);
    };
    const wrap = h('div', { class: 'dialog-wrap', role: 'dialog', 'aria-modal': 'true', 'aria-label': title },
      h('div', { class: 'dialog' },
        h('p', { class: 'dialog-title' }, title),
        body ? h('p', { class: 'dialog-body' }, body) : null,
        h('button', { class: 'btn primary', onClick: () => done(true) }, yes),
        h('button', { class: 'btn ghost', onClick: () => done(false) }, no)));
    wrap.addEventListener('click', (e) => { if (e.target === wrap) done(false); });
    layerRoot().append(wrap);
    requestAnimationFrame(() => wrap.classList.add('in'));
  });
}

/** 닫기 알약 */
export function closePill(onClick, label = '닫기') {
  return h('button', { class: 'pill-close', onClick, 'aria-label': label }, label);
}

export const uuid = () => (crypto.randomUUID ? crypto.randomUUID() : `${Date.now().toString(36)}-${Math.random().toString(36).slice(2)}`);

export const pickOne = (list) => list[Math.floor(Math.random() * list.length)];
