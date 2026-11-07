#!/usr/bin/env node
// Start the registry Worker locally for the bench: worker/tests/serve.mjs (Miniflare, local D1) with a seed made from the corpus of another registry.
//   node research/bench/local.mjs [--from <url>] [--dir <state dir>] [--port 8787] [--seed-only]
//   --from  the registry whose read API gives the corpus (default https://registry.roc-talon.org). The seed has its releases and toolchains.
//   --dir   the state dir (default: a new dir in the temp dir). It gets worker/ (seed.sql, settings.json, ratelimits.json, github/) and, from serve.mjs, worker.url, worker.log, worker.errs.
// Env: W2_DIR (the dir with app.wasm and .roc-cfw/, default worker/), MINIFLARE (as serve.mjs).
// The seed (SQL) has: the releases (tools/mk-l3w-seed.mjs: names, artifacts, log, releases, repos), the toolchain rows with the tags of the corpus, and one `bot` compat
// row (pass, target any) for each artifact on the 3 newest nightlies, so the closure answer has runs. The ids of the repositories are made up (1000 and up).
// The clock of the Worker (TALON_NOW) is the start time, as the seed times. RL_HINTS is raised to 1,000,000 a minute: the hints scenario sends more than 30 requests a minute.
// serve.mjs runs until TERM or INT. Fake GitHub: the tag list of roc-talon/talon (R-CT12) only.
import { spawn, spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { discover } from './discover.mjs';
import { sleep } from './lib.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, '..', '..');
const args = Object.fromEntries(process.argv.slice(2).reduce((a, x, i, all) => (x.startsWith('--') ? [...a, [x.slice(2), x.startsWith('--seed-only') ? 'true' : all[i + 1]]] : a), []));
const from = (args.from ?? 'https://registry.roc-talon.org').replace(/\/$/, '');
const port = Number(args.port ?? 8787);
const stateDir = args.dir ?? mkdtempSync(join(tmpdir(), 'bench-local-'));
const caseDir = join(stateDir, 'worker');
mkdirSync(join(caseDir, 'github/api.github.com/repos/roc-talon/talon'), { recursive: true });

const { toolchains, releases } = await discover(from);
const now = Date.now();

// Releases in the spec of mk-l3w-seed.mjs. A release whose tag is not the version or v+version cannot be seeded by that tool, and a hash with a second label is seeded once: they are left out.
const spec = { now: new Date(now).toISOString(), releases: [] };
const ids = new Map();
const skipped = [];
const seen = new Set();
for (const r of releases) {
  const m = /^github\.com\/([^/]+)\/([^/]+)\//.exec(r.group);
  if (!m || (r.tag !== r.version && r.tag !== `v${r.version}`)) { skipped.push(r.hash); continue; }
  if (seen.has(r.hash)) { skipped.push(r.hash); continue; } // mk-l3w-seed.mjs makes one artifact row for each release: a hash with 2 labels is seeded once
  seen.add(r.hash);
  const key = `${m[1]}/${m[2]}`.toLowerCase();
  if (!ids.has(key)) ids.set(key, ids.size + 1);
  const artifact = ids.get(key);
  spec.releases.push({
    owner: m[1], repo: m[2], tag: r.tag, version: r.version, hash: r.hash, published_at: new Date(r.published_at).toISOString(),
    roc_version: r.roc_version ?? null, repository_id: 1000 + artifact, owner_id: 2000 + artifact, size: 1000,
  });
}
writeFileSync(join(stateDir, 'seed-spec.json'), JSON.stringify(spec));
const mk = spawnSync(process.execPath, [join(root, 'worker/tests/tools/mk-l3w-seed.mjs'), join(stateDir, 'seed-spec.json')], { encoding: 'utf8' });
if (mk.status !== 0) { console.error(`local: mk-l3w-seed.mjs failed: ${mk.stderr}`); process.exit(1); }

// R-IK2, R-IK4: ids as the tools of worker/tests/tools.
const B58 = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
const b58 = (s) => { let n = 0n; for (const c of s) n = n * 58n + BigInt(B58.indexOf(c)); let h = n.toString(16); if (h.length % 2) h = `0${h}`; return Buffer.from(h, 'hex'); };
const hashId = (h) => createHash('sha256').update(Buffer.concat([Buffer.from([1]), b58(h)])).digest().readBigInt64BE(0).toString();
const nightlyId = (t) => { const [, y, mo, d, s] = t.split('-'); return Number(BigInt(Math.round(Date.UTC(+y, +mo - 1, +d) / 86400000)) * 268435456n + BigInt(parseInt(s, 16))); };
const q = (s) => `'${String(s).replace(/'/g, "''")}'`;

const sql = [mk.stdout];
let idx = spec.releases.length;
for (const t of toolchains) { // the log index of a toolchain row is its own (leaf check): the log gets one row for each
  idx++;
  sql.push(`INSERT INTO log (idx, grp, version, hash, time) VALUES (${idx}, ${q(`roc-lang/nightlies:${t.target}`)}, ${q(t.tag)}, ${q(`sha256:${t.sha256}`)}, ${now});`);
  sql.push(`INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, size, published_at, log_index) VALUES (${nightlyId(t.tag)}, ${q(t.target)}, ${q(t.tag)}, ${q(t.asset_name)}, ${q(t.sha256)}, ${t.size}, ${t.published_at}, ${idx});`);
}
const tags = [...new Set(toolchains.map((t) => t.tag))].slice(-3);
for (const r of spec.releases) for (const t of tags) {
  sql.push(`INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index) VALUES (${hashId(r.hash)}, ${nightlyId(t)}, 0, 0, 0, NULL, ${now}, NULL);`);
}
writeFileSync(join(caseDir, 'seed.sql'), sql.join('\n') + '\n');
writeFileSync(join(caseDir, 'settings.json'), JSON.stringify({ CONTRIBUTOR_KEY: 'test-contributor-key' }));
writeFileSync(join(caseDir, 'ratelimits.json'), JSON.stringify({ RL_HINTS: { limit: 1000000, period: 60 } }));
writeFileSync(join(caseDir, 'github/api.github.com/repos/roc-talon/talon/tags%3Fper_page=100'), JSON.stringify([{ name: 'v0.4.1', zipball_url: 'https://example.invalid/v0.4.1', commit: { sha: 'abc' } }]));
console.log(`seed: ${spec.releases.length} releases (${skipped.length} left out), ${ids.size} repos, ${toolchains.length} toolchain rows, ${spec.releases.length * tags.length} compat rows; dir ${stateDir}`);
if (args['seed-only']) process.exit(0);

const child = spawn(process.execPath, [join(root, 'worker/tests/serve.mjs'), caseDir, stateDir, String(port)], { stdio: ['ignore', 'inherit', 'inherit'], env: { ...process.env, TALON_NOW: new Date(now).toISOString() } });
child.on('exit', (code) => process.exit(code ?? 1));
for (const s of ['SIGINT', 'SIGTERM']) process.once(s, () => child.kill(s));
for (let i = 0; i < 600 && !existsSync(join(stateDir, 'worker.url')); i++) await sleep(100);
if (!existsSync(join(stateDir, 'worker.url'))) { console.error(`local: no worker.url after 60 s; see ${join(stateDir, 'worker.errs')}`); child.kill('SIGTERM'); process.exit(1); }
console.log(`ready ${readFileSync(join(stateDir, 'worker.url'), 'utf8')}  (stop: Ctrl-C or TERM; log ${join(stateDir, 'worker.log')})`);
