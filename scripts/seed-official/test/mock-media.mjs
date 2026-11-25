#!/usr/bin/env node
// Local stand-in for Cloudflare R2 (S3 API subset), Sightengine and the clips CDN, for testing
// the seed scripts against a local Supabase stack. Never used against production.
//
//   MOCK_PORT=59490 MOCK_DIR=/tmp/r2 node mock-media.mjs
//
//   /r2/<account>.r2.cloudflarestorage.com/<bucket>/<key>   PUT (If-None-Match: *) / GET / DELETE / ?list-type=2
//   /sightengine/1.0/(video/check-sync|check).json          always "clear", records each screened upload
//   /clips/<key>  /media/<key>                              what clips/media.handstrudel.com would serve
//   /_stats                                                  counts, for the e2e checks
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';

const port = Number(process.env.MOCK_PORT || 59490);
const root = process.env.MOCK_DIR || path.join(process.cwd(), 'mock-r2');
fs.mkdirSync(root, { recursive: true });
const stats = { puts: 0, putRejected: 0, gets: 0, deletes: 0, screenedVideos: 0, screenedImages: 0 };

const objectPath = (bucket, key) => path.join(root, bucket, ...key.split('/').map(decodeURIComponent));
function listKeys(dir, prefix) {
  const out = [];
  const walk = (d, rel) => {
    if (!fs.existsSync(d)) return;
    for (const e of fs.readdirSync(d, { withFileTypes: true })) {
      const r = rel ? `${rel}/${e.name}` : e.name;
      if (e.isDirectory()) walk(path.join(d, e.name), r);
      else if (!e.name.endsWith('.type') && r.startsWith(prefix)) out.push(r);
    }
  };
  walk(dir, '');
  return out;
}
const body = (req) => new Promise((ok) => { const c = []; req.on('data', (d) => c.push(d)); req.on('end', () => ok(Buffer.concat(c))); });

function serveObject(res, file) {
  if (!fs.existsSync(file)) { res.writeHead(404).end(); return; }
  const bytes = fs.readFileSync(file);
  const type = fs.existsSync(`${file}.type`) ? fs.readFileSync(`${file}.type`, 'utf8') : 'application/octet-stream';
  stats.gets++;
  res.writeHead(200, { 'Content-Type': type, 'Content-Length': bytes.length }).end(bytes);
}

http.createServer(async (req, res) => {
  const url = new URL(req.url, 'http://mock');
  const parts = url.pathname.split('/').filter(Boolean);
  try {
    if (parts[0] === '_stats') { res.writeHead(200, { 'Content-Type': 'application/json' }).end(JSON.stringify(stats)); return; }
    if (parts[0] === 'sightengine') {
      const raw = await body(req);
      const video = url.pathname.includes('video/');
      if (raw.length < 100) { res.writeHead(400).end('{"status":"failure"}'); return; }
      video ? stats.screenedVideos++ : stats.screenedImages++;
      const nudity = { sexual_activity: 0.001, sexual_display: 0.001 };
      res.writeHead(200, { 'Content-Type': 'application/json' })
        .end(JSON.stringify(video ? { status: 'success', data: { frames: [{ nudity }, { nudity }] } } : { status: 'success', nudity }));
      return;
    }
    if (parts[0] === 'clips' || parts[0] === 'media') {
      // Screened keys live in the private bucket; legacy keys in the public one.
      const key = parts.slice(1).join('/');
      const bucket = parts[0] === 'clips' ? 'handstrudel-private' : 'handstrudel-media';
      serveObject(res, objectPath(bucket, key));
      return;
    }
    if (parts[0] === 'r2') {
      const bucket = parts[2];
      const key = parts.slice(3).join('/');
      if (req.method === 'GET' && url.searchParams.get('list-type') === '2') {
        const keys = listKeys(path.join(root, bucket), url.searchParams.get('prefix') || '');
        res.writeHead(200, { 'Content-Type': 'application/xml' })
          .end(`<ListBucketResult>${keys.map((k) => `<Contents><Key>${k}</Key></Contents>`).join('')}</ListBucketResult>`);
        return;
      }
      const file = objectPath(bucket, key);
      if (req.method === 'PUT') {
        if (req.headers['if-none-match'] === '*' && fs.existsSync(file)) { stats.putRejected++; res.writeHead(412).end(); await body(req); return; }
        const bytes = await body(req);
        if (Number(req.headers['content-length']) !== bytes.length) { res.writeHead(400).end('length mismatch'); return; }
        fs.mkdirSync(path.dirname(file), { recursive: true });
        fs.writeFileSync(file, bytes);
        fs.writeFileSync(`${file}.type`, req.headers['content-type'] || 'application/octet-stream');
        stats.puts++;
        res.writeHead(200).end();
        return;
      }
      if (req.method === 'GET' || req.method === 'HEAD') { serveObject(res, file); return; }
      if (req.method === 'DELETE') {
        fs.rmSync(file, { force: true }); fs.rmSync(`${file}.type`, { force: true });
        stats.deletes++;
        res.writeHead(204).end();
        return;
      }
    }
    res.writeHead(404).end('mock: no route');
  } catch (e) {
    res.writeHead(500).end(String(e));
  }
}).listen(port, '0.0.0.0', () => console.log(`mock media on :${port}, storing in ${root}`));
