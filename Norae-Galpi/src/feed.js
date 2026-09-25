/**
 * ⑤ 홈 피드 쿼리. **쿼리 2번**으로 끝난다(엔지니어링 결정 4).
 *
 *   1번 — 곡 id 20개를 정렬 기준대로 고른다
 *   2번 — 그 곡들의 기억을 `song_id = ANY($1)` 로 한 번에 가져온다
 *   그다음 서버에서 곡별 N편씩 자른다
 *
 * `LATERAL JOIN` 한 방은 기각됐다 — SQL이 어렵고 정렬 기준이 바뀔 때마다 다시 지어야 한다.
 *
 * ## 왜 곡 단위로 접는가
 * 피드는 "곡이 위에 보이고, 그 아래로 글 몇 개"다. 글이 곡과 무관하게 주르륵 흐르면
 * 유튜브 댓글창과 정면으로 붙는데, 곡 단위로 접으면 *검색이 아니라 흐름으로* 들어오게 된다.
 *
 * ## 인덱스
 * 셋 다 `idx_mem_feed (song_id, created_at DESC) INCLUDE (season, id)`를 탄다.
 * `migrations/001_init.sql`의 주석이 왜 그 모양인지 적어두었다.
 */

/** 피드 한 페이지에 실리는 곡 수. */
export const FEED_SONGS_PER_PAGE = 20;

/**
 * 곡 카드 하나에 미리 보여주는 기억 수.
 *
 * 엔지니어링 결정 4는 3편, 와이어프레임 목업은 2편으로 그려져 있다. 쿼리가 아니라
 * 서버에서 자르는 값이라 화면을 보고 나중에 바꿔도 비용이 없어 여기 상수로 둔다.
 */
export const FEED_MEMORIES_PER_SONG = 3;

/** 정렬 3종. `지금 계절`이 기본값이다 — 푸시도 스트릭도 없이 계절이 사람을 부른다. */
export const SORTS = ['season', 'recent', 'lasting'];

/** 정렬별 캐시 TTL(초). `오래 남은`만 집계라 비싸고, 그래서 유일하게 SWR로 감싼다. */
export const CACHE_TTL_SECONDS = { season: 60, recent: 60, lasting: 300 };

/** SWR을 쓰는 정렬. 만료돼도 옛 값을 즉시 주고 갱신은 뒤에서 돈다. */
export const SWR_SORTS = new Set(['lasting']);

/**
 * 1번 쿼리 — 피드에 올릴 곡 id를 정렬 기준대로 고른다.
 *
 * 세 정렬 모두 `GROUP BY song_id` 라, 곡을 선행 컬럼으로 둔 `idx_mem_feed` 가
 * 그룹 정렬을 없애준다. `MAX(created_at)` 은 그 인덱스에서 그룹의 첫 행이다.
 *
 * @param {'season'|'recent'|'lasting'} sort
 * @returns {{text: string, params: (v: {season?: string, limit?: number}) => unknown[]}}
 *   `text` 는 $1… 자리표시자를 쓰는 SQL, `params` 는 그 순서대로 값을 만든다.
 */
export function feedSongIdsQuery(sort) {
  if (!SORTS.includes(sort)) throw new Error(`알 수 없는 정렬: ${sort}`);

  if (sort === 'recent') {
    return {
      text: `
        SELECT song_id, MAX(created_at) AS last_at
          FROM memories
         WHERE is_public AND status = 'visible'
         GROUP BY song_id
         ORDER BY last_at DESC
         LIMIT $1`,
      params: ({ limit = FEED_SONGS_PER_PAGE }) => [limit],
    };
  }

  if (sort === 'season') {
    // 필터가 아니라 **우선순위**다. 해당 계절 글이 있는 곡을 위에 놓고,
    // 그 아래로 나머지를 최신순으로 이어 붙인다 — 그래야 홈이 비지 않는다.
    // 드라이런에서 글 5편 중 3편에 계절이 아예 없었고, 필터로 두면 빈 상태가 기본값이 된다.
    //
    // COALESCE가 없으면 안 된다. 곡의 기억에 계절이 하나도 없으면 `BOOL_OR(season = $1)`이
    // FALSE가 아니라 **NULL**이고, Postgres의 `ORDER BY ... DESC`는 NULL을 맨 앞에 놓는다
    // (DESC의 기본값이 NULLS FIRST). 그러면 계절이 없는 곡이 해당 계절 곡보다 위로 올라가서
    // 이 제품의 기본 정렬이자 유일한 재방문 장치가 조용히 뒤집힌다.
    return {
      text: `
        SELECT song_id,
               MAX(created_at) AS last_at,
               COALESCE(BOOL_OR(season = $1), FALSE) AS in_season
          FROM memories
         WHERE is_public AND status = 'visible'
         GROUP BY song_id
         ORDER BY in_season DESC, last_at DESC
         LIMIT $2`,
      params: ({ season, limit = FEED_SONGS_PER_PAGE }) => [season, limit],
    };
  }

  // lasting — 좋아요 순. 개수는 화면에 안 나오고 정렬에만 쓴다.
  // like_count 컬럼을 두지 않은 이유: Neon HTTP에 트랜잭션이 없어 INSERT memory_likes 와
  // UPDATE like_count 의 원자성을 보장할 수 없고, 카운트 드리프트가 확정적으로 생긴다.
  // 그래서 권위 있는 값은 memory_likes 하나뿐이고 여기서 집계한다.
  //
  // ORDER BY likes DESC 는 인덱스로 풀 수 없다. 이 정렬만 TTL 5분 + SWR로 감싸는 이유다.
  return {
    text: `
      SELECT m.song_id,
             COUNT(l.liker_hash) AS likes,
             MAX(m.created_at)   AS last_at
        FROM memories m
        LEFT JOIN memory_likes l ON l.memory_id = m.id
       WHERE m.is_public AND m.status = 'visible'
       GROUP BY m.song_id
       ORDER BY likes DESC, last_at DESC
       LIMIT $1`,
    params: ({ limit = FEED_SONGS_PER_PAGE }) => [limit],
  };
}

/**
 * 2번 쿼리 — 1번이 고른 곡들의 기억을 한 번에.
 *
 * 곡별로 자르는 일은 서버가 한다. SQL에서 자르려면 윈도우 함수나 LATERAL이 필요한데,
 * 곡이 20개뿐이라 네트워크 왕복을 늘리지 않는 쪽이 싸다.
 */
export const feedMemoriesQuery = `
  SELECT m.id, m.song_id, m.body, m.season, m.era, m.created_at,
         s.source, s.title, s.artist, s.artwork_url, s.youtube_video_id
    FROM memories m
    JOIN songs s ON s.id = m.song_id
   WHERE m.song_id = ANY($1) AND m.is_public AND m.status = 'visible'
   ORDER BY m.song_id, m.created_at DESC`;

/**
 * 2번 쿼리 결과를 1번이 정한 곡 순서대로 카드로 접는다.
 *
 * `ANY($1)` 는 순서를 보장하지 않는다. 그래서 정렬 기준은 1번이 돌려준 `songIds` 배열이
 * 유일한 정본이고, 여기서 그 순서를 다시 씌운다. (이걸 빼먹으면 정렬 3종이 전부 무의미해진다)
 *
 * @param {number[]|string[]} songIds - 1번 쿼리가 돌려준 순서
 * @param {object[]} rows - 2번 쿼리 결과
 * @param {number} perSong - 카드당 미리보기 기억 수
 * @returns {{song: object, memories: object[]}[]}
 */
export function foldIntoCards(songIds, rows, perSong = FEED_MEMORIES_PER_SONG) {
  /** @type {Map<string, {song: object, memories: object[]}>} */
  const bySong = new Map();

  for (const r of rows) {
    const key = String(r.song_id);
    if (!bySong.has(key)) {
      bySong.set(key, {
        song: {
          id: r.song_id,
          source: r.source,
          title: r.title,
          artist: r.artist,
          artwork_url: r.artwork_url,
          youtube_video_id: r.youtube_video_id,
        },
        memories: [],
        // 카드가 보여주는 편수가 아니라 **그 곡이 가진 전부**. 2번 쿼리가 이미 전부를
        // 들고 오므로 세는 데 드는 값이 0 이다. `기억 5편 모두 보기` 한 줄을 위해
        // 쿼리를 하나 더 치는 일은 없어야 한다.
        total: 0,
      });
    }
    const card = bySong.get(key);
    card.total += 1;
    if (card.memories.length < perSong) {
      card.memories.push({
        id: r.id,
        body: r.body,
        season: r.season,
        era: r.era,
        created_at: r.created_at,
      });
    }
  }

  // 1번이 정한 순서대로. 2번에서 안 돌아온 곡(그사이 숨겨진 경우)은 조용히 빠진다.
  return songIds.map((id) => bySong.get(String(id))).filter(Boolean);
}
