/**
 * 곡 upsert — 시드 로더와 `POST /api/memories` 가 같은 경로를 쓴다.
 *
 * ## ON CONFLICT DO NOTHING RETURNING id 의 함정
 * 충돌하면 **빈 결과**가 돌아온다. id를 못 받으므로 반드시 SELECT를 한 번 더 쳐야 한다.
 * 트랜잭션이 없으니 두 호출 사이가 벌어지는데, 그사이 상대가 이미 INSERT를 마쳤으므로
 * SELECT는 성공한다. **이 두 줄이 빠지면 첫 등록이 조용히 실패하는 흔한 함정이다.**
 *
 * ## 동시에 같은 곡을 처음 등록하는 경우
 * `UNIQUE (itunes_artist_id, title_key)` 가 막는다. **먼저 쓴 쪽의 `youtube_video_id`가 이기고**,
 * 진 쪽에게는 이미 정해진 영상을 보여준 뒤 글만 저장한다. 그래서 반환값에 `videoWasAlreadySet`
 * 을 실어, 진 쪽 화면이 "이 곡은 이미 영상이 정해져 있어요"를 말할 수 있게 한다.
 * (설계에 그 화면이 아직 없다 — 미해결 항목이고, 여기서는 서버가 사실을 알려주는 데까지 한다)
 */

/**
 * @typedef {object} SongInput
 * @property {'itunes'|'youtube'} source
 * @property {number|null} [itunes_artist_id]
 * @property {number|null} [itunes_track_id]
 * @property {string} title_key
 * @property {number} [title_key_rev]
 * @property {string} title
 * @property {string} artist
 * @property {string|null} [artwork_url]
 * @property {string} youtube_video_id
 */

/**
 * 곡을 넣거나 이미 있는 것을 찾는다.
 *
 * @param {any} sql - Neon 클라이언트(template tag) 또는 같은 모양
 * @param {SongInput} s
 * @returns {Promise<{songId: number|string, inserted: boolean, videoWasAlreadySet: boolean,
 *                    existingVideoId: string|null}>}
 */
export async function upsertSong(sql, s) {
  const rev = s.title_key_rev ?? 1;

  const inserted = await sql`
    INSERT INTO songs
      (source, itunes_artist_id, itunes_track_id, title_key, title_key_rev,
       title, artist, artwork_url, youtube_video_id)
    VALUES
      (${s.source}, ${s.itunes_artist_id ?? null}, ${s.itunes_track_id ?? null},
       ${s.title_key}, ${rev}, ${s.title}, ${s.artist}, ${s.artwork_url ?? null},
       ${s.youtube_video_id})
    ON CONFLICT DO NOTHING
    RETURNING id, youtube_video_id
  `;

  if (inserted.length > 0) {
    return {
      songId: inserted[0].id,
      inserted: true,
      videoWasAlreadySet: false,
      existingVideoId: inserted[0].youtube_video_id,
    };
  }

  // 충돌. 여기서 SELECT를 빼먹으면 첫 등록이 조용히 실패한다.
  const found =
    s.source === 'itunes'
      ? await sql`
          SELECT id, youtube_video_id FROM songs
           WHERE source = 'itunes' AND itunes_artist_id = ${s.itunes_artist_id}
             AND title_key = ${s.title_key}
           LIMIT 1
        `
      : await sql`
          SELECT id, youtube_video_id FROM songs
           WHERE source = 'youtube' AND youtube_video_id = ${s.youtube_video_id}
           LIMIT 1
        `;

  if (found.length === 0) {
    // INSERT도 SELECT도 실패 — 열쇠가 안 맞거나 다른 제약에 걸린 것이다. 조용히 넘기면 안 된다.
    throw new Error(`곡 upsert 실패 — 넣지도 찾지도 못했다: ${s.title} / ${s.artist}`);
  }

  const existingVideoId = found[0].youtube_video_id;
  return {
    songId: found[0].id,
    inserted: false,
    // 진 쪽이 고른 영상이 말없이 버려지는 바로 그 경우.
    videoWasAlreadySet: existingVideoId !== s.youtube_video_id,
    existingVideoId,
  };
}
