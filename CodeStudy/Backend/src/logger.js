/**
 * 대화 로깅 — CodeStudy 분석 파이프라인 Stage 1.
 *
 * ## 현재 단계 (Stage 1)
 * Vercel 함수 로그(stdout)에 JSON line 출력.
 * - Vercel 대시보드 Functions → Logs에서 바로 조회
 * - `vercel logs <deployment-url>` CLI로 조회
 * - Hobby 플랜 30일 보관, Pro 플랜 30일
 * - 필터링: `tag:codestudy.log` 또는 JSON 필드로 grep
 *
 * ## 다음 단계 (Stage 2, DAU 100+ 달성 시)
 * Neon Postgres `conversation_logs` 테이블로 이전.
 * `logConversation`의 인터페이스는 그대로 유지하고 구현만 교체.
 *
 * ## 저장 필드
 *   ts         ISO8601 timestamp (자동)
 *   userId     익명 디바이스 ID (iOS AnonymousID)
 *   sessionId  StudySession.id — 한 세션의 turn들을 묶음
 *   conceptId  curriculum concept
 *   event      'turn' | 'error'
 *   userInput  유저 원문 (error 이벤트엔 생략 가능)
 *   aiOutput   AI 응답 원문 (error 이벤트엔 생략)
 *   model      사용한 모델 identifier
 *   provider   openrouter | claude | gemini
 *   latencyMs  stream 시작 ~ 종료 (ms)
 *   tokensIn   input token count (제공되는 provider만)
 *   tokensOut  output token count (제공되는 provider만)
 *   level      beginner | basic | intermediate | advanced
 *   language   ko | en
 *   turnIndex  세션 내 몇 번째 turn인가 (0부터)
 *   errorCode  error 이벤트에만
 *
 * ## 프라이버시
 * - 이메일/전화번호 등 PII는 유저 입력에서 들어올 수 있으므로 경고 suppress.
 *   유저 자신이 입력한 자유 텍스트를 저장. PRIVACY.md에 명시 필요.
 * - 30일 초과 시 자동 삭제 정책은 Stage 2 (Neon) 이전 시 적용.
 */

const LOG_TAG = 'codestudy.log';

/**
 * 대화 한 턴을 로깅한다.
 *
 * @param {object} entry - 로그 엔트리. 위 "저장 필드" 참조.
 */
export function logConversation(entry) {
  const safe = {
    ts: new Date().toISOString(),
    ...entry,
  };
  // 단일 JSON line — Vercel 로그 필터링에 유리
  console.log(`${LOG_TAG} ${JSON.stringify(safe)}`);
}
