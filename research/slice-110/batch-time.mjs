// Slice 110 probe: the time of the closure batch (12 statements, one D1 call) on local D1 (Miniflare), with the request shape of the W2 case
// closure/ap41-sixty-groups: 60 groups (a series and a range each) and 60 hashes, on the empty schema of sql/0001_init.sql.
// Run: node research/slice-110/batch-time.mjs [runs]. It prints the median and the max in ms.
import { readFileSync, mkdtempSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, join } from 'node:path';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, '..', '..');
const { closureSql, STATEMENTS } = await import(join(root, 'sql', 'tests', 'closure.mjs'));
const mfDir = process.env.MINIFLARE ?? join(dirname(dirname(process.execPath)), 'lib/node_modules/wrangler/node_modules/miniflare');
const { Miniflare, convertV4MiniflareOptions } = createRequire(import.meta.url)(mfDir);
const mf = new Miniflare(convertV4MiniflareOptions({
  modules: [{ type: 'ESModule', path: join(here, 'p.js'), contents: 'export default { fetch() { return new Response("p"); } }' }],
  modulesRoot: here, compatibilityDate: '2026-10-01', d1Databases: { DB: '00000000-0000-4000-8000-000000000110' }, d1Persist: mkdtempSync(join(tmpdir(), 'cl110-')),
}));
const db = await mf.getD1Database('DB');
const init = readFileSync(join(root, 'sql', '0001_init.sql'), 'utf8').replace(/--.*$/gm, '');
for (const s of init.split(';').map((x) => x.trim()).filter(Boolean)) await db.prepare(s).run();
// Series 1 and ^1.2.3: lo = the key of 1.2.3, hi = the end of series 1 (stored values, XOR 2^63). Random 64-bit ids (the values do not change the plan on an empty DB).
const big = (k) => (4611686018427387904n + BigInt(k) * 7919n).toString();
const groups = `[${Array.from({ length: 60 }, (_, i) => `{"form":${big(i)},"lo":-9223090553288130560,"hi":-9222809086901354497}`).join(',')}]`;
const hashes = `[${Array.from({ length: 60 }, (_, i) => big(1000 + i)).join(',')}]`;
const sql = closureSql();
const runs = Number(process.argv[2] ?? 30);
const times = [];
for (let i = 0; i < runs; i++) {
  const t0 = performance.now();
  await db.batch(STATEMENTS.map((s) => db.prepare(sql[s]).bind(groups, hashes, null, null)));
  times.push(performance.now() - t0);
}
times.sort((a, b) => a - b);
console.log(`closure batch, 60 groups and 60 hashes, local D1, ${runs} runs: median ${times[runs >> 1].toFixed(1)} ms, max ${times[runs - 1].toFixed(1)} ms`);
// The base: 12 statements `SELECT 1` in one batch (the cost of the call itself).
const base = [];
for (let i = 0; i < runs; i++) { const t0 = performance.now(); await db.batch(STATEMENTS.map(() => db.prepare("SELECT 1"))); base.push(performance.now() - t0); }
base.sort((a, b) => a - b);
console.log(`base batch of 12 SELECT 1: median ${base[runs >> 1].toFixed(1)} ms`);
await mf.dispose();
