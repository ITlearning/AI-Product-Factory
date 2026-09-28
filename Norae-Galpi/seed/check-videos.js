/**
 * 시드에 적힌 유튜브 영상이 실제로 살아 있는지 확인한다. `npm run seed:videos`
 *
 * oEmbed(`youtube.com/oembed?url=…`)는 살아있으면 200, 삭제·비공개·임베드 금지면 400을 준다(실측).
 * 곡 상세 진입 때마다 이걸 호출하지는 않는다(엔지니어링 결정 8) — 가장 자주 열리는 화면에
 * 외부 왕복이 매번 붙기 때문이다. 대신 **시드를 채울 때 한 번** 여기서 확인한다.
 *
 * 돌아온 제목도 같이 찍는다. 곡과 다른 영상을 붙여넣는 실수는 형식 검사로 못 잡는다 —
 * 「그래 우리 함께」의 기억이 BTS 봄날에 붙는 바로 그 사고다.
 */

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const seed = JSON.parse(readFileSync(join(__dirname, 'seed.json'), 'utf8'));

/**
 * @param {string} videoId
 * @returns {Promise<{ok: boolean, status: number, title?: string, author?: string}>}
 */
async function probe(videoId) {
  const url = `https://www.youtube.com/oembed?url=${encodeURIComponent(
    `https://www.youtube.com/watch?v=${videoId}`,
  )}&format=json`;
  const res = await fetch(url);
  if (!res.ok) return { ok: false, status: res.status };
  const body = await res.json();
  return { ok: true, status: res.status, title: body.title, author: body.author_name };
}

let dead = 0;
let unset = 0;

for (const s of seed.songs) {
  const label = `${s.title} — ${s.artist}`;
  if (!s.youtube_video_id) {
    unset += 1;
    console.log(`  미정  ${label}`);
    continue;
  }
  const r = await probe(s.youtube_video_id);
  if (!r.ok) {
    dead += 1;
    console.error(`  죽음  ${label}  (${s.youtube_video_id} → HTTP ${r.status})`);
    continue;
  }
  console.log(`  살아있음  ${label}`);
  console.log(`            ↳ ${r.title} / ${r.author}`);
}

console.log(`\n확인 ${seed.songs.length - unset}곡 · 미정 ${unset}곡 · 죽은 영상 ${dead}곡`);
console.log('영상 제목이 곡과 다르면 형식 검사로는 안 잡힌다. 위 제목을 눈으로 대조할 것.');
if (dead > 0) process.exit(1);
