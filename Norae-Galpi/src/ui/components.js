/**
 * 화면들이 같이 쓰는 조각들.
 */

import { el, artwork, icon } from './dom.js';
import { labelLine } from './labels.js';
import { setLike } from '../client/api.js';
import { markSongTransition } from './transition.js';
import { ensureKey } from '../client/device.js';

/**
 * 공통 헤더 — **일곱 화면 전부에 둔다.**
 *
 * `←`를 쓰지 않는다. 워드마크가 항상 홈으로 가는 명시적 경로다.
 * 피드↔상세 왕복이 헷갈리면 상세로 안 들어가고, **상세에 안 들어가면 노래를 아예 안 듣는다**
 * (재생이 ⑥에만 있으므로).
 *
 * 내 갈피는 탭바로 내려갔다 — 812px 화면의 우측 최상단은 엄지가 가장 안 닿는 자리다.
 * 워드마크만 남으니 헤더가 "지금 어디"를 말하는 일만 한다.
 *
 * @returns {HTMLElement}
 */
export function header() {
  return el('header', { className: 'header' }, [
    el('div', { className: 'header__inner' }, [
      el('a', { className: 'header__wordmark', href: '#/', text: '노래갈피' }),
    ]),
  ]);
}

const ICON_HOME = 'M4 10.3 12 4l8 6.3V19a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2z';
const ICON_WRITE = ['M12 3.6a8.4 8.4 0 1 1 0 16.8 8.4 8.4 0 0 1 0-16.8z', 'M12 8.3v7.4M8.3 12h7.4'];
const ICON_MARK = 'M7 3.6h10a1.4 1.4 0 0 1 1.4 1.4v15.4L12 16.3l-6.4 4.1V5A1.4 1.4 0 0 1 7 3.6z';

/**
 * 하단 탭바.
 *
 * **넣은 진짜 이유는 엄지가 아니라 CTA 다.** `나도 적기`가 카드마다 붙어서 피드 한 화면에
 * 같은 버튼이 열한 번 반복됐다. 적기로 가는 전역 입구가 없어서 생긴 일이다.
 * 가운데 `⊕` 하나가 그 자리를 전부 대신하고, 카드는 **읽는 일만 하는 물건**이 된다.
 *
 * 칸은 셋뿐이다. 인스타그램·네이버블로그가 다섯인 건 그만큼의 진입점이 있어서지
 * 다섯이 정답이라서가 아니다. 노래갈피의 진입점은 피드·적기·내 갈피 셋이고,
 * 빈 칸을 채우려고 없는 화면을 만들지 않는다.
 *
 * `setCurrent(tab)` 으로 갱신한다 — 다시 그리지 않는다. 라우트가 바뀔 때마다 새로 만들면
 * 탭바가 매번 처음부터 나타나서, 화면만 갈리는 게 아니라 **바닥이 같이 깜빡인다.**
 *
 * @returns {HTMLElement & {setCurrent: (tab: string|null) => void}}
 */
export function tabBar() {
  const items = [
    { tab: 'home', href: '#/', label: '홈', d: ICON_HOME },
    { tab: 'write', href: '#/start', label: '적기', d: ICON_WRITE },
    { tab: 'mine', href: '#/mine', label: '내 갈피', d: ICON_MARK },
  ];

  const links = items.map((it) =>
    el('a', { className: 'tabbar__item', href: it.href }, [
      icon(it.d, { size: 24 }),
      el('span', { className: 'tabbar__label', text: it.label }),
    ]),
  );

  const nav = el('nav', {
    className: 'tabbar',
    attrs: { 'aria-label': '주요 화면' },
  }, [el('div', { className: 'tabbar__inner' }, links)]);

  nav.setCurrent = (tab) => {
    links.forEach((a, i) => {
      const on = items[i].tab === tab;
      // `aria-current` 는 스크린리더용이면서 CSS 선택자이기도 하다. 상태를 한 군데만 둔다.
      if (on) a.setAttribute('aria-current', 'page');
      else a.removeAttribute('aria-current');
    });
  };

  return nav;
}

/**
 * 곡 머리 — 앨범아트 + 제목 + 가수.
 *
 * @param {object} song
 * @param {{size?: number, as?: 'div'|'a', href?: string}} [opts]
 */
export function songHead(song, opts = {}) {
  const { size = 300, as = 'div', href } = opts;

  const children = [
    artwork(song.artwork_url ?? song.artworkUrl, 'song-head__art', size),
    el('div', {}, [
      el('p', { className: 'song-head__title', text: song.title }),
      el('p', { className: 'song-head__artist', text: song.artist }),
    ]),
  ];

  return as === 'a'
    ? el('a', { className: 'song-head card__link', href }, children)
    : el('div', { className: 'song-head' }, children);
}

/**
 * ♡ 버튼. **숫자를 절대 표시하지 않는다.**
 *
 * 누군가의 진심이 `♡ 0`으로 박히면 안 된다. 서버도 개수를 안 주므로 그릴 방법 자체가 없다.
 * 스크린리더에는 상태가 말로 읽혀야 한다 — `aria-pressed` + 레이블.
 *
 * @param {{id: unknown, liked?: boolean}} memory
 */
export function heart(memory) {
  const btn = el('button', {
    className: 'heart',
    type: 'button',
    text: memory.liked ? '♥' : '♡',
    attrs: {
      'aria-pressed': String(Boolean(memory.liked)),
      'aria-label': memory.liked ? '좋아요 취소' : '좋아요',
    },
  });

  btn.addEventListener('click', async () => {
    const next = btn.getAttribute('aria-pressed') !== 'true';
    // 먼저 그리고 나중에 확인한다. 실패하면 되돌린다 — 손가락이 기다리지 않게.
    paint(next, true);
    try {
      // 좋아요도 신원이 필요하다 — 누가 눌렀는지로 중복을 막기 때문이다.
      // 글을 한 번도 안 쓴 사람은 키가 없어서 서버가 400 으로 돌려보내고,
      // 하트가 채워졌다 조용히 풀리기만 한다. 여기서 만든다.
      // "읽기만 하는 사람에게 신원을 발급하지 않는다"는 원칙과 어긋나지 않는다 —
      // 좋아요를 누른 사람은 읽기만 한 사람이 아니다.
      ensureKey();
      await setLike(memory.id, next);
    } catch {
      paint(!next);
    }
  });

  function paint(liked, punch = false) {
    btn.textContent = liked ? '♥' : '♡';
    btn.setAttribute('aria-pressed', String(liked));
    btn.setAttribute('aria-label', liked ? '좋아요 취소' : '좋아요');
    if (!punch) return;
    // 되돌리기(실패) 때는 튀기지 않는다 — 실패를 성공처럼 연출하면 안 된다.
    btn.classList.remove('heart--punch');
    void btn.offsetWidth; // 같은 애니메이션을 다시 돌리려면 리플로우가 필요하다
    btn.classList.add('heart--punch');
  }

  return btn;
}

/**
 * 기억 한 편.
 *
 * 카드에서는 3줄 미리보기 + `더 보기`로 접는다. 화면에 글자수나 카운트다운을 두지 않는다 —
 * 길게 쓰는 사람을 막지 않는다.
 *
 * @param {object} memory
 * @param {{clamp?: boolean, showHeart?: boolean}} [opts]
 */
export function memoryBlock(memory, opts = {}) {
  const { clamp = true, showHeart = true } = opts;

  const body = el('p', {
    className: `memory__body${clamp ? ' memory__body--clamped' : ''}`,
    text: memory.body,
  });

  // 높이를 보간하려면 감쌀 것이 필요하다. line-clamp 자체는 트랜지션이 안 된다.
  const clip = clamp ? el('div', { className: 'memory__clip' }, [body]) : body;

  const more = clamp
    ? el('button', { className: 'memory__more', type: 'button', text: '더 보기' })
    : null;

  if (more) {
    more.addEventListener('click', () => expand(clip, body, more));
    // **실제로 넘칠 때만 보여준다.** 세 줄이 안 되는 글에도 `더 보기`가 붙으면
    // 눌러도 아무 일이 없고, 짧게 쓴 글이 뭔가 잘린 것처럼 보인다.
    // 시드 11편 중 6편이 100자 안쪽이라 흔한 경우다.
    more.hidden = true;
    queueMicrotask(() => {
      // **최소 한 줄은 더 나올 때만** 탭을 요구한다. `+ 1` 이면 세 줄을 한 글자만 넘겨도
      // `더 보기`가 붙어서, 눌러봐야 두 글자가 더 나온다. 모바일 세 줄이 약 73자인데
      // 시드 하한이 70자라 드문 경우가 아니다.
      const line = parseFloat(getComputedStyle(body).lineHeight) || 0;
      more.hidden = body.scrollHeight <= body.clientHeight + line;
    });
  }

  const labels = labelLine(memory);

  return el('article', { className: 'memory' }, [
    clip,
    more,
    el('div', { className: 'memory__foot' }, [
      el('span', { className: 'memory__labels', text: labels }),
      showHeart ? heart(memory) : null,
    ]),
  ]);
}

/**
 * 접힌 글을 펼친다. 세 줄에서 전문까지 **높이가 자란다.**
 *
 * 순서가 중요하다 — 접힌 높이를 먼저 재고, clamp 를 풀어 전체 높이를 잰 다음,
 * 접힌 높이로 되돌려 놓고 한 프레임 뒤에 전체 높이로 보낸다.
 * 바로 auto 로 두면 브라우저가 보간할 시작값이 없어 그냥 튄다.
 *
 * @param {HTMLElement} clip
 * @param {HTMLElement} body
 * @param {HTMLElement} more
 */
function expand(clip, body, more) {
  const from = clip.getBoundingClientRect().height;
  body.classList.remove('memory__body--clamped');
  const to = clip.scrollHeight;
  more.remove();

  clip.style.height = `${from}px`;
  requestAnimationFrame(() => {
    clip.classList.add('memory__clip--animating');
    clip.style.height = `${to}px`;
  });

  // 끝나면 높이 고정을 푼다. px 로 박아두면 창 폭이 바뀔 때 글이 잘린다.
  const settle = () => {
    clip.classList.remove('memory__clip--animating');
    clip.style.height = '';
  };
  clip.addEventListener('transitionend', settle, { once: true });
  // prefers-reduced-motion 이면 트랜지션이 0.01ms 라 transitionend 가 안 올 수 있다.
  setTimeout(settle, 900);
}

/**
 * 곡 카드 — 피드의 단위. **iframe 을 하나도 깔지 않는다.**
 * 듣는 일은 전부 ⑥으로 옮겨져 있고, 그래서 피드가 훨씬 가볍다.
 *
 * @param {{song: object, memories: object[]}} card
 */
export function songCard(card) {
  const href = `#/song/${card.song.id}`;
  const head = songHead(card.song, { as: 'a', href, size: 150 });

  // ⑥ 으로 들어갈 때 앨범아트가 이어지도록, 떠나기 직전 위치와 곡 요약을 적어둔다.
  // 피드는 이미 제목·가수·아트워크·영상 ID 를 다 갖고 있어서 ⑥ 이 fetch 를 안 기다려도 된다.
  head.addEventListener('click', () => {
    markSongTransition(card.song.id, head.querySelector('.song-head__art'), card.song);
  });

  // 카드가 보여주는 것보다 기억이 더 있을 때만 꼬리를 단다.
  // **`♡ 705` 와 `기억 5편`은 다른 종류의 숫자다.** 앞은 경쟁을 만들고 뒤는 분량만 알려준다 —
  // 들어가기 전에 "이건 긴 거구나"를 아는 것은 읽는 사람의 편의지 인기 지표가 아니다.
  const hidden = (card.total ?? card.memories.length) - card.memories.length;
  const rest = hidden > 0
    ? el('a', { className: 'card__rest', href }, [
        el('span', { text: `기억 ${card.total}편 모두 보기` }),
        el('span', { className: 'card__rest-chev', attrs: { 'aria-hidden': 'true' }, text: '→' }),
      ])
    : null;

  if (rest) {
    rest.addEventListener('click', () => {
      markSongTransition(card.song.id, head.querySelector('.song-head__art'), card.song);
    });
  }

  // `나도 적기`는 여기 없다. 피드 한 화면에 같은 버튼이 열한 번 반복되던 자리이고,
  // 이제 탭바 `⊕` 가 그 일을 한다. 곡을 정해 쓰는 입구는 ⑥ 에 하나만 있다 —
  // **노래를 듣고 나서 쓰게 되는 순서**가 설계 의도이기도 하다.
  return el('section', { className: 'card' }, [
    head,
    el('div', { className: 'card__memories' }, card.memories.map((m) => memoryBlock(m))),
    rest,
  ]);
}

/**
 * 빈 상태. **기능이다.** 마지막 탈출구(`다른 계절 보기 →`)가 없으면
 * 사용자가 서비스 전체가 빈 줄 안다.
 *
 * @param {{line: string, action?: {label: string, href: string}, escape?: {label: string, onClick: () => void}}} spec
 */
export function emptyState(spec) {
  return el('div', { className: 'empty' }, [
    el('p', { className: 'empty__line', text: spec.line }),
    spec.action ? el('a', { className: 'btn btn--primary', href: spec.action.href, text: spec.action.label }) : null,
    spec.escape
      ? el('button', {
          className: 'empty__escape',
          type: 'button',
          text: spec.escape.label,
          on: { click: spec.escape.onClick },
        })
      : null,
  ]);
}

/**
 * 곡 카드 모양의 스켈레톤. 글자 한 줄 대신 **들어올 자리를 미리 잡아둔다.**
 *
 * Neon 이 5분 비활성이면 잠들어서 콜드스타트가 실재한다. 그 시간이 빈 화면이면
 * 길게 느껴지고, 내용이 도착할 때 레이아웃이 통째로 튄다.
 *
 * `aria-hidden` 으로 감춘다 — 스크린리더에 "빈 상자 여섯 개"를 읽어줄 이유가 없다.
 *
 * @param {number} [count] - 카드 수
 * @returns {HTMLElement}
 */
export function skeletonFeed(count = 2) {
  const cards = [];
  for (let i = 0; i < count; i++) {
    cards.push(
      el('section', { className: 'card' }, [
        el('div', { className: 'song-head' }, [
          el('div', { className: 'sk sk--art' }),
          el('div', { style: 'flex:1' }, [
            el('div', { className: 'sk sk--line', style: 'width:56%' }),
            el('div', { className: 'sk sk--line', style: 'width:32%;height:11px;margin-top:7px' }),
          ]),
        ]),
        el('div', { className: 'card__memories' }, [
          el('div', { className: 'sk sk--line', style: 'margin-top:4px' }),
          el('div', { className: 'sk sk--line', style: 'margin-top:8px;width:88%' }),
          el('div', { className: 'sk sk--line', style: 'margin-top:8px;width:54%' }),
        ]),
      ]),
    );
  }
  return el('div', { attrs: { 'aria-hidden': 'true' } }, cards);
}

/**
 * ⑥ 곡 상세에서 기억이 도착하기 전 자리.
 *
 * @param {number} [count]
 * @returns {HTMLElement}
 */
export function skeletonMemories(count = 3) {
  const blocks = [];
  for (let i = 0; i < count; i++) {
    blocks.push(
      el('article', { className: 'memory' }, [
        el('div', { className: 'sk sk--line' }),
        el('div', { className: 'sk sk--line', style: 'margin-top:8px;width:92%' }),
        el('div', { className: 'sk sk--line', style: `margin-top:8px;width:${60 - i * 8}%` }),
      ]),
    );
  }
  return el('div', { className: 'card__memories', attrs: { 'aria-hidden': 'true' } }, blocks);
}

/**
 * 시트(모달). ④ 공개 확인과 복구 코드가 쓴다.
 *
 * 포커스를 가두고 Esc 로 닫는다. 백드롭 클릭으로도 닫되,
 * **올리기 같은 되돌릴 수 없는 동작은 백드롭으로 실행되지 않는다** — 취소만 된다.
 *
 * @param {{title: string, children: Node[], onClose: () => void}} spec
 */
export function sheet(spec) {
  const panel = el('div', {
    className: 'sheet',
    attrs: { role: 'dialog', 'aria-modal': 'true', 'aria-label': spec.title },
  }, [el('h2', { className: 'sheet__title', text: spec.title }), ...spec.children]);

  const backdrop = el('div', { className: 'sheet-backdrop' }, [panel]);

  /**
   * 열기. **`@keyframes` 가 아니라 `transition` 이다.**
   *
   * keyframes 는 시작값이 0 으로 고정돼 있어서, 올라오는 도중에 닫으면
   * "닫기" 애니메이션이 **완전히 열린 위치에서 다시 시작**한다. 실제로 Y=177 에서 끊으면
   * 시트가 Y=0 까지 튀어올랐다가 내려갔다. transition 은 지금 값에서 재조준하므로
   * 어디서 끊든 그 자리에서 이어진다 — iOS 가 부드럽게 느껴지는 이유의 절반이 이거다.
   * (Sonner 를 만든 Emil Kowalski 가 정확히 이 이유로 keyframes 를 걷어냈다.)
   *
   * 켜는 시점이 까다롭다. 이 함수는 시트를 **만들기만** 하고 붙이는 건 부르는 쪽이라,
   * 여기서 바로 켜면 아직 문서에 없어서 시작값이 없다. 그렇다고 `requestAnimationFrame`
   * 한 번으로는 모자란다 — rAF 콜백은 스타일 계산 **앞**에 돌아서 "붙는 것"과 "켜는 것"이
   * 한 프레임에 합쳐지고, 시트가 트랜지션 없이 툭 나타난다.
   * 강제로 한 번 계산시켜 닫힌 상태를 확정한 뒤에 켠다.
   */
  requestAnimationFrame(() => {
    void backdrop.offsetWidth;
    backdrop.classList.add('sheet-backdrop--open');
  });

  /**
   * 내려가는 것도 보여준다. 올라올 때만 애니메이션하고 사라질 때 툭 없어지면
   * 절반만 만든 것처럼 읽힌다.
   *
   * @returns {Promise<void>}
   */
  backdrop.dismiss = () =>
    new Promise((resolve) => {
      backdrop.classList.remove('sheet-backdrop--open');
      let settled = false;
      const done = () => {
        if (settled) return;
        settled = true;
        backdrop.remove();
        resolve();
      };
      // 백드롭 opacity 와 시트 transform 이 같이 끝난다. **시트 쪽만** 듣는다 —
      // 둘 중 짧은 쪽이 먼저 끝나면 시트가 아직 내려가는 중에 DOM 에서 사라진다.
      panel.addEventListener('transitionend', (e) => {
        if (e.propertyName === 'transform') done();
      });
      // prefers-reduced-motion 이면 0.01ms 라 transitionend 를 못 받을 수 있다.
      setTimeout(done, 600);
    });

  backdrop.addEventListener('click', (e) => {
    if (e.target === backdrop) spec.onClose();
  });
  backdrop.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') spec.onClose();
  });

  // 열리자마자 시트 안으로 포커스를 넣는다. 안 그러면 스크린리더가 뒤 화면을 계속 읽는다.
  queueMicrotask(() => {
    const focusable = panel.querySelector('button, [href], textarea, input');
    (focusable ?? panel).focus?.();
  });

  return backdrop;
}
