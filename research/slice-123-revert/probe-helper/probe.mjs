// Slice 123 part 123e probe: the cost of startApp (platform 0.0.3 test helper) against the Miniflare of worker/tests/run.mjs, and the cost of app.reset().
//   node probe.mjs <dir with app.wasm and .roc-cfw/ and wrangler.toml>   (the reference build of ../ref.sh)
import { join } from 'node:path';
const dir = process.argv[2];
const { startApp } = await import(join(dir, '.roc-cfw', 'test.mjs'));
const t = (label, t0) => console.log(`${label}: ${(performance.now() - t0).toFixed(0)} ms`);
const migrations = ['../sql/0001_init.sql', '../sql/0002_triggers.sql'];
let t0 = performance.now();
const app = await startApp({ dir, now: 1767225600000, d1: { DB: migrations }, count: ['DB'], bindings: { AUDIENCE: 'https://registry.example' }, config: join(import.meta.dirname, 'wrangler-noconsumer.toml'), hooks: join(import.meta.dirname, 'hooks.js'),
  miniflareOptions: { ratelimits: Object.fromEntries(['RL_INGEST', 'RL_HINTS', 'RL_LOGIN'].map((n, i) => [n, { namespace_id: String(1000 + i), simple: { limit: 1000, period: 60 } }])) } });
t('startApp', t0);
for (let i = 0; i < 3; i++) {
  t0 = performance.now();
  const res = await app.fetch('/v1/packages?short=a');
  const body = await res.text();
  t(`fetch ${i}: ${res.status} d1 calls ${res.calls?.DB?.n}`, t0);
  t0 = performance.now();
  await app.sql('DB', ["INSERT INTO names (id, kind, value) VALUES (1, 3, 'o/r')"]);
  await app.reset();
  t(`reset ${i}`, t0);
}
t0 = performance.now();
await app.close();
t('close', t0);
