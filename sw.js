/* LIVIA.us — Service Worker
   Cache offline: depois da primeira abertura com internet, o app abre sem conexao.
   O banco de dados fica no proprio dispositivo (localStorage), nao depende do SW. */
const CACHE = 'livia-us-v1';

const CORE = [
  './',
  './index.html',
  './manifest.webmanifest',
  './icons/icon-192.png',
  './icons/icon-512.png',
  './icons/maskable-512.png',
  'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/leaflet.css',
  'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/leaflet.js',
  'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2'
];

self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE).then(cache =>
      // tenta cachear cada item; se algum falhar (ex.: CDN), nao quebra a instalacao
      Promise.allSettled(CORE.map(url => cache.add(url)))
    ).then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))
    ).then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', event => {
  const req = event.request;
  if (req.method !== 'GET') return;

  event.respondWith(
    caches.match(req).then(hit => {
      if (hit) return hit;
      return fetch(req).then(res => {
        // guarda em cache de runtime (inclui tiles do mapa)
        const copy = res.clone();
        caches.open(CACHE).then(cache => {
          try { cache.put(req, copy); } catch (_) {}
        });
        return res;
      }).catch(() => {
        // fallback de navegacao quando offline
        if (req.mode === 'navigate') return caches.match('./index.html');
      });
    })
  );
});
