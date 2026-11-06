// W2 harness probe (registry plan): the built Worker in Miniflare (from the global wrangler), local D1 with the
// schema, a fake GitHub as outboundService, and a D1 call count through worker-count.js.
//   node harness.mjs
import { createRequire } from 'node:module';
import { readFileSync, readdirSync, mkdtempSync, rmSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';
const here = dirname(fileURLToPath(import.meta.url));
const mfDir = process.env.MINIFLARE ?? join(dirname(dirname(process.execPath)), 'lib/node_modules/wrangler/node_modules/miniflare');
const { Miniflare, convertV4MiniflareOptions } = createRequire(import.meta.url)(mfDir);
const w = join(here, 'worker');
const t0 = performance.now();
const persist = mkdtempSync(join(tmpdir(), 'reg-probe-'));
const github = [];
const mf = new Miniflare(convertV4MiniflareOptions({
  modules: [
    { type: 'ESModule', path: join(w, 'worker-count.js'), contents: readFileSync(join(w, 'worker-count.js'), 'utf8') },
    ...readdirSync(join(w, '.roc-cfw')).filter((f) => f.endsWith('.js')).map((f) => ({ type: 'ESModule', path: join(w, '.roc-cfw', f), contents: readFileSync(join(w, '.roc-cfw', f), 'utf8') })),
    { type: 'CompiledWasm', path: join(w, 'app.wasm'), contents: readFileSync(join(w, 'app.wasm')) },
  ],
  modulesRoot: w,
  compatibilityDate: '2026-10-01',
  compatibilityFlags: ['enable_request_signal', 'global_fetch_strictly_public'],
  d1Databases: ['DB'],
  d1Persist: persist,
  outboundService: (req) => { github.push(req.url); return new Response('{"id":1}', { status: 299 }); },
}));
const db = await mf.getD1Database('DB');
for (const s of readFileSync(join(here, 'schema.sql'), 'utf8').split(';\n').filter((x) => x.trim())) await db.prepare(s).run();
const t1 = performance.now();
const get = async (p) => { const r = await mf.dispatchFetch('http://x' + p); return `${r.status} ${await r.text()}`; };
const out = [await get('/d1'), await get('/__d1count'), await get('/gh'), JSON.stringify(github)];
const t2 = performance.now();
await mf.dispose(); rmSync(persist, { recursive: true, force: true });
console.log(out.join('\n'));
console.log(`start+schema ${(t1 - t0).toFixed(0)} ms, 3 requests ${(t2 - t1).toFixed(0)} ms`);
