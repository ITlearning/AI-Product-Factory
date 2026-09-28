/**
 * 로컬 개발 서버 — **Neon 없이 앱 전체를 돌린다.**
 *
 *   npm run dev:local     → http://localhost:5173
 *
 * DB는 PGlite(WASM Postgres)를 메모리에 띄우고 `migrations/001_init.sql` 을 그대로 적용한다.
 * 시드도 `seed/seed.json` 에서 읽어 넣는다 — 유튜브 영상 ID 가 아직 없는 곡은
 * **자리표시자로 채운다.** 그 곡의 ⑥ 상세는 플레이어가 에러를 보여주는데, 그건 정상이다.
 * 실제 ID가 채워지면 그대로 제대로 재생된다.
 *
 * 이건 개발·확인용이다. 배포는 Vercel + Neon 이고 이 파일은 거기 안 올라간다.
 * Redis 도 없어서 캐시는 매번 미스, 레이트리밋은 통과다.
 */

import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { PGlite } from '@electric-sql/pglite';

import { _setSql } from '../src/db.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, '..');
const PORT = Number(process.env.PORT ?? 5173);

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml',
};

/** Neon 모양 어댑터 — 태그드 템플릿 + `.query(text, params)`. */
function neonLike(db) {
  const tagged = async (strings, ...values) => {
    let text = '';
    strings.forEach((p, i) => { text += p + (i < values.length ? `$${i + 1}` : ''); });
    return (await db.query(text, values)).rows;
  };
  tagged.query = async (text, params = []) => (await db.query(text, params)).rows;
  return tagged;
}

async function setupDb() {
  const db = await PGlite.create();
  const stmts = fs.readFileSync(path.join(root, 'migrations/001_init.sql'), 'utf8')
    .split('\n').filter((l) => !l.trim().startsWith('--')).join('\n')
    .split(';').map((s) => s.trim()).filter(Boolean);
  for (const s of stmts) await db.exec(s);

  const sql = neonLike(db);
  _setSql(sql);

  // 시드. 영상 ID 가 비었으면 자리표시자 — 스키마가 NOT NULL 이라 없이는 못 넣는다.
  const seed = JSON.parse(fs.readFileSync(path.join(root, 'seed/seed.json'), 'utf8'));
  const ids = {};
  let filler = 0;
  let placeholders = 0;
  for (const s of seed.songs) {
    let videoId = s.youtube_video_id;
    if (!videoId) {
      videoId = `DEV${String(filler++).padStart(8, '0')}`;
      placeholders += 1;
    }
    const rows = await sql.query(
      `INSERT INTO songs (source, itunes_artist_id, itunes_track_id, title_key, title_key_rev,
                          title, artist, artwork_url, youtube_video_id)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING id`,
      [s.source, s.itunes_artist_id, s.itunes_track_id, s.title_key, s.title_key_rev,
       s.title, s.artist, s.artwork_url, videoId],
    );
    ids[s.ref] = rows[0].id;
  }
  for (const m of seed.memories) {
    await sql.query(
      `INSERT INTO memories (song_id, author_hash, body, season, era, is_public)
       VALUES ($1,'dev-seed',$2,$3,$4,$5)`,
      [ids[m.song_ref], m.body, m.season, m.era, m.is_public],
    );
  }

  console.log(`시드: 곡 ${seed.songs.length} · 기억 ${seed.memories.length}`);
  if (placeholders > 0) {
    console.log(`  영상 ID 자리표시자 ${placeholders}곡 — 그 곡의 ⑥ 상세는 플레이어가 에러를 보여준다`);
  }
  return sql;
}

/** api/*.js 를 경로에 맞춰 불러온다. */
async function loadHandler(pathname) {
  const name = pathname.replace(/^\/api\//, '').replace(/\/$/, '');
  if (!/^[a-z0-9-]+$/.test(name)) return null;
  const file = path.join(root, 'api', `${name}.js`);
  if (!fs.existsSync(file)) return null;
  const mod = await import(pathToFileURL(file).href);
  return mod.default;
}

/** Vercel 의 (req, res) 모양을 흉내낸다 — req.query·req.body, res.status().json(). */
function adapt(req, res, url) {
  req.query = Object.fromEntries(url.searchParams);
  res.status = (code) => { res.statusCode = code; return res; };
  res.json = (body) => {
    res.setHeader('Content-Type', 'application/json; charset=utf-8');
    res.end(JSON.stringify(body));
    return res;
  };
}

function readBody(req) {
  return new Promise((resolve) => {
    const chunks = [];
    req.on('data', (c) => chunks.push(c));
    req.on('end', () => {
      const raw = Buffer.concat(chunks).toString('utf8');
      try {
        resolve(raw ? JSON.parse(raw) : {});
      } catch {
        resolve({});
      }
    });
  });
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://localhost:${PORT}`);

  if (url.pathname.startsWith('/api/')) {
    try {
      const handler = await loadHandler(url.pathname);
      if (!handler) return res.writeHead(404).end('no such endpoint');
      adapt(req, res, url);
      if (req.method !== 'GET') req.body = await readBody(req);
      return await handler(req, res);
    } catch (err) {
      console.error('api error', err);
      res.writeHead(500, { 'Content-Type': 'application/json' });
      return res.end(JSON.stringify({ error: String(err?.message ?? err) }));
    }
  }

  // 정적. dist 가 아니라 소스를 그대로 준다 — 고치고 새로고침하면 바로 보인다.
  let file = path.join(root, decodeURIComponent(url.pathname));
  if (!file.startsWith(root)) return res.writeHead(403).end('nope');
  if (!fs.existsSync(file) || fs.statSync(file).isDirectory()) {
    file = path.join(root, 'index.html'); // SPA 폴백
  }
  res.writeHead(200, { 'Content-Type': MIME[path.extname(file)] ?? 'application/octet-stream' });
  fs.createReadStream(file).pipe(res);
});

await setupDb();
server.listen(PORT, () => {
  console.log(`노래갈피 (로컬) → http://localhost:${PORT}`);
  console.log('DB: PGlite 인메모리. 껐다 켜면 초기화된다.');
});
