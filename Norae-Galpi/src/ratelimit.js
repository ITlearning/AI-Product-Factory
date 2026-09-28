/**
 * 어뷰즈 방어 — 최소선.
 *
 * 로그인이 없으므로 `author_hash`는 브라우저에서 무한 재발급이 가능하다.
 * **완전한 방어는 불가능하고, 목표는 자동화된 대량 투입을 귀찮게 만드는 것까지다.**
 * 그 선을 넘어 CAPTCHA나 계정으로 가면 이 제품이 아닌 게 된다.
 *
 * 한계: 키를 새로 뽑으면 카운터도 새로 시작한다. 여기서 막는 건 "한 사람이 스크립트로
 * 수백 편을 쏟아붓는 것"이지 "여러 키로 나눠 넣는 것"이 아니다.
 */

import { getKv } from './kv.js';

/** 같은 author_hash 기준 작성 상한. */
export const WRITE_LIMITS = [
  { id: 'minute', windowSeconds: 60, max: 1 },
  { id: 'day', windowSeconds: 86400, max: 20 },
];

/**
 * 유튜브 `search.list` 일일 상한. 2026-06-01 쿼터 개정으로 전용 버킷이 되어
 * **하루 100 calls가 경성 상한**이고 다른 호출을 아껴도 늘릴 수 없다.
 */
export const YOUTUBE_SEARCH_DAILY_MAX = 100;

/**
 * 작성 레이트리밋을 확인하고 카운터를 올린다.
 *
 * 카운터가 없으면(Redis 미설정) **통과시킨다.** 서비스 가용성을 우선하되,
 * 운영에서 키가 빠지면 방어가 사라진다는 뜻이다.
 *
 * @param {string} authorHash
 * @returns {Promise<{ok: true} | {ok: false, limit: string, retryAfterSeconds: number}>}
 */
export async function checkWriteLimit(authorHash) {
  const kv = getKv();
  if (!kv) return { ok: true };

  for (const { id, windowSeconds, max } of WRITE_LIMITS) {
    const key = `rl:write:${id}:${authorHash}`;
    let count;
    try {
      count = await kv.incr(key);
      // 첫 증가일 때만 만료를 건다. 매번 걸면 창이 계속 밀려 상한이 무의미해진다.
      if (count === 1) await kv.expire(key, windowSeconds);
    } catch {
      return { ok: true }; // 카운터 장애로 글쓰기를 막지 않는다
    }
    if (count > max) {
      let ttl = windowSeconds;
      try {
        const t = await kv.ttl(key);
        if (typeof t === 'number' && t > 0) ttl = t;
      } catch {
        /* ttl 조회 실패는 무해하다 — 창 길이를 그대로 쓴다 */
      }
      return { ok: false, limit: id, retryAfterSeconds: ttl };
    }
  }
  return { ok: true };
}

/**
 * 유튜브 검색 쿼터를 한 칸 쓴다.
 *
 * **태평양 표준시 자정에 리셋한다** — 구글 쿼터의 기준시다. 서버 자정에 리셋하면
 * 실제 쿼터가 안 풀린 시간대에 호출을 날려 403을 맞는다.
 *
 * 소진되면 ② 화면은 후보 목록 자리에 "오늘은 자동 찾기를 다 썼어요"를 띄우고
 * 직접 링크 입력만 남긴다. `403 quotaExceeded` 응답도 같은 경로를 탄다.
 * 이건 **접근법 A로 일시 전락하는 것**이 맞다.
 *
 * @param {Date} [now]
 * @returns {Promise<{ok: boolean, used: number, max: number}>}
 */
export async function spendYoutubeSearch(now = new Date()) {
  const kv = getKv();
  if (!kv) return { ok: true, used: 0, max: YOUTUBE_SEARCH_DAILY_MAX };

  const key = `quota:yt:${pacificDateString(now)}`;
  try {
    const used = await kv.incr(key);
    if (used === 1) await kv.expire(key, 2 * 86400); // 날짜가 넘어가면 자연히 사라진다
    return { ok: used <= YOUTUBE_SEARCH_DAILY_MAX, used, max: YOUTUBE_SEARCH_DAILY_MAX };
  } catch {
    // 카운터가 죽어도 검색은 시도한다. 진짜 초과는 403 quotaExceeded 로 같은 폴백을 탄다.
    return { ok: true, used: 0, max: YOUTUBE_SEARCH_DAILY_MAX };
  }
}

/**
 * 태평양 표준시 기준 `YYYY-MM-DD`. 구글 쿼터가 이 시각에 리셋된다.
 *
 * @param {Date} now
 * @returns {string}
 */
export function pacificDateString(now) {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'America/Los_Angeles',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(now);
}
