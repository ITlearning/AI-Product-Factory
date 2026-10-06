// 온보딩 — 원본 여섯 장(OnboardingSteps.swift) 가운데 웹에서 뜻이 있는 셋만: 소개 → 찍는 법 → 시작.
// 웹에만 있는 한 장: 소개 다음 「홈 화면에 추가」(홈 화면 앱으로 열었거나 데스크톱이면 건너뜀).
// 홈 화면 앱(standalone)이고 웹 푸시가 되면 iOS 처럼 「도착 소식」(권한 미정일 때만) · 「사진이 없는 날」 두 장이 찍는 법 앞에 낀다.
// 첫 장의 「쓰던 기록 가져오기」 — 홈 화면 몽돌은 Safari 와 저장소가 따로라, 코드로 기록을 받으면 온보딩을 바로 마친다.
// 한 번만 뜬다(다시 부르는 「도움말」 없음 — 원본 §1.5). 확인용으로만 ?onboarding 을 붙이면 다시 뜬다.
import { h, layers, layerRoot } from './dom.js';
import { pebbleNode, dashedPebbleNode } from './pebble-gl.js';
import { flowerEl, flowerSVG, PETAL_COLORS, reduceMotion, sprinkle } from './flowers.js';
import { animateSpring } from './motion.js';
import { canOfferInstall, installGuide, isStandalone } from './install.js';
import { pushSupported, enableNotices, getFrequency } from './push.js';
import { frequencyChips } from './settings.js';
import { BODY } from './notice.js';

const SAMPLE = (() => {
  const base = 1758000000000;
  return ['#E7B98A', '#9DB7CF', '#D98F7A'].map((hex, i) => ({ id: `ob-${i}`, capturedAt: base + i * 9000e3, colorHex: hex, dayKey: '2025-09-16' }));
})();

function introScene() {
  const scene = h('div', { class: 'ob-scene intro' });
  const blooms = h('div', { class: 'ob-blooms' },
    ...SAMPLE.map((m, i) => h('span', { class: 'ob-bloom', style: {
      background: `radial-gradient(closest-side, ${m.colorHex}88, ${m.colorHex}00)`,
      left: `calc(50% - 120px + ${(i - 1) * 46}px)`, top: `calc(50% - 120px + ${(i % 2) * 24 - 12}px)`,
    } })));
  const roll = h('div', { class: 'ob-roll' }, pebbleNode({ moments: SAMPLE, dayKey: '2025-09-16', height: 150, glow: 'hero', lazy: false }));
  const petals = h('div', { class: 'ob-flowers' });
  scene.append(blooms, roll, petals);
  const rm = reduceMotion();
  roll.animate([
    { transform: rm ? 'none' : 'translateX(-260px) rotate(-150deg)', opacity: 0 },
    { transform: 'translateX(0) rotate(0deg)', opacity: 1 },
  ], { duration: rm ? 600 : 1600, delay: 250, easing: 'cubic-bezier(.15,.7,.3,1)', fill: 'both' });
  blooms.querySelectorAll('.ob-bloom').forEach((b) => b.animate(
    [{ transform: 'scale(.3)', opacity: 0 }, { transform: 'scale(1.15)', opacity: 1 }],
    { duration: rm ? 600 : 2400, delay: rm ? 250 : 1500, easing: 'ease-out', fill: 'both' }));
  const n = 7;
  for (let i = 0; i < n; i++) {
    const a = -Math.PI * 0.95 + (i / (n - 1)) * Math.PI * 0.9;
    const size = 18 + (i % 3) * 6;
    const kind = i % 3 === 0 ? 'spark' : i % 2 ? 'five' : 'daisy';
    const f = flowerEl({ size, kind, color: kind === 'spark' ? '#FFD84D' : PETAL_COLORS[i % 7], rot: i * 30 });
    f.style.left = `calc(50% + ${Math.cos(a) * 118 - size / 2}px)`;
    f.style.top = `calc(50% + ${Math.sin(a) * 104 + 40 - size / 2}px)`;
    petals.append(f);
    animateSpring(f, (p) => ({ transform: `scale(${p})`, opacity: Math.min(1, p * 2) }), { response: 0.45, damping: 0.5, delay: (rm ? 0.4 : 2.1) + i * 0.08 });
  }
  return scene;
}

function howScene() {
  return h('div', { class: 'ob-scene how' },
    h('div', { class: 'ob-phone' },
      h('div', { class: 'ob-phone-screen' },
        h('span', { class: 'ob-mini-tab' }),
        h('span', { class: 'ob-tap-hand', html: flowerSVG({ size: 30, kind: 'five', color: '#FF8FB1', center: '#FFD84D' }) }),
        h('div', { class: 'ob-mini-cam' }, h('span', { class: 'ob-mini-shutter' })))),
    h('div', { class: 'ob-how-note' }, '톡!'));
}

function startScene() {
  const s = h('div', { class: 'ob-scene start' }, h('div', { class: 'ob-breathe' }, dashedPebbleNode(150)));
  sprinkle(s, 'ob-start', 10);
  return s;
}

const noteCard = (body, time) => h('div', { class: 'ob-note-card' },
  h('img', { src: './icons/icon-180.png', alt: '' }),
  h('div', null, h('b', null, '몽돌'), h('span', null, body)),
  h('time', null, time));

function arrivalPage() {
  return {
    scene: () => h('div', { class: 'ob-scene notice' },
      h('div', { class: 'ob-breathe' }, pebbleNode({ moments: SAMPLE, dayKey: '2025-09-16', height: 110, glow: 'hero', lazy: false })),
      noteCard(BODY.arrival, '오전 8:00')),
    title: '사진을 담은 다음 날 아침, 조약돌이 도착하면 톡! 하고 한 번 알려 드려요.',
    detail: '알림을 켜면 알림 시각만 서버로 가요. 사진·색·기록은 이 기기에만 있어요.',
    primary: '알려 주세요!',
    // 권한 창은 클릭 안에서 바로 띄운다 — 기다리지 않고 다음 장으로 넘어간다.
    onPrimary: (next) => { enableNotices(); next(); },
    secondary: '괜찮아요',
    onSecondary: (next) => next(),
  };
}

function reminderPage(followsArrival) {
  return {
    scene: () => h('div', { class: 'ob-scene notice' },
      noteCard(BODY.morning, '오전 9:00'),
      noteCard(BODY.evening, '노을 무렵')),
    title: `${followsArrival ? '그리고 사진이 없는 날엔' : '사진이 없는 날엔'} 아침이랑 노을 무렵에 살짝 알려 드릴게요!`,
    detail: '한 장이라도 담은 날은 안 와요. 설정에서 언제든 바꿀 수 있어요.',
    extra: () => [frequencyChips()],
    onPrimary: (next) => {
      if (getFrequency() !== 'off' && Notification.permission === 'default') enableNotices();
      next();
    },
  };
}

function installPage(hasRecords, carry) {
  const g = installGuide({ hasRecords, carry });
  return {
    scene: () => h('div', { class: 'ob-scene inst' }, g.scene),
    title: g.title,
    detail: g.detail,
    extra: () => [g.actions, g.note ? h('p', { class: 'inst-note' }, g.note) : null],
  };
}

export function showOnboarding({ onStart, onSample, onReceive, carry, hasRecords = false }) {
  layers.add('onboarding');
  const pages = [
    {
      scene: introScene,
      title: '찍을 땐 색을 꼭꼭 숨겨 뒀다가, 하루가 닫히면 그날 색으로 빚은 조약돌이 짠! 하고 도착해요.',
      detail: '안녕하세요, 몽돌이에요! 지나가다 눈에 걸린 색 한 점이면 충분해요.',
      secondary: onReceive ? (isStandalone() ? 'Safari에서 쓰던 기록 가져오기' : '쓰던 기록 가져오기') : null,
      onSecondary: () => onReceive(() => finish(false)),
    },
    {
      scene: howScene,
      title: '마음에 콕 박히는 순간이 오면 찰칵! 한 장이면 충분해요.',
      detail: '홈 아래 왼쪽 동그란 카메라 버튼을 톡 누르면 바로 찍거나 앨범에서 고를 수 있어요. 받은 조약돌은 「모은 조약돌」 탭에 모여요. 매일 안 와도 괜찮아요. 담고 싶은 날에만 담아도 조약돌은 차곡차곡 모여요.',
    },
    {
      scene: startScene,
      title: '준비 완료! 두근두근하죠?',
      detail: '오늘 담은 건 자정(새벽 4시)에 조약돌로 변신해요. 마음이 급하면 「오늘 마무리하고 조약돌 받기」로 먼저 받아도 돼요.',
    },
  ];
  if (canOfferInstall()) pages.splice(1, 0, installPage(hasRecords, carry));
  if (isStandalone() && pushSupported()) {
    const asks = Notification.permission === 'default';
    pages.splice(1, 0, ...(asks ? [arrivalPage()] : []), reminderPage(asks));
  }
  let index = 0;
  const track = h('div', { class: 'ob-track' });
  const dots = h('div', { class: 'ob-dots', 'aria-hidden': 'true' }, ...pages.map(() => h('span')));
  const primary = h('button', { class: 'btn primary' });
  const secondary = h('button', { class: 'btn ghost' });
  const back = h('button', { class: 'ob-back', 'aria-label': '이전' }, '이전');
  const root = h('section', { class: 'onboarding', role: 'dialog', 'aria-modal': 'true', 'aria-label': '몽돌 시작하기' },
    h('div', { class: 'ob-bg', 'aria-hidden': 'true' }),
    back,
    h('div', { class: 'ob-viewport' }, track),
    h('div', { class: 'ob-foot' }, dots, primary, secondary));
  const built = pages.map(() => null);

  const build = (i) => {
    if (built[i]) return built[i];
    const p = pages[i];
    const el = h('div', { class: 'ob-page' },
      i === 0 ? h('h1', { class: 'wordmark ob-mark' }, '몽돌', h('span', { class: 'wordmark-flower', html: flowerSVG({ size: 26, kind: 'five', color: '#FF8FB1', center: '#FFD84D', rot: 12 }) })) : null,
      p.scene(),
      h('div', { class: 'ob-words' }, h('p', { class: 'ob-title' }, p.title), h('p', { class: 'ob-detail' }, p.detail), p.extra?.()));
    built[i] = el;
    return el;
  };

  const go = (i) => {
    index = i;
    track.replaceChildren(build(i));
    track.firstChild.animate([{ opacity: 0, transform: 'translateX(24px)' }, { opacity: 1, transform: 'none' }], { duration: 380, easing: 'ease-out' });
    [...dots.children].forEach((d, k) => d.classList.toggle('on', k === i));
    back.style.visibility = i > 0 ? 'visible' : 'hidden';
    const last = i === pages.length - 1;
    const p = pages[i];
    primary.textContent = p.primary || (last ? '시작하기' : '다음');
    secondary.textContent = p.secondary || (last ? '견본 하루 채우고 둘러보기' : '');
    secondary.style.display = last || p.secondary ? '' : 'none';
  };

  const finish = (withSample) => {
    root.classList.add('out');
    setTimeout(() => {
      root.remove();
      layers.remove('onboarding');
      (withSample ? onSample : onStart)?.();
    }, 520);
  };
  const next = () => go(index + 1);
  primary.addEventListener('click', () => {
    const p = pages[index];
    if (p.onPrimary) p.onPrimary(next);
    else if (index < pages.length - 1) next();
    else finish(false);
  });
  secondary.addEventListener('click', () => (pages[index].onSecondary ? pages[index].onSecondary(next) : finish(true)));
  back.addEventListener('click', () => index > 0 && go(index - 1));

  layerRoot().append(root);
  go(0);
}
