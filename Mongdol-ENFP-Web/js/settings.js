// 설정 — 견본 하루 · 친구에게도 해보기(도구 공유) · 전부 지우기. 결과 자랑용 공유는 없다.
import { h, layers, layerRoot, closePill, confirmDialog, toast } from './dom.js';
import { rendererInfo } from './pebble-gl.js';
import { persistent } from './db.js';

export async function openSettings({ onSample, onClear }) {
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
  const sheet = h('section', { class: 'mini-sheet', role: 'dialog', 'aria-modal': 'true', 'aria-label': '설정' },
    h('div', { class: 'topbar' }, closePill(close)),
    h('h2', { class: 'mini-title' }, '몽돌 서랍'),
    h('button', { class: 'row-btn', onClick: () => { close(); onSample(); } },
      h('span', { class: 'row-main' }, '견본 하루 채우기'), h('span', { class: 'row-sub' }, '그림 사진으로 지난 하루들을 채워서 바로 둘러봐요')),
    h('button', { class: 'row-btn', onClick: share },
      h('span', { class: 'row-main' }, '친구에게도 해보라고 하기'), h('span', { class: 'row-sub' }, '내 조약돌 말고, 몽돌을 건네요')),
    h('button', { class: 'row-btn danger', onClick: async () => {
      const ok = await confirmDialog({ title: '기록을 전부 지울까요?', body: '이 브라우저에 담은 사진과 조약돌이 모두 사라져요. 되돌릴 수 없어요.', yes: '지울게요', no: '그냥 둘래요' });
      if (ok) { close(); onClear(); }
    } }, h('span', { class: 'row-main' }, '기록 전부 지우기')),
    h('p', { class: 'fine' }, saved
      ? '사진과 기록은 전부 이 기기 브라우저 안(IndexedDB)에만 있어요. 어디로도 보내지 않아요.'
      : '이 환경에선 기기 저장소를 못 열어서, 창을 닫으면 기록이 사라져요. 정적 서버(http://)로 열어 주세요.'),
    h('p', { class: 'fine num' }, `조약돌 렌더러 · ${rendererInfo()}`));
  const wrap = h('div', { class: 'sheet-wrap' }, sheet);
  wrap.addEventListener('click', (e) => { if (e.target === wrap) close(); });
  layerRoot().append(wrap);
  requestAnimationFrame(() => wrap.classList.add('in'));
}
