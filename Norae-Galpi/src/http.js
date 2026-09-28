/**
 * 핸들러 공통 — 메서드 가드 · 본문 파싱 · 에러 응답.
 *
 * Vercel 함수는 전부 **Pages 스타일 `(req, res)`** 를 쓴다.
 * App Router named export는 hang이 난다(`vercel-legacy-handler-hangs`).
 *
 * ## 로그 규율
 * 어떤 경로에서도 **요청 본문·헤더를 통째로 남기지 않는다.** 거기에 기기 비밀키 원본과
 * 남이 쓴 기억이 들어 있고, 그게 IP와 같은 자리에 남으면 이 제품이 피하려던 조합이 재현된다.
 * 남기는 건 태그·상태 코드·에러 코드뿐이다.
 */

/**
 * 메서드가 맞지 않으면 405를 보내고 true를 돌려준다.
 *
 * @param {object} req
 * @param {object} res
 * @param {string|string[]} allowed
 * @returns {boolean} 처리를 끝냈으면 true
 */
export function rejectMethod(req, res, allowed) {
  const list = Array.isArray(allowed) ? allowed : [allowed];
  if (list.includes(req.method)) return false;
  res.setHeader('Allow', list.join(', '));
  res.status(405).json({ error: `${list.join('/')}만 받습니다` });
  return true;
}

/**
 * 요청 본문을 객체로. Vercel이 파싱해주지만 로컬·테스트에서 문자열로 올 수도 있다.
 *
 * @param {object} req
 * @returns {object}
 */
export function parseBody(req) {
  if (req?.body == null) return {};
  if (typeof req.body === 'string') {
    try {
      return JSON.parse(req.body);
    } catch {
      const err = new Error('요청 본문을 읽을 수 없습니다');
      err.status = 400;
      throw err;
    }
  }
  return req.body;
}

/**
 * 쿼리에서 문자열 하나. Vercel은 반복 파라미터를 배열로 준다.
 *
 * @param {object} req
 * @param {string} name
 * @returns {string|null}
 */
export function queryParam(req, name) {
  const v = req?.query?.[name];
  const s = Array.isArray(v) ? v[0] : v;
  return typeof s === 'string' && s.length > 0 ? s : null;
}

/**
 * 에러를 응답으로. 500은 내부 사정을 사용자에게 보여주지 않는다.
 *
 * @param {object} res
 * @param {any} err
 * @param {string} tag - 로그 태그 (예: 'feed')
 */
export function sendError(res, err, tag) {
  const status = Number.isInteger(err?.status) ? err.status : 500;

  console.log(`noraegalpi.${tag} status=${status} code=${err?.code ?? '-'}`);
  if (status === 500) {
    // 메시지만. 스택에 쿼리 파라미터가 섞여 나올 수 있어 메시지로 한정한다.
    console.log(`noraegalpi.${tag}.error ${String(err?.message ?? err)}`);
  }

  const payload = { error: status === 500 ? '잠시 뒤에 다시 시도해주세요' : err.message };
  if (err?.code) payload.code = err.code;
  if (err?.spans) payload.spans = err.spans;
  if (err?.retryAfterSeconds) {
    payload.retryAfterSeconds = err.retryAfterSeconds;
    res.setHeader('Retry-After', String(err.retryAfterSeconds));
  }
  return res.status(status).json(payload);
}
