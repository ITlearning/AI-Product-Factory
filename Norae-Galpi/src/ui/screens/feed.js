/**
 * ⑤ 홈 피드.
 *
 * **iframe 이 하나도 없다.** 듣는 일은 전부 ⑥으로 옮겨져 있다.
 * 잃는 것은 "피드를 훑으며 듣는 경험"이고, 얻는 것은 RMF 세 조항을 전부 통과하면서
 * "노래가 흐르는 동안 읽는다"를 ⑥에서 온전히 지키는 것이다.
 */

import { el, replace } from '../dom.js';
import { songCard, emptyState, skeletonFeed } from '../components.js';
import { SORT_LABELS, SEASON_LABELS, currentSeason } from '../labels.js';
import { getFeed } from '../../client/api.js';
import { readCachedFeed, writeCachedFeed } from '../../client/feed-cache.js';

const SORTS = ['season', 'recent', 'lasting'];

/**
 * @param {HTMLElement} root
 * @param {URLSearchParams} query
 */
export function feedScreen(root, query) {
  const sort = SORTS.includes(query.get('sort')) ? query.get('sort') : 'season';
  // 계절 탭을 직접 누른 경우에만 season 이 필터로 쓰인다.
  const pinnedSeason = query.get('season');
  const season = pinnedSeason ?? currentSeason();

  const list = el('div', {});
  const view = el('div', { className: 'screen shell' }, [sortBar(sort, pinnedSeason), list]);
  replace(root, view);

  // 로딩은 두 갈래다. 재방문자는 지난 피드를 **즉시** 그리고 조용히 갱신한다.
  const cached = readCachedFeed(sort, pinnedSeason);
  if (cached) {
    render(cached);
  } else {
    // 첫 방문자에게는 서비스 자체 카피를 한 줄씩. **가사는 쓰지 않는다**(KOMCA 관리 저작물).
    // 그 아래로 카드 모양 스켈레톤 — Neon 콜드스타트가 실재해서 이 시간이 진짜로 있다.
    replace(
      list,
      el('p', {
        className: 'loading',
        // 스켈레톤과 나란히 서므로 위아래 여백을 줄인다. 혼자일 때의 --space-8 은 너무 멀다.
        style: 'padding: var(--space-5) var(--space-4) 0',
        text: '노래마다 그때가 한 편씩 붙어 있어요.',
      }),
      skeletonFeed(2),
    );
  }

  getFeed({ sort, season: pinnedSeason ?? undefined })
    .then((data) => {
      writeCachedFeed(sort, pinnedSeason, data);
      render(data);
    })
    .catch((err) => {
      // 캐시된 게 이미 떠 있으면 조용히 실패한다 — 읽던 화면을 에러로 덮지 않는다.
      if (cached) return;
      replace(list, el('p', { className: 'loading', text: err.message }));
    });

  function render(data) {
    if (!data.cards || data.cards.length === 0) {
      replace(list, emptySeason(season, pinnedSeason));
      return;
    }
    const nodes = [];
    for (const card of data.cards) {
      if (card.seasonBoundary) {
        nodes.push(el('div', { className: 'season-divider', text: '그 밖의 기억' }));
      }
      nodes.push(songCard(card));
    }
    replace(list, ...nodes);
  }
}

/**
 * 직전에 어느 정렬이었는지. 화면이 통째로 다시 그려지므로 모듈이 기억한다 —
 * 이게 없으면 인디케이터가 매번 제자리에서 태어나 미끄러질 곳이 없다.
 *
 * @type {string|null}
 */
let lastSort = null;

/**
 * 정렬 pill 3개. `지금 계절`이 기본값인 게 핵심이다 —
 * 겨울이 오면 홈이 저절로 바뀐다. **푸시도 스트릭도 없이 계절이 사람을 부른다.**
 *
 * 선택 표시가 **미끄러진다.** 색만 바뀌면 어디서 어디로 옮겨갔는지 흔적이 없다.
 */
function sortBar(active, pinnedSeason) {
  const items = SORTS.map((s) =>
    el('a', {
      className: 'sorts__item',
      href: `#/?sort=${s}`,
      text: s === 'season' && pinnedSeason ? SEASON_LABELS[pinnedSeason] : SORT_LABELS[s],
      attrs: { 'aria-pressed': String(s === active) },
    }),
  );

  const thumb = el('span', { className: 'sorts__thumb', attrs: { 'aria-hidden': 'true' } });
  const nav = el('nav', { className: 'sorts', attrs: { 'aria-label': '정렬' } }, [thumb, ...items]);

  const from = SORTS.indexOf(lastSort);
  const to = SORTS.indexOf(active);
  lastSort = active;

  // 레이아웃이 잡힌 뒤에 재야 한다. 붙기 전에는 offsetWidth 가 0이다.
  requestAnimationFrame(() => {
    const place = (i) => {
      const it = items[i];
      thumb.style.width = `${it.offsetWidth}px`;
      thumb.style.transform = `translateX(${it.offsetLeft - 3}px)`;
    };

    if (from < 0 || from === to) {
      // 첫 그림이거나 같은 정렬 — 제자리에 놓고 끝낸다.
      // 화면에 들어오자마자 미끄러지면 내가 뭘 바꾼 건지 헷갈린다.
      thumb.classList.add('sorts__thumb--settled');
      place(to);
      requestAnimationFrame(() => thumb.classList.remove('sorts__thumb--settled'));
      return;
    }

    // 직전 자리에 놓았다가 한 프레임 뒤에 새 자리로 보낸다.
    thumb.classList.add('sorts__thumb--settled');
    place(from);
    requestAnimationFrame(() => {
      thumb.classList.remove('sorts__thumb--settled');
      place(to);
    });
  });

  return nav;
}

/**
 * 빈 상태는 **사용자가 계절 탭을 직접 눌러 그 계절이 0편일 때만** 쓴다.
 * 기본 홈은 우선순위 정렬이라 비지 않는다.
 */
function emptySeason(season, pinnedSeason) {
  const name = SEASON_LABELS[season] ?? '이번 계절';
  return emptyState({
    line: pinnedSeason
      ? `아직 이번 ${name}의 기억이 없어요.\n첫 사람이 되어볼래요?`
      : '아직 아무 기억도 없어요.\n첫 사람이 되어볼래요?',
    action: { label: '기억 적기', href: '#/start' },
    // 마지막 탈출구. 이게 없으면 서비스 전체가 빈 줄 안다.
    escape: pinnedSeason
      ? { label: '다른 계절 보기 →', onClick: () => { location.hash = '#/?sort=season'; } }
      : undefined,
  });
}
