/**
 * 읽기 경로 — 피드 · 곡 상세 · 내 갈피 · 좋아요 · 신고 · 운영자 숨김.
 *
 * DB는 PGlite, Redis는 가짜. `sql` 은 Neon 처럼 태그드 템플릿이면서 `.query(text, params)`도 갖는다.
 */

import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { PGlite } from '@electric-sql/pglite';

import { getFeed, queryFeed, getSongDetail, getMyMemories, setLike } from '../src/read.js';
import { createReport, setMemoryStatus, AUTO_HIDE_THRESHOLD } from '../src/moderation-actions.js';
import { createMemory } from '../src/memories.js';
import { feedKey } from '../src/cache.js';
import { _setKv } from '../src/kv.js';

const __dirname = dirname(fileURLToPath(import.meta.url));

/** Neon 모양 어댑터 — 태그드 템플릿 + `.query(text, params)`. */
function neonLike(db) {
  const tagged = async (strings, ...values) => {
    let text = '';
    strings.forEach((p, i) => { text += p + (i < values.length ? `$${i + 1}` : ''); });
    return (await db.query(text, values)).rows;
  };
  tagged.query = async (text, params = []) => (await db.query(text, params)).rows;
  return tagged;
}

async function freshDb() {
  const db = await PGlite.create();
  const stmts = readFileSync(join(__dirname, '../migrations/001_init.sql'), 'utf8')
    .split('\n').filter((l) => !l.trim().startsWith('--')).join('\n')
    .split(';').map((s) => s.trim()).filter(Boolean);
  for (const s of stmts) await db.exec(s);
  return { db, sql: neonLike(db) };
}

function fakeKv() {
  const store = new Map();
  const deleted = [];
  return {
    store, deleted,
    async get(k) { return store.get(k) ?? null; },
    async set(k, v) { store.set(k, v); },
    async del(...ks) { ks.forEach((k) => { store.delete(k); deleted.push(k); }); return ks.length; },
    async incr(k) { const n = (store.get(k) ?? 0) + 1; store.set(k, n); return n; },
    async expire() { return 1; },
    async ttl() { return 30; },
  };
}

const SONG = (i) => ({
  source: 'youtube',
  titleKey: `k${i}`,
  title: `곡${i}`,
  artist: `가수${i}`,
  youtubeVideoId: `v${String(i).padStart(10, '0')}`,
});

test.afterEach(() => _setKv(null));

// ─── 피드 ───────────────────────────────────────────────────────────────────

test('피드 — 쿼리 2번으로 곡 카드를 만든다', async () => {
  const { sql } = await freshDb();
  _setKv(fakeKv());
  await createMemory(sql, 'a', { song: SONG(1), body: '첫 곡 기억', season: 'winter' });
  await createMemory(sql, 'b', { song: SONG(2), body: '둘째 곡 기억' });

  const feed = await queryFeed(sql, { sort: 'recent', season: 'winter', page: 1 });
  assert.equal(feed.cards.length, 2);
  assert.equal(feed.cards[0].song.title, '곡2', '최신 곡이 위여야 한다');
  assert.equal(feed.cards[0].memories.length, 1);
  assert.ok(!('liked' in feed.cards[0].memories[0]), '피드에는 좋아요 상태를 안 싣는다');
});

test('피드 — `지금 계절` 경계에 구분선이 정확히 한 번 생긴다', async () => {
  const { sql } = await freshDb();
  _setKv(fakeKv());
  // 계절 있는 곡 2개, 없는 곡 2개
  await createMemory(sql, 'a', { song: SONG(1), body: 'a', season: 'winter' });
  await createMemory(sql, 'b', { song: SONG(2), body: 'b', season: 'winter' });
  await createMemory(sql, 'c', { song: SONG(3), body: 'c' });
  await createMemory(sql, 'd', { song: SONG(4), body: 'd' });

  const feed = await queryFeed(sql, { sort: 'season', season: 'winter', page: 1 });
  const boundaries = feed.cards.filter((c) => c.seasonBoundary);
  assert.equal(boundaries.length, 1, '구분선이 한 줄이 아니다');
  assert.equal(feed.cards.indexOf(boundaries[0]), 2, '구분선이 계절 구간 끝이 아니다');
});

test('피드 — `최신` 정렬에는 구분선이 없다', async () => {
  const { sql } = await freshDb();
  _setKv(fakeKv());
  await createMemory(sql, 'a', { song: SONG(1), body: 'a', season: 'winter' });
  await createMemory(sql, 'b', { song: SONG(2), body: 'b' });
  const feed = await queryFeed(sql, { sort: 'recent', season: 'winter', page: 1 });
  assert.ok(feed.cards.every((c) => !c.seasonBoundary));
});

test('피드 — 캐시 히트는 DB를 안 친다', async () => {
  const { sql } = await freshDb();
  _setKv(fakeKv());
  await createMemory(sql, 'a', { song: SONG(1), body: 'a' });

  const first = await getFeed(sql, { sort: 'recent' });
  assert.equal(first.cached, false);

  // DB를 못 쓰게 막아두고 다시 부른다 — 캐시에서만 나와야 한다.
  const broken = { query: () => { throw new Error('DB를 쳤다'); } };
  const second = await getFeed(broken, { sort: 'recent' });
  assert.equal(second.cached, true);
  assert.equal(second.stale, false);
  assert.equal(second.cards.length, 1);
});

test('피드 — SWR: 만료돼도 옛 값을 즉시 주고 갱신은 뒤에서 돈다', async () => {
  const { sql } = await freshDb();
  const kv = fakeKv();
  _setKv(kv);
  await createMemory(sql, 'a', { song: SONG(1), body: '옛날 값' });
  await getFeed(sql, { sort: 'lasting' });

  // 캐시를 강제로 만료시킨다.
  const entry = JSON.parse(kv.store.get(feedKey('lasting')));
  entry.staleAt = Date.now() - 1000;
  kv.store.set(feedKey('lasting'), JSON.stringify(entry));

  // 그사이 새 글이 올라왔다. lasting 은 퍼지 대상이 아니라 캐시에 아직 없다.
  await createMemory(sql, 'b', { song: SONG(2), body: '새 값' });

  const queued = [];
  const stale = await getFeed(sql, { sort: 'lasting', revalidate: (fn) => queued.push(fn) });
  assert.equal(stale.stale, true);
  assert.equal(stale.cards.length, 1, '갱신을 기다렸다 — SWR이 성립하지 않는다');
  assert.equal(queued.length, 1, '갱신이 뒤로 안 넘어갔다');

  await queued[0]();
  const after = await getFeed(sql, { sort: 'lasting' });
  assert.equal(after.cards.length, 2, '뒤에서 도는 갱신이 캐시를 못 채웠다');
});

test('피드 — 2페이지 이후는 캐시를 안 탄다', async () => {
  const { sql } = await freshDb();
  const kv = fakeKv();
  _setKv(kv);
  await createMemory(sql, 'a', { song: SONG(1), body: 'a' });
  await getFeed(sql, { sort: 'recent', page: 2 });
  assert.equal(kv.store.has(feedKey('recent')), false, '2페이지를 캐시에 넣었다');
});

// ─── 곡 상세 · 내 갈피 ──────────────────────────────────────────────────────

test('곡 상세 — 그 곡의 기억 전부. 좋아요는 개수가 아니라 눌림 여부만', async () => {
  const { sql, db } = await freshDb();
  _setKv(fakeKv());
  const m1 = await createMemory(sql, 'a', { song: SONG(1), body: '첫 번째' });
  await createMemory(sql, 'b', { song: SONG(1), body: '두 번째' });
  await setLike(sql, m1.memoryId, 'me', true);
  await setLike(sql, m1.memoryId, 'other', true);

  const detail = await getSongDetail(sql, m1.songId, 'me');
  assert.equal(detail.memories.length, 2);
  assert.equal(detail.song.title, '곡1');
  assert.equal(detail.memories.find((m) => String(m.id) === String(m1.memoryId)).liked, true);
  assert.equal(detail.memories.find((m) => String(m.id) !== String(m1.memoryId)).liked, false);

  // 개수가 응답에 섞이면 안 된다. 실제로 2명이 눌렀다.
  assert.ok(!JSON.stringify(detail).includes('"likes"'), '응답에 좋아요 개수가 실렸다');
  const n = await db.query('SELECT count(*)::int n FROM memory_likes');
  assert.equal(n.rows[0].n, 2, '전제 확인 — DB에는 2건이 있다');

  assert.equal(await getSongDetail(sql, 999999, null), null);
});

test('내 갈피 — 비공개도 숨김도 removed 도 본인에게는 보인다', async () => {
  const { sql } = await freshDb();
  // 레이트리밋이 진짜로 분당 1편을 막는다(아래 테스트가 그걸 확인한다).
  // 여기서 보려는 건 한 사람의 글 여러 편이라 카운터를 끈다 — Redis 없이도 서비스는 돈다.
  _setKv(null);
  const pub = await createMemory(sql, 'me', { song: SONG(1), body: '공개 글' });
  await createMemory(sql, 'me', { song: SONG(2), body: '비공개 글', isPublic: false });
  const hidden = await createMemory(sql, 'me', { song: SONG(3), body: '숨겨질 글' });
  await createMemory(sql, 'other', { song: SONG(4), body: '남의 글' });
  await setMemoryStatus(sql, hidden.memoryId, 'removed');

  const mine = await getMyMemories(sql, 'me');
  assert.equal(mine.length, 3, '자기 글 3편이 다 보여야 한다');
  assert.ok(mine.every((m) => m.body !== '남의 글'));

  // 조용히 사라지면 사용자가 더 혼란스럽다 — 상태를 같이 준다.
  assert.equal(mine.find((m) => m.body === '숨겨질 글').status, 'removed');
  assert.equal(mine.find((m) => m.body === '비공개 글').is_public, false);
  assert.equal(mine.find((m) => String(m.id) === String(pub.memoryId)).status, 'visible');
});

test('좋아요 토글은 멱등하다', async () => {
  const { sql, db } = await freshDb();
  _setKv(fakeKv());
  const m = await createMemory(sql, 'a', { song: SONG(1), body: 'x' });

  for (let i = 0; i < 3; i++) await setLike(sql, m.memoryId, 'me', true);
  let n = await db.query('SELECT count(*)::int n FROM memory_likes');
  assert.equal(n.rows[0].n, 1);

  for (let i = 0; i < 3; i++) await setLike(sql, m.memoryId, 'me', false);
  n = await db.query('SELECT count(*)::int n FROM memory_likes');
  assert.equal(n.rows[0].n, 0);
});

test('좋아요는 캐시를 안 지운다 — 순위가 5분 늦어도 무해하다', async () => {
  const { sql } = await freshDb();
  const kv = fakeKv();
  _setKv(kv);
  const m = await createMemory(sql, 'a', { song: SONG(1), body: 'x' });
  kv.deleted.length = 0;
  await setLike(sql, m.memoryId, 'me', true);
  assert.deepEqual(kv.deleted, []);
});

// ─── 신고 · 운영자 ──────────────────────────────────────────────────────────

test('신고 — 같은 사람이 같은 글을 반복 신고해도 1건이다', async () => {
  const { sql, db } = await freshDb();
  _setKv(fakeKv());
  const m = await createMemory(sql, 'a', { song: SONG(1), body: 'x' });

  for (let i = 0; i < 5; i++) {
    await createReport(sql, 'spammer', { memoryId: m.memoryId, reason: '싫어요' });
  }
  const n = await db.query('SELECT count(*)::int n FROM reports');
  assert.equal(n.rows[0].n, 1);

  const still = await db.query('SELECT status FROM memories WHERE id=$1', [m.memoryId]);
  assert.equal(still.rows[0].status, 'visible', '한 사람이 혼자서 글을 내렸다');
});

test('신고 — 임계치를 넘으면 자동으로 내려가고 캐시 3키가 전부 지워진다', async () => {
  const { sql, db } = await freshDb();
  const kv = fakeKv();
  _setKv(kv);
  const m = await createMemory(sql, 'a', { song: SONG(1), body: 'x' });
  kv.deleted.length = 0;

  for (let i = 0; i < AUTO_HIDE_THRESHOLD - 1; i++) {
    const out = await createReport(sql, `r${i}`, { memoryId: m.memoryId, reason: '문제' });
    assert.equal(out.autoHidden, false);
  }
  const last = await createReport(sql, 'rN', { memoryId: m.memoryId, reason: '문제' });
  assert.equal(last.autoHidden, true);

  const row = await db.query('SELECT status FROM memories WHERE id=$1', [m.memoryId]);
  assert.equal(row.rows[0].status, 'hidden');

  // 숨긴 글 노출은 지연이 허용되지 않는다. 여기서는 SWR을 포기한다.
  assert.deepEqual(kv.deleted.sort(), [feedKey('lasting'), feedKey('recent'), feedKey('season')].sort());
});

test('신고 — 무엇을 신고하는지 없으면 거부한다', async () => {
  const { sql } = await freshDb();
  _setKv(fakeKv());
  await assert.rejects(() => createReport(sql, 'r', { reason: '문제' }), /알 수 없습니다/);
  await assert.rejects(() => createReport(sql, 'r', { songId: 1 }), /사유/);
});

test('운영자 숨김 — 이미 그 상태면 캐시를 안 건드린다', async () => {
  const { sql } = await freshDb();
  const kv = fakeKv();
  _setKv(kv);
  const m = await createMemory(sql, 'a', { song: SONG(1), body: 'x' });

  assert.equal(await setMemoryStatus(sql, m.memoryId, 'hidden'), true);
  kv.deleted.length = 0;
  assert.equal(await setMemoryStatus(sql, m.memoryId, 'hidden'), false, '같은 상태인데 바꿨다고 한다');
  assert.deepEqual(kv.deleted, [], '바뀐 게 없는데 캐시를 지웠다');
});

test('숨긴 글은 피드에서 빠지지만 곡은 남는다', async () => {
  const { sql } = await freshDb();
  _setKv(fakeKv());
  const m = await createMemory(sql, 'a', { song: SONG(1), body: '내려갈 글' });
  await createMemory(sql, 'b', { song: SONG(1), body: '남을 글' });
  await setMemoryStatus(sql, m.memoryId, 'hidden');

  const feed = await queryFeed(sql, { sort: 'recent', season: 'winter', page: 1 });
  assert.equal(feed.cards.length, 1);
  assert.equal(feed.cards[0].memories.length, 1);
  assert.equal(feed.cards[0].memories[0].body, '남을 글');
});

test('레이트리밋 — 같은 사람이 1분 안에 두 번째 글을 못 올린다', async () => {
  // 설계값: 작성 분당 1편 / 일 20편. 로그인이 없어 키를 새로 뽑으면 우회되지만,
  // 여기서 막는 건 "한 사람이 스크립트로 수백 편을 쏟아붓는 것"이다.
  const { sql } = await freshDb();
  _setKv(fakeKv());
  await createMemory(sql, 'burst', { song: SONG(1), body: '첫 글' });
  await assert.rejects(
    () => createMemory(sql, 'burst', { song: SONG(2), body: '두 번째 글' }),
    (err) => err.status === 429 && err.limit === 'minute',
  );
  // 다른 사람은 막히지 않는다.
  await createMemory(sql, 'other', { song: SONG(3), body: '남의 글' });
});
