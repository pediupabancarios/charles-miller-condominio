const CACHE_NAME = "charles-miller-v24";
const ASSETS = [
  "./",
  "./index.html",
  "./manifest.json",
  "./icon-192.png",
  "./icon-512.png",
  "./icon-512-maskable.png"
];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(ASSETS))
  );
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE_NAME).map((k) => caches.delete(k)))
    )
  );
  self.clients.claim();
});

self.addEventListener("fetch", (event) => {
  const req = event.request;
  if (req.method !== "GET") return;
  // cache.put() só aceita http/https — ignora chrome-extension:, data:, etc.
  if (!req.url.startsWith("http")) return;
  // Só gerencia os arquivos do próprio app. Chamadas ao Supabase (e a qualquer
  // outra origem) passam direto: cacheá-las devolveria dados desatualizados.
  if (new URL(req.url).origin !== self.location.origin) return;

  // O app é um arquivo só: servir index.html do cache significa servir a
  // versão anterior inteira. Para a navegação vale a rede primeiro — o
  // cache fica como rede de segurança para quando não houver conexão.
  const ehONucleoDoApp =
    req.mode === "navigate" ||
    new URL(req.url).pathname.replace(/\/$/, "").endsWith("/index.html") ||
    new URL(req.url).pathname.endsWith("/");

  if (ehONucleoDoApp) {
    event.respondWith(
      fetch(req)
        .then((resposta) => {
          if (resposta && resposta.status === 200) {
            const copia = resposta.clone();
            event.waitUntil(caches.open(CACHE_NAME).then((c) => c.put("./index.html", copia)));
          }
          return resposta;
        })
        .catch(() => caches.match("./index.html"))
    );
    return;
  }

  // Ícones, manifesto e afins continuam saindo do cache: mudam pouco.
  event.respondWith(
    caches.match(req).then((cached) => {
      const network = fetch(req)
        .then((response) => {
          if (response && response.status === 200 && response.type !== "opaque") {
            const clone = response.clone();
            // waitUntil mantém o SW vivo até a gravação terminar
            event.waitUntil(caches.open(CACHE_NAME).then((cache) => cache.put(req, clone)));
          }
          return response;
        })
        .catch(() => {
          if (cached) return cached;
          // offline numa rota sem cache próprio: devolve o app
          if (req.mode === "navigate") return caches.match("./index.html");
          return Response.error();
        });
      return cached || network;
    })
  );
});
