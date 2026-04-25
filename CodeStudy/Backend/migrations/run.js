/**
 * Migration runner — Neon HTTP driver 기반.
 *
 * Usage:
 *   DATABASE_URL=postgres://... node migrations/run.js
 *   또는 .env.local에 DATABASE_URL 등록 후:
 *     node --env-file=.env.local migrations/run.js
 *
 * Tabber가 한 번 수동 실행. 마이그레이션은 멱등(IF NOT EXISTS)이라 재실행 안전.
 *
 * 주의: 트랜잭션 미적용. 각 statement를 개별 호출.
 *       Neon HTTP는 multi-statement query를 지원하지 않음.
 */

import { neon } from '@neondatabase/serverless';
import { readFileSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));

async function main() {
  const databaseUrl = process.env.DATABASE_URL;
  if (!databaseUrl) {
    console.error('ERROR: DATABASE_URL is not set.');
    console.error('       Provide it via env var or use --env-file=.env.local');
    process.exit(1);
  }

  const sql = neon(databaseUrl);

  // 001, 002, ... 순서대로 실행
  const files = readdirSync(__dirname)
    .filter((f) => f.endsWith('.sql'))
    .sort();

  if (files.length === 0) {
    console.log('No .sql migration files found in', __dirname);
    return;
  }

  for (const file of files) {
    const path = join(__dirname, file);
    const content = readFileSync(path, 'utf8');

    // ;로 statement 분리 후, 각 statement 내부에서 -- 주석 라인 제거.
    //
    // 이전 구현은 `s.startsWith('--')`로 통째로 필터링했는데,
    // 첫 번째 statement(CREATE TABLE)가 보통 파일 상단 주석 블록으로
    // 시작해서 통째로 누락되는 버그가 있었음.
    const statements = content
      .split(';')
      .map((s) =>
        s
          .split('\n')
          .filter((line) => !line.trim().startsWith('--'))
          .join('\n')
          .trim()
      )
      .filter((s) => s.length > 0);

    console.log(`\n--- Running ${file} (${statements.length} statements) ---`);

    for (const stmt of statements) {
      // 첫 줄(또는 첫 80자)만 미리보기로 출력
      const preview = stmt.split('\n')[0].slice(0, 80);
      console.log(`  > ${preview}${preview.length >= 80 ? '...' : ''}`);
      try {
        // neon() 함수 호출(template tag 아님) — 임의 SQL 문자열 실행
        await sql.query(stmt);
      } catch (err) {
        console.error(`  ERROR: ${err.message}`);
        throw err;
      }
    }
  }

  console.log('\nAll migrations applied successfully.');
}

main().catch((err) => {
  console.error('Migration failed:', err);
  process.exit(1);
});
