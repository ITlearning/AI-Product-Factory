/**
 * 시드 검증 — DB 없이 지금 돌아간다.
 *
 * 시드가 규범이 되는 제품이라(`docs/designs/norae-galpi-seed.md`),
 * 시드가 스키마 제약이나 제품 규칙에 걸리면 출시 당일 홈이 비거나 로더가 절반에서 죽는다.
 * 그래서 Neon 프로젝트가 생기기 **전에** 다음을 전부 확인한다.
 *
 * - `songs` / `memories` 의 CHECK · NOT NULL · UNIQUE 제약을 SQL 없이 재현
 * - 본문이 제품의 PII 정규식(`src/moderation.js`)을 실제로 통과하는지
 * - 아직 못 채운 칸(유튜브 영상 ID)이 조용히 넘어가지 않게 따로 세기
 *
 * 실행: `npm run seed:validate`
 */

import { SEASONS, ERAS } from '../src/labels.js';
import { detectPII, summarizePII } from '../src/moderation.js';

const SOURCES = ['itunes', 'youtube'];
const BODY_MAX = 5000;
/** 유튜브 영상 ID는 11자 [A-Za-z0-9_-]. */
const VIDEO_ID_RE = /^[A-Za-z0-9_-]{11}$/;

/**
 * Postgres `char_length`에 맞춘 길이. JS `.length`는 UTF-16 코드 단위라
 * 이모지가 섞이면 2로 세어 상한이 실제보다 빨리 걸린다.
 *
 * @param {string} s
 * @returns {number}
 */
function charLength(s) {
  return [...s].length;
}

/**
 * @param {unknown} v
 * @returns {boolean}
 */
function isNonEmptyString(v) {
  return typeof v === 'string' && v.trim().length > 0;
}

/**
 * 시드 객체를 검증한다.
 *
 * @param {object} seed - `seed.json` 을 파싱한 것
 * @returns {{errors: string[], warnings: string[], pending: string[]}}
 *   `errors`가 비어야 로더를 돌릴 수 있다. `pending`은 사람이 채워야 하는 칸이라
 *   에러는 아니지만 로더는 이것도 비어야 진행한다.
 */
export function validateSeed(seed) {
  /** @type {string[]} */ const errors = [];
  /** @type {string[]} */ const warnings = [];
  /** @type {string[]} */ const pending = [];

  const songs = Array.isArray(seed?.songs) ? seed.songs : null;
  const memories = Array.isArray(seed?.memories) ? seed.memories : null;
  if (!songs) errors.push('songs 배열이 없다');
  if (!memories) errors.push('memories 배열이 없다');
  if (!songs || !memories) return { errors, warnings, pending };

  // --- songs ---
  const refs = new Set();
  const itunesKeys = new Set();   // uq_songs_itunes (itunes_artist_id, title_key)
  const videoIds = new Set();     // uq_songs_youtube (youtube_video_id)

  for (const [i, s] of songs.entries()) {
    const at = `songs[${i}] ${s?.ref ?? '(ref 없음)'}`;

    if (!isNonEmptyString(s?.ref)) errors.push(`${at}: ref가 비었다`);
    else if (refs.has(s.ref)) errors.push(`${at}: ref 중복`);
    else refs.add(s.ref);

    if (!SOURCES.includes(s?.source)) {
      errors.push(`${at}: source는 ${SOURCES.join('|')} 중 하나여야 한다 (받은 값: ${s?.source})`);
    }
    if (!isNonEmptyString(s?.title_key)) errors.push(`${at}: title_key가 비었다`);
    if (!isNonEmptyString(s?.title)) errors.push(`${at}: title이 비었다 (NOT NULL)`);
    if (!isNonEmptyString(s?.artist)) errors.push(`${at}: artist가 비었다 (NOT NULL)`);
    if (!Number.isInteger(s?.title_key_rev)) errors.push(`${at}: title_key_rev는 정수여야 한다`);

    if (s?.source === 'itunes') {
      // CHECK (source <> 'itunes' OR itunes_artist_id IS NOT NULL)
      if (!Number.isInteger(s?.itunes_artist_id)) {
        errors.push(`${at}: source=itunes인데 itunes_artist_id가 없다`);
      } else {
        const key = `${s.itunes_artist_id}::${s.title_key}`;
        if (itunesKeys.has(key)) {
          errors.push(`${at}: uq_songs_itunes 위반 — (${s.itunes_artist_id}, ${s.title_key}) 중복`);
        } else {
          itunesKeys.add(key);
        }
      }
      if (!isNonEmptyString(s?.artwork_url)) {
        warnings.push(`${at}: artwork_url이 없다 — 카드에서 앨범아트가 빈칸이 된다`);
      }
    }

    // youtube_video_id는 두 출처 모두 NOT NULL이다. 재생이 거기서만 나오므로.
    if (s?.youtube_video_id == null) {
      pending.push(`${at}: youtube_video_id 미정 — 「${s?.title ?? '?'}」의 영상 링크가 필요하다`);
    } else if (!VIDEO_ID_RE.test(s.youtube_video_id)) {
      errors.push(`${at}: youtube_video_id 형식이 아니다 (받은 값: ${s.youtube_video_id})`);
    } else if (s.source === 'youtube') {
      if (videoIds.has(s.youtube_video_id)) {
        errors.push(`${at}: uq_songs_youtube 위반 — ${s.youtube_video_id} 중복`);
      } else {
        videoIds.add(s.youtube_video_id);
      }
    }

    if (s?.source === 'youtube' && !isNonEmptyString(s?.artwork_url)) {
      warnings.push(`${at}: artwork_url이 없다 — 영상 ID 확정 후 oEmbed 썸네일로 채운다`);
    }
  }

  // --- memories ---
  const seasonCount = Object.fromEntries(SEASONS.map((s) => [s, 0]));
  let labelledSeasons = 0;

  for (const [i, m] of memories.entries()) {
    const at = `memories[${i}] → ${m?.song_ref ?? '(song_ref 없음)'}`;

    // FK: song_id REFERENCES songs(id)
    if (!isNonEmptyString(m?.song_ref)) errors.push(`${at}: song_ref가 비었다`);
    else if (!refs.has(m.song_ref)) errors.push(`${at}: 그런 곡이 시드에 없다 (FK 위반)`);

    // CHECK (char_length(body) BETWEEN 1 AND 5000)
    if (!isNonEmptyString(m?.body)) {
      errors.push(`${at}: body가 비었다`);
    } else {
      const len = charLength(m.body);
      if (len > BODY_MAX) errors.push(`${at}: body가 ${len}자 — 상한 ${BODY_MAX}자를 넘는다`);

      // 제품이 실제로 쓰는 규칙으로 시드를 검사한다. 시드가 자기 규칙에 걸리면 안 된다.
      const hits = detectPII(m.body);
      if (hits.length > 0) errors.push(`${at}: PII 검출 — ${summarizePII(hits)}`);
    }

    if (m?.season != null) {
      if (!SEASONS.includes(m.season)) errors.push(`${at}: season 값이 아니다 (${m.season})`);
      else {
        seasonCount[m.season] += 1;
        labelledSeasons += 1;
      }
    }
    if (m?.era != null && !ERAS.includes(m.era)) {
      errors.push(`${at}: era 값이 아니다 (${m.era})`);
    }
    if (typeof m?.is_public !== 'boolean') errors.push(`${at}: is_public이 boolean이 아니다`);
  }

  // 기억 0편인 유령 곡 — 스키마는 막지 않지만 피드에 빈 카드가 생긴다.
  const usedRefs = new Set(memories.map((m) => m?.song_ref));
  for (const ref of refs) {
    if (!usedRefs.has(ref)) warnings.push(`songs ${ref}: 기억이 0편이다 — 피드에 빈 곡 카드가 생긴다`);
  }

  // 계절 분포. `지금 계절`이 기본 정렬이라 0편인 계절에 들어온 사람은
  // 맨 위에 자기 계절 글이 하나도 없다. (필터가 아니라 우선순위라 홈이 비지는 않는다)
  const emptySeasons = SEASONS.filter((s) => seasonCount[s] === 0);
  if (emptySeasons.length > 0) {
    warnings.push(
      `계절 분포: ${SEASONS.map((s) => `${s} ${seasonCount[s]}편`).join(' / ')}` +
        ` — ${emptySeasons.join('·')}에 들어온 사람은 맨 위가 자기 계절이 아니다`,
    );
  }
  if (labelledSeasons < memories.length / 2) {
    warnings.push(
      `계절 라벨이 붙은 기억 ${labelledSeasons}/${memories.length}편 — 설계상 정상이지만 ` +
        '`지금 계절` 정렬이 그만큼 덜 작동한다',
    );
  }

  return { errors, warnings, pending };
}
