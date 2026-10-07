/**
 * 관리(/admin) 공통 문지기 — api/admin/*.js 가 모두 이것부터 부른다.
 *
 * - 환경변수 ADMIN_TOKEN 이 없으면 503(닫힘). 열려 있는 채로 배포되지 않게.
 * - Authorization: Bearer <ADMIN_TOKEN> 을 timingSafeEqual 로 비교, 틀리면 401.
 * - 틀린 횟수: mongdol:desk:authfail:<IP 해시> — 15분에 10번 넘으면 맞는 토큰도 429.
 */
import { authorized } from "./http.js";
import { ipHash } from "./feedback.js";

export const AUTH_FAIL_LIMIT = 10;
export const AUTH_FAIL_WINDOW = 900;
export const authFailKey = (hash) => `mongdol:desk:authfail:${hash}`;

/** 통과면 null, 아니면 {status, message}. */
export async function checkAdmin(redis, { header, ip, env }) {
  if (!env.ADMIN_TOKEN) return { status: 503, message: "ADMIN_TOKEN 이 설정되지 않았어요." };
  const key = authFailKey(ipHash(ip));
  if (Number((await redis.get(key)) ?? 0) >= AUTH_FAIL_LIMIT) return { status: 429, message: "여러 번 틀렸어요. 15분 뒤에 다시 해 주세요." };
  if (authorized(header, env.ADMIN_TOKEN)) return null;
  const n = await redis.incr(key);
  if (n === 1) await redis.expire(key, AUTH_FAIL_WINDOW);
  return { status: 401, message: "토큰이 맞지 않아요." };
}
