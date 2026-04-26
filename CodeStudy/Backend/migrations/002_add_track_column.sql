-- Cycle 3 — 학습 트랙 컬럼 추가 (swift / backend)
--
-- 기존 행은 모두 swift 트랙으로 본다 (Cycle 3 이전 데이터).
-- iOS 1.0.x 클라이언트는 track 미전송 → tutor.js에서 'swift' fallback.
-- 분석 쿼리: SELECT track, COUNT(*) FROM codestudy_log GROUP BY track;
--
-- raw JSONB에도 track이 들어가지만 첫 번째 컬럼으로 승격해서 인덱스/그룹바이 비용 절감.

ALTER TABLE codestudy_log
  ADD COLUMN IF NOT EXISTS track TEXT;

-- 기존 행 backfill — Cycle 3 이전엔 swift 트랙만 존재
UPDATE codestudy_log SET track = 'swift' WHERE track IS NULL;

-- 트랙별 분포/리텐션 분석 인덱스
CREATE INDEX IF NOT EXISTS idx_codestudy_log_track
  ON codestudy_log (track);
