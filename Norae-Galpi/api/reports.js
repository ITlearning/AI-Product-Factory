/**
 * POST /api/reports — 신고.
 *
 * v1 모더레이션의 세 층 중 **사람이 하는 층**이다. 정규식 PII가 못 잡는 것
 * (실명+소속 조합, 맥락상 저격, 유해물)은 전부 여기로만 잡힌다. LLM 의미 판정은 v2다.
 *
 * `songId` 로 오면 "영상이 곡과 달라요" 신고다 — 같은 화면에서 운영자가 영상을 고친다.
 */

import { requireSql } from '../src/db.js';
import { createReport } from '../src/moderation-actions.js';
import { keyFromRequest } from '../src/identity.js';
import { rejectMethod, parseBody, sendError } from '../src/http.js';

export const config = { runtime: 'nodejs' };

export default async function handler(req, res) {
  if (rejectMethod(req, res, 'POST')) return;
  try {
    const body = parseBody(req);
    const reporterHash = keyFromRequest(req, body);
    const out = await createReport(requireSql(), reporterHash, body);
    // 자동 숨김 여부는 알려주지 않는다 — 신고자가 임계치를 떠보는 데 쓸 수 있다.
    return res.status(201).json({ reported: out.reported });
  } catch (err) {
    return sendError(res, err, 'reports');
  }
}
