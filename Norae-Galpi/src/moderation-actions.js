/**
 * 신고와 운영자 숨김.
 *
 * ## 대기열을 만들지 않는다
 * "걸린 글은 운영자가 확인"으로 설계하면 **매일 대기열을 봐야 하는 제품**이 된다.
 * 하루만 안 봐도 글이 멈춘다. 그래서 `pending` 상태가 없고, 글은 올라가는 즉시 보인다.
 *
 * ## 행을 지우지 않는다
 * 운영자 처리는 삭제가 아니라 `status` 변경이다. 오처리를 되돌릴 수 있어야 하고,
 * 신고 이력이 곧 판단 근거이기 때문이다. `reports.memory_id`의 `ON DELETE RESTRICT`는
 * 그 규율을 강제하는 안전장치이지 이유가 아니다.
 */

import { purgeFeed, PURGE_ON_STATUS_CHANGE } from './cache.js';

/**
 * 신고가 이 수를 넘으면 자동으로 `hidden` 으로 내린다.
 *
 * `요확인` — 설계가 "임계치는 착수 시 확정"으로 남긴 값이다. 3은 **잠정값**이고
 * Tabber가 정하면 바꾼다. 낮으면 소수의 반복 신고로 멀쩡한 글이 내려가고,
 * 높으면 문제 글이 오래 남는다. `UNIQUE (memory_id, reporter_hash)`가
 * 한 사람의 반복 신고는 이미 막고 있으므로 서로 다른 3명이 필요하다.
 */
export const AUTO_HIDE_THRESHOLD = 3;

const MAX_REASON_LENGTH = 500;

/**
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
 * 신고를 접수한다. 기억 신고와 "영상이 곡과 달라요" 곡 신고 두 가지다.
 *
 * @param {any} sql
 * @param {string} reporterHash
 * @param {{memoryId?: unknown, songId?: unknown, reason?: unknown}} payload
 * @returns {Promise<{reported: boolean, autoHidden: boolean}>}
 */
export async function createReport(sql, reporterHash, payload) {
  const memoryId = payload?.memoryId ?? null;
  const songId = payload?.songId ?? null;
  if (memoryId == null && songId == null) fail(400, '무엇을 신고하는지 알 수 없습니다');

  const reason = typeof payload?.reason === 'string' ? payload.reason.trim() : '';
  if (reason.length === 0) fail(400, '신고 사유를 적어주세요');
  if ([...reason].length > MAX_REASON_LENGTH) fail(400, '신고 사유가 너무 깁니다');

  // 한 사람이 같은 글을 반복 신고하지 못한다 — UNIQUE (memory_id, reporter_hash).
  // 이미 신고했으면 조용히 성공으로 돌려준다. "이미 신고했습니다"를 알려줄 이유가 없고,
  // 알려주면 남의 신고 여부를 떠보는 데 쓰인다.
  await sql.query(
    `INSERT INTO reports (memory_id, song_id, reason, reporter_hash)
     VALUES ($1, $2, $3, $4) ON CONFLICT DO NOTHING`,
    [memoryId, songId, reason, reporterHash],
  );

  if (memoryId == null) return { reported: true, autoHidden: false };

  // 임계치를 넘으면 자동으로 내린다. 이것도 코드 경로라 캐시 퍼지가 일어난다.
  const counted = await sql.query(
    `SELECT count(*)::int AS n FROM reports WHERE memory_id = $1 AND resolved_at IS NULL`,
    [memoryId],
  );
  if ((counted[0]?.n ?? 0) < AUTO_HIDE_THRESHOLD) return { reported: true, autoHidden: false };

  const changed = await setMemoryStatus(sql, memoryId, 'hidden');
  return { reported: true, autoHidden: changed };
}

/**
 * 기억의 `status`를 바꾸고 **피드 캐시 3키를 전부 퍼지한다.**
 *
 * 여기서는 SWR을 포기한다 — 숨긴 글이 피드에 남아 있는 건 지연이 허용되지 않는다.
 *
 * Vercel Data editor로 DB를 직접 고치면 이 코드를 안 거쳐 퍼지가 일어날 수 없다.
 * Data editor는 **보고 판단하는 용도**로 쓰고 실제 숨김은 `POST /api/admin/hide`로 한다.
 * 직접 수정했을 때의 폴백은 60초 TTL뿐이다.
 *
 * @param {any} sql
 * @param {unknown} memoryId
 * @param {'visible'|'hidden'|'removed'} status
 * @returns {Promise<boolean>} 실제로 바뀌었으면 true
 */
export async function setMemoryStatus(sql, memoryId, status) {
  if (!['visible', 'hidden', 'removed'].includes(status)) fail(400, 'status 값이 올바르지 않습니다');

  const rows = await sql.query(
    `UPDATE memories SET status = $2 WHERE id = $1 AND status <> $2 RETURNING id`,
    [memoryId, status],
  );
  if (rows.length === 0) return false;

  await purgeFeed(PURGE_ON_STATUS_CHANGE);
  return true;
}

/**
 * 곡의 유튜브 영상을 고친다 — "영상이 곡과 달라요" 신고를 받은 뒤 같은 화면에서.
 *
 * @param {any} sql
 * @param {unknown} songId
 * @param {string} videoId
 * @returns {Promise<boolean>}
 */
export async function setSongVideo(sql, songId, videoId) {
  if (!/^[A-Za-z0-9_-]{11}$/.test(videoId ?? '')) fail(400, '영상 ID가 올바르지 않습니다');
  const rows = await sql.query(
    `UPDATE songs SET youtube_video_id = $2 WHERE id = $1 RETURNING id`,
    [songId, videoId],
  );
  // 곡 카드는 피드에도 실리므로 캐시를 지운다.
  if (rows.length > 0) await purgeFeed(PURGE_ON_STATUS_CHANGE);
  return rows.length > 0;
}
