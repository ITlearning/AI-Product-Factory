/**
 * 대화 로깅 — CodeStudy 분석 파이프라인 Stage 2.
 *
 * ## 현재 단계 (Stage 2, Cycle 2 시점부터)
 * Neon Postgres `codestudy_log` 테이블에 INSERT.
 * - DATABASE_URL 환경 변수가 있을 때만 시도 (Vercel Production/Preview)
 * - INSERT 실패(network/schema/timeout)는 catch → console.log 폴백 (Stage 1 동작 보존)
 * - 로컬 개발 등 DATABASE_URL 미설정 환경은 console.log만 (Stage 1 그대로)
 *
 * ## 마이그레이션
 * `migrations/001_create_codestudy_log.sql` 참고. Tabber가 한 번 수동 실행:
 *   DATABASE_URL=... node migrations/run.js
 *
 * ## 저장 필드 (entry shape — interface 호환 유지)
 *   ts            ISO8601 timestamp (자동, NOW() default)
 *   userId        익명 디바이스 ID (iOS AnonymousID)
 *   sessionId     StudySession.id — 한 세션의 turn들을 묶음
 *   conceptId     curriculum concept
 *   event         'turn' | 'error'
 *   userInput     유저 원문 (error 이벤트엔 생략 가능)
 *   aiOutput      AI 응답 원문 (error 이벤트엔 생략)
 *   model         사용한 모델 identifier
 *   provider      openrouter | claude | gemini
 *   latencyMs     stream 시작 ~ 종료 (ms)
 *   tokensIn      input token count (제공되는 provider만)
 *   tokensOut     output token count (제공되는 provider만)
 *   level         beginner | basic | intermediate | advanced
 *   language      ko | en
 *   turnIndex     세션 내 몇 번째 turn인가 (0부터)
 *   errorCode     error 이벤트에만
 *   errorMessage  error 이벤트에만
 *
 * ## 컬럼 매핑 (Neon)
 *   user_id, session_id, concept_id, event, model — 1차 컬럼
 *   prompt_tokens (=tokensIn), completion_tokens (=tokensOut)
 *   error (=errorCode||errorMessage), cost_usd (현재 N/A → null)
 *   raw — entry 전체를 JSONB로 보존 (schema-drift 안전망)
 *
 * ## 프라이버시
 * - 이메일/전화번호 등 PII는 유저 입력에서 들어올 수 있으므로 경고 suppress.
 *   유저 자신이 입력한 자유 텍스트를 저장. PRIVACY.md에 명시.
 * - 30일 초과 행 자동 삭제는 Neon 측 cron 또는 Vercel Cron으로 별도 적용.
 */

import { neon } from '@neondatabase/serverless';

const LOG_TAG = 'codestudy.log';

// 모듈 스코프에서 한 번만 생성. neon() 호출은 단순 클라이언트 wrapper라
// 매 호출마다 만드는 것보다 재사용이 약간 효율적.
let _sqlClient = null;

/**
 * Neon HTTP SQL client 반환. DATABASE_URL이 없으면 null.
 * 테스트에서 쉽게 override 할 수 있도록 별도 export.
 *
 * @returns {Function|null} neon() template tag function 또는 null
 */
export function getSqlClient() {
  if (_sqlClient) return _sqlClient;
  const url = process.env.DATABASE_URL;
  if (!url) return null;
  _sqlClient = neon(url);
  return _sqlClient;
}

/**
 * 테스트 헬퍼 — 모듈 스코프 client cache 초기화 + 임의 client 주입.
 *
 * @param {Function|null} client - neon-like template tag function 또는 null
 */
export function _setSqlClient(client) {
  _sqlClient = client;
}

/**
 * console.log fallback — Stage 1 동작 보존.
 * INSERT 실패 또는 DATABASE_URL 부재 시 호출.
 *
 * @param {object} safe - ts가 추가된 entry
 */
function consoleFallback(safe) {
  console.log(`${LOG_TAG} ${JSON.stringify(safe)}`);
}

/**
 * 대화 한 턴을 로깅한다.
 *
 * @param {object} entry - 로그 엔트리. 위 "저장 필드" 참조.
 * @returns {Promise<void>} 비동기. 호출 측은 fire-and-forget 또는 await 자유.
 */
export async function logConversation(entry) {
  const safe = {
    ts: new Date().toISOString(),
    ...entry,
  };

  const sql = getSqlClient();
  if (!sql) {
    // DATABASE_URL 미설정 — Stage 1처럼 console.log만
    consoleFallback(safe);
    return;
  }

  // Neon INSERT 시도
  try {
    const userId = String(entry.userId || 'unknown');
    const sessionId = String(entry.sessionId || 'unknown');
    const conceptId = entry.conceptId || null;
    const event = String(entry.event || 'turn');
    const promptTokens = entry.tokensIn ?? null;
    const completionTokens = entry.tokensOut ?? null;
    const costUsd = entry.costUsd ?? null;
    const model = entry.model || null;
    const errorText = entry.errorMessage || entry.errorCode || null;
    // Cycle 3 — 트랙별 분석을 위한 first-class 컬럼.
    // 1.0.x 클라이언트는 track 미전송 → 'swift' fallback (tutor.js와 동일).
    const track = String(entry.track || 'swift');

    await sql`
      INSERT INTO codestudy_log
        (user_id, session_id, concept_id, event, prompt_tokens,
         completion_tokens, cost_usd, model, error, track, raw)
      VALUES
        (${userId}, ${sessionId}, ${conceptId}, ${event}, ${promptTokens},
         ${completionTokens}, ${costUsd}, ${model}, ${errorText}, ${track}, ${JSON.stringify(safe)})
    `;
  } catch (err) {
    // 어떠한 실패도 호출자에게 전파하지 않고 console로 fallback.
    // Stage 1 동작이 보존되므로 Vercel logs에서 여전히 조회 가능.
    consoleFallback(safe);
    // 디버깅용 — 어떤 에러였는지 별도 라인으로 남김.
    console.log(
      `${LOG_TAG}.error ${JSON.stringify({ message: String(err?.message || err) })}`,
    );
  }
}
