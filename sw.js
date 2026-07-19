const CACHE = 'skill-issue-v4';
const ASSETS = ['./','./index.html','./config.js','./anime.min.js','./manifest.webmanifest','./icon-192.png','./icon-512.png'];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(ASSETS)));
  self.skipWaiting();
});
self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(keys =>
    Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))
  ).then(() => self.clients.claim()));
});
self.addEventListener('fetch', e => {
  if (e.request.method !== 'GET') return;
  const url = new URL(e.request.url);
  // never cache Supabase API calls
  if (url.pathname.includes('/rest/') || url.pathname.includes('/auth/') ||
      url.pathname.includes('/realtime/') || url.pathname.includes('/storage/')) return;
  e.respondWith(
    caches.match(e.request).then(hit =>
      hit || fetch(e.request).then(res => {
        if (res.ok && (url.origin === location.origin || url.hostname === 'cdn.jsdelivr.net' || url.hostname.includes('fonts.g'))) {
          const copy = res.clone();
          caches.open(CACHE).then(c => c.put(e.request, copy));
        }
        return res;
      }).catch(() => caches.match('./index.html'))
    )
  );
});
self.addEventListener('notificationclick', e => {
  e.notification.close();
  const action = e.action;
  e.waitUntil(self.clients.matchAll({type:'window',includeUncontrolled:true}).then(list => {
    if (action && list.length) {
      list[0].postMessage({type:'pairAction', action});
      if (list[0].focus) return list[0].focus();
      return;
    }
    for (const c of list) if ('focus' in c) return c.focus();
    return self.clients.openWindow(action ? ('./?pairAction='+action) : './');
  }));
});
