-- CodeStudy 대화 로그 테이블 (Stage 2)
--
-- src/logger.js의 logConversation() entry shape에 맞춘 컬럼.
-- Stage 1 (console.log JSON line)에서 Stage 2 (Neon Postgres INSERT)로 이전.
--
-- entry shape:
--   ts (auto), userId, sessionId, conceptId, event ('turn'|'error'),
--   userInput, aiOutput, mastered, model, provider,
--   latencyMs, level, language, turnIndex,
--   errorCode, errorMessage (error event)
--
-- 변경 가능한 자유 텍스트는 raw JSONB로 보존하여 schema-drift에 견고.

CREATE TABLE IF NOT EXISTS codestudy_log (
  id BIGSERIAL PRIMARY KEY,
  ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  user_id TEXT NOT NULL,
  session_id TEXT NOT NULL,
  concept_id TEXT,
  event TEXT NOT NULL,
  prompt_tokens INT,
  completion_tokens INT,
  cost_usd NUMERIC(10, 6),
  model TEXT,
  error TEXT,
  raw JSONB
);

CREATE INDEX IF NOT EXISTS idx_codestudy_log_user_session
  ON codestudy_log (user_id, session_id);

CREATE INDEX IF NOT EXISTS idx_codestudy_log_ts
  ON codestudy_log (ts DESC);

CREATE INDEX IF NOT EXISTS idx_codestudy_log_event
  ON codestudy_log (event);
