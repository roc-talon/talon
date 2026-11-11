// Platform 0.0.10 check of the registry Worker: the queue consumer on a local copy of the prod D1 (no write to prod).
//   node research/platform-0.0.10/queue-prodcopy.mjs <build dir: app.wasm and .roc-cfw/> <seed.sql: research/d1-dump/dump.mjs of prod>
// It starts the build with startApp (as worker/tests/serve.mjs), runs the migrations and the seed, then sends 3 queue messages with the JSON shape that the Worker
// sends (Queue.json) for the real repo imclerran/roc-isodate (repository_id 747209484), and prints the results, the D1 rows and the package read before and after.
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { splitSql, migrationFiles } from '../../sql/tests/split.mjs';
import { appSettings, dropNulls } from '../../worker/tests/githubapp.mjs';

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const tests = join(root, 'worker', 'tests');
const [buildDir, seedFile] = process.argv.slice(2);
const now = Date.now();
const mfDir = process.env.MINIFLARE ?? join(dirname(dirname(process.execPath)), 'lib/node_modules/wrangler/node_modules/miniflare');
const settings = dropNulls({ ...appSettings(), ...JSON.parse(readFileSync(join(tests, 'settings.json'), 'utf8')) });
const github = [];
const { startApp } = await import(pathToFileURL(join(buildDir, '.roc-cfw', 'test.mjs')).href);
const app = await startApp({
  dir: tests, shim: join(buildDir, '.roc-cfw'), wasm: join(buildDir, 'app.wasm'), config: join(tests, 'wrangler-test.toml'), hooks: 'hooks.js', now,
  bindings: settings, ratelimits: { RL_INGEST: { limit: 60, period: 60 }, RL_HINTS: { limit: 1000, period: 60 }, RL_LOGIN: { limit: 1000, period: 60 } },
  outbound: (req) => { github.push(`${req.method} ${req.url}`); return new Response('no fake GitHub', { status: 599 }); }, miniflare: mfDir,
});
const db = await app.d1('DB');
await db.batch(migrationFiles(join(root, 'sql')).flatMap((f) => splitSql(readFileSync(f, 'utf8')).map((s) => db.prepare(s.sql))));
for (const s of splitSql(readFileSync(seedFile, 'utf8'))) await db.prepare(s.sql).run();
const repo = 'imclerran/roc-isodate', rid = 747209484;
const rows = async () => (await db.prepare(`SELECT r.state, c.app_installed, (SELECT COUNT(*) FROM releases x WHERE x.repo = r.repo AND x.withdrawn IS NOT NULL) AS withdrawn FROM repos r JOIN repo_checks c ON c.repo = r.repo WHERE r.repository_id = ?1`).bind(rid).all()).results;
const read = async () => { const r = await app.fetch(`/v1/packages/${repo}/releases`); const j = await r.json(); return `${r.status} ${j.releases?.length} releases, withdrawn: ${JSON.stringify(j.releases?.map((x) => x.withdrawn))}`; };
const msg = (id, body) => ({ id, timestamp: new Date(now), attempts: 1, body });
const base = { installation_id: 177657685, repository_id: rid, release_id: 0, repository_ids: [] };
console.log('before:', JSON.stringify(await rows()), '|', await read());
const steps = [
  ['m1 installation_repositories added', msg('m1', { ...base, event: 'installation_repositories', action: 'added', repository_id: 0, repository_ids: [rid] })],
  ['m2 release published (needs GitHub: the fake gives 599)', msg('m2', { ...base, event: 'release', action: 'published', release_id: 262144001 })],
  ['m3 repository privatized', msg('m3', { ...base, event: 'repository', action: 'privatized' })],
];
for (const [what, m] of steps) {
  const r = await app.queue('talon-index', [m], { now });
  console.log(`${what}: ${JSON.stringify(r)}`);
  console.log('  rows:', JSON.stringify(await rows()), '|', await read());
}
await new Promise((r) => setTimeout(r, 1500));
for (const l of app.logs) { const t = typeof l === 'string' ? l : JSON.stringify(l.message ?? l); if (/warn|error/.test(t)) console.log('log:', t.slice(0, 300)); }
console.log('outbound:', JSON.stringify(github));
await app.close();
