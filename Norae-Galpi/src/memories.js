/**
 * ③④ 기억 올리기 — 검증·저장 로직. 핸들러(`api/memories.js`)는 이걸 부르기만 한다.
 *
 * ## 순서가 못 박혀 있다 (엔지니어링 결정 3)
 *   본문 검증 → PII → 레이트리밋 → 곡 upsert → 글 INSERT → 캐시 2키 퍼지
 *
 * **PII 반려가 upsert 뒤에 오면 합친 의미가 사라진다** — 글은 거부됐는데 기억 0편인
 * 유령 곡만 남는다. 곡 upsert와 글 작성을 한 엔드포인트로 합친 이유가 그거다
 * (Neon HTTP에 트랜잭션이 없어 나누면 그 유령 곡을 막을 방법이 없다).
 */

import { SEASONS, ERAS } from './labels.js';
import { detectPII } from './moderation.js';
import { checkWriteLimit } from './ratelimit.js';
import { upsertSong } from './songs.js';
import { purgeFeed, PURGE_ON_NEW_MEMORY } from './cache.js';

/** 서버측 본문 상한. 화면에는 글자수도 카운트다운도 두지 않는다 — 길게 쓰는 사람을 막지 않는다. */
export const BODY_MAX = 5000;

const VIDEO_ID_RE = /^[A-Za-z0-9_-]{11}$/;

/**
 * 에러에 HTTP 상태를 달아 던진다.
 *
 * @param {number} status
 * @param {string} message
 * @param {object} [extra]
 */
function fail(status, message, extra = {}) {
  const err = new Error(message);
  err.status = status;
  Object.assign(err, extra);
  throw err;
}

/**
 * 요청 본문에서 기억 부분을 검증한다. **순수 함수** — DB도 네트워크도 안 탄다.
 *
 * @param {object} payload
 * @returns {{body: string, season: string|null, era: string|null, isPublic: boolean}}
 */
export function validateMemoryInput(payload) {
  const raw = payload?.body;
  if (typeof raw !== 'string') fail(400, '기억을 적어주세요');

  // 앞뒤 공백만 다듬는다. 줄바꿈은 글쓴이가 만든 리듬이라 안 건드린다.
  const body = raw.replace(/^\s+|\s+$/g, '');
  if (body.length === 0) fail(400, '기억을 적어주세요');

  // Postgres char_length 와 같은 기준으로 센다. JS .length 는 이모지를 2로 센다.
  const length = [...body].length;
  if (length > BODY_MAX) {
    fail(400, `${BODY_MAX}자까지 쓸 수 있어요`, { length, max: BODY_MAX });
  }

  const season = payload?.season ?? null;
  if (season !== null && !SEASONS.includes(season)) fail(400, '계절 값이 올바르지 않습니다');

  const era = payload?.era ?? null;
  if (era !== null && !ERAS.includes(era)) fail(400, '시절 값이 올바르지 않습니다');

  // 공개가 기본이다. 명시적으로 false 일 때만 비공개.
  const isPublic = payload?.isPublic !== false;

  return { body, season, era, isPublic };
}

/**
 * 곡 입력을 검증해 DB 모양으로 바꾼다.
 *
 * @param {object} song
 * @returns {import('./songs.js').SongInput}
 */
export function validateSongInput(song) {
  const source = song?.source;
  if (source !== 'itunes' && source !== 'youtube') fail(400, '곡 출처가 올바르지 않습니다');

  const videoId = song?.youtubeVideoId;
  // 두 경로 모두 필수다 — 재생이 거기서만 나온다.
  if (typeof videoId !== 'string' || !VIDEO_ID_RE.test(videoId)) {
    fail(400, '유튜브 영상을 정해주세요');
  }

  const titleKey = typeof song?.titleKey === 'string' ? song.titleKey.trim() : '';
  const title = typeof song?.title === 'string' ? song.title.trim() : '';
  const artist = typeof song?.artist === 'string' ? song.artist.trim() : '';
  if (!titleKey || !title || !artist) fail(400, '곡 정보가 모자랍니다');

  if (source === 'itunes' && !Number.isInteger(song?.itunesArtistId)) {
    fail(400, '곡 정보가 모자랍니다');
  }

  return {
    source,
    itunes_artist_id: source === 'itunes' ? song.itunesArtistId : null,
    itunes_track_id: Number.isInteger(song?.itunesTrackId) ? song.itunesTrackId : null,
    title_key: titleKey,
    title_key_rev: Number.isInteger(song?.titleKeyRev) ? song.titleKeyRev : 1,
    title,
    artist,
    artwork_url: typeof song?.artworkUrl === 'string' ? song.artworkUrl : null,
    youtube_video_id: videoId,
  };
}

/**
 * 기억 한 편을 올린다.
 *
 * @param {any} sql - Neon 클라이언트
 * @param {string} authorHash - **서버에서 계산한** 해시. 원본 키가 여기까지 오면 안 된다
 * @param {object} payload - 요청 본문
 * @returns {Promise<{memoryId: unknown, songId: unknown, videoWasAlreadySet: boolean,
 *                    existingVideoId: string|null, purgedKeys: number}>}
 */
export async function createMemory(sql, authorHash, payload) {
  // 1) 본문 검증
  const { body, season, era, isPublic } = validateMemoryInput(payload);

  // 2) PII — 저장하지 않고 즉시 돌려주며 **어느 부분인지** 표시한다.
  //    ④ 공개 확인 시트 안에서 한 번만 뜨고, 고칠 때까지 올리기가 비활성화된다.
  const pii = detectPII(body);
  if (pii.length > 0) {
    fail(422, '개인정보로 보이는 부분이 있어요', {
      code: 'pii_detected',
      // 원문 조각은 싣지 않는다 — 위치와 종류만 준다. 본문은 클라이언트가 이미 갖고 있다.
      spans: pii.map((h) => ({ id: h.id, label: h.label, index: h.index, length: h.length })),
    });
  }

  // 3) 레이트리밋
  const limit = await checkWriteLimit(authorHash);
  if (!limit.ok) {
    fail(429, '조금 뒤에 다시 올려주세요', {
      code: 'rate_limited',
      limit: limit.limit,
      retryAfterSeconds: limit.retryAfterSeconds,
    });
  }

  // 4) 곡 — 이미 있는 곡이면 id 만 받는다
  //
  // ⑥ 곡 상세의 "나도 적기"로 들어온 사람은 곡을 새로 만드는 게 아니다. 그때 클라이언트가
  // 곡 정보를 통째로 되돌려 보내게 하면, 화면이 갖고 있지도 않은 값(title_key 등)까지
  // 들고 다녀야 하고 남의 곡 필드를 손댈 여지가 생긴다. **id 하나면 충분하다.**
  const song = payload?.songId != null
    ? await useExistingSong(sql, payload.songId)
    // 새 곡이면 upsert. 여기까지 와야 유령 곡이 안 생긴다.
    : await upsertSong(sql, validateSongInput(payload?.song));

  // 5) 글 INSERT
  const rows = await sql`
    INSERT INTO memories (song_id, author_hash, body, season, era, is_public)
    VALUES (${song.songId}, ${authorHash}, ${body}, ${season}, ${era}, ${isPublic})
    RETURNING id
  `;

  // 6) 캐시 퍼지 — `최신`·`지금 계절` 2키만.
  //    `오래 남은`은 건드리지 않는다. 좋아요 0인 새 글은 어차피 맨 뒤고,
  //    여기까지 퍼지하면 stale 값이 사라져 SWR이 막으려던 최악 경로를 그대로 맞는다.
  //    비공개 글이면 피드에 안 나가므로 퍼지할 이유도 없다.
  const purgedKeys = isPublic ? await purgeFeed(PURGE_ON_NEW_MEMORY) : 0;

  return {
    memoryId: rows[0].id,
    songId: song.songId,
    videoWasAlreadySet: song.videoWasAlreadySet,
    existingVideoId: song.existingVideoId,
    purgedKeys,
  };
}

/**
 * 이미 있는 곡을 쓴다. 없는 id 면 거부한다 — FK 위반으로 500이 나는 대신
 * 무엇이 잘못됐는지 말해준다.
 *
 * @param {any} sql
 * @param {unknown} songId
 * @returns {Promise<{songId: unknown, inserted: boolean, videoWasAlreadySet: boolean,
 *                    existingVideoId: string|null}>}
 */
async function useExistingSong(sql, songId) {
  if (!/^\d+$/.test(String(songId))) fail(400, '곡을 찾을 수 없습니다');
  const rows = await sql`SELECT id, youtube_video_id FROM songs WHERE id = ${String(songId)} LIMIT 1`;
  if (rows.length === 0) fail(404, '곡을 찾을 수 없습니다');
  return {
    songId: rows[0].id,
    inserted: false,
    // 이미 있는 곡을 고른 것이지 경합에서 진 게 아니다.
    videoWasAlreadySet: false,
    existingVideoId: rows[0].youtube_video_id,
  };
}
