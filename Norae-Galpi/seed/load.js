/**
 * 시드 로더 — 곡 11개 + 기억 11편을 Neon에 넣는다. **멱등하다.**
 *
 * 실행 (마이그레이션이 끝난 뒤):
 *   node --env-file=.env.local seed/load.js
 *   node --env-file=.env.local seed/load.js --dry-run   ← DB에 손대지 않고 무엇이 들어갈지만 출력
 *
 * ## 왜 멱등이 필요한가
 * Neon HTTP 드라이버에는 트랜잭션이 없다. 11곡 중 7번째에서 끊기면 롤백이 안 되고,
 * 다시 돌릴 수 있어야 한다. 그래서 곡은 UNIQUE 인덱스로, 기억은 (곡, 작성자, 본문) 조회로 막는다.
 *
 * ## ON CONFLICT DO NOTHING RETURNING id 의 함정
 * 충돌하면 **빈 결과**가 돌아온다. id를 못 받으므로 반드시 SELECT를 한 번 더 쳐야 한다.
 * 이 두 줄이 빠지면 재실행 시 곡을 못 찾아 기억 INSERT가 조용히 실패한다.
 *
 * ## 작성자
 * 시드 11편은 Tabber의 실제 기억이다. 운영자 표시를 달지 않고 다른 사람 글과 똑같이 섞인다.
 * `SEED_AUTHOR_KEY`(기기 비밀키 원본)를 주면 그 해시로 넣어 나중에 ⑦ 내 갈피에서 꺼낼 수 있다.
 * 없으면 무작위로 만들어 **한 번만 출력한다** — 그 줄을 놓치면 시드 글의 수정·삭제권이 사라진다.
 * 서버에는 여전히 해시만 들어간다.
 */

import { neon } from '@neondatabase/serverless';
import { readFileSync } from 'node:fs';
import { randomBytes } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

import { hashKey } from '../src/identity.js';
import { validateSeed } from './validate.js';

const __dirname = dirname(fileURLToPath(import.meta.url));
const DRY_RUN = process.argv.includes('--dry-run');

async function main() {
  const seed = JSON.parse(readFileSync(join(__dirname, 'seed.json'), 'utf8'));

  // 1) 검증부터. 시드가 스키마를 어기면 DB에 절반만 들어가는 게 최악이다.
  const { errors, warnings, pending } = validateSeed(seed);
  for (const w of warnings) console.log(`주의  ${w}`);
  if (errors.length > 0) {
    for (const e of errors) console.error(`에러  ${e}`);
    throw new Error(`시드 검증 실패 — 에러 ${errors.length}건`);
  }
  // --dry-run은 DB에 손대지 않으므로 미정 칸이 있어도 미리보기는 보여준다.
  // 실제 적재는 막는다 — songs.youtube_video_id가 NOT NULL이라 절반만 들어간다.
  if (pending.length > 0) {
    for (const p of pending) console.error(`미정  ${p}`);
    if (!DRY_RUN) {
      throw new Error(
        `유튜브 영상 ID가 ${pending.length}곡 비어 있다. songs.youtube_video_id는 NOT NULL이라 ` +
          '이 상태로는 넣을 수 없다 — seed.json을 채우고 다시 실행한다.',
      );
    }
  }

  // 2) 작성자 키
  const rawKey = process.env.SEED_AUTHOR_KEY ?? randomBytes(24).toString('base64url');
  const authorHash = hashKey(rawKey);
  if (!process.env.SEED_AUTHOR_KEY) {
    console.log('\n──────────────────────────────────────────────────────');
    console.log('시드 작성자 키를 새로 만들었다. 이 줄은 다시 안 나온다.');
    console.log(`  SEED_AUTHOR_KEY=${rawKey}`);
    console.log('.env.local에 적어두면 시드 글을 ⑦ 내 갈피에서 꺼낼 수 있다.');
    console.log('──────────────────────────────────────────────────────\n');
  }

  if (DRY_RUN) {
    console.log(`[dry-run] 곡 ${seed.songs.length}개 · 기억 ${seed.memories.length}편`);
    for (const s of seed.songs) {
      console.log(`  곡  ${s.source.padEnd(7)} ${s.title} — ${s.artist} (yt:${s.youtube_video_id})`);
    }
    console.log(`  기억 작성자 해시: ${authorHash.slice(0, 12)}…`);
    return;
  }

  const databaseUrl = process.env.DATABASE_URL;
  if (!databaseUrl) {
    throw new Error('DATABASE_URL이 없다. --env-file=.env.local 을 쓰거나 환경변수로 넘긴다.');
  }
  const sql = neon(databaseUrl);

  // 3) 곡
  /** @type {Map<string, number>} ref → songs.id */
  const songIds = new Map();
  let songsInserted = 0;

  for (const s of seed.songs) {
    const id = await upsertSong(sql, s);
    songIds.set(s.ref, id.songId);
    if (id.inserted) songsInserted += 1;
    console.log(`  곡  ${id.inserted ? '추가' : '이미 있음'}  #${id.songId}  ${s.title} — ${s.artist}`);
  }

  // 4) 기억
  let memoriesInserted = 0;
  for (const m of seed.memories) {
    const songId = songIds.get(m.song_ref);
    // 기억엔 자연 키가 없다. (곡, 작성자, 본문)이 같으면 같은 글로 본다.
    const existing = await sql`
      SELECT id FROM memories
       WHERE song_id = ${songId} AND author_hash = ${authorHash} AND body = ${m.body}
       LIMIT 1
    `;
    if (existing.length > 0) {
      console.log(`  기억 이미 있음  #${existing[0].id}  ${m.song_ref}`);
      continue;
    }
    const rows = await sql`
      INSERT INTO memories (song_id, author_hash, body, season, era, is_public)
      VALUES (${songId}, ${authorHash}, ${m.body}, ${m.season}, ${m.era}, ${m.is_public})
      RETURNING id
    `;
    memoriesInserted += 1;
    console.log(`  기억 추가      #${rows[0].id}  ${m.song_ref}`);
  }

  console.log(`\n곡 ${songsInserted}개 · 기억 ${memoriesInserted}편 새로 들어갔다.`);
  if (songsInserted === 0 && memoriesInserted === 0) {
    console.log('(전부 이미 있었다 — 멱등 재실행)');
  }
  console.log('피드 캐시를 쓰고 있다면 feed:* 3키를 퍼지할 것.');
}

/**
 * 곡 하나를 넣거나 이미 있는 것을 찾는다.
 *
 * 출처마다 유일성 열쇠가 다르다 — itunes는 (artist_id, title_key), youtube는 video_id.
 * 그래서 ON CONFLICT 대상도 갈린다.
 *
 * @param {ReturnType<typeof neon>} sql
 * @param {object} s - seed.json 의 song 항목
 * @returns {Promise<{songId: number, inserted: boolean}>}
 */
async function upsertSong(sql, s) {
  const inserted = await sql`
    INSERT INTO songs
      (source, itunes_artist_id, itunes_track_id, title_key, title_key_rev,
       title, artist, artwork_url, youtube_video_id)
    VALUES
      (${s.source}, ${s.itunes_artist_id}, ${s.itunes_track_id}, ${s.title_key}, ${s.title_key_rev},
       ${s.title}, ${s.artist}, ${s.artwork_url}, ${s.youtube_video_id})
    ON CONFLICT DO NOTHING
    RETURNING id
  `;
  if (inserted.length > 0) return { songId: inserted[0].id, inserted: true };

  // 충돌 — DO NOTHING은 빈 결과를 준다. 반드시 다시 찾아야 한다.
  const found =
    s.source === 'itunes'
      ? await sql`
          SELECT id FROM songs
           WHERE source = 'itunes' AND itunes_artist_id = ${s.itunes_artist_id}
             AND title_key = ${s.title_key}
           LIMIT 1
        `
      : await sql`
          SELECT id FROM songs
           WHERE source = 'youtube' AND youtube_video_id = ${s.youtube_video_id}
           LIMIT 1
        `;

  if (found.length === 0) {
    throw new Error(`곡 upsert 실패 — 넣지도 찾지도 못했다: ${s.ref}`);
  }
  return { songId: found[0].id, inserted: false };
}

main().catch((err) => {
  console.error('\n시드 적재 실패:', err.message);
  process.exit(1);
});
