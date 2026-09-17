/**
 * 지난 피드를 브라우저에 둔다 — **재방문자가 기다리지 않게.**
 *
 * 설계의 "로딩은 두 갈래" 중 한쪽이다. 재방문자는 지난 피드를 즉시 보고,
 * 갱신은 뒤에서 조용히 돈다. Neon 이 5분 비활성으로 잠들어 있을 때 이게 체감을 가른다.
 *
 * localStorage 는 시크릿 모드·사이트 데이터 차단에서 던지거나 비어 올 수 있다.
 * **없어도 화면이 정상으로 그려져야 한다** — 그래서 전부 try/catch 로 감싸고 실패는 캐시 미스로 친다.
 */

const PREFIX = 'norae-galpi.feed.';
/** 이보다 오래된 건 안 그린다. 옛날 피드를 새것처럼 보여주면 그게 더 나쁘다. */
const MAX_AGE_MS = 24 * 60 * 60 * 1000;

function key(sort, season) {
  return `${PREFIX}${sort}:${season ?? '-'}`;
}

/**
 * @param {string} sort
 * @param {string|null} season
 * @returns {object|null}
 */
export function readCachedFeed(sort, season) {
  try {
    const raw = localStorage.getItem(key(sort, season));
    if (!raw) return null;
    const entry = JSON.parse(raw);
    if (!entry?.at || Date.now() - entry.at > MAX_AGE_MS) return null;
    return entry.data;
  } catch {
    return null;
  }
}

/**
 * @param {string} sort
 * @param {string|null} season
 * @param {object} data
 */
export function writeCachedFeed(sort, season, data) {
  try {
    localStorage.setItem(key(sort, season), JSON.stringify({ at: Date.now(), data }));
  } catch {
    /* 용량 초과·차단. 캐시는 편의일 뿐이라 조용히 넘어간다. */
  }
}
