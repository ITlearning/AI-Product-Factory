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
 * v1 착수 시점에는 `hashKey`만 있다. 요청에서 키를 꺼내 검증하는 `requireKey`는
 * 엔드포인트가 생기는 Next Step 2에서 이 파일에 함께 들어간다.
 */

import { createHash } from 'node:crypto';

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
