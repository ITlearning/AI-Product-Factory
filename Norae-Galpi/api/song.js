/**
 * GET /api/song?id=… — ⑥ 곡 상세. 그 곡의 기억 전부.
 *
 * **이 제품에서 소리가 나는 유일한 화면**의 데이터다.
 *
 * 진입할 때 oEmbed로 영상 생존 확인을 **하지 않는다**(엔지니어링 결정 8).
 * 가장 자주 열리는 화면에 외부 왕복이 매번 붙는 값이 크고, 죽은 영상은 iframe이 알아서
 * 에러를 보여주며 "영상이 곡과 달라요" 신고 경로가 이미 있다.
 */

import { requireSql } from '../src/db.js';
import { getSongDetail } from '../src/read.js';
import { optionalKeyFromRequest } from '../src/identity.js';
import { rejectMethod, queryParam, sendError } from '../src/http.js';

export const config = { runtime: 'nodejs' };

export default async function handler(req, res) {
  if (rejectMethod(req, res, 'GET')) return;
  try {
    const id = queryParam(req, 'id');
    if (!id || !/^\d+$/.test(id)) return res.status(400).json({ error: '곡을 찾을 수 없습니다' });

    const likerHash = optionalKeyFromRequest(req);
    const detail = await getSongDetail(requireSql(), id, likerHash);
    if (!detail) return res.status(404).json({ error: '곡을 찾을 수 없습니다' });

    // v1은 검색엔진에 열지 않는다. 화면의 <meta> 와 함께 헤더로도 못 박는다.
    res.setHeader('X-Robots-Tag', 'noindex');
    res.setHeader('Cache-Control', 'no-store');
    return res.status(200).json(detail);
  } catch (err) {
    return sendError(res, err, 'song');
  }
}
