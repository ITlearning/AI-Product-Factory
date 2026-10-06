// 홈 화면에 추가 안내 — 환경마다 다른 길(iPhone Safari · 앱 안 브라우저 · Android · 데스크톱)을 고른다.
// iOS 웹 푸시는 홈 화면 앱에서만 된다 — 설정의 「도착 소식 받기」가 이 시트로 이어진다.
import { h, layers, layerRoot, closePill, toast } from './dom.js';

const UA = navigator.userAgent || '';
const IN_APP = /KAKAOTALK|Instagram|FBAN|FBAV|FB_IAB|\bLine\/|NAVER\(inapp|DaumApps|everytimeApp|BAND\//i;

// 홈 화면에 둔 몽돌인지 — iOS 는 navigator.standalone 만 믿을 수 있을 때가 있다.
export const isStandalone = () =>
  navigator.standalone === true || (typeof matchMedia === 'function' && matchMedia('(display-mode: standalone)').matches);

const isIOS = () => /iPhone|iPad|iPod/.test(UA) || (/Macintosh/.test(UA) && navigator.maxTouchPoints > 1);
const isAndroid = () => /Android/.test(UA);

/** 'standalone' | 'ios-inapp' | 'android-inapp' | 'ios' | 'android' | 'desktop' */
export function installEnv() {
  if (isStandalone()) return 'standalone';
  if (isIOS()) return IN_APP.test(UA) ? 'ios-inapp' : 'ios';
  if (isAndroid()) return IN_APP.test(UA) || /; wv\)/.test(UA) ? 'android-inapp' : 'android';
  return 'desktop';
}

// Chrome 의 설치 창 — 페이지 뜨자마자 올 수 있어서 모듈을 읽을 때부터 붙잡아 둔다.
let deferred = null;
const waiters = new Set();
addEventListener('beforeinstallprompt', (e) => {
  e.preventDefault();
  deferred = e;
  for (const fn of waiters) fn();
});
addEventListener('appinstalled', () => {
  deferred = null;
  for (const fn of waiters) fn();
});

export const hasPrompt = () => deferred != null;

/** 온보딩에 안내 장을 넣을지 · 설정에 항목을 둘지 */
export const canOfferInstall = () => {
  const env = installEnv();
  return env !== 'standalone' && (env !== 'desktop' || hasPrompt());
};

async function promptInstall() {
  const e = deferred;
  if (!e) return false;
  deferred = null;
  try {
    await e.prompt();
    const { outcome } = await e.userChoice;
    if (outcome === 'accepted') toast('짠! 홈 화면에 몽돌이 생겼어요');
    return outcome === 'accepted';
  } catch {
    return false;
  } finally {
    for (const fn of waiters) fn();
  }
}

const pageURL = () => location.href.split(/[?#]/)[0];

async function copyURL() {
  try {
    await navigator.clipboard.writeText(pageURL());
    toast('주소를 복사했어요! Safari 주소창에 붙여 넣어 주세요');
  } catch {
    toast('복사가 막혔어요. 아래 주소를 꾹 눌러 복사해 주세요');
  }
}

const ICON = {
  share: '<svg width="26" height="26" viewBox="0 0 26 26" aria-hidden="true"><path d="M9 9.5H7.5A1.5 1.5 0 0 0 6 11v10a1.5 1.5 0 0 0 1.5 1.5h11A1.5 1.5 0 0 0 20 21V11a1.5 1.5 0 0 0-1.5-1.5H17" fill="none" stroke="#2F7BF6" stroke-width="1.9" stroke-linecap="round"/><path d="M13 3.5v12M9 7.4l4-3.9 4 3.9" fill="none" stroke="#2F7BF6" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/></svg>',
  add: '<svg width="26" height="26" viewBox="0 0 26 26" aria-hidden="true"><rect x="4.5" y="4.5" width="17" height="17" rx="4.5" fill="none" stroke="currentColor" stroke-width="1.9"/><path d="M13 9v8M9 13h8" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/></svg>',
  done: '<span class="inst-key">추가</span>',
  more: '<svg width="26" height="26" viewBox="0 0 26 26" aria-hidden="true"><g fill="currentColor"><circle cx="13" cy="6.5" r="2.1"/><circle cx="13" cy="13" r="2.1"/><circle cx="13" cy="19.5" r="2.1"/></g></svg>',
  copy: '<svg width="26" height="26" viewBox="0 0 26 26" aria-hidden="true"><rect x="8.5" y="8.5" width="12" height="13" rx="3" fill="none" stroke="currentColor" stroke-width="1.9"/><path d="M5.5 16.5V7A2.5 2.5 0 0 1 8 4.5h7.5" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/></svg>',
  code: '<svg width="26" height="26" viewBox="0 0 26 26" aria-hidden="true"><rect x="3.5" y="7" width="19" height="12" rx="3.5" fill="none" stroke="currentColor" stroke-width="1.9"/><g fill="currentColor"><circle cx="8.5" cy="13" r="1.4"/><circle cx="13" cy="13" r="1.4"/><circle cx="17.5" cy="13" r="1.4"/></g></svg>',
  dots: '<svg width="26" height="26" viewBox="0 0 26 26" aria-hidden="true"><g fill="currentColor"><circle cx="6.5" cy="13" r="2.1"/><circle cx="13" cy="13" r="2.1"/><circle cx="19.5" cy="13" r="2.1"/></g></svg>',
};

const step = (n, icon, text, sub) => h('li', { class: 'inst-step' },
  h('span', { class: 'inst-num num' }, n),
  h('span', { class: 'inst-icon', html: icon }),
  h('span', { class: 'inst-text' }, text, sub ? h('small', null, sub) : null));

// 기록이 있는 브라우저에서만 맨 앞에 — 홈 화면 몽돌은 저장소가 따로라 코드로 기록을 데려간다(transfer.js).
const transferStep = (n, onTransfer) => h('li', { class: 'inst-step xfer-step' },
  h('button', { class: 'xfer-step-btn', onClick: onTransfer },
    h('span', { class: 'inst-num num' }, n),
    h('span', { class: 'inst-icon', html: ICON.code }),
    h('span', { class: 'inst-text' }, '지금까지 담은 기록 옮길 코드 받기', h('small', null, '홈 화면 몽돌을 처음 열 때 이 코드를 넣으면 기록이 따라와요'))));

const appIcon = () => h('img', { class: 'inst-app', src: './icons/icon-180.png', alt: '', width: 72, height: 72 });

/**
 * 환경에 맞는 안내 한 벌 — 온보딩 한 장과 설정 시트가 같이 쓴다.
 * hasRecords: 이 브라우저에 기록이 있는지(iPhone 은 홈 화면 앱과 저장소가 따로라 미리 알린다).
 * onTransfer: 있으면 기록이 있을 때 「① 기록 옮길 코드 받기」를 맨 앞에 둔다.
 */
export function installGuide({ hasRecords = false, onTransfer = null } = {}) {
  const env = installEnv();
  const title = '홈 화면에 몽돌을 두면 앱처럼 톡 열려요!';
  let scene, detail, note = null, actions = null;

  if (env === 'ios') {
    detail = '주소창 없이 화면 가득, 아이콘 한 번이면 바로 몽돌이에요. 조약돌 도착 알림도 홈 화면 몽돌에서 받을 수 있어요. Safari 에서 세 번만 톡톡톡!';
    const carry = hasRecords && onTransfer;
    const o = carry ? 1 : 0;
    scene = h('ol', { class: 'inst-steps' },
      carry ? transferStep(1, onTransfer) : null,
      step(1 + o, ICON.share, '아래(또는 위) 공유 버튼을 눌러요', '주소창 옆 「…」 메뉴 안에 있을 수도 있어요'),
      step(2 + o, ICON.add, '「홈 화면에 추가」를 골라요', '안 보이면 목록을 살짝 내려 봐요'),
      step(3 + o, ICON.done, '오른쪽 위 「추가」를 누르면 끝!'));
    note = carry
      ? '잠깐! iPhone 은 홈 화면 몽돌이 새로 시작해요. ①에서 받은 코드를 홈 화면 몽돌 첫 화면 「Safari에서 쓰던 기록 가져오기」에 넣으면 지금까지 담은 기록이 따라와요.'
      : hasRecords
        ? '잠깐! iPhone 은 홈 화면에서 열면 몽돌이 새로 시작해요. 지금까지 담은 건 이 Safari 에 그대로 남아 있어요.'
        : 'iPhone 은 홈 화면 몽돌과 Safari 몽돌이 기록을 따로 담아요. 한쪽에서만 써 주세요!';
  } else if (env === 'ios-inapp' || env === 'android-inapp') {
    const browser = env === 'ios-inapp' ? 'Safari' : 'Chrome';
    detail = `지금은 앱 속 브라우저라 바로는 못 둬요. ${browser}로 열어야 홈 화면에 추가할 수 있어요!`;
    scene = h('div', { class: 'inst-solo' }, appIcon(),
      h('ol', { class: 'inst-steps' },
        step(1, ICON.dots, `메뉴(… 또는 공유)에서 「${browser}로 열기」`, '「다른 브라우저로 열기」일 수도 있어요'),
        step(2, ICON.copy, `안 보이면 주소를 복사해서 ${browser}에 붙여 넣어요`)));
    actions = h('div', { class: 'inst-actions' },
      h('button', { class: 'btn primary inst-copy', onClick: copyURL }, '주소 복사하기'),
      h('p', { class: 'inst-url num' }, pageURL()));
    if (hasRecords) note = `${browser}에서 열면 몽돌이 새로 시작해요. 지금까지 담은 건 이 창에 그대로 남아요.`;
  } else {
    detail = env === 'desktop'
      ? '이 컴퓨터에도 앱처럼 둘 수 있어요. 그래도 몽돌은 휴대폰에서 찰칵할 때 제일 신나요!'
      : '주소창 없이 화면 가득, 아이콘 한 번이면 바로 몽돌이에요.';
    const slot = h('div', { class: 'inst-actions' });
    const fill = () => {
      slot.replaceChildren(hasPrompt()
        ? h('button', { class: 'btn primary inst-add', onClick: promptInstall }, '홈 화면에 추가')
        : h('ol', { class: 'inst-steps' },
          step(1, ICON.more, '오른쪽 위 ⋮ 메뉴를 눌러요'),
          step(2, ICON.add, '「홈 화면에 추가」 또는 「앱 설치」를 골라요', '이미 있으면 홈 화면에서 몽돌을 찾아 주세요')));
    };
    fill();
    waiters.add(fill);
    scene = h('div', { class: 'inst-solo' }, appIcon());
    actions = slot;
  }
  return { env, scene, title, detail, note, actions };
}

/** 설정에서 여는 안내 시트 */
export function openInstallSheet({ hasRecords = false, onTransfer = null } = {}) {
  if (layers.has('install')) return;
  layers.add('install');
  const g = installGuide({ hasRecords, onTransfer });
  const close = () => {
    wrap.classList.remove('in');
    setTimeout(() => { wrap.remove(); layers.remove('install'); }, 300);
  };
  const sheet = h('section', { class: 'mini-sheet inst-sheet', role: 'dialog', 'aria-modal': 'true', 'aria-label': '홈 화면에 추가하기' },
    h('div', { class: 'topbar' }, closePill(close)),
    h('h2', { class: 'mini-title' }, '홈 화면에 추가하기'),
    h('p', { class: 'inst-lead' }, g.title),
    h('p', { class: 'inst-detail' }, g.detail),
    g.scene, g.actions,
    g.note ? h('p', { class: 'inst-note' }, g.note) : null);
  const wrap = h('div', { class: 'sheet-wrap' }, sheet);
  wrap.addEventListener('click', (e) => { if (e.target === wrap) close(); });
  layerRoot().append(wrap);
  requestAnimationFrame(() => wrap.classList.add('in'));
}
