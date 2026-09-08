/* Dicionário — service worker
   Casca e índice ficam pré-carregados; as fatias de verbetes entram no cache
   na primeira consulta ou de uma vez pelo botão "Baixar tudo". */

const VERSAO = 'dicionario-v1';
const CASCA = [
  './',
  './index.html',
  './estilo.css',
  './app.js',
  './manifest.webmanifest',
  './icones/icone.svg',
  './icones/icone-180.png',
  './icones/icone-192.png',
  './icones/icone-512.png',
  './data/meta.json',
  './data/indice.json',
];

self.addEventListener('install', (evento) => {
  evento.waitUntil(
    caches.open(VERSAO).then((cache) => cache.addAll(CASCA)).then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (evento) => {
  evento.waitUntil(
    caches.keys()
      .then((chaves) => Promise.all(chaves.filter((c) => c !== VERSAO).map((c) => caches.delete(c))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (evento) => {
  const requisicao = evento.request;
  if (requisicao.method !== 'GET') return;

  const url = new URL(requisicao.url);
  if (url.origin !== self.location.origin) return;

  // Navegação: casca primeiro, para abrir instantaneamente sem rede.
  if (requisicao.mode === 'navigate') {
    evento.respondWith(
      caches.match('./index.html').then((resposta) => resposta || fetch(requisicao))
    );
    return;
  }

  // Fatias de verbetes e demais estáticos: cache primeiro, rede como reserva.
  evento.respondWith(
    caches.match(requisicao).then((emCache) => {
      if (emCache && requisicao.cache !== 'reload') return emCache;
      return fetch(requisicao)
        .then((resposta) => {
          if (resposta.ok) {
            const copia = resposta.clone();
            caches.open(VERSAO).then((cache) => cache.put(requisicao, copia));
          }
          return resposta;
        })
        .catch(() => emCache || Response.error());
    })
  );
});
