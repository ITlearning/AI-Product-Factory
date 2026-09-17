/**
 * 스키마 + 피드 쿼리 테스트 — PGlite(WASM Postgres)에 실제로 적용해서 돌린다.
 *
 * Neon 프로젝트 없이 다음을 확인한다.
 *   - `migrations/001_init.sql` 이 실제로 적용된다(러너와 같은 방식으로 ;를 쪼개서)
 *   - CHECK · UNIQUE · FK 가 의도한 것을 실제로 막는다
 *   - 피드 쿼리 3종이 옳은 결과를 주고 `idx_mem_feed` 를 탄다
 *
 * 설계(엔지니어링 결정 7)는 "피드 쿼리는 손으로 확인한다"였다. 여기서 자동으로 돌리는 이유는
 * **인덱스 설계가 미해결로 남아 있던 항목**이라, 근거 없이 "맞게 잡았다"고 적을 수 없어서다.
 *
 * 주의: PGlite는 PostgreSQL 18, Neon은 보통 17이다. 이 스키마는 버전 의존 기능을 쓰지 않지만
 *       (INCLUDE는 PG11+, 부분 유니크 인덱스는 그보다 오래됐다) **실행 계획은 Neon에서 다를 수 있다.**
 */

import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { PGlite } from '@electric-sql/pglite';

import { feedSongIdsQuery, feedMemoriesQuery, foldIntoCards } from '../src/feed.js';

const __dirname = dirname(fileURLToPath(import.meta.url));

/**
 * migrations/run.js 와 **같은 방식으로** 쪼갠다. 러너가 못 돌리는 SQL을 테스트만 통과시키면
 * 의미가 없다 — 러너의 ; 분리와 -- 주석 제거를 그대로 재현한다.
 *
 * @param {string} content
 * @returns {string[]}
 */
function splitStatements(content) {
  return content
    .split('\n')
    .filter((line) => !line.trim().startsWith('--'))
    .join('\n')
    .split(';')
    .map((s) => s.trim())
    .filter((s) => s.length > 0);
}

/** @returns {Promise<PGlite>} 마이그레이션이 적용된 새 DB */
async function freshDb() {
  const db = await PGlite.create();
  const sql = readFileSync(join(__dirname, '../migrations/001_init.sql'), 'utf8');
  for (const stmt of splitStatements(sql)) {
    await db.exec(stmt);
  }
  return db;
}

test('마이그레이션이 러너와 같은 방식으로 적용된다', async () => {
  const db = await freshDb();

  const tables = await db.query(
    `SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename`,
  );
  assert.deepEqual(
    tables.rows.map((r) => r.tablename),
    ['memories', 'memory_likes', 'reports', 'songs'],
  );

  const indexes = await db.query(
    `SELECT indexname FROM pg_indexes WHERE schemaname='public'
       AND indexname LIKE 'idx_%' OR indexname LIKE 'uq_%' ORDER BY indexname`,
  );
  assert.deepEqual(
    indexes.rows.map((r) => r.indexname),
    [
      'idx_mem_author',
      'idx_mem_feed',
      'idx_mem_feed_season',
      'idx_reports_open',
      'uq_songs_itunes',
      'uq_songs_youtube',
    ],
  );
});

test('마이그레이션은 멱등하다 — 두 번 돌려도 같다', async () => {
  const db = await freshDb();
  const sql = readFileSync(join(__dirname, '../migrations/001_init.sql'), 'utf8');
  for (const stmt of splitStatements(sql)) {
    await db.exec(stmt); // 두 번째 적용
  }
  const n = await db.query(`SELECT count(*)::int AS n FROM pg_tables WHERE schemaname='public'`);
  assert.equal(n.rows[0].n, 4);
});

test('곡 유일성 — 싱글판과 앨범판이 한 카드로 합쳐진다', async () => {
  const db = await freshDb();
  // 같은 아티스트 + 같은 title_key = 같은 곡. trackId가 달라도 갈라지지 않는다.
  await db.query(
    `INSERT INTO songs (source, itunes_artist_id, itunes_track_id, title_key, title, artist, youtube_video_id)
     VALUES ('itunes', 409076743, 1219218446, 'throughthenight', '밤편지', '아이유', 'aaaaaaaaaaa')`,
  );
  await assert.rejects(
    () =>
      db.query(
        `INSERT INTO songs (source, itunes_artist_id, itunes_track_id, title_key, title, artist, youtube_video_id)
         VALUES ('itunes', 409076743, 1229073406, 'throughthenight', '밤편지', '아이유', 'bbbbbbbbbbb')`,
      ),
    /uq_songs_itunes|duplicate key/,
    '싱글판/앨범판이 카드 두 장으로 갈라졌다',
  );

  // 남이 부른 커버는 artistId가 달라 자동으로 갈린다 — 이건 원하는 동작이다.
  await db.query(
    `INSERT INTO songs (source, itunes_artist_id, itunes_track_id, title_key, title, artist, youtube_video_id)
     VALUES ('itunes', 111111111, 999999999, 'throughthenight', '밤편지 (Cover)', '형제사진관', 'ccccccccccc')`,
  );
  const n = await db.query(`SELECT count(*)::int AS n FROM songs`);
  assert.equal(n.rows[0].n, 2);
});

test('source=itunes 인데 artist_id가 없으면 거부된다', async () => {
  const db = await freshDb();
  await assert.rejects(
    () =>
      db.query(
        `INSERT INTO songs (source, title_key, title, artist, youtube_video_id)
         VALUES ('itunes', 'x', 'x', 'x', 'aaaaaaaaaaa')`,
      ),
    /violates check constraint/,
  );
  // youtube 출처는 artist_id 없이 들어간다 — iTunes 카탈로그에 없는 곡의 경로.
  await db.query(
    `INSERT INTO songs (source, title_key, title, artist, youtube_video_id)
     VALUES ('youtube', '그래우리함께', '그래 우리 함께', '무한도전', 'ddddddddddd')`,
  );
});

test('본문 상한 5000자 · 라벨 CHECK · status CHECK', async () => {
  const db = await freshDb();
  const { rows } = await db.query(
    `INSERT INTO songs (source, title_key, title, artist, youtube_video_id)
     VALUES ('youtube','k','t','a','aaaaaaaaaaa') RETURNING id`,
  );
  const songId = rows[0].id;

  await assert.rejects(
    () => db.query(`INSERT INTO memories (song_id, author_hash, body) VALUES ($1,'h',$2)`, [
      songId,
      'ㄱ'.repeat(5001),
    ]),
    /violates check constraint/,
    '5000자 상한이 안 걸렸다',
  );
  await db.query(`INSERT INTO memories (song_id, author_hash, body) VALUES ($1,'h',$2)`, [
    songId,
    'ㄱ'.repeat(5000),
  ]);

  await assert.rejects(
    () =>
      db.query(`INSERT INTO memories (song_id, author_hash, body, era) VALUES ($1,'h','x','twenties')`, [
        songId,
      ]),
    /violates check constraint/,
    'rev.4의 twenties가 아직 통과한다',
  );
  await db.query(
    `INSERT INTO memories (song_id, author_hash, body, era, season) VALUES ($1,'h','x','military','winter')`,
    [songId],
  );
});

test('행을 지우지 않는 규율을 FK가 강제한다', async () => {
  const db = await freshDb();
  const song = await db.query(
    `INSERT INTO songs (source,title_key,title,artist,youtube_video_id)
     VALUES ('youtube','k','t','a','aaaaaaaaaaa') RETURNING id`,
  );
  const mem = await db.query(
    `INSERT INTO memories (song_id, author_hash, body) VALUES ($1,'h','x') RETURNING id`,
    [song.rows[0].id],
  );
  await db.query(`INSERT INTO reports (memory_id, reason, reporter_hash) VALUES ($1,'x','r')`, [
    mem.rows[0].id,
  ]);

  // 신고 이력은 증거라 같이 지워지면 안 된다. 운영자 처리는 DELETE가 아니라 status 변경이다.
  await assert.rejects(
    () => db.query(`DELETE FROM memories WHERE id = $1`, [mem.rows[0].id]),
    /foreign key constraint/,
  );
  // 기억이 달린 곡도 지울 수 없다.
  await assert.rejects(
    () => db.query(`DELETE FROM songs WHERE id = $1`, [song.rows[0].id]),
    /foreign key constraint/,
  );

  // 한 사람이 같은 글을 반복 신고하지 못한다.
  await assert.rejects(
    () =>
      db.query(`INSERT INTO reports (memory_id, reason, reporter_hash) VALUES ($1,'또','r')`, [
        mem.rows[0].id,
      ]),
    /duplicate key/,
  );
});

test('좋아요 토글은 트랜잭션 없이도 멱등하다', async () => {
  const db = await freshDb();
  const song = await db.query(
    `INSERT INTO songs (source,title_key,title,artist,youtube_video_id)
     VALUES ('youtube','k','t','a','aaaaaaaaaaa') RETURNING id`,
  );
  const mem = await db.query(
    `INSERT INTO memories (song_id, author_hash, body) VALUES ($1,'h','x') RETURNING id`,
    [song.rows[0].id],
  );
  const id = mem.rows[0].id;

  for (let i = 0; i < 3; i++) {
    await db.query(
      `INSERT INTO memory_likes (memory_id, liker_hash) VALUES ($1,'liker') ON CONFLICT DO NOTHING`,
      [id],
    );
  }
  let n = await db.query(`SELECT count(*)::int AS n FROM memory_likes WHERE memory_id=$1`, [id]);
  assert.equal(n.rows[0].n, 1, 'PK가 중복을 막지 못했다');

  await db.query(`DELETE FROM memory_likes WHERE memory_id=$1 AND liker_hash='liker'`, [id]);
  await db.query(`DELETE FROM memory_likes WHERE memory_id=$1 AND liker_hash='liker'`, [id]);
  n = await db.query(`SELECT count(*)::int AS n FROM memory_likes WHERE memory_id=$1`, [id]);
  assert.equal(n.rows[0].n, 0);
});

// ─────────────────────────────────────────────────────────────────────────────
// 피드 쿼리
// ─────────────────────────────────────────────────────────────────────────────

/**
 * 곡과 기억을 넣는다.
 * @param {PGlite} db
 * @param {{title: string, memories: {body: string, season?: string|null, is_public?: boolean, status?: string, daysAgo?: number}[]}[]} spec
 * @returns {Promise<Record<string, number>>} title → song id
 */
async function seedSongs(db, spec) {
  /** @type {Record<string, number>} */ const ids = {};
  let v = 0;
  for (const s of spec) {
    const { rows } = await db.query(
      `INSERT INTO songs (source, title_key, title, artist, youtube_video_id)
       VALUES ('youtube', $1, $1, 'a', $2) RETURNING id`,
      [s.title, `v${String(v++).padStart(10, '0')}`],
    );
    ids[s.title] = rows[0].id;
    for (const m of s.memories) {
      await db.query(
        `INSERT INTO memories (song_id, author_hash, body, season, is_public, status, created_at)
         VALUES ($1, 'h', $2, $3, $4, $5, NOW() - ($6 || ' days')::interval)`,
        [ids[s.title], m.body, m.season ?? null, m.is_public ?? true, m.status ?? 'visible', m.daysAgo ?? 0],
      );
    }
  }
  return ids;
}

test('`지금 계절`은 필터가 아니라 우선순위 — 그 계절 글이 없어도 홈이 안 빈다', async () => {
  const db = await freshDb();
  // 드라이런에서 글 5편 중 3편에 계절이 아예 없었다. 필터로 두면 빈 상태가 예외가 아니라 기본값이 된다.
  const ids = await seedSongs(db, [
    { title: '계절없음-최신', memories: [{ body: 'a', season: null, daysAgo: 0 }] },
    { title: '봄',           memories: [{ body: 'b', season: 'spring', daysAgo: 10 }] },
    { title: '겨울',         memories: [{ body: 'c', season: 'winter', daysAgo: 20 }] },
  ]);

  const q = feedSongIdsQuery('season');
  const { rows } = await db.query(q.text, q.params({ season: 'winter', limit: 20 }));

  assert.equal(rows.length, 3, '계절로 걸러서 홈이 비었다');
  assert.equal(String(rows[0].song_id), String(ids['겨울']), '해당 계절이 맨 위가 아니다');
  // 나머지는 최신순으로 이어 붙는다 — 계절이 없는 글도 사라지지 않는다.
  assert.deepEqual(
    rows.slice(1).map((r) => String(r.song_id)),
    [String(ids['계절없음-최신']), String(ids['봄'])],
  );
});

test('비공개·숨김·삭제 글은 피드에 안 나온다', async () => {
  const db = await freshDb();
  await seedSongs(db, [
    { title: '공개',   memories: [{ body: 'a' }] },
    { title: '비공개', memories: [{ body: 'b', is_public: false }] },
    { title: '숨김',   memories: [{ body: 'c', status: 'hidden' }] },
    { title: '삭제',   memories: [{ body: 'd', status: 'removed' }] },
  ]);

  for (const sort of ['recent', 'season', 'lasting']) {
    const q = feedSongIdsQuery(sort);
    const { rows } = await db.query(q.text, q.params({ season: 'winter', limit: 20 }));
    assert.equal(rows.length, 1, `${sort} 정렬에서 안 보여야 할 글이 샜다`);
  }
});

test('`오래 남은`은 좋아요 순이고 개수는 응답에만 있다', async () => {
  const db = await freshDb();
  const ids = await seedSongs(db, [
    { title: '좋아요0', memories: [{ body: 'a', daysAgo: 0 }] },
    { title: '좋아요2', memories: [{ body: 'b', daysAgo: 5 }] },
    { title: '좋아요1', memories: [{ body: 'c', daysAgo: 10 }] },
  ]);
  const mems = await db.query(`SELECT m.id, s.title FROM memories m JOIN songs s ON s.id=m.song_id`);
  const byTitle = Object.fromEntries(mems.rows.map((r) => [r.title, r.id]));
  await db.query(`INSERT INTO memory_likes (memory_id, liker_hash) VALUES ($1,'p'),($1,'q')`, [
    byTitle['좋아요2'],
  ]);
  await db.query(`INSERT INTO memory_likes (memory_id, liker_hash) VALUES ($1,'p')`, [byTitle['좋아요1']]);

  const q = feedSongIdsQuery('lasting');
  const { rows } = await db.query(q.text, q.params({ limit: 20 }));
  assert.deepEqual(
    rows.map((r) => String(r.song_id)),
    [String(ids['좋아요2']), String(ids['좋아요1']), String(ids['좋아요0'])],
  );
});

test('2번 쿼리는 idx_mem_feed 를 탄다', async () => {
  const db = await freshDb();
  const ids = await seedSongs(db, [{ title: 'x', memories: [{ body: 'a' }] }]);
  // 행이 몇 개뿐이면 플래너가 당연히 Seq Scan을 고른다. 여기서 확인하려는 건 비용이 아니라
  // **인덱스가 이 쿼리 모양에 맞느냐**라, seqscan을 끄고 무엇을 고르는지 본다.
  await db.exec('SET enable_seqscan = off');
  const r = await db.query(`EXPLAIN (COSTS OFF) ${feedMemoriesQuery}`, [[ids['x']]]);
  const plan = r.rows.map((x) => x['QUERY PLAN']).join('\n');
  await db.exec('RESET enable_seqscan');
  assert.match(plan, /idx_mem_feed\b/, `idx_mem_feed 가 안 쓰였다:\n${plan}`);
});

test('계절 탭은 idx_mem_feed_season 을 탄다', async () => {
  const db = await freshDb();
  await seedSongs(db, [{ title: 'x', memories: [{ body: 'a', season: 'autumn' }] }]);
  await db.exec('SET enable_seqscan = off');
  const r = await db.query(
    `EXPLAIN (COSTS OFF)
     SELECT song_id, MAX(created_at) FROM memories
      WHERE is_public AND status='visible' AND season = $1
      GROUP BY song_id ORDER BY 2 DESC LIMIT 20`,
    ['autumn'],
  );
  const plan = r.rows.map((x) => x['QUERY PLAN']).join('\n');
  await db.exec('RESET enable_seqscan');
  assert.match(plan, /idx_mem_feed_season/, `idx_mem_feed_season 이 안 쓰였다:\n${plan}`);
});

test('foldIntoCards 는 1번 쿼리가 정한 순서를 지킨다', async () => {
  const db = await freshDb();
  const ids = await seedSongs(db, [
    { title: 'A', memories: [{ body: 'a1', daysAgo: 3 }, { body: 'a2', daysAgo: 2 }, { body: 'a3', daysAgo: 1 }, { body: 'a4', daysAgo: 0 }] },
    { title: 'B', memories: [{ body: 'b1', daysAgo: 30 }] },
  ]);
  // 1번이 정한 순서를 일부러 뒤집어 준다 — ANY($1)는 순서를 보장하지 않으므로
  // 여기서 순서가 안 지켜지면 정렬 3종이 전부 무의미해진다.
  const order = [ids['B'], ids['A']];
  const { rows } = await db.query(feedMemoriesQuery, [order]);
  const cards = foldIntoCards(order, rows, 3);

  assert.deepEqual(cards.map((c) => c.song.title), ['B', 'A']);
  assert.equal(cards[1].memories.length, 3, '곡별 미리보기 편수가 안 잘렸다');
  assert.deepEqual(cards[1].memories.map((m) => m.body), ['a4', 'a3', 'a2'], '최신 3편이 아니다');
});

test('시드가 실제 스키마에 그대로 들어간다', async () => {
  // 유튜브 영상 ID 9곡이 아직 미정이라(NOT NULL) 그대로는 못 넣는다.
  // 그 칸만 자리표시자로 채워 **나머지 전부**가 스키마를 통과하는지 지금 확인한다.
  // 실제 ID가 들어오면 이 테스트가 그대로 진짜 값을 검사하게 된다.
  const db = await freshDb();
  const seed = JSON.parse(readFileSync(join(__dirname, '../seed/seed.json'), 'utf8'));

  /** @type {Record<string, number>} */ const songIds = {};
  let filler = 0;
  for (const s of seed.songs) {
    const videoId = s.youtube_video_id ?? `TODO${String(filler++).padStart(7, '0')}`;
    const { rows } = await db.query(
      `INSERT INTO songs (source, itunes_artist_id, itunes_track_id, title_key, title_key_rev,
                          title, artist, artwork_url, youtube_video_id)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING id`,
      [s.source, s.itunes_artist_id, s.itunes_track_id, s.title_key, s.title_key_rev,
       s.title, s.artist, s.artwork_url, videoId],
    );
    songIds[s.ref] = rows[0].id;
  }
  for (const m of seed.memories) {
    await db.query(
      `INSERT INTO memories (song_id, author_hash, body, season, era, is_public)
       VALUES ($1,'seed',$2,$3,$4,$5)`,
      [songIds[m.song_ref], m.body, m.season, m.era, m.is_public],
    );
  }

  const n = await db.query(
    `SELECT (SELECT count(*)::int FROM songs) songs, (SELECT count(*)::int FROM memories) mems`,
  );
  assert.equal(n.rows[0].songs, 11);
  assert.equal(n.rows[0].mems, 11);

  // 시드가 들어간 상태에서 기본 정렬이 실제로 무언가를 보여주는가 —
  // "시드 없이는 피드·정렬 3종·빈 상태를 검증할 수 없다"는 게 Next Step 0의 이유였다.
  const q = feedSongIdsQuery('season');
  const { rows } = await db.query(q.text, q.params({ season: 'autumn', limit: 20 }));
  assert.equal(rows.length, 11, '곡 11개가 전부 피드에 올라와야 한다');
  assert.equal(rows[0].in_season, true, '가을에 홈을 열면 가을 기억이 맨 위여야 한다');

  // 계절이 하나도 안 붙은 나머지가 뒤로 밀리되 사라지지는 않는다.
  assert.equal(rows.filter((r) => r.in_season).length, 1);
});
