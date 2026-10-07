// 브라우저 확인 — 정적 파일 + /api/feedback · /api/admin/feedback(같은 핸들러, 메모리 Redis)을 node 서버 하나로 127.0.0.1:8776 에 띄운다.
// TZ=Asia/Seoul node tests/e2e.mjs <스크린샷 폴더> [chromium|webkit …]   (playwright 는 gstack 에 깔린 것을 빌려 쓴다)
import { chromium, webkit } from '/Users/tabber/.claude/skills/gstack/node_modules/playwright/index.mjs';
import http from 'node:http';
import assert from 'node:assert/strict';
import { readFile, mkdir } from 'node:fs/promises';
import { extname, join, normalize } from 'node:path';
import { makeHandler as makeFeedback } from '../api/feedback.js';
import { makeHandler as makeAdmin } from '../api/admin/feedback.js';
import { ClockRedis } from './clock-redis.mjs';

const ROOT = new URL('..', import.meta.url).pathname;
const SHOTS = process.argv[2] ?? join(ROOT, '.shots');
const ENGINES = process.argv.slice(3).length ? process.argv.slice(3) : ['webkit', 'chromium'];
const PORT = 8776;
const TOKEN = 'test-token-0123456789abcdef';
const TYPES = { '.html': 'text/html; charset=utf-8', '.css': 'text/css', '.js': 'text/javascript' };

const redis = new ClockRedis();
const okLimiter = { limit: async () => ({ success: true }) };
const feedback = makeFeedback({ getRedis: async () => redis, getLimiter: async () => okLimiter });
const admin = makeAdmin({ getRedis: async () => redis, env: { ADMIN_TOKEN: TOKEN } });
let posts = 0;

const server = http.createServer(async (req, res) => {
  const path = new URL(req.url, 'http://x').pathname;
  if (path === '/api/feedback') { posts++; await new Promise((r) => setTimeout(r, 400)); return feedback(req, res); }
  if (path === '/api/admin/feedback') return admin(req, res);
  if (path === '/') { res.writeHead(307, { location: `/feedback${new URL(req.url, 'http://x').search}` }); return res.end(); } // Vercel 리다이렉트도 쿼리를 넘긴다
  // vercel.json cleanUrls 흉내 — /feedback → feedback.html
  const file = normalize(join(ROOT, extname(path) ? path : `${path}.html`));
  if (!file.startsWith(ROOT)) { res.statusCode = 403; return res.end(); }
  try {
    const body = await readFile(file);
    res.writeHead(200, { 'content-type': TYPES[extname(file)] ?? 'application/octet-stream' });
    res.end(body);
  } catch { res.statusCode = 404; res.end(); }
});
await new Promise((r) => server.listen(PORT, '127.0.0.1', r));
await mkdir(SHOTS, { recursive: true });
const base = `http://127.0.0.1:${PORT}`;

try {
  for (const name of ENGINES) {
    const browser = await ({ chromium, webkit })[name].launch();
    const ctx = await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, locale: 'ko-KR' });
    const page = await ctx.newPage();
    const errors = [];
    page.on('pageerror', (e) => errors.push(String(e)));

    await page.goto(`${base}/?v=1.1.1&b=4&d=iPhone17,1`);
    assert.equal(new URL(page.url()).pathname, '/feedback');
    await page.waitForTimeout(600);
    assert.equal(await page.textContent('#fb-meta'), '몽돌 1.1.1 (4) · iPhone17,1 정보가 함께 가요.');
    assert.equal(await page.isDisabled('#fb-send'), true, '빈 글이면 못 보낸다');
    await page.screenshot({ path: join(SHOTS, `${name}-feedback-empty.png`) });

    await page.click('text=불편한 점');
    await page.fill('#fb-text', '하루가 닫힌 다음 날 아침에 조약돌이 늦게 도착했어요.\n알림은 8시에 왔는데 앱을 열면 아직 진행 중이었어요.');
    await page.fill('#fb-contact', 'me@example.com');
    await page.waitForTimeout(400); // 칩·버튼 전환(0.2초)이 끝난 뒤
    await page.screenshot({ path: join(SHOTS, `${name}-feedback-filled.png`), fullPage: true });

    const before = posts;
    await page.click('#fb-send');
    await page.click('#fb-send', { force: true, timeout: 500 }).catch(() => {});
    await page.waitForSelector('#fb-done:not([hidden])');
    assert.equal(posts - before, 1, '두 번 눌러도 한 번만 간다');
    await page.waitForTimeout(1000);
    assert.equal(await page.isVisible('.done-close .web-only'), true, '앱 밖이면 「이제 이 창을 닫아도 돼요」');
    await page.screenshot({ path: join(SHOTS, `${name}-feedback-done.png`) });

    await page.goto(`${base}/feedback`);
    assert.equal(await page.isHidden('#fb-meta'), true, '쿼리가 없으면 정보 줄을 숨긴다');
    await page.fill('#fb-text', '조약돌 이름을 길게 눌러 복사하고 싶어요.');
    await page.click('text=바라는 기능');
    await page.click('#fb-send');
    await page.waitForSelector('#fb-done:not([hidden])');

    // 앱 안(?app=1): 「몽돌」 머리 숨김, 위 번짐 끔(단색), 아래 여백 넉넉히. 쿼리 v·b·d 는 그대로.
    await page.goto(`${base}/feedback?app=1&v=1.1.1&b=4&d=iPhone17,1`);
    await page.waitForTimeout(600);
    assert.equal(await page.isHidden('.page-head'), true, 'app=1 이면 「몽돌」 머리를 숨긴다');
    assert.equal(await page.isVisible('.lede'), true);
    assert.equal(await page.evaluate(() => getComputedStyle(document.body, '::before').display), 'none', 'app=1 이면 번짐 없음');
    assert.ok(await page.evaluate(() => parseFloat(getComputedStyle(document.querySelector('.page')).paddingBottom)) >= 40, '아래 여백 40 이상');
    assert.equal(await page.textContent('#fb-meta'), '몽돌 1.1.1 (4) · iPhone17,1 정보가 함께 가요.');
    await page.screenshot({ path: join(SHOTS, `${name}-feedback-app.png`) });
    await page.fill('#fb-text', '앱 안에서 보내 봐요.');
    await page.click('#fb-send');
    await page.waitForSelector('#fb-done:not([hidden])');
    await page.waitForTimeout(1000); // 돌 굴러 들어오기(0.9초)
    const box = await page.locator('.done-pebble').boundingBox();
    assert.ok(box.width >= 140 && box.width <= 160 && Math.abs(box.width - box.height) < 1, `돌은 1:1 (${box.width}×${box.height})`);
    assert.equal(await page.textContent('.done-close'), '이제 이 창을 닫아도 돼요.위의 「닫기」를 누르면 돼요.');
    assert.equal(await page.isVisible('.done-close .app-only'), true, 'app=1 이면 위의 닫기 안내');
    assert.equal(await page.isHidden('.done-close .web-only'), true);
    await page.screenshot({ path: join(SHOTS, `${name}-feedback-done-app.png`) });
    await page.goto(`${base}/feedback?v=1.1.1`);
    assert.equal(await page.isVisible('.page-head'), true, 'app=1 이 아니면 그대로');

    await page.goto(`${base}/admin`);
    await page.waitForSelector('#ad-login:not([hidden])');
    await page.screenshot({ path: join(SHOTS, `${name}-admin-login.png`) });
    await page.fill('#ad-token', 'wrong');
    await page.click('#ad-login button[type=submit]');
    await page.waitForSelector('#ad-login-error:not([hidden])');
    assert.equal(await page.textContent('#ad-login-error'), '토큰이 맞지 않아요.');
    await page.fill('#ad-token', TOKEN);
    await page.click('#ad-login button[type=submit]');
    await page.waitForSelector('#ad-list .item');
    const count = await page.locator('#ad-list .item').count();
    assert.ok(count >= 2);
    await page.screenshot({ path: join(SHOTS, `${name}-admin-list.png`), fullPage: true });

    await page.locator('#ad-list .item').first().locator('text=읽음으로').click();
    await page.waitForSelector('#ad-list .item.read');
    await page.click('.filters input[value=unread] + span');
    assert.equal(await page.locator('#ad-list .item').count(), count - 1);
    await page.click('.filters input[value=all] + span');
    page.once('dialog', (d) => d.accept());
    await page.locator('#ad-list .item').first().locator('text=지우기').click();
    await page.waitForFunction((n) => document.querySelectorAll('#ad-list .item').length === n, count - 1);

    await page.reload();
    await page.waitForSelector('#ad-list .item');
    assert.equal(await page.locator('#ad-list .item').count(), count - 1, '토큰을 기억하고, 지운 건 다시 안 나온다');
    assert.deepEqual(errors, []);
    console.log(`${name}: ok`);
    await browser.close();
  }
} finally {
  server.close();
}
