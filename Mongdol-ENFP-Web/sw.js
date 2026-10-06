// 서비스 워커 — 같은 출처 요청은 네트워크 먼저, 안 되면 마지막으로 받아 둔 것(오프라인 대비).
// 캐시를 먼저 쓰지 않는다: 새로 배포하면 다음에 열 때 바로 새 판이 뜬다. 바깥(Google Fonts 등)은 건드리지 않는다.
const CACHE = 'mongdol-v2';

self.addEventListener('install', () => self.skipWaiting());

self.addEventListener('activate', (e) => {
  e.waitUntil((async () => {
    for (const name of await caches.keys()) if (name !== CACHE) await caches.delete(name);
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (e) => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.origin !== self.location.origin || url.pathname.startsWith('/api/')) return;
  // 페이지는 ?now= · ?debug 같은 쿼리를 떼고 한 칸에 담는다 — 오프라인에서 어떤 쿼리로 열어도 뜨게.
  const key = req.mode === 'navigate' ? url.origin + url.pathname : req;
  e.respondWith((async () => {
    try {
      const res = await fetch(req);
      if (res.ok && res.type === 'basic') {
        const copy = res.clone();
        e.waitUntil(caches.open(CACHE).then((c) => c.put(key, copy)).catch(() => {}));
      }
      return res;
    } catch (err) {
      const hit = await caches.match(key) || (req.mode === 'navigate' && await caches.match(new URL('./', self.location).href));
      if (hit) return hit;
      throw err;
    }
  })());
});

// 웹 푸시 — 서버가 보내는 Declarative Web Push({web_push:8030, notification:{…}})를 받아 띄운다.
// iOS 는 push 를 받고 알림을 안 띄우면 구독을 끊는다 — 무슨 일이 있어도 하나는 띄운다.
const NOTICE_TITLE = '몽돌';
const NOTICE_BODY = '어제의 조약돌이 도착했어요.';

function noticeFrom(text) {
  let n = null;
  try { n = JSON.parse(text || 'null'); } catch { /* 기본 문구로 */ }
  const src = (n && typeof n.notification === 'object' && n.notification) || n || {};
  const str = (v) => (typeof v === 'string' && v ? v : null);
  return {
    title: str(src.title) || NOTICE_TITLE,
    body: str(src.body) || NOTICE_BODY,
    tag: str(src.tag) || str(n && n.tag) || undefined,
    url: str(src.navigate) || './',
  };
}

self.addEventListener('push', (e) => {
  let text = null;
  try { text = e.data ? e.data.text() : null; } catch { /* 빈 것으로 */ }
  const n = noticeFrom(text);
  e.waitUntil(self.registration.showNotification(n.title, {
    body: n.body, tag: n.tag, data: { url: n.url }, icon: './icons/icon-192.png', lang: 'ko',
  }));
});

self.addEventListener('notificationclick', (e) => {
  e.notification.close();
  e.waitUntil((async () => {
    const wins = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    const mine = wins.find((c) => new URL(c.url).origin === self.location.origin);
    if (mine) return mine.focus();
    return self.clients.openWindow('./');
  })());
});
