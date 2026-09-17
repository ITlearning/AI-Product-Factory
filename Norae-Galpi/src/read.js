/**
 * 읽기 경로 — ⑤ 피드 · ⑥ 곡 상세 · ⑦ 내 갈피.
 *
 * ## 좋아요 개수는 어디로도 안 나간다
 * DB에만 두고 `오래 남은` 정렬에만 쓴다. 누군가의 진심이 `♡ 0`으로 박히면 안 된다.
 * 응답에 싣는 건 **내가 눌렀는지**(`liked`)뿐이라 클라이언트가 셀 방법이 없다.
 */

import { feedSongIdsQuery, feedMemoriesQuery, foldIntoCards, FEED_SONGS_PER_PAGE, FEED_MEMORIES_PER_SONG, SORTS } from './feed.js';
import { readFeed, writeFeed } from './cache.js';
import { currentSeason } from './labels.js';

/**
 * ⑤ 피드 1페이지. 쿼리 2번 + 캐시.
 *
 * SWR(`오래 남은`)은 만료돼도 옛 값을 **즉시** 주고 갱신은 뒤에서 돈다.
 * 캐시 만료와 Neon 콜드스타트가 겹치는 최악 경로에서 사용자를 안 기다리게 하려는 것이다.
 *
 * @param {any} sql
 * @param {{sort?: string, season?: string, page?: number, now?: Date,
 *          revalidate?: (fn: () => Promise<void>) => void}} [opts]
 * @returns {Promise<{sort: string, season: string, cards: object[], cached: boolean, stale: boolean}>}
 */
export async function getFeed(sql, opts = {}) {
  const sort = SORTS.includes(opts.sort) ? opts.sort : 'season';
  const season = opts.season ?? currentSeason(opts.now);
  const page = Number.isInteger(opts.page) && opts.page > 0 ? opts.page : 1;

  // 캐시는 정렬당 1페이지뿐이다. 키가 3개인 이유이고, 2페이지 이후는 전부 DB 직행이다.
  const cacheable = page === 1;

  if (cacheable) {
    const hit = await readFeed(sort);
    if (hit) {
      if (!hit.stale) return { ...hit.value, cached: true, stale: false };

      // stale — 옛 값을 즉시 주고 갱신은 뒤로 넘긴다.
      // 호출 측이 revalidate를 안 주면(테스트·스크립트) 그냥 지금 갱신한다.
      const refresh = async () => {
        const fresh = await queryFeed(sql, { sort, season, page });
        await writeFeed(sort, fresh);
      };
      if (opts.revalidate) {
        opts.revalidate(refresh);
        return { ...hit.value, cached: true, stale: true };
      }
    }
  }

  const fresh = await queryFeed(sql, { sort, season, page });
  if (cacheable) await writeFeed(sort, fresh);
  return { ...fresh, cached: false, stale: false };
}

/**
 * 캐시를 거치지 않는 실제 조회. **쿼리 2번.**
 *
 * @param {any} sql
 * @param {{sort: string, season: string, page: number}} params
 * @returns {Promise<{sort: string, season: string, cards: object[]}>}
 */
export async function queryFeed(sql, { sort, season, page }) {
  const limit = FEED_SONGS_PER_PAGE * page;
  const q = feedSongIdsQuery(sort);

  // 1번 — 곡 id. 페이지네이션은 곡 단위로 자른다(기억 단위로 자르면 카드가 쪼개진다).
  const idRows = await sql.query(q.text, q.params({ season, limit }));
  const pageIds = idRows.slice((page - 1) * FEED_SONGS_PER_PAGE).map((r) => r.song_id);
  if (pageIds.length === 0) return { sort, season, cards: [] };

  // 2번 — 그 곡들의 기억을 한 번에.
  const memRows = await sql.query(feedMemoriesQuery, [pageIds]);

  const cards = foldIntoCards(pageIds, memRows, FEED_MEMORIES_PER_SONG).map((card, i) => ({
    ...card,
    // `지금 계절` 정렬에서 해당 계절 구간과 나머지 구간 사이에 조용한 구분선 하나를 둔다.
    // 그 경계가 어디인지는 서버만 안다(클라이언트는 개별 글의 계절만 봐서는 못 정한다).
    seasonBoundary: sort === 'season' && i > 0
      && Boolean(idRows[i - 1]?.in_season) && !idRows[i]?.in_season,
  }));

  return { sort, season, cards };
}

/**
 * ⑥ 곡 상세 — 그 곡의 기억 전부. **이 제품에서 소리가 나는 유일한 화면.**
 *
 * `noindex` 는 화면 쪽에서 건다. v1은 검색엔진에 열지 않는다 —
 * "밤편지 가사 의미"로 들어온 사람이 글 3편을 보면 유튜브 댓글 수만 개와 바로 비교된다.
 * 곡당 평균 5편을 넘으면 그때 연다.
 *
 * @param {any} sql
 * @param {string|number} songId
 * @param {string|null} [likerHash] - 있으면 각 기억에 `liked`를 채운다
 * @returns {Promise<{song: object, memories: object[]}|null>}
 */
export async function getSongDetail(sql, songId, likerHash = null) {
  const songs = await sql.query(
    `SELECT id, source, title, artist, artwork_url, youtube_video_id FROM songs WHERE id = $1`,
    [songId],
  );
  if (songs.length === 0) return null;

  const memories = await sql.query(
    `SELECT m.id, m.body, m.season, m.era, m.created_at
       FROM memories m
      WHERE m.song_id = $1 AND m.is_public AND m.status = 'visible'
      ORDER BY m.created_at DESC`,
    [songId],
  );

  return { song: songs[0], memories: await withLiked(sql, memories, likerHash) };
}

/**
 * ⑦ 내 갈피 — 본인 글.
 *
 * 공개·비공개를 모두 보고 **`status` 술어도 일부러 걸지 않는다.**
 * `removed` 된 자기 글도 "숨겨진 글"로 표시한다 — 조용히 사라지면 사용자가 더 혼란스럽다.
 *
 * @param {any} sql
 * @param {string} authorHash
 * @param {{limit?: number}} [opts]
 * @returns {Promise<object[]>}
 */
export async function getMyMemories(sql, authorHash, opts = {}) {
  const limit = Number.isInteger(opts.limit) && opts.limit > 0 ? Math.min(opts.limit, 200) : 100;
  return sql.query(
    `SELECT m.id, m.body, m.season, m.era, m.is_public, m.status, m.created_at,
            s.id AS song_id, s.source, s.title, s.artist, s.artwork_url, s.youtube_video_id
       FROM memories m JOIN songs s ON s.id = m.song_id
      WHERE m.author_hash = $1
      ORDER BY m.created_at DESC
      LIMIT $2`,
    [authorHash, limit],
  );
}

/**
 * 각 기억에 "내가 눌렀는지"만 붙인다. **개수는 절대 안 붙인다.**
 *
 * @param {any} sql
 * @param {object[]} memories
 * @param {string|null} likerHash
 * @returns {Promise<object[]>}
 */
async function withLiked(sql, memories, likerHash) {
  if (!likerHash || memories.length === 0) {
    return memories.map((m) => ({ ...m, liked: false }));
  }
  const rows = await sql.query(
    `SELECT memory_id FROM memory_likes WHERE liker_hash = $1 AND memory_id = ANY($2)`,
    [likerHash, memories.map((m) => m.id)],
  );
  const mine = new Set(rows.map((r) => String(r.memory_id)));
  return memories.map((m) => ({ ...m, liked: mine.has(String(m.id)) }));
}

/**
 * 좋아요 토글. 트랜잭션 없이도 안전하다 —
 * `INSERT … ON CONFLICT DO NOTHING` / `DELETE` 둘 다 멱등이고 PK가 중복을 막는다.
 *
 * **캐시를 퍼지하지 않는다.** 순위가 5분 늦어도 무해하고, 여기서 `오래 남은`을 지우면
 * SWR 재고가 사라진다.
 *
 * @param {any} sql
 * @param {string|number} memoryId
 * @param {string} likerHash
 * @param {boolean} liked - 원하는 상태
 * @returns {Promise<{liked: boolean}>}
 */
export async function setLike(sql, memoryId, likerHash, liked) {
  if (liked) {
    await sql.query(
      `INSERT INTO memory_likes (memory_id, liker_hash) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
      [memoryId, likerHash],
    );
  } else {
    await sql.query(`DELETE FROM memory_likes WHERE memory_id = $1 AND liker_hash = $2`, [
      memoryId,
      likerHash,
    ]);
  }
  // 응답에 개수를 싣지 않으므로 클라이언트는 눌림 여부만 알면 된다.
  return { liked };
}
