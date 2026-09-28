/**
 * GET /api/video-search?q=… — ② 영상 확정.
 *
 * **키가 없거나 쿼터가 끝나면 우아하게 떨어진다.** `available: false` + 이유를 주고,
 * 화면은 후보 목록 자리에 직접 링크 입력만 남긴다. 이건 접근법 A로 일시 전락하는 것이 맞다.
 *
 * `videoId` 파라미터를 주면 검색 대신 그 영상 하나를 확인한다 — 직접 링크를 붙여넣었을 때
 * 제목을 보여주기 위해서다. 사용자가 엉뚱한 영상을 붙였는지 **본인이** 알아볼 유일한 방법이다.
 */

import { findVideos, parseVideoId, probeVideo } from '../src/youtube.js';
import { rejectMethod, queryParam, sendError } from '../src/http.js';

export const config = { runtime: 'nodejs' };

export default async function handler(req, res) {
  if (rejectMethod(req, res, 'GET')) return;
  try {
    // 직접 링크 확인 경로 — 쿼터를 쓰지 않는다.
    const raw = queryParam(req, 'videoId') ?? queryParam(req, 'url');
    if (raw) {
      const videoId = parseVideoId(raw);
      if (!videoId) {
        return res.status(400).json({
          error: '유튜브 주소가 아닌 것 같아요',
          code: 'bad_video_url',
        });
      }
      const probe = await probeVideo(videoId);
      return res.status(200).json({ videoId, ...probe });
    }

    const q = queryParam(req, 'q');
    if (!q || q.trim().length === 0) {
      return res.status(400).json({ error: '어떤 곡의 영상을 찾을까요?' });
    }

    const result = await findVideos(q.trim());
    return res.status(200).json({
      available: result.available,
      reason: result.reason ?? null,
      videos: result.videos,
      // 폴백은 키가 있든 없든 항상 열려 있다. 90일 미사용 차단 같은 일이 언제든 생긴다.
      manualEntry: true,
    });
  } catch (err) {
    return sendError(res, err, 'video-search');
  }
}
