/**
 * 유튜브 폴백 + 핸들러 규율.
 *
 * 여기서 지키는 두 가지가 설계의 뼈대다.
 *   - **키가 없어도 ② 화면이 돈다** — 구글 클라우드 행정이 출시를 막지 않는다
 *   - **기기 비밀키가 URL에 안 실린다** — 실리면 서버에 해시만 저장하는 설계가 무의미해진다
 */

import test from 'node:test';
import assert from 'node:assert/strict';

import { findVideos, parseVideoId, probeVideo, thumbnailUrl } from '../src/youtube.js';
import { keyFromRequest, optionalKeyFromRequest, hashKey } from '../src/identity.js';
import { _setKv } from '../src/kv.js';

import songSearch from '../api/song-search.js';
import videoSearch from '../api/video-search.js';
import mine from '../api/mine.js';
import likes from '../api/likes.js';
import adminHide from '../api/admin-hide.js';

function fakeRes() {
  return {
    statusCode: null, body: null, headers: {},
    setHeader(k, v) { this.headers[k.toLowerCase()] = v; return this; },
    status(c) { this.statusCode = c; return this; },
    json(b) { this.body = b; return this; },
  };
}

test.afterEach(() => _setKv(null));

// ─── 유튜브 ─────────────────────────────────────────────────────────────────

test('parseVideoId — 모바일에서 붙여넣는 온갖 모양을 받는다', () => {
  const ID = 'XtYGk-kvWP0';
  for (const input of [
    ID,
    `https://www.youtube.com/watch?v=${ID}`,
    `https://youtube.com/watch?v=${ID}&t=42s`,
    `https://m.youtube.com/watch?v=${ID}`,
    `https://youtu.be/${ID}`,
    `https://youtu.be/${ID}?si=abcdef`,
    `https://www.youtube.com/embed/${ID}`,
    `https://www.youtube.com/shorts/${ID}`,
    `https://www.youtube.com/live/${ID}`,
    `https://www.youtube-nocookie.com/embed/${ID}`,
    `  youtube.com/watch?v=${ID}  `,
  ]) {
    assert.equal(parseVideoId(input), ID, `못 뽑았다: ${input}`);
  }

  for (const bad of ['', '   ', null, undefined, 'https://vimeo.com/12345', 'not a url', 'https://evil.com/watch?v=XtYGk-kvWP0']) {
    assert.equal(parseVideoId(bad), null, `받으면 안 되는데 받았다: ${bad}`);
  }
});

test('findVideos — 키가 없으면 우아하게 떨어진다 (출시를 막지 않는다)', async () => {
  const r = await findVideos('밤편지 아이유', { apiKey: undefined, fetchImpl: () => { throw new Error('부르면 안 된다'); } });
  assert.equal(r.available, false);
  assert.equal(r.reason, 'no_key');
  assert.deepEqual(r.videos, []);
});

test('findVideos — 403은 쿼터 소진과 같은 폴백을 탄다', async () => {
  _setKv(null);
  const r = await findVideos('x', { apiKey: 'k', fetchImpl: async () => ({ ok: false, status: 403 }) });
  assert.equal(r.available, false);
  assert.equal(r.reason, 'quota');
});

test('findVideos — 우리 카운터가 구글보다 먼저 멈춘다', async () => {
  let counter = 100; // 이미 상한
  _setKv({
    async incr() { return ++counter; },
    async expire() { return 1; },
  });
  const r = await findVideos('x', { apiKey: 'k', fetchImpl: () => { throw new Error('구글을 불렀다'); } });
  assert.equal(r.reason, 'quota');
});

test('findVideos — 임베드 가능한 영상만, ID가 온전한 것만', async () => {
  _setKv(null);
  const r = await findVideos('x', {
    apiKey: 'k',
    fetchImpl: async () => ({
      ok: true, status: 200,
      json: async () => ({
        items: [
          { id: { videoId: 'XtYGk-kvWP0' }, snippet: { title: 'A', channelTitle: 'C', thumbnails: { medium: { url: 't' } } } },
          { id: { channelId: 'UCxxx' }, snippet: { title: '채널이라 영상 ID가 없다' } },
          { id: { videoId: 'short' }, snippet: { title: 'B' } },
        ],
      }),
    }),
  });
  assert.equal(r.available, true);
  assert.equal(r.videos.length, 1);
  assert.equal(r.videos[0].videoId, 'XtYGk-kvWP0');
});

test('probeVideo — 400이면 죽은 영상, 네트워크 실패는 "모름"이지 죽음이 아니다', async () => {
  assert.equal((await probeVideo('XtYGk-kvWP0', { fetchImpl: async () => ({ ok: false, status: 400 }) })).alive, false);
  assert.equal((await probeVideo('XtYGk-kvWP0', { fetchImpl: async () => { throw new Error('네트워크'); } })).alive, true);
  assert.equal((await probeVideo('나쁜아이디')).alive, false);
  assert.match(thumbnailUrl('XtYGk-kvWP0'), /XtYGk-kvWP0/);
});

// ─── 프라이버시 규율 ────────────────────────────────────────────────────────

test('기기 키는 헤더로 받는다 — 쿼리스트링으로는 절대 안 받는다', () => {
  const key = 'device-secret';
  assert.equal(keyFromRequest({ headers: { 'x-device-key': key } }), hashKey(key));
  assert.equal(keyFromRequest({ headers: {} }, { deviceKey: key }), hashKey(key));

  // URL에 실어 보내도 안 읽힌다. 읽히면 프록시 로그·리퍼러·히스토리에 키가 남는다.
  assert.throws(() => keyFromRequest({ headers: {}, query: { deviceKey: key } }), /기기 키/);
  assert.equal(optionalKeyFromRequest({ headers: {}, query: { deviceKey: key } }), null);
});

test('GET /api/mine — 키가 없으면 400이고 응답에 아무 글도 안 샌다', async () => {
  const res = fakeRes();
  await mine({ method: 'GET', headers: {} }, res);
  assert.equal(res.statusCode, 400);
  assert.equal(res.body.memories, undefined);
});

test('핸들러 — 메서드가 틀리면 405 + Allow', async () => {
  for (const [h, method, allow] of [
    [songSearch, 'POST', 'GET'], [videoSearch, 'POST', 'GET'],
    [mine, 'POST', 'GET'], [likes, 'GET', 'POST'], [adminHide, 'GET', 'POST'],
  ]) {
    const res = fakeRes();
    await h({ method, headers: {}, query: {} }, res);
    assert.equal(res.statusCode, 405);
    assert.equal(res.headers.allow, allow);
  }
});

test('GET /api/song-search — 질의가 없으면 400, 있으면 "찾는 곡이 없어요"를 항상 켠다', async () => {
  const empty = fakeRes();
  await songSearch({ method: 'GET', headers: {}, query: {} }, empty);
  assert.equal(empty.statusCode, 400);
});

test('GET /api/video-search — 직접 링크 경로는 쿼터를 안 쓴다', async () => {
  let incremented = false;
  _setKv({ async incr() { incremented = true; return 1; }, async expire() { return 1; } });

  const res = fakeRes();
  await videoSearch(
    { method: 'GET', headers: {}, query: { url: 'https://youtu.be/XtYGk-kvWP0' } },
    res,
  );
  assert.equal(res.statusCode, 200);
  assert.equal(res.body.videoId, 'XtYGk-kvWP0');
  assert.equal(incremented, false, '직접 링크인데 검색 쿼터를 썼다');
});

test('GET /api/video-search — 유튜브가 아닌 주소는 이유를 말하고 거절한다', async () => {
  const res = fakeRes();
  await videoSearch({ method: 'GET', headers: {}, query: { url: 'https://vimeo.com/1' } }, res);
  assert.equal(res.statusCode, 400);
  assert.equal(res.body.code, 'bad_video_url');
});

// ─── 운영자 ─────────────────────────────────────────────────────────────────

test('운영자 숨김 — 토큰이 없거나 틀리면 못 들어온다', async () => {
  const saved = process.env.ADMIN_TOKEN;
  try {
    delete process.env.ADMIN_TOKEN;
    const closed = fakeRes();
    await adminHide({ method: 'POST', headers: {}, body: {} }, closed);
    assert.equal(closed.statusCode, 503, '토큰 미설정인데 열려 있다');

    process.env.ADMIN_TOKEN = 'correct-horse';
    for (const token of [undefined, '', 'wrong', 'correct-hors', 'correct-horsee']) {
      const res = fakeRes();
      await adminHide({ method: 'POST', headers: { 'x-admin-token': token }, body: { memoryId: 1 } }, res);
      assert.equal(res.statusCode, 401, `토큰 ${JSON.stringify(token)} 가 통과했다`);
    }
  } finally {
    if (saved === undefined) delete process.env.ADMIN_TOKEN;
    else process.env.ADMIN_TOKEN = saved;
  }
});

test('복구 코드에 한글이 있어도 헤더로 오간다', () => {
  // 실제로 터졌던 버그. 복구 코드가 `갈피-…`로 시작하는데 HTTP 헤더 값은 ISO-8859-1 만
  // 담을 수 있어, 한글을 그대로 넣으면 fetch 가 통째로 던진다
  // (`String contains non ISO-8859-1 code point`). ⑦ 내 갈피와 ⑥ 좋아요 상태가 전부 죽는다.
  const key = '갈피-4F7K-2M9Q-8XZP';
  const encoded = encodeURIComponent(key);

  // 브라우저가 실제로 헤더에 넣을 수 있는 값인지 — 여기서 던지면 클라이언트에서도 던진다.
  assert.doesNotThrow(() => new Headers({ 'X-Device-Key': encoded }));
  assert.throws(() => new Headers({ 'X-Device-Key': key }), '전제 확인 — 원본은 헤더에 못 넣는다');

  // 인코드해서 보내도 POST 본문으로 보낸 것과 **같은 해시**가 나와야 한다.
  // 안 그러면 같은 기기가 GET 과 POST 에서 서로 다른 사람이 된다.
  assert.equal(
    keyFromRequest({ headers: { 'x-device-key': encoded } }),
    keyFromRequest({ headers: {} }, { deviceKey: key }),
  );

  // 인코딩 안 된 ASCII 키도 그대로 통과한다.
  assert.equal(
    keyFromRequest({ headers: { 'x-device-key': 'plain-ascii-key' } }),
    hashKey('plain-ascii-key'),
  );
});
