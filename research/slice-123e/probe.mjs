// Slice 123e probe (platform 0.0.4): startApp, one request, app.reset() and app.close(), 5 runs each.
//   node probe.mjs <dir with app.wasm, .roc-cfw/, wrangler.toml>   (research/slice-123e/build.sh makes the dir: build/worker)
// Own config: CFG=<file> (kept in research/slice-123e/). No hooks. The ratelimit bindings come from the option `ratelimits`.
import { join } from 'node:path';
const dir = process.argv[2];
const { startApp } = await import(join(dir, '.roc-cfw', 'test.mjs'));
const migrations = ['../sql/0001_init.sql', '../sql/0002_triggers.sql'];
const opts = { dir, now: 1767225600000, d1: { DB: migrations }, count: ['DB'], bindings: { AUDIENCE: 'https://registry.example' }, config: process.env.CFG || join(dir, 'wrangler.toml'),
  ratelimits: { RL_INGEST: { limit: 60, period: 60 }, RL_HINTS: { limit: 30, period: 60 }, RL_LOGIN: { limit: 10, period: 60 } } };
const R = { start: [], fetch: [], reset: [], close: [] };
const ms = (t0) => performance.now() - t0;
for (let r = 0; r < 5; r++) {
  let t0 = performance.now();
  const app = await startApp(opts); R.start.push(ms(t0));
  t0 = performance.now(); const res = await app.fetch('/v1/packages?short=a'); await res.text(); R.fetch.push(ms(t0));
  await app.sql('DB', ["INSERT INTO names (id, kind, value) VALUES (1, 3, 'o/r')"]);
  t0 = performance.now(); await app.reset(); R.reset.push(ms(t0));
  t0 = performance.now(); await app.close(); R.close.push(ms(t0));
}
for (const [k, v] of Object.entries(R)) console.log(k.padEnd(6), v.map((x) => x.toFixed(0).padStart(5)).join(' '), ' mean', (v.reduce((a, b) => a + b) / v.length).toFixed(0), 'ms');
