/**
 * Neon HTTP 클라이언트. 모듈 스코프에서 한 번만 만들고 재사용한다.
 * (CodeStudy/Backend/src/logger.js 의 캐시 + 테스트 주입 훅 패턴)
 *
 * ## 이 드라이버로 못 하는 것 — 설계 전체가 여기에 묶여 있다
 * - **multi-statement 쿼리 불가.** 마이그레이션은 ;로 쪼개 개별 호출한다
 * - **트랜잭션 불가.** 그래서
 *   · 곡 upsert와 글 작성을 한 엔드포인트로 합쳤다(나누면 기억 0편인 유령 곡이 남는다)
 *   · `like_count` 비정규화 컬럼을 두지 않는다(INSERT + UPDATE의 원자성을 못 지켜 드리프트가 확정적이다)
 *   · 시드 로더가 멱등해야 한다(중간에 끊겨도 롤백이 없다)
 *
 * ## scale-to-zero
 * Neon 무료 티어는 **5분 비활성 시 자동 정지**하고 끌 수 없다. 크론으로 깨워두는 것도 불가능하다 —
 * 월 730시간 × 0.25 CU = 182 CU-hours로 한도(100)를 넘는다. 그래서 홈 첫 화면만 캐시로 막는다.
 */

import { neon } from '@neondatabase/serverless';

let _sql = null;

/**
 * Neon SQL 클라이언트. `DATABASE_URL`이 없으면 null.
 *
 * null을 던지지 않고 돌려주는 이유 — 로컬 개발이나 키가 안 꽂힌 프리뷰에서
 * 앱이 통째로 죽는 대신 호출 측이 폴백을 고를 수 있게 한다.
 *
 * @returns {ReturnType<typeof neon>|null}
 */
export function getSql() {
  if (_sql) return _sql;
  const url = process.env.DATABASE_URL;
  if (!url) return null;
  _sql = neon(url);
  return _sql;
}

/**
 * DB가 반드시 있어야 하는 경로용.
 *
 * @returns {ReturnType<typeof neon>}
 * @throws {Error} DATABASE_URL이 없을 때
 */
export function requireSql() {
  const sql = getSql();
  if (!sql) throw new Error('DATABASE_URL이 설정되지 않았다');
  return sql;
}

/**
 * 테스트 헬퍼 — 모듈 스코프 캐시를 비우고 임의 클라이언트를 꽂는다.
 *
 * @param {unknown} client - neon 과 같은 모양의 template tag 함수, 또는 null
 */
export function _setSql(client) {
  _sql = client;
}
