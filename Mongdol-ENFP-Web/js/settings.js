// 설정 — 알림(도착 소식 · 사진이 없는 날) · 견본 하루 · 홈 화면에 추가하기 · 기록 옮기기 · 친구에게도 해보기(도구 공유) · 전부 지우기. 결과 자랑용 공유는 없다.
import { h, layers, layerRoot, closePill, confirmDialog, toast } from './dom.js';
import { rendererInfo } from './pebble-gl.js';
import { persistent } from './db.js';
import { canOfferInstall } from './install.js';
import { pushState, isSubscribed, enableNotices, disableNotices, getFrequency, setFrequency } from './push.js';
import { FREQUENCIES, FREQUENCY_TITLE } from './notice.js';

/** 사진이 없는 날 알림 빈도 칩 — 설정과 온보딩이 같이 쓴다. */
export function frequencyChips(onPick) {
  const row = h('div', { class: 'freq-chips', role: 'radiogroup', 'aria-label': '사진이 없는 날 알림' });
  const paint = () => {
    const cur = getFrequency();
    for (const b of row.children) {
      const on = b.dataset.f === cur;
      b.classList.toggle('on', on);
      b.setAttribute('aria-checked', String(on));
    }
  };
  for (const f of FREQUENCIES) {
    row.append(h('button', { class: 'freq-chip', role: 'radio', 'data-f': f, onClick: () => { setFrequency(f); paint(); onPick?.(f); } }, FREQUENCY_TITLE[f]));
  }
  paint();
  return row;
}

function noticeRow(onInstall, close) {
  const slot = h('div', { class: 'notice-slot' });
  const row = (main, sub, onClick) => (onClick
    ? h('button', { class: 'row-btn', onClick }, h('span', { class: 'row-main' }, main), h('span', { class: 'row-sub' }, sub))
    : h('div', { class: 'row-btn static' }, h('span', { class: 'row-main' }, main), h('span', { class: 'row-sub' }, sub)));
  const paint = async () => {
    const state = pushState();
    if (state === 'needs-install') {
      slot.replaceChildren(row('도착 소식 받기', '홈 화면에 추가하면 알림을 받을 수 있어요', () => { close(); onInstall(); }));
    } else if (state === 'unsupported') {
      slot.replaceChildren(row('도착 소식 받기', '이 브라우저에선 알림을 받을 수 없어요'));
    } else if (state === 'denied') {
      slot.replaceChildren(row('알림이 막혀 있어요', '브라우저(또는 기기) 설정에서 몽돌 알림을 허용하면 다시 와요'));
    } else if (await isSubscribed()) {
      slot.replaceChildren(row('도착 소식 받는 중', '사진을 담은 다음 날 아침 8시에 톡! 누르면 알림을 꺼요', async () => {
        await disableNotices();
        toast('알림을 껐어요');
        paint();
      }));
    } else {
      slot.replaceChildren(row('도착 소식 켜기', '사진을 담은 다음 날 아침, 조약돌이 도착하면 알려 드려요', () => {
        enableNotices().then((ok) => { toast(ok ? '짠! 알림을 켰어요' : '알림을 켜지 못했어요'); paint(); });
      }));
    }
  };
  paint();
  return slot;
}

export async function openSettings({ onSample, onClear, onInstall, onTransfer }) {
  if (layers.has('settings')) return;
  layers.add('settings');
  const saved = await persistent();
  const close = () => {
    wrap.classList.remove('in');
    setTimeout(() => { wrap.remove(); layers.remove('settings'); }, 300);
  };
  const share = async () => {
    const url = location.href.split(/[?#]/)[0];
    const text = '찍을 땐 색을 숨겨 뒀다가, 하루가 닫히면 그날 색으로 빚은 조약돌이 도착하는 앱이래! 너도 한 번 해 볼래?';
    try {
      if (navigator.share) { await navigator.share({ title: '몽돌', text, url }); return; }
      await navigator.clipboard.writeText(`${text} ${url}`);
      toast('주소를 복사했어요! 친구에게 톡 보내 주세요');
    } catch { /* 취소는 조용히 */ }
  };
  const sheet = h('section', { class: 'mini-sheet set-sheet', role: 'dialog', 'aria-modal': 'true', 'aria-label': '설정' },
    h('div', { class: 'topbar' }, closePill(close)),
    h('h2', { class: 'mini-title' }, '몽돌 서랍'),
    h('p', { class: 'set-label' }, '알림'),
    noticeRow(onInstall, close),
    h('p', { class: 'set-label sub' }, '사진이 없는 날 알림'),
    frequencyChips(),
    h('p', { class: 'fine tight' }, '아침과 노을 무렵에 가볍게. 담은 날은 오지 않아요.'),
    h('p', { class: 'set-label' }, '몽돌'),
    h('button', { class: 'row-btn', onClick: () => { close(); onSample(); } },
      h('span', { class: 'row-main' }, '견본 하루 채우기'), h('span', { class: 'row-sub' }, '그림 사진으로 지난 하루들을 채워서 바로 둘러봐요')),
    canOfferInstall() ? h('button', { class: 'row-btn', onClick: () => { close(); onInstall(); } },
      h('span', { class: 'row-main' }, '홈 화면에 추가하기'), h('span', { class: 'row-sub' }, '아이콘 한 번에 앱처럼 톡 열려요')) : null,
    h('button', { class: 'row-btn', onClick: () => { close(); onTransfer(); } },
      h('span', { class: 'row-main' }, '기록 옮기기'), h('span', { class: 'row-sub' }, '코드 하나로 홈 화면 몽돌이나 새 기기에 기록을 옮겨요')),
    h('button', { class: 'row-btn', onClick: share },
      h('span', { class: 'row-main' }, '친구에게도 해보라고 하기'), h('span', { class: 'row-sub' }, '내 조약돌 말고, 몽돌을 건네요')),
    h('button', { class: 'row-btn danger', onClick: async () => {
      const ok = await confirmDialog({ title: '기록을 전부 지울까요?', body: '이 브라우저에 담은 사진과 조약돌이 모두 사라져요. 되돌릴 수 없어요.', yes: '지울게요', no: '그냥 둘래요' });
      if (ok) { close(); onClear(); }
    } }, h('span', { class: 'row-main' }, '기록 전부 지우기')),
    h('p', { class: 'fine' }, saved
      ? '사진·색·기록은 이 기기 브라우저 안(IndexedDB)에만 있어요. 알림을 켜면 알림 시각만 서버로 가요. 기록 옮기기를 쓸 때만, 폰에서 암호화한 기록이 10분 동안 서버를 거쳐요.'
      : '이 환경에선 기기 저장소를 못 열어서, 창을 닫으면 기록이 사라져요. 정적 서버(http://)로 열어 주세요.'),
    h('p', { class: 'fine num' }, `조약돌 렌더러 · ${rendererInfo()}`));
  const wrap = h('div', { class: 'sheet-wrap' }, sheet);
  wrap.addEventListener('click', (e) => { if (e.target === wrap) close(); });
  layerRoot().append(wrap);
  requestAnimationFrame(() => wrap.classList.add('in'));
}
