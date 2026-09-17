/**
 * 화면 사이를 잇는 모션.
 *
 * ## 앨범아트 연속성 (FLIP)
 * 곡 카드를 탭해 ⑥ 곡 상세로 들어갈 때, 앨범아트가 **그 자리에서 이어진다.**
 * iOS 의 `matchedGeometryEffect` 와 같은 것이고, 방법은 FLIP —
 * 떠나는 쪽의 위치를 재두었다가(First) 도착지에 그려진 뒤(Last) 그 차이만큼
 * 되감아 놓고(Invert) 0 으로 푼다(Play).
 *
 * 덮어 그리는 유령 요소를 만들지 않고 **도착지 요소 자체**를 움직인다.
 * 유령을 띄우면 원본과 겹치는 한 프레임에서 깜빡이고, 이미지가 두 번 디코드된다.
 *
 * ## 곡 요약을 같이 넘긴다
 * 피드는 이미 곡의 제목·가수·아트워크·영상 ID 를 전부 갖고 있다. 그걸 같이 넘기면
 * ⑥ 이 fetch 를 기다리지 않고 **즉시** 곡 머리와 플레이어를 그릴 수 있다.
 * 모션이 자연스러워질 뿐 아니라 유튜브 iframe 이 왕복 한 번 먼저 뜬다.
 */

/** @type {{songId: string, rect: DOMRect, song: object, at: number}|null} */
let pending = null;

/** 이보다 오래된 건 버린다. 뒤로가기로 한참 뒤에 들어온 경우까지 되감으면 엉뚱하다. */
const MAX_AGE_MS = 1200;

/**
 * 떠나기 직전에 아트워크 위치와 곡 요약을 적어둔다.
 *
 * @param {string|number} songId
 * @param {Element|null} artEl - 피드 카드의 아트워크 (없으면 위치만 건너뛴다)
 * @param {object} song - 피드가 이미 가진 곡 요약
 */
export function markSongTransition(songId, artEl, song) {
  pending = {
    songId: String(songId),
    rect: artEl ? artEl.getBoundingClientRect() : null,
    song,
    at: Date.now(),
  };
}

/**
 * 도착지에서 꺼낸다. **한 번만 쓰인다** — 꺼내면 지운다.
 *
 * @param {string|number} songId
 * @returns {{rect: DOMRect|null, song: object}|null}
 */
export function takeSongTransition(songId) {
  const hit = pending;
  pending = null;
  if (!hit) return null;
  if (hit.songId !== String(songId)) return null;
  if (Date.now() - hit.at > MAX_AGE_MS) return null;
  return { rect: hit.rect, song: hit.song };
}

/**
 * 재둔 위치에서 현재 위치로 되감았다가 푼다.
 *
 * 움직임이 1px 도 안 되면 아무것도 하지 않는다 — 같은 자리에서 트랜지션을 거는 건
 * 낭비이고, 레이아웃이 같은 화면끼리는 실제로 그런 경우가 있다.
 *
 * @param {DOMRect|null} fromRect
 * @param {HTMLElement|null} toEl
 */
export function flipFrom(fromRect, toEl) {
  if (!fromRect || !toEl) return;

  const to = toEl.getBoundingClientRect();
  if (to.width === 0 || to.height === 0) return;

  const dx = fromRect.left - to.left;
  const dy = fromRect.top - to.top;
  const sx = fromRect.width / to.width;
  const sy = fromRect.height / to.height;

  if (Math.abs(dx) < 1 && Math.abs(dy) < 1 && Math.abs(sx - 1) < 0.01 && Math.abs(sy - 1) < 0.01) {
    return;
  }

  toEl.classList.add('art-flip');
  // Invert — 트랜지션 없이 출발 위치로 돌려놓는다.
  toEl.style.transition = 'none';
  toEl.style.transform = `translate(${dx}px, ${dy}px) scale(${sx}, ${sy})`;

  requestAnimationFrame(() => {
    // Play — 인라인 transition 을 지워 클래스의 스프링이 다시 먹게 한다.
    toEl.style.transition = '';
    toEl.style.transform = '';
  });

  // 끝나면 흔적을 지운다. z-index 가 남아 있으면 나중에 겹침이 이상해진다.
  const cleanup = () => {
    toEl.classList.remove('art-flip');
    toEl.style.transform = '';
    toEl.style.transition = '';
  };
  toEl.addEventListener('transitionend', cleanup, { once: true });
  // prefers-reduced-motion 이면 트랜지션이 0.01ms 라 transitionend 가 안 올 수 있다.
  setTimeout(cleanup, 900);
}
