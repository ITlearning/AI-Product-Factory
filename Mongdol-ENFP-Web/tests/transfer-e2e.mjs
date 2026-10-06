// 브라우저 확인 — 기록 옮기기. 정적 파일 + /api/transfer(같은 핸들러, 메모리 Redis)를 node 서버 하나로 127.0.0.1:8775 에 띄운다.
// TZ=Asia/Seoul node tests/transfer-e2e.mjs [chromium|webkit …]
import { chromium, webkit } from '/Users/tabber/.claude/skills/gstack/node_modules/playwright/index.mjs';
import http from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, join, normalize } from 'node:path';
import { makeHandler } from '../api/transfer.js';
import { ClockRedis } from './clock-redis.mjs';

const ROOT = new URL('..', import.meta.url).pathname;
const SHOTS = join(ROOT, 'screenshots/');
const PORT = 8775;
const BASE = `http://127.0.0.1:${PORT}/`;
const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.css': 'text/css', '.json': 'application/json', '.png': 'image/png', '.webmanifest': 'application/manifest+json', '.svg': 'image/svg+xml' };

const redis = new ClockRedis();
const api = makeHandler({ getRedis: async () => redis, getLimiter: async () => ({ limit: async () => ({ success: true }) }) });
const calls = [];
const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, BASE);
  if (url.pathname === '/api/transfer') {
    calls.push(req.method);
    return api(req, res);
  }
  const path = normalize(join(ROOT, url.pathname === '/' ? 'index.html' : decodeURIComponent(url.pathname)));
  if (!path.startsWith(ROOT)) { res.statusCode = 403; return res.end(); }
  try {
    const body = await readFile(path);
    res.writeHead(200, { 'content-type': TYPES[extname(path)] || 'application/octet-stream', 'cache-control': 'no-store' });
    res.end(body);
  } catch { res.statusCode = 404; res.end(); }
});
await new Promise((r) => server.listen(PORT, '127.0.0.1', r));

const IPHONE = 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.5 Mobile/15E148 Safari/604.1';
const errors = [];
const notFound = [];
const log = (...a) => console.log(...a);
let ok = true;
const check = (label, cond, extra = '') => { log(`${cond ? '✔' : '✘'} ${label}${extra ? ` — ${extra}` : ''}`); if (!cond) ok = false; };

// 기기 쪽 상태 — 기록·닫은 날·받은 날·사진 바이트 해시
const snapshot = (page) => page.evaluate(async () => {
  const db = await import('./js/db.js');
  const moments = (await db.loadMoments()).sort((a, b) => a.id.localeCompare(b.id));
  const hex = async (blob) => (blob ? [...new Uint8Array(await crypto.subtle.digest('SHA-256', await blob.arrayBuffer()))].slice(0, 8).map((b) => b.toString(16).padStart(2, '0')).join('') : null);
  const photos = {};
  for (const m of moments) {
    const p = await db.loadPhoto(m.id);
    photos[m.id] = [await hex(p?.full), await hex(p?.thumb), p?.thumb?.type];
  }
  return {
    count: moments.length,
    moments: moments.map(({ dayKey: _d, ...m }) => JSON.stringify(m)),
    closures: db.meta.get('closures', {}),
    gifted: [...db.meta.get('gifted', [])].sort(),
    photos,
  };
});

async function run(engine, name) {
  const browser = await engine.launch();
  const tag = name === 'chromium' ? '' : `-${name}`;
  const ctx = async ({ standalone = false, onboarded = true } = {}) => {
    const c = await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, userAgent: IPHONE, serviceWorkers: 'block' });
    await c.addInitScript(({ standalone, onboarded }) => {
      if (onboarded) localStorage.setItem('mongdol.onboarded', 'true');
      if (standalone) {
        try { Object.defineProperty(Navigator.prototype, 'standalone', { get: () => true, configurable: true }); } catch { /* 아래로 */ }
        try { Object.defineProperty(navigator, 'standalone', { get: () => true, configurable: true }); } catch { /* 무시 */ }
      }
    }, { standalone, onboarded });
    const page = await c.newPage();
    page.on('console', (m) => { if (m.type() === 'error') errors.push(`[${name}] ${m.text()}`); });
    page.on('pageerror', (e) => errors.push(`[${name}] pageerror ${e.message}`));
    page.on('response', (r) => { if (r.status() >= 400) notFound.push(`[${name}] ${r.status()} ${new URL(r.url()).pathname}`); });
    return { c, page };
  };
  const booted = (page) => page.waitForFunction(() => document.documentElement.classList.contains('booted'));

  // A — iPhone Safari 탭: 견본 하루 → 홈 화면 안내의 ① → 코드
  const A = await ctx();
  await A.page.goto(BASE + '?debug');
  await booted(A.page);
  await A.page.evaluate(async () => {
    const { layers } = await import('./js/dom.js');
    layers.add('e2e'); // 견본 뒤 증정이 떠서 버튼을 가리지 않게
    const { store } = await import('./js/store.js');
    const { fillSample } = await import('./js/sample.js');
    await store.clear();
    await fillSample(store);
  });
  const before = await A.page.evaluate(() => window.__mongdol.store.all.size);
  await A.page.click('#settings-btn');
  await A.page.waitForSelector('.set-sheet');
  await A.page.waitForTimeout(500);
  if (!tag) await A.page.screenshot({ path: SHOTS + '50-transfer-settings.jpg', quality: 80 });
  await A.page.click('.row-btn:has-text("홈 화면에 추가하기")');
  await A.page.waitForSelector('.inst-sheet .xfer-card .xfer-go');
  await A.page.waitForTimeout(500);
  check(`[${name}] 안내 위에 「기록 옮길 코드 만들기」 카드`, (await A.page.textContent('.inst-sheet .xfer-card')).includes('기록 옮길 코드 만들기'));
  check(`[${name}] 홈 화면 단계는 1~3 그대로`, (await A.page.textContent('.inst-steps li:first-child')).includes('공유 버튼'));
  if (!tag) await A.page.screenshot({ path: SHOTS + '51-transfer-install-step.jpg', quality: 80 });
  await A.page.evaluate(() => {
    window.__progress = [];
    new MutationObserver(() => {
      const s = document.querySelector('.xfer-progress')?.textContent;
      if (s && window.__progress.at(-1) !== s) window.__progress.push(s);
    }).observe(document.getElementById('layers'), { subtree: true, childList: true, characterData: true });
  });
  await A.page.click('.inst-sheet .xfer-card .xfer-go');
  await A.page.waitForSelector('.inst-sheet .xfer-card .xfer-code', { timeout: 60000 });
  const progress = await A.page.evaluate(() => window.__progress);
  const shown = (await A.page.textContent('.xfer-code')).trim();
  const code = shown.replace(/\D/g, '');
  check(`[${name}] 코드가 안내 안에서 4+4 로 보인다(덮개 창 없음)`, /^\d{4} \d{4}$/.test(shown) && !(await A.page.$('.xfer-sheet')), shown);
  check(`[${name}] 진행률 표시`, progress.some((s) => /코드 만드는 중 \d+\/\d+/.test(s)), progress.slice(-2).join(' · '));
  check(`[${name}] 홈 화면 단계가 코드와 같이 보인다·남은 시간`, (await A.page.textContent('.inst-sheet')).includes('공유 버튼') && /\d:\d\d 남았어요/.test(await A.page.textContent('.xfer-left')));
  if (!tag) await A.page.screenshot({ path: SHOTS + '52-transfer-code.jpg', quality: 80 });
  // 안내를 닫았다 다시 열어도 같은 코드
  await A.page.click('.inst-sheet .pill-close');
  await A.page.waitForTimeout(450);
  await A.page.evaluate(async () => { const { openInstallSheet } = await import('./js/install.js'); const { carryCard } = await import('./js/transfer.js'); const { store } = await import('./js/store.js'); openInstallSheet({ hasRecords: true, carry: () => carryCard(store) }); });
  await A.page.waitForSelector('.inst-sheet .xfer-code');
  check(`[${name}] 다시 열어도 같은 코드`, (await A.page.textContent('.inst-sheet .xfer-code')).trim() === shown);
  const stored = redis.keys();
  check(`[${name}] 서버엔 mongdol:xfer: 키만`, stored.every((k) => k.startsWith('mongdol:xfer:')), `${stored.length}개`);
  const a = await snapshot(A.page);
  check(`[${name}] 견본 기록 수`, a.count === before && a.count > 10, String(a.count));

  // B — 홈 화면 앱 처음 열기: 온보딩 첫 장 → 가져오기
  const B = await ctx({ standalone: true, onboarded: false });
  await B.page.goto(BASE + '?debug');
  await B.page.waitForSelector('.onboarding');
  await B.page.waitForTimeout(600);
  const second = await B.page.textContent('.ob-foot .btn.ghost');
  check(`[${name}] 온보딩 첫 장에 가져오기`, second.includes('Safari에서 쓰던 기록 가져오기'), second);
  if (!tag) await B.page.screenshot({ path: SHOTS + '53-transfer-onboarding.jpg', quality: 80 });
  await B.page.click('.ob-foot .btn.ghost');
  await B.page.waitForSelector('.xfer-input');
  check(`[${name}] 숫자 키패드`, (await B.page.getAttribute('.xfer-input', 'inputmode')) === 'numeric');
  await B.page.type('.xfer-input', code);
  check(`[${name}] 넣은 코드도 4+4`, (await B.page.inputValue('.xfer-input')) === shown);
  if (!tag) await B.page.screenshot({ path: SHOTS + '54-transfer-enter.jpg', quality: 80 });
  await B.page.click('.xfer-go');
  await B.page.waitForSelector('.xfer-done', { timeout: 60000 });
  const doneText = await B.page.textContent('.xfer-done');
  check(`[${name}] 「짠! 기록 N개를 다 데려왔어요」`, doneText === `짠! 기록 ${a.count}개를 다 데려왔어요`, doneText);
  if (!tag) await B.page.screenshot({ path: SHOTS + '55-transfer-done.jpg', quality: 80 });
  check(`[${name}] 받은 뒤 서버에 남은 묶음 없음`, redis.keys().filter((k) => !/:(fail|up):/.test(k)).length === 0, redis.keys().join(','));
  await B.page.click('.xfer-ok');
  await B.page.waitForFunction(() => !document.querySelector('.onboarding'), null, { timeout: 5000 });
  check(`[${name}] 온보딩 마침(onboarded)`, await B.page.evaluate(() => localStorage.getItem('mongdol.onboarded') === 'true'));
  const b = await snapshot(B.page);
  check(`[${name}] 기록 수 같음`, b.count === a.count, `${b.count}/${a.count}`);
  check(`[${name}] 기록 내용 같음`, JSON.stringify(b.moments) === JSON.stringify(a.moments));
  check(`[${name}] 닫은 날 같음`, JSON.stringify(b.closures) === JSON.stringify(a.closures), JSON.stringify(b.closures));
  check(`[${name}] 받은 날 같음`, JSON.stringify(b.gifted) === JSON.stringify(a.gifted), JSON.stringify(b.gifted));
  check(`[${name}] 사진(원본·썸네일) 바이트 같음`, JSON.stringify(b.photos) === JSON.stringify(a.photos), `${Object.keys(b.photos).length}장`);
  await B.page.waitForTimeout(1500);
  if (await B.page.$('.ceremony')) {
    if (!tag) await B.page.screenshot({ path: SHOTS + '56-transfer-ceremony.jpg', quality: 80 });
    await B.page.click('.cer-close').catch(() => {});
    await B.page.waitForTimeout(1200);
  }
  const imgs = await B.page.evaluate(async () => {
    const list = [...document.querySelectorAll('#home img.card-img')];
    await Promise.all(list.map((i) => (i.complete && i.naturalWidth ? null : new Promise((r) => { i.onload = i.onerror = r; setTimeout(r, 4000); }))));
    return { all: list.length, loaded: list.filter((i) => i.naturalWidth > 0).length };
  });
  check(`[${name}] 홈 썸네일이 불러와진다`, imgs.all > 0 && imgs.loaded === imgs.all, `${imgs.loaded}/${imgs.all}`);
  if (!tag) await B.page.screenshot({ path: SHOTS + '57-transfer-home.jpg', quality: 80 });

  // C — 같은 코드 두 번째, 그리고 틀린 코드
  const C = await ctx({ standalone: true, onboarded: false });
  await C.page.goto(BASE + '?debug');
  await C.page.waitForSelector('.onboarding');
  await C.page.click('.ob-foot .btn.ghost');
  await C.page.waitForSelector('.xfer-input');
  await C.page.type('.xfer-input', code);
  await C.page.click('.xfer-go');
  await C.page.waitForFunction(() => document.querySelector('.xfer-error')?.textContent, null, { timeout: 20000 });
  const err = await C.page.textContent('.xfer-error');
  check(`[${name}] 같은 코드 두 번째는 실패`, err.startsWith('코드를 다시 확인해 주세요'), err);
  check(`[${name}] 실패한 쪽엔 아무것도 안 들어옴`, (await C.page.evaluate(() => window.__mongdol.store.all.size)) === 0);
  if (!tag) await C.page.screenshot({ path: SHOTS + '58-transfer-wrong.jpg', quality: 80 });

  await browser.close();
}

const want = process.argv.slice(2);
const engines = { chromium, webkit };
try {
  for (const name of want.length ? want : ['chromium', 'webkit']) {
    log(`── ${name}`);
    await run(engines[name], name);
  }
} catch (e) {
  ok = false;
  console.error(e);
} finally {
  server.close();
}
log('API 호출 수:', calls.length);
// 「Failed to load resource」는 일부러 틀린 코드를 넣은 /api/transfer 404 뿐이어야 한다.
const expected404 = notFound.filter((s) => / 404 \/api\/transfer$/.test(s));
const loadErrors = errors.filter((e) => e.includes('Failed to load resource'));
const realErrors = errors.filter((e) => !e.includes('Failed to load resource'));
log('4xx 응답:', notFound);
check('브라우저 「Failed to load resource」는 일부러 틀린 코드의 /api/transfer 404 뿐', loadErrors.length === expected404.length && notFound.length === expected404.length);
log('콘솔 에러(위 404 빼고):', realErrors.length, realErrors);
process.exit(ok && realErrors.length === 0 ? 0 : 1);
