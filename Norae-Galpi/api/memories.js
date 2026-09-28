/**
 * POST /api/memories — 기억 한 편을 올린다.
 *
 * **Pages 스타일 `(req, res)` 시그니처를 쓴다.** App Router의 named export는 Vercel에서
 * hang이 난다(`vercel-legacy-handler-hangs`, Seoul-Youth-Rent-Checker 코드 주석).
 *
 * ## 로그에 무엇을 남기지 않는가
 * **요청 본문을 통째로 로깅하지 않는다.** 본문에는 기기 비밀키 원본이 들어 있고,
 * 그게 IP와 같은 자리에 남으면 이 제품이 피하려던 Whisper 유출 조합이 재현된다.
 * 실패해도 남기는 건 상태 코드와 에러 코드뿐이다.
 *
 * 요청 예:
 * ```json
 * { "deviceKey": "…",
 *   "song": { "source": "itunes", "itunesArtistId": 409076743, "itunesTrackId": 1219218446,
 *             "titleKey": "throughthenight", "title": "밤편지", "artist": "아이유",
 *             "artworkUrl": "https://…", "youtubeVideoId": "BzYnNdJhZQw" },
 *   "body": "…", "season": "winter", "era": "school", "isPublic": true }
 * ```
 */

import { requireKey } from '../src/identity.js';
import { requireSql } from '../src/db.js';
import { createMemory } from '../src/memories.js';

export const config = { runtime: 'nodejs' };

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST');
    return res.status(405).json({ error: 'POST만 받습니다' });
  }

  try {
    // req.body 는 Vercel이 파싱해준다. 로컬/테스트에서 문자열로 올 수도 있어 둘 다 받는다.
    const payload = typeof req.body === 'string' ? JSON.parse(req.body) : (req.body ?? {});

    // 해시는 **서버에서** 계산한다. 이 줄 밖으로 원본 키가 나가지 않는다.
    const authorHash = requireKey(payload);

    const result = await createMemory(requireSql(), authorHash, payload);

    return res.status(201).json({
      memoryId: String(result.memoryId),
      songId: String(result.songId),
      // 동시 등록에서 진 경우 — 고른 영상이 말없이 버려졌다는 사실을 화면에 알린다.
      videoWasAlreadySet: result.videoWasAlreadySet,
      videoId: result.existingVideoId,
    });
  } catch (err) {
    const status = Number.isInteger(err?.status) ? err.status : 500;
    // 상태와 코드만 남긴다. 본문·키는 절대 남기지 않는다.
    console.log(`noraegalpi.memories status=${status} code=${err?.code ?? '-'}`);
    if (status === 500) console.log(`noraegalpi.memories.error ${String(err?.message ?? err)}`);

    const payload = { error: status === 500 ? '잠시 뒤에 다시 시도해주세요' : err.message };
    if (err?.code) payload.code = err.code;
    if (err?.spans) payload.spans = err.spans;
    if (err?.retryAfterSeconds) {
      payload.retryAfterSeconds = err.retryAfterSeconds;
      res.setHeader('Retry-After', String(err.retryAfterSeconds));
    }
    return res.status(status).json(payload);
  }
}
