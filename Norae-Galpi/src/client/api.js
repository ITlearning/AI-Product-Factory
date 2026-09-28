/**
 * 서버 호출 — 엔드포인트 9개의 클라이언트 쪽.
 *
 * ## 기기 키를 URL에 싣지 않는다
 * GET은 `X-Device-Key` 헤더, POST는 본문. 쿼리스트링에 실으면 프록시 로그·리퍼러·
 * 브라우저 히스토리에 그대로 남아, 서버에 해시만 저장하는 설계가 통째로 무의미해진다.
 */

import { readKey } from './device.js';

/**
 * @param {string} path
 * @param {{method?: string, body?: object, withKey?: boolean|'required'}} [opts]
 * @returns {Promise<any>}
 */
async function call(path, opts = {}) {
  const { method = 'GET', body, withKey = false } = opts;
  const headers = {};
  let payload;

  if (body !== undefined) {
    headers['Content-Type'] = 'application/json';
    payload = { ...body };
  }

  if (withKey) {
    const key = readKey();
    if (!key && withKey === 'required') {
      const err = new Error('이 기기에 저장된 글이 없어요');
      err.code = 'no_key';
      throw err;
    }
    if (key) {
      if (method === 'GET') {
        // **퍼센트 인코딩해서 보낸다.** 복구 코드가 `갈피-…`로 시작하는데 HTTP 헤더 값은
        // ISO-8859-1 만 담을 수 있어, 한글을 그대로 넣으면 fetch 가 통째로 던진다
        // (`String contains non ISO-8859-1 code point`). 서버가 받자마자 디코드하므로
        // 해시 대상 문자열은 POST 경로와 같다.
        headers['X-Device-Key'] = encodeURIComponent(key);
      } else {
        payload = { ...(payload ?? {}), deviceKey: key };
      }
    }
  }

  const res = await fetch(path, {
    method,
    headers,
    body: payload ? JSON.stringify(payload) : undefined,
  });

  let data = null;
  try {
    data = await res.json();
  } catch {
    /* 본문이 없는 응답도 있다 */
  }

  if (!res.ok) {
    const err = new Error(data?.error ?? '잠시 뒤에 다시 시도해주세요');
    err.status = res.status;
    err.code = data?.code;
    err.spans = data?.spans;
    err.retryAfterSeconds = data?.retryAfterSeconds;
    throw err;
  }
  return data;
}

/** ① 곡 검색 */
export const searchSongs = (q) => call(`/api/song-search?q=${encodeURIComponent(q)}`);

/** ② 영상 후보 */
export const searchVideos = (q) => call(`/api/video-search?q=${encodeURIComponent(q)}`);

/** ② 직접 링크 확인 — 쿼터를 쓰지 않는다 */
export const checkVideoUrl = (url) => call(`/api/video-search?url=${encodeURIComponent(url)}`);

/** ③④ 기억 올리기 */
export const postMemory = (body) => call('/api/memories', { method: 'POST', body, withKey: true });

/** ⑤ 피드 */
export function getFeed({ sort = 'season', season, page = 1 } = {}) {
  const q = new URLSearchParams({ sort, page: String(page) });
  if (season) q.set('season', season);
  return call(`/api/feed?${q}`);
}

/** ⑥ 곡 상세 */
export const getSong = (id) => call(`/api/song?id=${encodeURIComponent(id)}`, { withKey: true });

/** ⑦ 내 갈피 */
export const getMine = () => call('/api/mine', { withKey: 'required' });

/** 좋아요 토글 — 응답에 개수가 없다 */
export const setLike = (memoryId, liked) =>
  call('/api/likes', { method: 'POST', body: { memoryId, liked }, withKey: true });

/** 신고 */
export const report = (body) => call('/api/reports', { method: 'POST', body, withKey: true });
