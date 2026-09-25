/**
 * POST /api/admin-hide — 운영자 숨김. 비밀 토큰으로 막는다.
 *
 * **왜 Data editor로 안 하는가** — Vercel Data editor는 DB를 직접 고쳐 앱 코드를 안 거치므로
 * 캐시 퍼지가 일어날 수 없다. 숨겼는데 피드에 남는다. Data editor는 **보고 판단하는 용도**로 쓰고
 * 실제 숨김은 이 엔드포인트로 한다. 직접 수정했을 때의 폴백은 60초 TTL뿐이다.
 *
 * 행을 지우지 않는다. `status` 를 바꾼다 — 오처리를 되돌릴 수 있어야 하고,
 * 신고 이력이 곧 판단 근거다.
 */

import { requireSql } from '../src/db.js';
import { setMemoryStatus, setSongVideo } from '../src/moderation-actions.js';
import { rejectMethod, parseBody, sendError } from '../src/http.js';

export const config = { runtime: 'nodejs' };

/**
 * 길이가 달라도 같은 시간이 걸리게 비교한다. 토큰을 한 글자씩 떠보지 못하게.
 *
 * @param {unknown} a
 * @param {string} b
 * @returns {boolean}
 */
function safeEqual(a, b) {
  const x = typeof a === 'string' ? a : '';
  let diff = x.length ^ b.length;
  for (let i = 0; i < Math.max(x.length, b.length); i++) {
    diff |= (x.charCodeAt(i) || 0) ^ (b.charCodeAt(i) || 0);
  }
  return diff === 0;
}

export default async function handler(req, res) {
  if (rejectMethod(req, res, 'POST')) return;
  try {
    const expected = process.env.ADMIN_TOKEN;
    // 토큰이 설정되지 않았으면 열어두지 않는다. 비어 있는 것과 맞는 것은 다르다.
    if (!expected) return res.status(503).json({ error: '운영자 기능이 설정되지 않았습니다' });

    const token = req.headers?.['x-admin-token'];
    if (!safeEqual(token, expected)) return res.status(401).json({ error: '권한이 없습니다' });

    const body = parseBody(req);

    if (body?.songId != null && typeof body?.videoId === 'string') {
      const changed = await setSongVideo(requireSql(), body.songId, body.videoId);
      return res.status(200).json({ changed });
    }

    if (body?.memoryId == null) return res.status(400).json({ error: 'memoryId가 필요합니다' });
    const changed = await setMemoryStatus(requireSql(), body.memoryId, body?.status ?? 'hidden');
    return res.status(200).json({ changed });
  } catch (err) {
    return sendError(res, err, 'admin-hide');
  }
}
