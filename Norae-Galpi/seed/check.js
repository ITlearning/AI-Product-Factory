/**
 * 시드 검증 CLI. `npm run seed:validate`
 *
 * DB가 필요 없다 — Neon 프로젝트를 만들기 전에도 돌아간다.
 * 종료 코드: errors가 있으면 1, pending만 남으면 2, 전부 통과면 0.
 */

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { validateSeed } from './validate.js';

const __dirname = dirname(fileURLToPath(import.meta.url));
const seed = JSON.parse(readFileSync(join(__dirname, 'seed.json'), 'utf8'));
const { errors, warnings, pending } = validateSeed(seed);

console.log(`시드: 곡 ${seed.songs.length}개 · 기억 ${seed.memories.length}편`);

for (const w of warnings) console.log(`  주의  ${w}`);
for (const p of pending) console.log(`  미정  ${p}`);
for (const e of errors) console.error(`  에러  ${e}`);

if (errors.length > 0) {
  console.error(`\n실패 — 에러 ${errors.length}건. 고치기 전에는 로더를 돌리지 않는다.`);
  process.exit(1);
}
if (pending.length > 0) {
  console.log(`\n보류 — 스키마 제약은 전부 통과. 사람이 채울 칸이 ${pending.length}개 남았다.`);
  process.exit(2);
}
console.log('\n통과 — 로더를 돌릴 수 있다.');
