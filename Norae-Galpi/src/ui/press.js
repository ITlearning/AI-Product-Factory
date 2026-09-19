/**
 * 누름 피드백.
 *
 * **비대칭 타이밍이 전부다.** 눌릴 때는 80ms 로 즉시 수축하고, 뗄 때는 스프링으로
 * 천천히 돌아온다. 양쪽을 같은 시간으로 맞추면 고무처럼 물렁하게 읽히고,
 * 반대로 걸면 굼떠 보인다. iOS 가 "부드럽다"고 느껴지는 건 이징이 예뻐서가 아니라
 * **손가락이 닿는 순간** 화면이 먼저 반응하기 때문이다. 그 전까지 이 제품은
 * 전부 손을 뗀 뒤에 색만 바뀌었다.
 *
 * `:active` 를 안 쓴다 — iOS Safari 는 스크롤 의도를 판정하느라 touchstart 에서
 * 즉시 걸어주지 않는다. 포인터 이벤트는 바로 온다.
 *
 * 노드마다 감싸지 않고 **위임 한 번으로 끝낸다.** 누를 수 있는 것은 화면 일곱에 흩어져
 * 있고 대부분 fetch 뒤에 생긴다. 만드는 자리마다 등록하면 한 군데를 빠뜨리는 날이 오고,
 * 그때 생기는 버그는 "저 버튼만 안 눌리는 느낌"이라 아무도 신고하지 않는다.
 */

/**
 * 누름이 걸리는 것들. CSS 의 기본 트랜지션도 **같은 목록**을 쓴다 —
 * 한쪽에만 추가하면 수축은 하는데 안 돌아오거나, 그 반대가 된다.
 */
export const PRESSABLE =
  '.btn, .chip, .tabbar__item, .card__link, .card__rest, .card__add, .memory__more';

/**
 * @param {Document|HTMLElement} [root]
 * @returns {() => void} 해제
 */
export function installPress(root = document) {
  /** @type {Element|null} */
  let held = null;

  const down = (e) => {
    // 주 버튼만. 오른쪽 클릭에 화면이 반응하면 눌린 것처럼 보이고 아무 일도 안 일어난다.
    if (e.button != null && e.button !== 0) return;
    const node = e.target instanceof Element ? e.target.closest(PRESSABLE) : null;
    if (!node) return;
    held = node;
    node.classList.add('press--down');
  };

  // pointerup 만 듣고 끝내면, 목록을 훑다가 스크롤로 넘어간 손가락 밑에서
  // 수축이 영영 안 풀린다. 스크롤이 시작되면 브라우저가 `pointercancel` 을 보내준다.
  const release = () => {
    if (!held) return;
    held.classList.remove('press--down');
    held = null;
  };

  root.addEventListener('pointerdown', down, { passive: true });
  for (const ev of ['pointerup', 'pointercancel']) {
    root.addEventListener(ev, release, { passive: true });
  }
  // 포인터가 창 밖으로 나가면 pointerup 이 안 온다.
  window.addEventListener('blur', release);

  return () => {
    root.removeEventListener('pointerdown', down);
    for (const ev of ['pointerup', 'pointercancel']) root.removeEventListener(ev, release);
    window.removeEventListener('blur', release);
  };
}
