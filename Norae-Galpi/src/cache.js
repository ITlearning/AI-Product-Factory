/**
 * 피드 캐시 — 홈 첫 화면 한 번만 막는다.
 *
 * ## 정직하게 말하면
 * "대부분의 방문자가 DB를 안 건드린다"는 과장이다. 캐시가 막아주는 건 **홈 첫 화면 한 번**뿐이고,
 * 2페이지 이후·⑥ 곡 상세·⑦ 내 갈피·좋아요·쓰기는 전부 DB 직행이라 조금이라도 파고드는 사용자는
 * Neon을 깨운다. 그래도 가장 흔한 진입(홈 열고 훑다 나감)에서 콜드스타트를 없애는 것만으로
 * 체감 차이가 크고 CU 소모도 준다.
 *
 * 크론으로 Neon을 상시 깨워두는 건 불가능하다 — 월 730시간 × 0.25 CU = 182 CU-hours로
 * 무료 한도(100)를 넘는다.
 *
 * ## 퍼지 대상이 트리거마다 다르다. 이게 핵심이다.
 *
 * | 트리거 | 퍼지 | 이유 |
 * |---|---|---|
 * | 글이 올라감 | `recent`·`season` 2키 | 작성자가 자기 글을 즉시 봐야 한다. `lasting`은 건드리지 않는다 — 좋아요 0인 새 글은 어차피 맨 뒤고, 여기까지 퍼지하면 stale 값이 사라져 **SWR이 막으려던 최악 경로를 그대로 맞는다** |
 * | `status` 변경 | 3키 전부 | 숨긴 글 노출은 지연이 허용되지 않는다. 여기서는 SWR을 포기한다 |
 * | 좋아요 | 없음 | 순위가 5분 늦어도 무해하다 |
 */

import { getKv } from './kv.js';
import { CACHE_TTL_SECONDS, SORTS, SWR_SORTS } from './feed.js';

/** 글이 올라갔을 때 퍼지할 키. `lasting`이 빠진 게 의도다. */
export const PURGE_ON_NEW_MEMORY = ['recent', 'season'];

/** `status`가 바뀌었을 때 — 3키 전부. */
export const PURGE_ON_STATUS_CHANGE = SORTS;

/**
 * @param {string} sort
 * @returns {string} 키는 정렬당 하나뿐이라 전부 3개다
 */
export function feedKey(sort) {
  return `feed:${sort}:p1`;
}

/**
 * 캐시에서 읽는다. stale 여부까지 같이 준다.
 *
 * SWR 정렬(`lasting`)은 TTL이 지나도 값을 지우지 않고 `staleAt`만 넘긴 상태로 둔다.
 * 캐시 만료와 Neon 콜드스타트가 겹치는 최악 경로에서 사용자를 안 기다리게 하려는 것이다.
 *
 * @param {string} sort
 * @returns {Promise<{value: unknown, stale: boolean}|null>} 없으면 null
 */
export async function readFeed(sort) {
  const kv = getKv();
  if (!kv) return null;
  try {
    const raw = await kv.get(feedKey(sort));
    if (!raw) return null;
    const entry = typeof raw === 'string' ? JSON.parse(raw) : raw;
    return { value: entry.value, stale: Date.now() > (entry.staleAt ?? 0) };
  } catch {
    // 캐시 장애로 피드가 죽으면 안 된다. 미스로 친다.
    return null;
  }
}

/**
 * 캐시에 쓴다.
 *
 * SWR 정렬은 Redis TTL을 TTL보다 길게 잡아(여유 24시간) 만료돼도 옛 값이 남게 한다.
 * 그 값이 **SWR이 주는 즉답의 재고**다. 그냥 EX로 지우면 SWR이 성립하지 않는다.
 *
 * @param {string} sort
 * @param {unknown} value
 */
export async function writeFeed(sort, value) {
  const kv = getKv();
  if (!kv) return;
  const ttl = CACHE_TTL_SECONDS[sort] ?? 60;
  const entry = JSON.stringify({ value, staleAt: Date.now() + ttl * 1000 });
  const ex = SWR_SORTS.has(sort) ? ttl + 86400 : ttl;
  try {
    await kv.set(feedKey(sort), entry, { ex });
  } catch {
    // 캐시에 못 써도 응답은 이미 만들어졌다. 조용히 넘어간다.
  }
}

/**
 * 키를 지운다.
 *
 * @param {string[]} sorts - `PURGE_ON_NEW_MEMORY` 또는 `PURGE_ON_STATUS_CHANGE`
 * @returns {Promise<number>} 지운 키 수. 캐시가 없으면 0
 */
export async function purgeFeed(sorts) {
  const kv = getKv();
  if (!kv) return 0;
  try {
    return (await kv.del(...sorts.map(feedKey))) ?? 0;
  } catch {
    // 퍼지에 실패해도 60초 TTL이 폴백이다. (status 변경에서는 그 60초가 대가다)
    return 0;
  }
}
