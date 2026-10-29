// Service worker: makes the portal installable and lets visited pages open offline.
const CACHE = 'sarvocch-v2';
const PRECACHE = ['/static/style.css', '/static/app.js', '/static/icons/icon-192.png', '/static/icons/icon-512.png', '/offline'];
const SKIP = ['/api/', '/uploads/', '/logout', '/login', '/pay/'];   // never cache API calls, private files, login pages or payment pages

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(PRECACHE)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim()));
});
// The page asks us to wipe saved pages when someone logs out (so the next person on a shared phone sees nothing).
self.addEventListener('message', e => {
  if (e.data === 'clear') e.waitUntil(caches.keys().then(ks => Promise.all(ks.map(k => caches.delete(k)))));
});
self.addEventListener('fetch', e => {
  const req = e.request, url = new URL(req.url);
  if (req.method !== 'GET') return;
  if (url.origin === self.location.origin && SKIP.some(p => url.pathname.startsWith(p))) return;
  e.respondWith(
    fetch(req).then(res => {
      if (res.ok && (url.origin === self.location.origin || url.hostname === 'cdn.jsdelivr.net')) {
        const copy = res.clone(); caches.open(CACHE).then(c => c.put(req, copy));
      }
      return res;
    }).catch(() => caches.match(req).then(m => m || (req.mode === 'navigate' ? caches.match('/offline') : Response.error())))
  );
});
