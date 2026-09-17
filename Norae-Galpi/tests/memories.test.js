/**
 * 쓰기 경로 — `POST /api/memories`.
 *
 * 설계(엔지니어링 결정 7)가 자동 테스트 대상으로 못 박은 것 중 하나다. 여기가 이 제품에서
 * 유일하게 데이터를 만드는 길이고, **순서가 틀리면 조용히 망가진다**(유령 곡·PII 통과·유령 퍼지).
 *
 * DB는 PGlite에 실제 마이그레이션을 적용해 쓰고, Redis는 가짜를 꽂는다.
 */

import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { PGlite } from '@electric-sql/pglite';

import { createMemory, validateMemoryInput, validateSongInput, BODY_MAX } from '../src/memories.js';
import { upsertSong } from '../src/songs.js';
import { _setKv } from '../src/kv.js';
import { feedKey } from '../src/cache.js';
import handler from '../api/memories.js';

const __dirname = dirname(fileURLToPath(import.meta.url));

/**
 * Neon 의 태그드 템플릿 API를 PGlite 로 흉내낸다.
 * `sql\`… ${v} …\`` → `db.query('… $1 …', [v])`, 그리고 rows 배열을 그대로 돌려준다.
 *
 * @param {PGlite} db
 */
function neonLike(db) {
  return async (strings, ...values) => {
    let text = '';
    strings.forEach((part, i) => {
      text += part + (i < values.length ? `$${i + 1}` : '');
    });
    const r = await db.query(text, values);
    return r.rows;
  };
}

/** @returns {Promise<{db: PGlite, sql: ReturnType<typeof neonLike>}>} */
async function freshDb() {
  const db = await PGlite.create();
  const stmts = readFileSync(join(__dirname, '../migrations/001_init.sql'), 'utf8')
    .split('\n')
    .filter((l) => !l.trim().startsWith('--'))
    .join('\n')
    .split(';')
    .map((s) => s.trim())
    .filter(Boolean);
  for (const s of stmts) await db.exec(s);
  return { db, sql: neonLike(db) };
}

/** 가짜 Redis. 무엇이 지워졌는지 기록해 캐시 퍼지를 검사한다. */
function fakeKv({ counts = {} } = {}) {
  const deleted = [];
  const store = new Map();
  return {
    deleted,
    store,
    async get(k) { return store.get(k) ?? null; },
    async set(k, v) { store.set(k, v); },
    async del(...keys) { deleted.push(...keys); return keys.length; },
    async incr(k) {
      const n = (counts[k] ?? store.get(k) ?? 0) + 1;
      store.set(k, n);
      counts[k] = n;
      return n;
    },
    async expire() { return 1; },
    async ttl() { return 42; },
  };
}

const SONG = {
  source: 'itunes',
  itunesArtistId: 409076743,
  itunesTrackId: 1219218446,
  titleKey: 'throughthenight',
  title: '밤편지',
  artist: '아이유',
  artworkUrl: 'https://example.invalid/a.jpg',
  youtubeVideoId: 'BzYnNdJhZQw',
};

test.afterEach(() => _setKv(null));

// ─── 순수 검증 ──────────────────────────────────────────────────────────────

test('본문 검증 — 빈 글·상한·라벨', () => {
  assert.throws(() => validateMemoryInput({ body: '' }), /기억을 적어주세요/);
  assert.throws(() => validateMemoryInput({ body: '   \n ' }), /기억을 적어주세요/);
  assert.throws(() => validateMemoryInput({ body: 123 }), /기억을 적어주세요/);

  // 앞뒤 공백만 다듬고 줄바꿈은 글쓴이의 리듬이라 안 건드린다.
  assert.equal(validateMemoryInput({ body: '  첫 줄\n\n둘째 줄  ' }).body, '첫 줄\n\n둘째 줄');

  assert.equal(validateMemoryInput({ body: 'ㄱ'.repeat(BODY_MAX) }).body.length, BODY_MAX);
  assert.throws(() => validateMemoryInput({ body: 'ㄱ'.repeat(BODY_MAX + 1) }), /5000자/);

  // Postgres char_length 와 같은 기준. JS .length 였으면 이모지 2500개가 상한에 걸린다.
  const emoji = '🎧'.repeat(BODY_MAX);
  assert.equal(validateMemoryInput({ body: emoji }).body, emoji);

  assert.throws(() => validateMemoryInput({ body: 'x', season: 'monsoon' }), /계절/);
  assert.throws(() => validateMemoryInput({ body: 'x', era: 'twenties' }), /시절/);
});

test('공개가 기본이다', () => {
  assert.equal(validateMemoryInput({ body: 'x' }).isPublic, true);
  assert.equal(validateMemoryInput({ body: 'x', isPublic: undefined }).isPublic, true);
  assert.equal(validateMemoryInput({ body: 'x', isPublic: false }).isPublic, false);
});

test('곡 검증 — 영상 ID는 두 경로 모두 필수다', () => {
  assert.throws(() => validateSongInput({ ...SONG, youtubeVideoId: undefined }), /영상/);
  assert.throws(() => validateSongInput({ ...SONG, youtubeVideoId: 'short' }), /영상/);
  assert.throws(
    () => validateSongInput({ ...SONG, youtubeVideoId: 'https://youtu.be/BzYnNdJhZQw' }),
    /영상/,
    'URL 통째로 오는 걸 받으면 안 된다 — 클라이언트가 ID를 뽑아 보낸다',
  );
  assert.throws(() => validateSongInput({ ...SONG, itunesArtistId: undefined }), /모자랍/);
  // youtube 출처는 artistId 없이 통과한다.
  assert.ok(
    validateSongInput({
      source: 'youtube', titleKey: '그래우리함께', title: '그래 우리 함께',
      artist: '무한도전', youtubeVideoId: 'aaaaaaaaaaa',
    }),
  );
});

// ─── 순서 ───────────────────────────────────────────────────────────────────

test('PII 반려가 곡 upsert보다 **먼저** 온다 — 유령 곡이 남으면 안 된다', async () => {
  const { db, sql } = await freshDb();
  _setKv(fakeKv());

  await assert.rejects(
    () => createMemory(sql, 'hash', { song: SONG, body: '연락처는 010-1234-5678이야' }),
    (err) => err.status === 422 && err.code === 'pii_detected',
  );

  // 이게 이 테스트의 전부다. 순서가 뒤집히면 여기 곡이 1개 있다.
  const n = await db.query('SELECT count(*)::int n FROM songs');
  assert.equal(n.rows[0].n, 0, 'PII로 반려됐는데 기억 0편인 유령 곡이 남았다');
});

test('PII 응답은 위치만 주고 원문 조각은 안 싣는다', async () => {
  const { sql } = await freshDb();
  _setKv(fakeKv());
  const body = '내 번호 010-1234-5678 로 연락 줘';
  try {
    await createMemory(sql, 'hash', { song: SONG, body });
    assert.fail('통과했다');
  } catch (err) {
    assert.equal(err.code, 'pii_detected');
    assert.equal(err.spans.length, 1);
    assert.equal(err.spans[0].id, 'phone');
    assert.equal(body.slice(err.spans[0].index, err.spans[0].index + err.spans[0].length), '010-1234-5678');
    assert.ok(!JSON.stringify(err.spans).includes('1234'), 'span 에 원문이 실렸다');
    assert.ok(!err.message.includes('1234'), '메시지에 원문이 실렸다');
  }
});

test('레이트리밋 반려가 곡 upsert보다 먼저 온다', async () => {
  const { db, sql } = await freshDb();
  _setKv(fakeKv({ counts: { 'rl:write:minute:hash': 5 } })); // 이미 분당 상한 초과

  await assert.rejects(
    () => createMemory(sql, 'hash', { song: SONG, body: '멀쩡한 기억' }),
    (err) => err.status === 429 && err.code === 'rate_limited' && err.retryAfterSeconds === 42,
  );
  const n = await db.query('SELECT count(*)::int n FROM songs');
  assert.equal(n.rows[0].n, 0, '레이트리밋에 걸렸는데 곡이 생겼다');
});

// ─── 정상 경로 ──────────────────────────────────────────────────────────────

test('정상 경로 — 곡과 글이 같이 생기고 캐시 2키만 지운다', async () => {
  const { db, sql } = await freshDb();
  const kv = fakeKv();
  _setKv(kv);

  const out = await createMemory(sql, 'hash', {
    song: SONG, body: '야자 끝나고 혼자 걷던 길', season: 'winter', era: 'school',
  });

  const rows = await db.query(
    `SELECT m.body, m.season, m.era, m.is_public, m.status, s.title, s.youtube_video_id
       FROM memories m JOIN songs s ON s.id = m.song_id`,
  );
  assert.equal(rows.rows.length, 1);
  assert.equal(rows.rows[0].title, '밤편지');
  assert.equal(rows.rows[0].season, 'winter');
  assert.equal(rows.rows[0].era, 'school');
  assert.equal(rows.rows[0].is_public, true);
  assert.equal(rows.rows[0].status, 'visible');
  assert.equal(out.videoWasAlreadySet, false);

  // `오래 남은`은 건드리지 않는다. 좋아요 0인 새 글은 어차피 맨 뒤이고,
  // 여기까지 퍼지하면 stale 값이 사라져 SWR이 막으려던 최악 경로를 그대로 맞는다.
  assert.deepEqual(kv.deleted, [feedKey('recent'), feedKey('season')]);
  assert.ok(!kv.deleted.includes(feedKey('lasting')), 'lasting 을 퍼지했다 — SWR 재고가 사라진다');
});

test('비공개 글은 캐시를 안 지운다 — 피드에 안 나가므로', async () => {
  const { sql } = await freshDb();
  const kv = fakeKv();
  _setKv(kv);
  await createMemory(sql, 'hash', { song: SONG, body: '나만 보는 글', isPublic: false });
  assert.deepEqual(kv.deleted, []);
});

test('같은 곡에 두 번째 기억이 붙으면 곡은 하나뿐이다', async () => {
  const { db, sql } = await freshDb();
  _setKv(fakeKv());
  await createMemory(sql, 'a', { song: SONG, body: '첫 번째' });
  await createMemory(sql, 'b', { song: SONG, body: '두 번째' });

  const n = await db.query('SELECT (SELECT count(*)::int FROM songs) s, (SELECT count(*)::int FROM memories) m');
  assert.equal(n.rows[0].s, 1);
  assert.equal(n.rows[0].m, 2);
});

test('동시 등록에서 진 쪽 — 먼저 쓴 영상이 이기고, 진 쪽에게 그 사실을 알린다', async () => {
  const { db, sql } = await freshDb();
  _setKv(fakeKv());

  await createMemory(sql, 'winner', { song: SONG, body: '먼저 쓴 사람' });
  const loser = await createMemory(sql, 'loser', {
    song: { ...SONG, youtubeVideoId: 'ZZZZZZZZZZZ' }, // 다른 영상을 골랐다
    body: '나중에 쓴 사람',
  });

  assert.equal(loser.videoWasAlreadySet, true, '고른 영상이 말없이 버려졌는데 아무도 모른다');
  assert.equal(loser.existingVideoId, SONG.youtubeVideoId, '먼저 쓴 쪽의 영상이 이겨야 한다');

  const rows = await db.query('SELECT youtube_video_id FROM songs');
  assert.equal(rows.rows.length, 1);
  assert.equal(rows.rows[0].youtube_video_id, SONG.youtubeVideoId);
});

test('upsertSong — ON CONFLICT DO NOTHING 이 빈 결과를 줘도 id를 찾아낸다', async () => {
  const { sql } = await freshDb();
  const input = {
    source: 'itunes', itunes_artist_id: 1, itunes_track_id: 2,
    title_key: 'k', title: 't', artist: 'a', youtube_video_id: 'aaaaaaaaaaa',
  };
  const first = await upsertSong(sql, input);
  const second = await upsertSong(sql, input);
  assert.equal(first.inserted, true);
  assert.equal(second.inserted, false);
  assert.equal(String(second.songId), String(first.songId), 'id를 못 찾아 첫 등록이 조용히 실패했다');
  assert.equal(second.videoWasAlreadySet, false, '같은 영상인데 버려졌다고 말한다');
});

// ─── 핸들러 ─────────────────────────────────────────────────────────────────

/** 최소 res 스텁. */
function fakeRes() {
  const res = {
    statusCode: null, body: null, headers: {},
    setHeader(k, v) { this.headers[k] = v; return this; },
    status(c) { this.statusCode = c; return this; },
    json(b) { this.body = b; return this; },
  };
  return res;
}

test('핸들러 — POST 외는 405', async () => {
  const res = fakeRes();
  await handler({ method: 'GET' }, res);
  assert.equal(res.statusCode, 405);
  assert.equal(res.headers.Allow, 'POST');
});

test('핸들러 — 기기 키가 없으면 400이고, 그 값을 응답에 되비추지 않는다', async () => {
  const res = fakeRes();
  await handler({ method: 'POST', body: { body: 'x', song: SONG } }, res);
  assert.equal(res.statusCode, 400);
  assert.match(res.body.error, /기기 키/);
});

test('핸들러 — 본문을 로그에 남기지 않는다', async () => {
  const secret = 'SECRET-DEVICE-KEY-0001';
  const logged = [];
  const orig = console.log;
  console.log = (...a) => logged.push(a.join(' '));
  try {
    const res = fakeRes();
    // DATABASE_URL 이 없어 500으로 떨어지는 경로 — 가장 많이 로그를 남기는 쪽이다.
    await handler(
      { method: 'POST', body: { deviceKey: secret, body: '내 번호 010-1234-5678', song: SONG } },
      res,
    );
    const all = logged.join('\n');
    assert.ok(!all.includes(secret), `로그에 기기 키가 남았다:\n${all}`);
    assert.ok(!all.includes('010-1234-5678'), `로그에 본문이 남았다:\n${all}`);
  } finally {
    console.log = orig;
  }
});

test('이미 있는 곡이면 songId 하나만 보내면 된다 — "나도 적기" 경로', async () => {
  // 실제로 터졌던 버그. ⑥ 곡 상세의 "나도 적기"로 들어오면 화면은 곡의 title_key 를
  // 갖고 있지 않다(곡 상세 응답에 없다). 곡 정보를 통째로 되돌려 보내게 만들면
  // "곡 정보가 모자랍니다"로 막힌다.
  const { db, sql } = await freshDb();
  _setKv(fakeKv());

  const first = await createMemory(sql, 'a', { song: SONG, body: '첫 글' });
  const second = await createMemory(sql, 'b', { songId: String(first.songId), body: '나도 적기' });

  assert.equal(String(second.songId), String(first.songId));
  assert.equal(second.videoWasAlreadySet, false, '이미 있는 곡을 고른 건 경합에서 진 게 아니다');

  const n = await db.query('SELECT (SELECT count(*)::int FROM songs) s, (SELECT count(*)::int FROM memories) m');
  assert.equal(n.rows[0].s, 1, '곡이 새로 생겼다');
  assert.equal(n.rows[0].m, 2);
});

test('없는 songId 는 FK 위반 500이 아니라 404로 막는다', async () => {
  const { sql } = await freshDb();
  _setKv(fakeKv());
  await assert.rejects(
    () => createMemory(sql, 'a', { songId: '999999', body: 'x' }),
    (err) => err.status === 404,
  );
  // 작성자를 나눈다 — 같은 해시로 연달아 부르면 분당 1편 제한이 먼저 걸린다.
  await assert.rejects(
    () => createMemory(sql, 'b', { songId: 'not-a-number', body: 'x' }),
    (err) => err.status === 400,
  );
});
