/**
 * GET /api/song-search?q=… — ① 곡 검색.
 *
 * search(us, limit 6) → lookup(kr, 배치 1회) → 한글 기준 재정렬 → MR 하향 → 후보 3개.
 *
 * **자동 선택이 없다.** 응답은 후보 배열일 뿐이고 "이게 답"이라는 표시를 담지 않는다.
 * iTunes에 없는 곡을 검색해도 빈손으로 돌아오지 않고 **그럴듯한 오답**이 오기 때문이다
 * (「그래 우리 함께」 → 방탄소년단 봄날). 그래서 `alwaysOfferManual: true` 를 같이 보내
 * 화면이 "찾는 곡이 없어요"를 **결과가 있을 때도 항상** 띄우게 한다.
 */

import { findCandidates } from '../src/itunes.js';
import { rejectMethod, queryParam, sendError } from '../src/http.js';

export const config = { runtime: 'nodejs' };

export default async function handler(req, res) {
  if (rejectMethod(req, res, 'GET')) return;
  try {
    const q = queryParam(req, 'q');
    if (!q || q.trim().length === 0) {
      return res.status(400).json({ error: '무슨 노래를 찾으시나요?' });
    }

    const candidates = await findCandidates(q.trim());

    // 곡 이름은 민감 정보가 아니라 캐시해도 된다. 같은 질의가 반복되면 iTunes 왕복을 아낀다.
    res.setHeader('Cache-Control', 'public, max-age=300, s-maxage=300');
    return res.status(200).json({ candidates, alwaysOfferManual: true });
  } catch (err) {
    return sendError(res, err, 'song-search');
  }
}
