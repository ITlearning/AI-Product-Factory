/**
 * POST /api/likes — 좋아요 토글.
 *
 * 응답에 **개수를 싣지 않는다.** 누군가의 진심이 `♡ 0`으로 박히면 안 되고,
 * 개수를 내보내는 순간 클라이언트가 그걸 그릴 수 있게 된다. 눌림 여부만 돌려준다.
 *
 * 캐시를 퍼지하지 않는다 — 순위가 5분 늦어도 무해하고, 여기서 `오래 남은`을 지우면
 * SWR이 쥐고 있던 즉답 재고가 사라진다.
 */

import { requireSql } from '../src/db.js';
import { setLike } from '../src/read.js';
import { keyFromRequest } from '../src/identity.js';
import { rejectMethod, parseBody, sendError } from '../src/http.js';

export const config = { runtime: 'nodejs' };

export default async function handler(req, res) {
  if (rejectMethod(req, res, 'POST')) return;
  try {
    const body = parseBody(req);
    const likerHash = keyFromRequest(req, body);

    const memoryId = body?.memoryId;
    if (memoryId == null || !/^\d+$/.test(String(memoryId))) {
      return res.status(400).json({ error: '어떤 기억인지 알 수 없습니다' });
    }

    const out = await setLike(requireSql(), String(memoryId), likerHash, body?.liked !== false);
    return res.status(200).json(out);
  } catch (err) {
    return sendError(res, err, 'likes');
  }
}
