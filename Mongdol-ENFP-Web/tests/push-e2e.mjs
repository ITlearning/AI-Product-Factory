// 브라우저 확인 — 정적 서버(python3 -m http.server 8773 --bind 127.0.0.1)를 띄우고 TZ=Asia/Seoul node tests/push-e2e.mjs. /api 는 page.route 로 가로챈다.
import { chromium } from '/Users/tabber/.claude/skills/gstack/node_modules/playwright/index.mjs';

const BASE = 'http://127.0.0.1:8773/';
const SHOTS = new URL('../screenshots/', import.meta.url).pathname;
const errors = [];
const log = (...a) => console.log(...a);

const browser = await chromium.launch({ channel: 'chromium' });
async function ctx({ grant = true, standalone = false, ios = false, onboarded = true } = {}) {
  const c = await browser.newContext({
    viewport: { width: 390, height: 844 }, deviceScaleFactor: 2,
    userAgent: ios ? 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.5 Mobile/15E148 Safari/604.1' : undefined,
    serviceWorkers: 'allow',
  });
  if (grant) await c.grantPermissions(['notifications'], { origin: BASE.slice(0, -1) });
  await c.addInitScript(({ standalone, ios, onboarded }) => {
    if (onboarded) localStorage.setItem('mongdol.onboarded', 'true');
    if (standalone) Object.defineProperty(Navigator.prototype, 'standalone', { get: () => true });
    if (ios) { delete window.PushManager; }
    // 헤드리스 chromium 엔 푸시 서비스가 없어 subscribe 가 늘 실패한다 — 구독만 흉내 낸다(권한·SW·본문은 진짜).
    if (window.PushManager) {
      let cur = null;
      const make = (opts) => ({
        endpoint: 'https://fcm.googleapis.com/fcm/send/e2e-' + Math.random().toString(36).slice(2, 8),
        options: opts,
        toJSON() { return { endpoint: this.endpoint, expirationTime: null, keys: { p256dh: 'BPp256dhE2EKeyAAAAAAAA', auth: 'authE2EKeyAA' } }; },
        async unsubscribe() { cur = null; return true; },
      });
      PushManager.prototype.subscribe = async function (opts) {
        if (Notification.permission !== 'granted') throw new DOMException('permission denied', 'NotAllowedError');
        window.__subOpts = { userVisibleOnly: opts.userVisibleOnly, keyLen: opts.applicationServerKey.byteLength, first: opts.applicationServerKey[0] };
        cur = cur || make(opts); return cur;
      };
      PushManager.prototype.getSubscription = async function () { return cur; };
    }
  }, { standalone, ios, onboarded });
  const bodies = [];
  await c.route('**/api/push-schedule', async (route) => {
    const req = route.request();
    bodies.push({ method: req.method(), body: JSON.parse(req.postData() || 'null') });
    await route.fulfill({ status: 200, contentType: 'application/json', body: '{"ok":true}' });
  });
  const page = await c.newPage();
  page.on('console', (m) => { if (m.type() === 'error') errors.push(`${m.text()}`); });
  page.on('pageerror', (e) => errors.push(`pageerror ${e.message}`));
  return { c, page, bodies };
}
const waitBodies = async (bodies, n, ms = 15000) => {
  const t = Date.now();
  while (bodies.length < n && Date.now() - t < ms) await new Promise((r) => setTimeout(r, 100));
  return bodies.length >= n;
};
const expected = (page, frequency) => page.evaluate(async (frequency) => {
  const { schedule } = await import('./js/notice.js');
  const { store } = await import('./js/store.js');
  const { now } = await import('./js/clock.js');
  return schedule({
    hasSealedMoments: (k) => store.hasSealedMoments(k), closedAt: (k) => store.closedAt(k),
    isGifted: (k) => store.isGifted(k), todayCount: store.today.length,
  }, { nowMs: now(), frequency });
}, frequency);
const summary = (items) => items.map((i) => `${i.kind}:${i.key}@${new Date(i.at).toLocaleString('ko-KR', { timeZone: 'Asia/Seoul', month: 'numeric', day: 'numeric', hour: '2-digit', minute: '2-digit', hour12: false })}`);

// 1) 데스크톱 chromium — 권한 허락 → 설정에서 켜기 → 빈도 바꾸기 → 견본(오늘 사진) → 끄기
{
  const { c, page, bodies } = await ctx();
  await page.goto(BASE + '?debug');
  await page.waitForFunction(() => document.documentElement.classList.contains('booted'));
  await page.waitForTimeout(1500);
  log('부팅 직후(권한 허락돼 있음 → 자동 구독·동기화) 보낸 수:', bodies.length);
  await page.click('#settings-btn');
  await page.waitForSelector('.set-sheet');
  await page.waitForTimeout(800);
  log('알림 줄:', await page.textContent('.notice-slot'));
  log('subscribe 옵션:', JSON.stringify(await page.evaluate(() => window.__subOpts)));
  await page.screenshot({ path: SHOTS + '40-push-settings.jpg', quality: 80 });
  const first = bodies.at(-1);
  log('첫 POST:', first?.method, 'endpoint', first?.body?.subscription?.endpoint?.slice(0, 40), 'keys', Object.keys(first?.body?.subscription?.keys || {}), 'tz', first?.body?.tz);
  const exp = await expected(page, 'sometimes');
  log('가끔 기대 == 보낸 것:', JSON.stringify(exp) === JSON.stringify(first.body.items), summary(first.body.items));
  log('본문 최상위 키:', Object.keys(first.body), '항목 키:', Object.keys(first.body.items[0] || {}));

  let n = bodies.length;
  await page.click('.freq-chip[data-f="often"]');
  await waitBodies(bodies, n + 1);
  const often = bodies.at(-1);
  log('자주 기대 == 보낸 것:', JSON.stringify(await expected(page, 'often')) === JSON.stringify(often.body.items), '개수', often.body.items.length);

  n = bodies.length;
  await page.click('.freq-chip[data-f="off"]');
  await waitBodies(bodies, n + 1);
  log('받지 않기 → ', bodies.at(-1).method, '항목', bodies.at(-1).body.items.length);
  await page.screenshot({ path: SHOTS + '41-push-settings-off.jpg', quality: 80 });

  n = bodies.length;
  await page.click('.freq-chip[data-f="often"]');
  await waitBodies(bodies, n + 1);
  // 같은 내용이면 다시 안 보낸다
  n = bodies.length;
  await page.evaluate(async () => (await import('./js/push.js')).requestSync({ immediate: true }));
  await page.waitForTimeout(800);
  log('같은 내용 재동기화 → 추가로 보낸 수:', bodies.length - n);

  // 견본 하루 — 오늘 사진이 생긴다 → 오늘 남은 알림 빠지고 오늘 도착 소식이 생긴다
  n = bodies.length;
  await page.click('.row-btn:has-text("견본 하루 채우기")');
  await page.waitForFunction(() => window.__mongdol?.store?.today?.length > 0, null, { timeout: 60000 });
  await waitBodies(bodies, n + 1, 30000);
  await page.waitForTimeout(3500);
  const after = bodies.at(-1);
  const today = await page.evaluate(() => window.__mongdol.store.todayKey);
  log('견본 뒤 기대 == 보낸 것:', JSON.stringify(await expected(page, 'often')) === JSON.stringify(after.body.items));
  log('  오늘', today, '오늘 아침/노을 남음?', after.body.items.some((i) => i.key === today && i.kind !== 'arrival'), '오늘 도착 소식:', summary(after.body.items.filter((i) => i.kind === 'arrival')));
  await page.keyboard.press('Escape');
  await page.waitForTimeout(300);

  // 끄기 → DELETE
  await page.evaluate(() => document.querySelectorAll('.sheet-wrap').forEach((w) => w.click()));
  await page.waitForTimeout(500);
  const blocking = await page.evaluate(() => document.querySelectorAll('.ceremony, .sheet-wrap').length);
  log('남은 겹 수(증정 등):', blocking);
  n = bodies.length;
  await page.evaluate(async () => (await import('./js/push.js')).disableNotices());
  await waitBodies(bodies, n + 1);
  log('끄기 →', bodies.at(-1).method, JSON.stringify(bodies.at(-1).body).slice(0, 60));
  await c.close();
}

// 2) iPhone Safari(홈 화면 앱 아님) — 설정이 홈 화면 안내로 잇는다
{
  const { c, page, bodies } = await ctx({ grant: false, ios: true });
  await page.goto(BASE);
  await page.waitForFunction(() => document.documentElement.classList.contains('booted'));
  await page.click('#settings-btn');
  await page.waitForSelector('.set-sheet');
  await page.waitForTimeout(600);
  log('iOS Safari 알림 줄:', await page.textContent('.notice-slot'));
  await page.screenshot({ path: SHOTS + '42-push-settings-ios-safari.jpg', quality: 80 });
  await page.click('.notice-slot .row-btn');
  await page.waitForSelector('.inst-sheet');
  await page.waitForTimeout(500);
  log('→ 홈 화면 안내 시트 열림:', await page.textContent('.inst-sheet .mini-title'), '보낸 수', bodies.length);
  await c.close();
}

// 3) 홈 화면 앱으로 처음 열기 — 권한 미정: 소개 → 도착 소식 → 사진 없는 날 → 찍는 법 → 시작
{
  const { c, page, bodies } = await ctx({ grant: false, standalone: true, onboarded: false });
  await page.goto(BASE);
  await page.waitForSelector('.onboarding');
  const dots = await page.$$eval('.ob-dots span', (s) => s.length);
  log('standalone 온보딩 장 수:', dots);
  await page.click('.ob-foot .btn.primary');
  await page.waitForTimeout(1200);
  log('2장:', await page.textContent('.ob-title'), '/ 버튼', await page.textContent('.ob-foot .btn.primary'), '·', await page.textContent('.ob-foot .btn.ghost'));
  await page.screenshot({ path: SHOTS + '43-onboarding-arrival.jpg', quality: 80 });
  await page.click('.ob-foot .btn.ghost');
  await page.waitForTimeout(1200);
  log('3장:', await page.textContent('.ob-title'));
  await page.screenshot({ path: SHOTS + '44-onboarding-reminder.jpg', quality: 80 });
  await page.click('.freq-chip[data-f="often"]');
  log('빈도 저장:', await page.evaluate(() => localStorage.getItem('mongdol.reminderFrequency')));
  await page.click('.ob-foot .btn.primary');
  await page.waitForTimeout(800);
  log('4장:', (await page.textContent('.ob-title')).slice(0, 30), '보낸 수', bodies.length);
  await c.close();
}

// 4) 홈 화면 앱 · 권한 이미 허락 — 도착 소식 장은 빠지고 「사진이 없는 날엔」 장만
{
  const { c, page } = await ctx({ grant: true, standalone: true, onboarded: false });
  await page.goto(BASE);
  await page.waitForSelector('.onboarding');
  log('허락된 standalone 장 수:', await page.$$eval('.ob-dots span', (s) => s.length));
  await page.click('.ob-foot .btn.primary');
  await page.waitForTimeout(1000);
  log('2장:', await page.textContent('.ob-title'));
  await c.close();
}

// 5) 일반 데스크톱 브라우저(standalone 아님) — 알림 장 없음
{
  const { c, page } = await ctx({ grant: false, onboarded: false });
  await page.goto(BASE);
  await page.waitForSelector('.onboarding');
  log('일반 브라우저 온보딩 장 수:', await page.$$eval('.ob-dots span', (s) => s.length));
  await c.close();
}

log('콘솔 에러:', errors.length, errors);
await browser.close();
