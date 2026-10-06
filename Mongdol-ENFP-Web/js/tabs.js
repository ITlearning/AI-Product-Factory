// 아래 탭바(PageTabBar.swift) — 왼쪽 동그란 카메라 버튼, 캡슐은 홈 · 모은 조약돌.
// 웹은 가장자리 쓸기를 쓰지 않는다 — iOS Safari 의 「뒤로 가기」 몸짓과 겹친다. 버튼으로만 넘어간다.
const FOLD_TOP = 60;

export function createTabs({ onCamera, onReselect }) {
  const wrap = document.getElementById('home-wrap');
  const bar = document.getElementById('tabbar');
  const panes = { home: document.getElementById('pane-home'), collection: document.getElementById('pane-collection') };
  const tabs = [...bar.querySelectorAll('.tab')];
  let current = 'home';

  function select(name) {
    if (name === current) { onReselect?.(name); return; }
    current = name;
    wrap.classList.toggle('on-collection', name === 'collection');
    for (const t of tabs) t.setAttribute('aria-selected', String(t.dataset.tab === name));
    for (const [k, el] of Object.entries(panes)) el.inert = k !== name;
    fold(false);
  }

  let folded = false;
  function fold(v) {
    if (v === folded) return;
    folded = v;
    bar.classList.toggle('folded', v);
  }

  /** 스크롤 방향으로 접고 편다 — 맨 위 근처는 늘 편다(TabBarFold.report). */
  function watch(scroller) {
    let last = scroller.scrollTop;
    scroller.addEventListener('scroll', () => {
      const y = scroller.scrollTop;
      if (y < FOLD_TOP) fold(false);
      else if (y - last > 3) fold(true);
      else if (last - y > 3) fold(false);
      last = y;
    }, { passive: true });
  }

  for (const t of tabs) t.addEventListener('click', () => select(t.dataset.tab));
  document.getElementById('tab-camera').addEventListener('click', () => onCamera());

  return { select, watch, get current() { return current; } };
}
