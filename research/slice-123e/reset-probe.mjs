// Slice 123e: where does app.reset() spend its time? Compare the platform seeds (d1 option) with an empty seed and one db.batch of the migrations by the runner.
//   node research/slice-123e/reset-probe.mjs <W2_DIR>
import { join, dirname } from 'node:path';
import { readFileSync } from 'node:fs';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { splitSql, migrationFiles } from '../../sql/tests/split.mjs';
const w2Dir = process.argv[2];
const here = join(dirname(fileURLToPath(import.meta.url)), '../../worker/tests');
const { startApp } = await import(pathToFileURL(join(w2Dir, '.roc-cfw/test.mjs')).href);
const migrations = migrationFiles(join(here, '../../sql')).map((f) => readFileSync(f, 'utf8'));
const stmts = migrations.flatMap((m) => splitSql(m).map((s) => s.sql));
const mk = (d1) => startApp({ dir: here, shim: join(w2Dir, '.roc-cfw'), wasm: join(w2Dir, 'app.wasm'), config: join(here, 'wrangler-test.toml'), hooks: 'hooks.js', now: 1767225600000, d1, count: ['DB', 'INDEX'], bindings: { AUDIENCE: 'x' }, ratelimits: {}, miniflare: process.env.MINIFLARE ?? join(dirname(dirname(process.execPath)), 'lib/node_modules/wrangler/node_modules/miniflare') });
const ms = async (f) => { const t = performance.now(); await f(); return +(performance.now() - t).toFixed(0); };
for (const mode of ['platform seeds', 'own batch']) {
  const app = await mk(mode === 'platform seeds' ? { DB: migrations } : {});
  const db = await app.d1('DB');
  const own = async () => { await db.batch(stmts.map((s) => db.prepare(s))); };
  if (mode === 'own batch') await own();
  const r = [];
  for (let i = 0; i < 6; i++) {
    await app.sql('DB', ["INSERT INTO names (id, kind, value) VALUES (" + (i + 1) + ", 3, 'o/r')"]);
    r.push(await ms(async () => { await app.reset(); if (mode === 'own batch') await own(); }));
  }
  console.log(mode.padEnd(16), 'reset ms:', r.join(' '));
  await app.close();
}
