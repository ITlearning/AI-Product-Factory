/**
 * 기기 비밀키 → 해시. 로그인이 없는 이 제품의 신원 전부.
 *
 * **해시는 반드시 서버에서 계산한다**(엔지니어링 결정 1). 클라이언트가 해싱하면
 * DB에 저장된 해시가 곧 bearer token이 되어, DB 유출 한 번에 전체 사용자의
 * 삭제권이 털린다. 그러면 "유출돼도 나올 게 없다"는 전제가 거짓이 된다.
 *
 * **원본 키를 로그에 남기지 않는다.** 요청 본문 로깅도 마찬가지다.
 * 원본 키가 IP와 같은 자리에 남으면 Whisper 유출이 재식별로 이어진 조합이 재현된다.
 *
 */

import { createHash, randomBytes } from 'node:crypto';

/** 무한 길이 입력으로 해시 계산을 밀어붙이지 못하게 하는 상한. */
const MAX_KEY_LENGTH = 512;

/**
 * 기기 비밀키를 SHA-256 16진 문자열로.
 *
 * @param {string} rawKey - 클라이언트가 HTTPS로 보낸 원본 키
 * @returns {string} 소문자 16진 64자
 * @throws {TypeError} 문자열이 아니거나, 비었거나, 너무 길 때
 */
export function hashKey(rawKey) {
  if (typeof rawKey !== 'string') {
    throw new TypeError('rawKey must be a string');
  }
  const key = rawKey.trim();
  if (key.length === 0) {
    throw new TypeError('rawKey must not be empty');
  }
  if (key.length > MAX_KEY_LENGTH) {
    throw new TypeError(`rawKey must be at most ${MAX_KEY_LENGTH} characters`);
  }
  return createHash('sha256').update(key, 'utf8').digest('hex');
}

/**
 * 요청 본문에서 기기 비밀키를 꺼내 해시로 바꾼다.
 *
 * **원본 키를 반환하지 않는다.** 호출 측이 실수로 로그에 남기지 못하게, 이 함수 밖으로는
 * 해시만 나간다. 요청 본문 전체를 로깅하는 미들웨어도 두지 않는다 —
 * 원본 키가 IP와 같은 자리에 남으면 Whisper 유출이 재식별로 이어진 조합이 재현된다.
 *
 * @param {{deviceKey?: unknown}} body - 파싱된 요청 본문
 * @returns {string} SHA-256 16진 64자
 * @throws {Error} 키가 없거나 모양이 아닐 때. `.status = 400` 이 붙는다
 */
export function requireKey(body) {
  const raw = body?.deviceKey;
  try {
    return hashKey(typeof raw === 'string' ? raw : '');
  } catch {
    // 어떤 값이 왔는지 메시지에 싣지 않는다 — 그 값이 곧 키다.
    const err = new Error('기기 키가 없거나 올바르지 않습니다');
    err.status = 400;
    throw err;
  }
}

/**
 * 새 기기 비밀키를 만든다. 클라이언트가 첫 방문에 한 번 부르고 localStorage에 넣는다.
 *
 * 서버는 이걸 저장하지 않는다 — 해시만 갖는다. 그래서 이 값의 유일한 사본이 사용자 기기에 있고,
 * 브라우저 데이터를 지우면 ⑦ 내 갈피와 수정·삭제권이 증발한다. 복구 코드가 그 대가다.
 *
 * @returns {string} base64url 32자
 */
export function newDeviceKey() {
  return randomBytes(24).toString('base64url');
}
