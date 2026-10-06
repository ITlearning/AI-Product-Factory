// 진입 — HomeShell 역할: 홈·카메라·겹을 잇고, 가려진 게 없을 때 증정을 띄운다.
import { store } from './store.js';
import { createHome } from './home.js';
import { createCapture } from './capture.js';
import { openDay } from './detail.js';
import { showCeremony } from './ceremony.js';
import { openHandful } from './handful.js';
import { showOnboarding } from './onboarding.js';
import { openSettings } from './settings.js';
import { fillSample } from './sample.js';
import { warmUp } from './pebble-gl.js';
import { layers, toast, confirmDialog } from './dom.js';
import { meta } from './db.js';
import { forgetURLs } from './images.js';
import { T } from './copy.js';
import { sprinkle, flowerSVG } from './flowers.js';
import { now, isShifted, isDebug } from './clock.js';

let home, capture;
let sampling = false;

async function finishToday(key) {
  // 이미 저절로 닫혔으면(04시 넘김) 원본처럼 그냥 시트를 닫는다.
  if (!store.canClose(key)) return true;
  const ok = await confirmDialog({ title: T.confirmTitle, body: T.confirmBody, yes: T.confirmYes, no: T.confirmNo });
  if (!ok) return false;
  // 확인창이 떠 있는 사이 04시가 넘어 이미 저절로 닫혔을 수 있다 — 그땐 그냥 닫는다.
  if (store.canClose(key)) store.close(key);
  return true;
}

async function runSample() {
  if (sampling) return;
  sampling = true;
  toast('견본 하루를 그리는 중이에요…', 60000);
  try {
    const filled = await fillSample(store, (done, total) => toast(`견본 하루를 그리는 중이에요… ${done}/${total}`, 60000));
    if (filled === false) { toast('견본은 그리다 말았어요'); return; }
    meta.set('onboarded', true);
    toast('짠! 견본 하루가 채워졌어요');
    home.scrollToTop();
  } catch (e) {
    console.error(e);
    toast('앗, 견본을 못 채웠어요. 다시 한 번 눌러 주세요');
  } finally {
    sampling = false;
    setTimeout(maybeCeremony, 300);
  }
}

async function clearAll() {
  await store.clear();
  forgetURLs();
  toast('깨끗해졌어요! 새로 시작해 봐요');
}

const app = {
  openDay: (key) => openDay(key, { onFinish: finishToday }),
  openHandful: (month) => openHandful(month),
  openCamera: () => capture.open(),
  fillSample: runSample,
  finishToday: (key) => finishToday(key),
};

// 원본 DayGiftPresenter — 가려진 게 하나라도 있으면 미룬다. 하루에 여러 날이 밀려 있어도 가장 최근 하루만.
let presentTimer = 0;
function maybeCeremony() {
  // 창이 가려져 있으면 예약하지 않는다 — 다시 보일 때(visibilitychange) 띄운다.
  if (presentTimer || sampling || document.hidden) return;
  if (layers.blocking || !store.pendingGift()) return;
  presentTimer = setTimeout(() => {
    presentTimer = 0;
    if (layers.blocking || sampling || document.hidden) return;
    const key = store.pendingGift();
    if (key) showCeremony(key, (k) => store.markGifted(k));
  }, 380);
}

let renderQueued = false;
function queueRender() {
  if (renderQueued) return;
  renderQueued = true;
  requestAnimationFrame(() => { renderQueued = false; home.render(); });
}

function updateSwipeHint() {
  document.getElementById('swipe-hint').hidden = meta.get('swiped', false) || !store.loaded;
}

async function boot() {
  sprinkle(document.getElementById('bg-flowers'), 'home-bg', 18);
  document.querySelector('#swipe-hint .hint-flower').innerHTML = flowerSVG({ size: 16, kind: 'five', color: '#FF8FB1', center: '#FFD84D' });
  warmUp();
  home = createHome(app);
  capture = createCapture({ onSwiped: updateSwipeHint });
  document.getElementById('settings-btn').addEventListener('click', () => openSettings({ onSample: runSample, onClear: clearAll }));
  document.getElementById('swipe-hint').addEventListener('click', () => capture.open());

  store.addEventListener('change', () => { queueRender(); setTimeout(maybeCeremony, 0); });
  layers.onClose(() => setTimeout(maybeCeremony, 0));

  await store.load();
  updateSwipeHint();
  home.render();

  const forceOnboarding = new URLSearchParams(location.search).has('onboarding');
  if (forceOnboarding || (!meta.get('onboarded', false) && store.isEmpty)) {
    showOnboarding({
      onStart: () => meta.set('onboarded', true),
      onSample: () => { meta.set('onboarded', true); runSample(); },
    });
  } else {
    maybeCeremony();
  }

  // 새벽 4시를 넘기면 오늘이 바뀐다 — 켜 둔 채로 넘겨도 홈과 증정이 따라온다.
  let lastToday = store.todayKey;
  setInterval(() => {
    if (store.todayKey !== lastToday) { lastToday = store.todayKey; home.render(); maybeCeremony(); }
  }, 20000);
  document.addEventListener('visibilitychange', () => { if (!document.hidden) { home.render(); maybeCeremony(); } });
  let lastW = innerWidth;
  addEventListener('resize', () => { if (Math.abs(innerWidth - lastW) > 30) { lastW = innerWidth; queueRender(); } });

  if (isDebug()) window.__mongdol = { store, ready: true };
  if (isShifted()) {
    // 시각을 옮긴 미리 보기 — 기록은 따로 담긴다(db.js). 헷갈리지 않게 표시만 한다.
    document.getElementById('stage').append(Object.assign(document.createElement('div'), {
      className: 'preview-badge', textContent: `미리 보기 시각 · ${new Date(now()).toLocaleString('ko-KR', { month: 'numeric', day: 'numeric', hour: '2-digit', minute: '2-digit' })}`,
    }));
  }
  document.documentElement.classList.add('booted');
}

boot().catch((e) => {
  console.error(e);
  const f = document.getElementById('boot-fail');
  if (f) { f.hidden = false; f.querySelector('code').textContent = String(e && e.message || e); }
});
