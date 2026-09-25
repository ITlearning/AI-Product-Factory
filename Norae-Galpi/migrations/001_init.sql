-- 노래갈피 v1 스키마. 테이블 4개 + 인덱스 5개.
--
-- 멱등하다(IF NOT EXISTS). Neon HTTP 드라이버는 multi-statement 쿼리도 트랜잭션도
-- 지원하지 않아 migrations/run.js가 ;로 쪼개 하나씩 보낸다. 중간에 끊겨도 재실행이 안전해야 한다.

CREATE TABLE IF NOT EXISTS songs (
  id                BIGSERIAL PRIMARY KEY,
  source            TEXT   NOT NULL CHECK (source IN ('itunes','youtube')),
  itunes_artist_id  BIGINT,
  itunes_track_id   BIGINT,
  title_key         TEXT   NOT NULL,
  title_key_rev     INT    NOT NULL DEFAULT 1,
  title             TEXT   NOT NULL,
  artist            TEXT   NOT NULL,
  artwork_url       TEXT,
  youtube_video_id  TEXT   NOT NULL,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (source <> 'itunes' OR itunes_artist_id IS NOT NULL)
);

-- 곡의 유일성은 출처마다 다른 열쇠로 지킨다.
-- itunes: 같은 아티스트의 Live·Acoustic·Remix는 title_key가 같아 한 카드로 합쳐지고,
--         남이 부른 커버는 artistId가 달라 자동으로 갈린다. 둘 다 의도한 동작이다.
CREATE UNIQUE INDEX IF NOT EXISTS uq_songs_itunes
  ON songs (itunes_artist_id, title_key) WHERE source = 'itunes';
CREATE UNIQUE INDEX IF NOT EXISTS uq_songs_youtube
  ON songs (youtube_video_id)            WHERE source = 'youtube';

CREATE TABLE IF NOT EXISTS memories (
  id           BIGSERIAL PRIMARY KEY,
  song_id      BIGINT  NOT NULL REFERENCES songs(id) ON DELETE RESTRICT,
  author_hash  TEXT    NOT NULL,
  body         TEXT    NOT NULL CHECK (char_length(body) BETWEEN 1 AND 5000),
  season       TEXT    CHECK (season IN ('spring','summer','autumn','winter')),
  era          TEXT    CHECK (era   IN ('child','school','university','military','career','now')),
  is_public    BOOLEAN NOT NULL DEFAULT TRUE,
  status       TEXT    NOT NULL DEFAULT 'visible'
                       CHECK (status IN ('visible','hidden','removed')),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS memory_likes (
  memory_id   BIGINT NOT NULL REFERENCES memories(id) ON DELETE CASCADE,
  liker_hash  TEXT   NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (memory_id, liker_hash)
);

CREATE TABLE IF NOT EXISTS reports (
  id             BIGSERIAL PRIMARY KEY,
  memory_id      BIGINT REFERENCES memories(id) ON DELETE RESTRICT,
  song_id        BIGINT REFERENCES songs(id)    ON DELETE CASCADE,
  reason         TEXT NOT NULL,
  reporter_hash  TEXT NOT NULL,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  resolved_at    TIMESTAMPTZ,
  UNIQUE (memory_id, reporter_hash),
  CHECK (memory_id IS NOT NULL OR song_id IS NOT NULL)
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 피드 인덱스 — 설계가 "착수 시 첫 작업"으로 남긴 미해결 항목의 결론
--
-- 문제 제기: 피드 1번 쿼리는 곡 단위로 접는데(GROUP BY song_id) 설계 초안의 부분 인덱스는
--            (created_at DESC)·(season, created_at DESC)라 그룹 키가 선행 컬럼이 아니다.
--
-- 실측 결론 (PGlite/PG18, 곡 800 · 기억 20,000 · 좋아요 30,000, VACUUM ANALYZE 후):
--
--   **1번 쿼리는 어떤 인덱스로도 빨라지지 않는다.** 정렬 3종 전부 "모든 곡의 MAX(created_at)"을
--   구하므로 가시 행 전체를 읽어야 한다. 본질이 O(n)이고, 인덱스는 힙 접근만 없앨 뿐이다.
--   실측에서 플래너는 Seq Scan + HashAggregate를 골랐고(8~11ms), 인덱스를 강제해도
--   6~12ms로 차이가 30% 안쪽이었다. 이 규모에서는 둘 중 무엇이든 무해하다.
--
--   그래서 인덱스는 **1번을 위해 만들지 않는다.** 대신 실제로 인덱스가 일하는 두 곳만 덮는다.
--
--   ① 2번 쿼리  WHERE song_id = ANY($1)        → idx_mem_feed (Bitmap Index Scan 확인)
--   ② 계절 탭   WHERE season = $1              → idx_mem_feed_season
--
--   그리고 1번 쿼리를 인덱스로 강제했을 때 플래너가 고른 것도 idx_mem_feed_season이었다 —
--   가장 작아서 훑기 싸기 때문이다. 즉 두 인덱스면 충분하고 세 번째는 필요 없다.
--
-- 버린 것 1: idx_mem_feed 에 INCLUDE (season, id).
--   index-only scan을 노렸는데 인덱스가 2배가 되고(544kB → 1080kB) 플래너는 그래도
--   더 작은 idx_mem_feed_season 을 골랐다. 2번 쿼리는 body를 읽어 어차피 index-only가 안 된다.
--   값을 치르고 아무것도 못 샀다.
--
-- 버린 것 2: 설계 초안의 idx_mem_feed_recent (created_at DESC).
--   피드가 곡 단위로 접히면서 평평한 최신순으로 읽는 쿼리가 사라졌다.
--
-- 남는 비용: `오래 남은`의 ORDER BY likes DESC는 여전히 인덱스로 못 푼다(집계 결과 정렬).
--   이 정렬만 TTL 5분 + SWR로 감싸는 이유가 그대로 유효하다.
--
-- 비공개·숨김 글이 피드·정렬·곡 상세에서 배제되는 건 이 WHERE 절이 보장한다.
CREATE INDEX IF NOT EXISTS idx_mem_feed
  ON memories (song_id, created_at DESC)
  WHERE is_public AND status = 'visible';

-- 계절 탭을 직접 눌렀을 때(빈 상태 화면으로 가는 경로). 여기서만 season이 필터다 —
-- 기본 정렬 `지금 계절`은 필터가 아니라 우선순위라 집계로 푼다.
-- song_id를 second 컬럼에 둔 건 이 경로도 곡 단위로 접기 때문이다.
CREATE INDEX IF NOT EXISTS idx_mem_feed_season
  ON memories (season, song_id, created_at DESC)
  WHERE is_public AND status = 'visible';

-- ⑦ 내 갈피는 본인 글이므로 공개·비공개를 모두 보고, status 술어도 일부러 걸지 않는다.
-- removed 된 자기 글도 "숨겨진 글"로 표시한다 — 조용히 사라지면 사용자가 더 혼란스럽다.
CREATE INDEX IF NOT EXISTS idx_mem_author ON memories (author_hash, created_at DESC);

-- 미처리 신고
CREATE INDEX IF NOT EXISTS idx_reports_open ON reports (created_at DESC)
  WHERE resolved_at IS NULL;
