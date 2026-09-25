/**
 * 마이그레이션 러너 — Neon HTTP 드라이버 기반. CodeStudy/Backend/migrations/run.js 를 복사했다.
 *
 * 실행:
 *   DATABASE_URL=postgres://... node migrations/run.js
 *   또는 .env.local 에 DATABASE_URL 을 넣고:  npm run migrate
 *
 * 마이그레이션은 멱등(IF NOT EXISTS)이라 재실행이 안전하다.
 *
 * 주의: 트랜잭션이 없다. Neon HTTP 드라이버가 multi-statement 쿼리를 지원하지 않아
 *       ;로 쪼개 각 statement 를 개별 호출한다. 중간에 실패하면 거기까지만 적용된 상태로 남는다.
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

    // -- 주석 라인을 **먼저** 지우고, 그다음 ;로 statement를 분리한다.
    //
    // 순서가 중요하다. CodeStudy에서 복사해온 원본은 ;로 먼저 쪼개고 각 조각에서
    // 주석을 지웠는데, 그러면 주석 안에 ;가 하나만 있어도 statement가 거기서 잘린다.
    // 잘린 뒷부분은 더 이상 --로 시작하지 않아 주석 제거도 안 먹고, 한국어 주석이
    // 그대로 SQL로 넘어가 `syntax error at or near`로 죽는다. (이 스키마에서 실제로 터졌다)
    //
    // 남은 한계: 문자열 리터럴 안의 ;나 --는 여전히 구분하지 못한다.
    // 이 리포의 마이그레이션에는 그런 리터럴이 없고, 생기면 그때 진짜 파서가 필요하다.
    const statements = content
      .split('\n')
      .filter((line) => !line.trim().startsWith('--'))
      .join('\n')
      .split(';')
      .map((s) => s.trim())
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
