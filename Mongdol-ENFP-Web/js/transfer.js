// 기록 옮기기 — iPhone 은 Safari 탭과 홈 화면 몽돌의 저장소가 따로라, 8자리 코드로 기록을 넘긴다(기기를 바꿀 때도).
// 폰에서 묶고 잠근 암호문만 10분 동안 서버(api/transfer)를 거친다. 묶기·잠그기는 transfer-core.js.
import { h, layers, layerRoot, closePill, toast } from './dom.js';
import * as db from './db.js';
import {
  CHUNK, MAX_SIZE, TransferError, makeCode, cleanCode, formatCode, isCode, idFor, deriveKey,
  randomBytes, chunkCount, sealChunk, openChunk, toB64, fromB64, pack, unpack,
} from './transfer-core.js';

const API = './api/transfer';
const CARRY = ['wordRejects', 'didLearnWordReject', 'reminderFrequency'];
const DAY_KEY = /^\d{4}-\d{2}-\d{2}$/;
const PRIVACY = '암호화된 채로 10분만 서버를 거쳐요. 코드를 모르면 아무도 못 열어요.';

async function call(body) {
  let res;
  try {
    res = await fetch(API, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(body) });
  } catch {
    throw new TransferError('network');
  }
  const json = await res.json().catch(() => ({}));
  if (res.ok) return json;
  const kind = { 429: 'limited', 413: 'too-big', 404: 'bad-code', 403: 'bad-code', 410: 'used', 409: 'conflict' }[res.status] || 'server';
  throw new TransferError(kind, json.message);
}

async function retry(fn, tries = 3) {
  for (let k = 1; ; k++) {
    try { return await fn(); } catch (e) {
      if (k >= tries || !['network', 'server'].includes(e.kind)) throw e;
      await new Promise((r) => setTimeout(r, 600 * k));
    }
  }
}

const bytesOf = async (v) => (v ? { bytes: new Uint8Array(await v.arrayBuffer()), type: v.type || '' } : null);

async function collect() {
  const moments = (await db.loadMoments()).map(({ dayKey: _drop, ...m }) => m);
  const photos = [];
  for (const m of moments) {
    const p = await db.loadPhoto(m.id);
    if (p && (p.full || p.thumb)) photos.push({ id: m.id, full: await bytesOf(p.full), thumb: await bytesOf(p.thumb) });
  }
  const meta = { closures: db.meta.get('closures', {}), gifted: db.meta.get('gifted', []) };
  for (const k of CARRY) {
    const v = db.meta.get(k, undefined);
    if (v !== undefined) meta[k] = v;
  }
  return { moments, meta, photos };
}

/** 묶고 잠가서 올린다 → { code, ttl, moments } */
export async function sendRecords(onProgress = () => {}) {
  const bundle = await collect();
  const p = pack(bundle);
  if (p.size > MAX_SIZE) throw new TransferError('too-big');
  const count = chunkCount(p.size);
  const salt = randomBytes(16);
  let code, id, token;
  for (let k = 0; !token; k++) {
    code = makeCode();
    id = await idFor(code);
    try {
      ({ token } = await retry(() => call({ action: 'start', id, size: p.size, count, salt: toB64(salt) })));
    } catch (e) {
      if (e.kind !== 'conflict' || k >= 3) throw e;
    }
  }
  const key = await deriveKey(code, salt);
  onProgress(0, count);
  for (let i = 0; i < count; i++) {
    const sealed = await sealChunk(key, p.slice(i * CHUNK, Math.min(p.size, (i + 1) * CHUNK)), i, count);
    const data = toB64(sealed);
    await retry(() => call({ action: 'chunk', id, token, index: i, data }));
    onProgress(i + 1, count);
  }
  const { ttl } = await retry(() => call({ action: 'finish', id, token }));
  return { code, ttl, moments: bundle.moments.length };
}

const isMoment = (m) => m && typeof m.id === 'string' && Number.isFinite(m.capturedAt);
const toBlob = (p) => (p?.buf ? new Blob([p.buf], { type: p.type }) : null);

/** 받은 묶음을 이 기기 기록에 합친다 — 같은 id 는 건너뛴다. */
export async function importBundle(store, bundle) {
  const photos = new Map(bundle.photos.map((p) => [p.id, p]));
  const fresh = bundle.moments.filter((m) => isMoment(m) && !store.moment(m.id));
  for (let i = 0; i < fresh.length; i += 20) {
    await store.add(fresh.slice(i, i + 20).map(({ dayKey: _drop, ...moment }) => {
      const p = photos.get(moment.id);
      return { moment, full: toBlob(p?.full), thumb: toBlob(p?.thumb) };
    }));
  }
  const m = bundle.meta;
  const closures = Object.fromEntries(Object.entries(m.closures && typeof m.closures === 'object' ? m.closures : {})
    .filter(([k, v]) => DAY_KEY.test(k) && Number.isFinite(v)));
  const gifted = (Array.isArray(m.gifted) ? m.gifted : []).filter((k) => typeof k === 'string' && DAY_KEY.test(k));
  store.absorb({ closures, gifted });
  if (Array.isArray(m.wordRejects)) {
    const mine = db.meta.get('wordRejects', []);
    const seen = new Set(mine.map((r) => `${r.momentID}|${r.wordID}`));
    const more = m.wordRejects.filter((r) => typeof r?.momentID === 'string' && typeof r?.wordID === 'string' && !seen.has(`${r.momentID}|${r.wordID}`));
    if (more.length) db.meta.set('wordRejects', [...mine, ...more]);
  }
  if (m.didLearnWordReject === true) db.meta.set('didLearnWordReject', true);
  if (typeof m.reminderFrequency === 'string' && db.meta.get('reminderFrequency', null) == null) db.meta.set('reminderFrequency', m.reminderFrequency);
  return { added: fresh.length, skipped: bundle.moments.length - fresh.length };
}

/** 코드로 받아서 합친다 → { added, skipped } */
export async function receiveRecords(store, code, onProgress = () => {}) {
  const id = await idFor(code);
  const info = await call({ action: 'info', id });
  const key = await deriveKey(code, fromB64(info.salt));
  const all = new Uint8Array(info.size);
  onProgress(0, info.count);
  try {
    for (let i = 0; i < info.count; i++) {
      const { data } = await retry(() => call({ action: 'get', id, claim: info.claim, index: i }));
      all.set(await openChunk(key, fromB64(data), i, info.count), i * CHUNK);
      onProgress(i + 1, info.count);
    }
  } catch (e) {
    call({ action: 'done', id, claim: info.claim }).catch(() => {});
    throw e;
  }
  return importBundle(store, unpack(all));
}

// ── 화면 ──

const SEND_ERR = {
  'too-big': '기록이 너무 많아서(100MB 넘게) 한 번에 못 옮겨요. 미안해요!',
  limited: '코드를 너무 여러 번 받았어요. 조금 쉬었다가 다시 해 주세요.',
};
const RECV_ERR = {
  'bad-code': '코드를 다시 확인해 주세요. 10분이 지났거나 이미 쓴 코드일 수도 있어요.',
  used: '이미 받아 간 코드예요. 보내는 쪽에서 코드를 새로 받아 주세요.',
  limited: '여러 번 틀려서 잠깐 쉬어야 해요. 10분 뒤에 다시 해 주세요.',
  'bad-bundle': '코드를 다시 확인해 주세요.',
};
const errText = (e, table) => table[e?.kind] || (e?.kind === 'network' ? '앗, 연결이 끊겼어요. 다시 한 번 눌러 주세요.' : '앗, 잘 안 됐어요. 다시 한 번 눌러 주세요.');

const bar = () => {
  const fill = h('span', { class: 'xfer-fill' });
  const label = h('p', { class: 'xfer-progress num', role: 'status', 'aria-live': 'polite' });
  return { el: h('div', { class: 'xfer-wait' }, h('div', { class: 'xfer-bar' }, fill), label), set(text, done, total) {
    label.textContent = text;
    fill.style.width = `${total ? Math.round((done / total) * 100) : 0}%`;
  } };
};

// 클립보드는 탭 안에서 바로 써야 한다. 막히면(오래된 Safari·앱 속 브라우저) 숨긴 글상자로 한 번 더.
async function copyText(text) {
  try {
    await navigator.clipboard.writeText(text);
    return true;
  } catch {
    const t = h('textarea', { readonly: true, style: { position: 'fixed', top: '0', left: '0', opacity: '0' } });
    t.value = text;
    document.body.append(t);
    t.select();
    t.setSelectionRange(0, text.length);
    let ok = false;
    try { ok = document.execCommand('copy'); } catch { /* 무시 */ }
    t.remove();
    return ok;
  }
}

const copyCode = async (c) => {
  toast(await copyText(c) ? '복사됐어요!' : '복사가 막혔어요. 코드를 꾹 눌러 복사해 주세요');
};

// 만든 코드는 10분 동안 기억한다 — 안내를 닫았다 다시 열어도 같은 코드가 보여야 홈 화면에 추가하는 동안 잃지 않는다.
const COPY_ICON = '<svg width="20" height="20" viewBox="0 0 26 26"><rect x="8.5" y="8.5" width="12" height="13" rx="3" fill="none" stroke="currentColor" stroke-width="2"/><path d="M5.5 16.5V7A2.5 2.5 0 0 1 8 4.5h7.5" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>';
const ACTIVE = 'mongdol.xferActive';
const activeCode = () => {
  try {
    const a = JSON.parse(sessionStorage.getItem(ACTIVE) || 'null');
    return a && a.until > Date.now() ? a : null;
  } catch { return null; }
};
const rememberCode = (a) => { try { sessionStorage.setItem(ACTIVE, JSON.stringify(a)); } catch { /* 이번 화면만 */ } };

/**
 * 「기록 옮길 코드」 카드 — 안내 안에 그대로 붙어 있고, 누르면 그 자리에서 코드로 바뀐다(덮개 창 없음).
 * 코드는 누를 때만 만든다: 안내만 연 사람의 사진까지 서버로 올리지 않게.
 */
export function carryCard(store) {
  const card = h('div', { class: 'xfer-card' });
  let timer = 0;
  const show = (...kids) => { clearInterval(timer); card.replaceChildren(...kids.filter(Boolean)); };

  const idle = () => show(
    h('p', { class: 'xfer-card-title' }, '지금까지 담은 기록도 같이 데려가요'),
    h('p', { class: 'xfer-card-sub' }, `홈 화면 몽돌은 새로 시작해요. 코드를 만들어 두고 홈 화면 몽돌을 처음 열 때 넣으면 기록 ${store.all.size}개가 따라와요.`),
    h('button', { class: 'btn primary xfer-go', onClick: make }, '기록 옮길 코드 만들기'));

  async function make() {
    const b = bar();
    show(h('p', { class: 'xfer-card-title' }, `기록 ${store.all.size}개를 꼭꼭 싸는 중이에요`), b.el);
    b.set('코드 만드는 중…', 0, 1);
    try {
      const out = await sendRecords((done, total) => b.set(`코드 만드는 중 ${done}/${total}`, done, total));
      const a = { code: out.code, until: Date.now() + out.ttl * 1000, moments: out.moments };
      rememberCode(a);
      code(a);
    } catch (e) {
      if (e?.kind !== 'too-big' && e?.kind !== 'limited') console.warn('transfer send', e);
      show(h('p', { class: 'xfer-error' }, errText(e, SEND_ERR)),
        e?.kind === 'too-big' ? null : h('button', { class: 'btn primary xfer-go', onClick: make }, '다시 만들기'));
    }
  }

  function code({ code: c, until, moments }) {
    const left = h('span', { class: 'xfer-left num' });
    const tick = () => {
      const s = Math.max(0, Math.round((until - Date.now()) / 1000));
      left.textContent = `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')} 남았어요`;
      if (s === 0) {
        try { sessionStorage.removeItem(ACTIVE); } catch { /* 무시 */ }
        show(h('p', { class: 'xfer-card-title' }, '코드 시간이 다 됐어요'),
          h('button', { class: 'btn primary xfer-go', onClick: make }, '코드 새로 만들기'));
      }
    };
    show(
      h('p', { class: 'xfer-card-title' }, `기록 ${moments}개를 옮길 코드예요`),
      h('button', { class: 'xfer-code num', 'aria-label': `코드 ${c.split('').join(' ')}, 누르면 복사`, onClick: () => copyCode(c) }, formatCode(c)),
      h('button', { class: 'btn xfer-copy', onClick: () => copyCode(c) },
        h('span', { class: 'xfer-copy-icon', 'aria-hidden': 'true', html: COPY_ICON }), '코드 복사하기'),
      h('p', { class: 'xfer-card-sub xfer-center' }, '아래대로 홈 화면에 추가한 뒤, 홈 화면 몽돌 첫 화면에서 이 코드를 넣어요. ', left),
      h('p', { class: 'fine xfer-center' }, `한 번만 쓸 수 있어요. ${PRIVACY}`));
    tick();
    timer = setInterval(tick, 1000);
  }

  const a = activeCode();
  if (a) code(a); else idle();
  return card;
}

/**
 * mode: 'choose'(설정 — 받기·넣기 둘 다) | 'send' | 'receive'
 * onReceived({added, skipped}): 받기를 마치고 「좋아요」를 누른 뒤
 */
export function openTransferSheet({ store, mode = 'choose', onReceived }) {
  if (layers.has('transfer')) return;
  layers.add('transfer');
  let timer = 0;
  let busy = false;
  const body = h('div', { class: 'xfer-body' });
  const close = () => {
    if (busy) return;
    clearInterval(timer);
    wrap.classList.remove('in');
    setTimeout(() => { wrap.remove(); layers.remove('transfer'); }, 300);
  };
  const show = (...kids) => { clearInterval(timer); body.replaceChildren(...kids.filter(Boolean)); };

  const choose = () => show(
    h('p', { class: 'inst-detail' }, '지금까지 담은 기록을 코드 하나로 홈 화면 몽돌이나 다른 기기에 옮겨요.'),
    h('button', { class: 'row-btn', onClick: send },
      h('span', { class: 'row-main' }, '코드 받기'), h('span', { class: 'row-sub' }, '이 기기의 기록을 보낼 때')),
    h('button', { class: 'row-btn', onClick: receive },
      h('span', { class: 'row-main' }, '코드 입력하기'), h('span', { class: 'row-sub' }, '다른 곳에서 쓰던 기록을 데려올 때')),
    h('p', { class: 'fine' }, PRIVACY));

  function send() {
    if (store.isEmpty) {
      show(h('p', { class: 'inst-detail' }, '아직 옮길 기록이 없어요. 한 장 담고 나서 다시 와 주세요!'));
      return;
    }
    show(carryCard(store));
  }

  function receive() {
    const input = h('input', {
      class: 'xfer-input num', type: 'text', inputmode: 'numeric', autocomplete: 'one-time-code', pattern: '[0-9 ]*',
      maxlength: '9', placeholder: '0000 0000', 'aria-label': '코드 8자리',
    });
    const go = h('button', { class: 'btn primary xfer-go', disabled: true }, '가져오기');
    const msg = h('p', { class: 'xfer-error', role: 'alert' });
    input.addEventListener('input', () => {
      const c = cleanCode(input.value);
      input.value = formatCode(c);
      go.disabled = !isCode(c);
      msg.textContent = '';
    });
    const start = async () => {
      const code = cleanCode(input.value);
      if (!isCode(code)) return;
      input.blur();
      const b = bar();
      show(h('p', { class: 'inst-lead' }, '기록을 데려오는 중이에요'), b.el);
      b.set('데려오는 중…', 0, 1);
      busy = true;
      try {
        const out = await receiveRecords(store, code, (done, total) => b.set(`데려오는 중 ${done}/${total}`, done, total));
        busy = false;
        show(
          h('p', { class: 'xfer-done' }, `짠! 기록 ${out.added}개를 다 데려왔어요`),
          out.skipped ? h('p', { class: 'inst-detail xfer-center' }, `이미 있던 ${out.skipped}개는 그대로 두었어요.`) : null,
          h('button', { class: 'btn primary xfer-ok', onClick: () => { close(); onReceived?.(out); } }, '좋아요!'));
      } catch (e) {
        busy = false;
        if (!RECV_ERR[e?.kind]) console.warn('transfer receive', e);
        receive();
        body.querySelector('.xfer-error').textContent = errText(e, RECV_ERR);
      }
    };
    go.addEventListener('click', start);
    input.addEventListener('keydown', (e) => { if (e.key === 'Enter') start(); });
    show(
      h('p', { class: 'inst-lead' }, '받은 코드 8자리를 넣어 주세요!'),
      h('p', { class: 'inst-detail' }, 'Safari 몽돌(또는 쓰던 기기)의 「기록 옮기기」에서 받은 코드예요.'),
      input, msg, go,
      h('p', { class: 'fine' }, PRIVACY));
    setTimeout(() => input.focus(), 350);
  }

  const sheet = h('section', { class: 'mini-sheet inst-sheet xfer-sheet', role: 'dialog', 'aria-modal': 'true', 'aria-label': '기록 옮기기' },
    h('div', { class: 'topbar' }, closePill(close)),
    h('h2', { class: 'mini-title' }, '기록 옮기기'),
    body);
  const wrap = h('div', { class: 'sheet-wrap xfer-wrap' }, sheet);
  wrap.addEventListener('click', (e) => { if (e.target === wrap) close(); });
  layerRoot().append(wrap);
  requestAnimationFrame(() => wrap.classList.add('in'));
  ({ choose, send, receive })[mode]();
}

