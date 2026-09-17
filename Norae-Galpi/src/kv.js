/**
 * Upstash Redis — 피드 캐시 3키와 레이트리밋 카운터에만 쓴다.
 *
 * Vercel Marketplace 연동은 `KV_*` prefix로 환경변수를 주입한다
 * (Seoul-Youth-Rent-Checker가 이미 쓰는 방식).
 *
 * ## 없어도 서비스는 돈다
 * 키가 안 꽂히면 `getKv()`가 null을 주고, 캐시는 매번 미스, 레이트리밋은 통과다.
 * 초기 개발과 프리뷰에서 Redis 하나 때문에 앱이 죽지 않게 하려는 것이고,
 * **운영에서 키가 빠지면 어뷰즈 방어가 사라진다는 뜻**이라 배포 전 확인이 필요하다.
 */

import { Redis } from '@upstash/redis';

let _kv = null;
let _resolved = false;

/**
 * @returns {Redis|null} 환경변수가 없으면 null
 */
export function getKv() {
  if (_resolved) return _kv;
  _resolved = true;
  const url = process.env.UPSTASH_REDIS_REST_URL ?? process.env.KV_REST_API_URL;
  const token = process.env.UPSTASH_REDIS_REST_TOKEN ?? process.env.KV_REST_API_TOKEN;
  _kv = url && token ? new Redis({ url, token }) : null;
  return _kv;
}

/**
 * 테스트 헬퍼 — 임의 클라이언트를 꽂는다. null을 주면 다시 환경변수에서 읽는다.
 *
 * @param {unknown} client
 */
export function _setKv(client) {
  _kv = client ?? null;
  _resolved = client != null;
}
