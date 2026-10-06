// 서비스 워커 — 같은 출처 요청은 네트워크 먼저, 안 되면 마지막으로 받아 둔 것(오프라인 대비).
// 캐시를 먼저 쓰지 않는다: 새로 배포하면 다음에 열 때 바로 새 판이 뜬다. 바깥(Google Fonts 등)은 건드리지 않는다.
const CACHE = 'mongdol-v1';

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
  if (url.origin !== self.location.origin) return;
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
