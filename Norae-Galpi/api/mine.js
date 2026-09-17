/**
 * GET /api/mine — ⑦ 내 갈피. 기기 키가 필요하다.
 *
 * **키는 `X-Device-Key` 헤더로 받는다.** 쿼리스트링에 실으면 프록시 로그·리퍼러·브라우저
 * 히스토리에 그대로 남아, 서버에 해시만 저장하는 설계가 통째로 무의미해진다.
 *
 * 공개·비공개를 모두 보여주고 `removed` 된 글도 "숨겨진 글"로 표시한다 —
 * 조용히 사라지면 사용자가 더 혼란스럽다.
 */

import { requireSql } from '../src/db.js';
import { getMyMemories } from '../src/read.js';
import { keyFromRequest } from '../src/identity.js';
import { rejectMethod, sendError } from '../src/http.js';

export const config = { runtime: 'nodejs' };

export default async function handler(req, res) {
  if (rejectMethod(req, res, 'GET')) return;
  try {
    const authorHash = keyFromRequest(req);
    const memories = await getMyMemories(requireSql(), authorHash);
    res.setHeader('Cache-Control', 'no-store');
    return res.status(200).json({ memories });
  } catch (err) {
    return sendError(res, err, 'mine');
  }
}
