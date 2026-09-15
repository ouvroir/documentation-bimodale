// Serveur de développement avec live reload
// Compatible Node.js, Deno et Bun — modules natifs uniquement
//
//   node serve.mjs
//   deno run --allow-net --allow-read --allow-run serve.mjs
//   bun serve.mjs

import { createServer }                        from 'node:http';
import { readFileSync, statSync, watch, existsSync } from 'node:fs';
import { extname, join }                        from 'node:path';
import { execFile }                             from 'node:child_process';

const PORT    = Number(process.env.PORT ?? 8000);
const PUBLIC  = 'public';

// SRC_DIR : variable d'environnement (injectée par `make serve`) sinon lu
// directement dans bimodale.config.mk (cas d'un lancement direct sans make)
function readSrcDirFromConfig() {
  try {
    const match = readFileSync('bimodale.config.mk', 'utf8').match(/^SRC_DIR=(.+)$/m);
    return match ? match[1].trim() : null;
  } catch {
    return null;
  }
}
const SRC_DIR = process.env.SRC_DIR ?? readSrcDirFromConfig() ?? '.';

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.css':  'text/css',
  '.js':   'application/javascript',
  '.json': 'application/json',
  '.svg':  'image/svg+xml',
  '.png':  'image/png',
  '.jpg':  'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.webp': 'image/webp',
  '.gif':  'image/gif',
  '.woff': 'font/woff',
  '.woff2':'font/woff2',
  '.ico':  'image/x-icon',
};

/////////////

/** @type {Set} connexions SSE en attente de rechargement */
const clients = new Set();

/**
 * Notifie tous les clients SSE connectés de recharger la page
 */
function notify() {
  for (const res of clients) res.write('data: reload\n\n');
}

/**
 * Sert un fichier statique depuis public/
 * @param {import('node:http').ServerResponse} res
 * @param {string} pathname - chemin de l’URL (sans query string)
 */
function serveFile(res, pathname) {
  let file = join(PUBLIC, pathname);
  try {
    if (statSync(file).isDirectory()) file = join(file, 'index.html');
  } catch {
    res.writeHead(404); res.end('Not found'); return;
  }
  try {
    res.writeHead(200, { 'Content-Type': MIME[extname(file)] ?? 'application/octet-stream' });
    res.end(readFileSync(file));
  } catch {
    res.writeHead(404); res.end('Not found');
  }
}

/**
 * Ouvre une connexion SSE et l’enregistre jusqu’à fermeture du client
 * @param {import('node:http').IncomingMessage} req
 * @param {import('node:http').ServerResponse} res
 */
function serveSSE(req, res) {
  res.writeHead(200, {
    'Content-Type': 'text/event-stream',
    'Cache-Control': 'no-cache',
    'Connection':    'keep-alive',
  });
  res.write(': ok\n\n');
  clients.add(res);
  req.on('close', () => clients.delete(res));
}

createServer((req, res) => {
  const pathname = new URL(req.url, 'http://x').pathname;
  if (pathname === '/reload-events') serveSSE(req, res);
  else serveFile(res, pathname);
}).on('error', err => {
  if (err.code === 'EADDRINUSE') {
    console.error(`Port ${PORT} déjà utilisé. Essayez : PORT=${PORT + 1} make serve`);
    process.exit(1);
  }
  throw err;
}).listen(PORT, () => {
  console.log(`http://localhost:${PORT}  (Ctrl+C pour arrêter)`);
});

/////////////

// verrou anti-concurrence pour les builds successifs
let building = false, queued = false, timer = null;

function scheduleBuild() {
  clearTimeout(timer);
  timer = setTimeout(build, 200);
}

/**
 * Lance make html et notifie les clients après un build réussi
 */
function build() {
  if (building) { queued = true; return; }
  building = true;
  process.stdout.write(`[${new Date().toTimeString().slice(0, 8)}] → make html... `);
  execFile('make', ['html'], (err, stdout, stderr) => {
    building = false;
    if (err) console.error('\nerreur :', stderr.trim());
    else { console.log(stdout.trim() || 'ok'); notify(); }
    if (queued) { queued = false; build(); }
  });
}

/////////////

const IGNORE = new Set(['README.md', 'index.md']);

// fichiers .md dans SRC_DIR
watch(SRC_DIR, (_, f) => {
  if (!f) return;
  if (f === 'index.md') {
    process.stdout.write(`[${new Date().toTimeString().slice(0, 8)}] → make index... `);
    execFile('make', ['index'], (err, stdout, stderr) => {
      if (err) console.error('\nerreur :', stderr.trim());
      else { console.log(stdout.trim() || 'ok'); notify(); }
    });
  } else if (extname(f) === '.md' && !IGNORE.has(f)) {
    scheduleBuild();
  }
});

// template/ et filters/
for (const dir of ['template', 'filters']) {
  if (existsSync(dir))
    watch(dir, (_, f) => {
      if (f && ['.html', '.lua'].includes(extname(f))) scheduleBuild();
    });
}

// images/ — fs.watch récursif supporté sur macOS via FSEvents
const imagesDir = join(SRC_DIR, 'images');
if (existsSync(imagesDir))
  watch(imagesDir, { recursive: true }, scheduleBuild);
