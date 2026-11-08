'use strict';
// KepToh POS service worker: keeps the app's own files so it still opens
// when the shop's internet is down. Network first, cache as fallback, so an
// online device always gets the latest deploy. Only same-origin GETs are
// handled; Supabase and other services are never cached here.
const BUILD = 'dev'; // __BUILD_LINE__
let ASSETS = []; // __ASSETS_LINE__
const CACHE = 'keptoh-app-' + BUILD;

self.addEventListener('install', (event) => {
  self.skipWaiting();
  event.waitUntil(
    caches.open(CACHE).then((cache) =>
      Promise.all(
        ['./', ...ASSETS].map((url) =>
          cache.add(new Request(url, { cache: 'reload' })).catch(() => {}),
        ),
      ),
    ),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      for (const key of await caches.keys()) {
        if (key.startsWith('keptoh-app-') && key !== CACHE) {
          await caches.delete(key);
        }
      }
      await self.clients.claim();
    })(),
  );
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.origin !== self.location.origin) return;
  const isPage = req.mode === 'navigate';
  event.respondWith(
    (async () => {
      const cache = await caches.open(CACHE);
      try {
        const res = await fetch(req);
        if (res.ok) await cache.put(isPage ? './' : req, res.clone());
        return res;
      } catch (err) {
        const hit = isPage
          ? await cache.match('./')
          : await cache.match(req, { ignoreSearch: true });
        if (hit) return hit;
        throw err;
      }
    })(),
  );
});
