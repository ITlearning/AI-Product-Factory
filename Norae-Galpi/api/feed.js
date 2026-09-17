/**
 * GET /api/feed?sort=season|recent|lasting&season=…&page=1 — ⑤ 홈 피드.
 *
 * 쿼리 2번 + 캐시 1키. `오래 남은`만 TTL 5분 + SWR이다.
 *
 * 기기 키를 요구하지 않는다 — 피드는 누구나 읽는다. `X-Device-Key` 헤더가 있으면
 * 각 기억에 `liked`만 채워준다. **좋아요 개수는 어디에도 싣지 않는다.**
 */

import { requireSql } from '../src/db.js';
import { getFeed } from '../src/read.js';
import { rejectMethod, queryParam, sendError } from '../src/http.js';

export const config = { runtime: 'nodejs' };

export default async function handler(req, res) {
  if (rejectMethod(req, res, 'GET')) return;
  try {
    const page = Number.parseInt(queryParam(req, 'page') ?? '1', 10);
    const feed = await getFeed(requireSql(), {
      sort: queryParam(req, 'sort') ?? undefined,
      season: queryParam(req, 'season') ?? undefined,
      page: Number.isFinite(page) ? page : 1,
      // SWR — 옛 값을 즉시 주고 갱신은 응답 뒤에 돈다. await 하지 않는 게 핵심이다.
      revalidate: (fn) => {
        fn().catch((e) => console.log(`noraegalpi.feed.revalidate ${String(e?.message ?? e)}`));
      },
    });

    // 브라우저에는 캐시하지 않는다. 자기 글을 올린 직후 홈이 옛날 걸 보여주면 안 된다.
    res.setHeader('Cache-Control', 'no-store');
    return res.status(200).json(feed);
  } catch (err) {
    return sendError(res, err, 'feed');
  }
}
