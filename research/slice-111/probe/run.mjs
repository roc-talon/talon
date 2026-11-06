// Probe of slice 111: how the Worker sees Content-Length and a stream body of the fake GitHub (Miniflare outboundService).
// node research/slice-111/probe/run.mjs <bundle.tar.zst>
import { createRequire } from 'node:module';
import { readFileSync, readdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
const here = dirname(new URL(import.meta.url).pathname);
const js = process.env.SHIM;
const mfDir = join(dirname(dirname(process.execPath)), 'lib/node_modules/wrangler/node_modules/miniflare');
const { Miniflare, convertV4MiniflareOptions } = createRequire(import.meta.url)(mfDir);
const bundle = readFileSync(process.argv[2]);
const entry = `import app from './app.wasm'; import { makeHandler } from './js/index.js'; export default makeHandler(app);`;
const modules = [
  { type: 'ESModule', path: join(here, 'entry.js'), contents: entry },
  ...readdirSync(js).filter((f) => f.endsWith('.js')).map((f) => ({ type: 'ESModule', path: join(here, 'js', f), contents: readFileSync(join(js, f), 'utf8') })),
  { type: 'CompiledWasm', path: join(here, 'app.wasm'), contents: readFileSync(join(here, 'app.wasm')) },
];
const stream = (buf, n) => new ReadableStream({ start(c) { for (let i = 0; i < buf.length; i += n) c.enqueue(buf.subarray(i, i + n)); c.close(); } });

// A zstd frame of raw blocks (window 128 KiB, no content size) with a tar of one member of `size` bytes, made while the reader pulls.
function rawZstdTar(size) {
  const hdr = new Uint8Array(512);
  const put = (o, t) => { for (let i = 0; i < t.length; i++) hdr[o + i] = t.charCodeAt(i); };
  put(0, 'big.bin'); put(100, '0000644\0'); put(108, '0000000\0'); put(116, '0000000\0'); put(124, size.toString(8).padStart(11, '0') + '\0'); put(136, '00000000000\0');
  put(156, '0'); put(257, 'ustar\0'); put(263, '00');
  for (let i = 148; i < 156; i++) hdr[i] = 32;
  let sum = 0; for (const b of hdr) sum += b; put(148, sum.toString(8).padStart(6, '0') + '\0 ');
  let left = 512 + size; let first = true; const B = 131072;
  return new ReadableStream({ pull(c) {
    if (first) { c.enqueue(new Uint8Array([0x28, 0xb5, 0x2f, 0xfd, 0x00, 0x38])); first = false; }
    if (left <= 0) { c.close(); return; }
    const n = Math.min(B, left); left -= n; const last = left <= 0 ? 1 : 0;
    const blk = new Uint8Array(3 + n); const h = (n << 3) | last; blk[0] = h & 255; blk[1] = (h >> 8) & 255; blk[2] = (h >> 16) & 255;
    if (n === B && first === false && blk.length && left + n === size) {} // the first block holds the header
    if (left + n === 512 + size) blk.set(hdr, 3);
    c.enqueue(blk);
  } });
}
const modes = {
  rawbig: () => new Response(rawZstdTar(110_000_000)),
  plain: () => new Response(bundle),
  clEq: () => new Response(bundle, { headers: { 'content-length': String(bundle.length) } }),
  clHugeReal: () => { const n = 100_000_001; let sent = 0; return new Response(new ReadableStream({ pull(c) { if (sent >= n) { c.close(); return; } const k = Math.min(1 << 20, n - sent); c.enqueue(new Uint8Array(k)); sent += k; } }), { headers: { 'content-length': String(n) } }); },
  stream: () => new Response(stream(bundle, 1000)),
  clBig: () => new Response(stream(bundle, 1000), { headers: { 'content-length': String(bundle.length + 50) } }),
  clSmall: () => new Response(stream(bundle, 1000), { headers: { 'content-length': '100' } }),
  clHuge: () => new Response(stream(bundle, 1000), { headers: { 'content-length': '100000001' } }),
  big: () => { const n = 110_000_000; let sent = 0; return new Response(new ReadableStream({ pull(c) { if (sent >= n) { c.close(); return; } const k = Math.min(1 << 20, n - sent); c.enqueue(new Uint8Array(k)); sent += k; } })); },
};
const mf = new Miniflare(convertV4MiniflareOptions({ modules, modulesRoot: here, compatibilityDate: '2026-10-01', compatibilityFlags: ['enable_request_signal', 'global_fetch_strictly_public'],
  outboundService: async (req) => modes[new URL(req.url).pathname.slice(1)](), handleStructuredLogs: (l) => console.log('log', l.message) }));
for (const m of (process.env.MODES ?? Object.keys(modes).join(",")).split(",")) {
  const t = performance.now();
  const r = await mf.dispatchFetch(`http://localhost/?url=${encodeURIComponent(`https://github.com/${m}`)}`);
  console.log(m, r.status, (await r.text()).slice(0, 300), `${(performance.now() - t).toFixed(0)} ms`);
}
await mf.dispose();
