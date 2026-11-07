#!/usr/bin/env node
// Write the scenario files (scenarios/<name>.jsonl) from the live read API of a registry (Registry 4: R-AP5, R-AP14).
//   node research/bench/gen-scenarios.mjs --base <url> [--out-dir <dir>] [--seed N] [--mixed-size N]
// One request in each line: {"method","path","json"?,"headers"?,"expected_status"}. The same corpus and seed give the same files.
// The text {{uniq}} in a header or a body is a new 32 digit lower-case hex text for each sent request (drive.mjs).
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { discover } from './discover.mjs';
import { isWrite } from './lib.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const args = Object.fromEntries(process.argv.slice(2).reduce((a, x, i, all) => (x.startsWith('--') ? [...a, [x.slice(2), all[i + 1]]] : a), []));
if (!args.base) { console.error('usage: gen-scenarios.mjs --base <url> [--out-dir <dir>] [--seed N] [--mixed-size N]'); process.exit(2); }
const base = args.base.replace(/\/$/, '');
const outDir = args['out-dir'] ?? join(here, 'scenarios');
const seed = Number(args.seed ?? 1);
const mixedSize = Number(args['mixed-size'] ?? 400);

// Caps: the corpus can grow; the files must stay small.
const CAP = { single: 60, multi: 12, shorts: 60, multiShort: 10, releases: 300, groupReads: 20, artifacts: 100, compat: 40, sweeps: 8, hints: 30 };

const corpus = await discover(base);
const { toolchains, releases } = corpus;
if (releases.length === 0 || toolchains.length === 0) { console.error('the registry has no release or no toolchain: no corpus'); process.exit(1); }

// The corpus: groups (any host), GitHub packages, hashes, nightly tags. Order of first appearance in the log.
const uniq = (xs) => [...new Set(xs)];
const groups = uniq(releases.map((r) => r.group));
const hashes = uniq(releases.map((r) => r.hash));
const tags = uniq(toolchains.map((t) => t.tag));
const pk = new Map();
for (const r of releases) {
  const m = /^github\.com\/([^/]+)\/([^/]+)\//.exec(r.group);
  if (!m) continue;
  const key = `${m[1]}/${m[2]}`.toLowerCase();
  if (!pk.has(key)) pk.set(key, { owner: m[1], repo: m[2], groups: new Set() });
  pk.get(key).groups.add(r.group);
}
const pkgs = [...pk.values()];
const shortOf = (p) => (p.repo.length > 4 && /^roc-/i.test(p.repo) ? p.repo.slice(4) : p.repo);

// A request line.
const get = (path, expected = 200, headers) => ({ method: 'GET', path, ...(headers ? { headers } : {}), expected_status: expected });
const post = (path, json, expected, headers) => ({ method: 'POST', path, ...(headers ? { headers } : {}), json, expected_status: expected });
const q = encodeURIComponent;

// A seeded generator (mulberry32) and a pick with Zipf weights (rank r has weight 1/r): a few packages get most requests.
let st = seed >>> 0;
const rnd = () => { st = (st + 0x6d2b79f5) >>> 0; let t = st; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
const zipf = (xs) => {
  const w = xs.map((_, i) => 1 / (i + 1));
  let x = rnd() * w.reduce((a, b) => a + b, 0);
  for (let i = 0; i < xs.length; i++) { x -= w[i]; if (x <= 0) return xs[i]; }
  return xs[xs.length - 1];
};
const sample = (xs, n) => { // n items, spread over the list
  if (xs.length <= n) return xs;
  return Array.from({ length: n }, (_, i) => xs[Math.floor((i * xs.length) / n)]);
};
const windows = (xs, size, n) => Array.from({ length: Math.min(n, Math.ceil(xs.length / size)) }, (_, i) => {
  const at = Math.floor((i * xs.length) / Math.min(n, Math.ceil(xs.length / size)));
  return xs.slice(at, at + size);
});

const latest = tags.slice(-1)[0];
// A hint on a pair that has a bot row is skipped (R-CT14, `bot-row`). So the hint hashes are the hashes with no bot run at all (GET /v1/artifacts/{hash}/compat:
// no `runs` item with `source` bot). The bot set (R-MX11) does not hold every hash, so such hashes exist. The hint tags are up to 5 of the older nightlies.
const hintTags = tags.length > 4 ? tags.slice(0, -3).slice(-5) : tags;
const hintPairs = [];
for (const h of hashes) {
  const res = await fetch(`${base}/v1/artifacts/${h}/compat`);
  if (res.status !== 200) continue;
  if (((await res.json()).runs ?? []).some((r) => r.source === 'bot')) continue;
  for (const tag of hintTags) hintPairs.push({ hash: h, nightly: tag });
}
if (hintPairs.length === 0) console.error('warning: every (hash, nightly) pair has a bot row: the hint posts give 200 written 0');
const window2 = { from: tags[Math.max(0, tags.length - 3)], to: latest };
const grp = (g) => ({ group: g });

// Request makers, one for each use case (the use case is the class of the mixed scenario).
const reqs = {
  toolchains: () => get('/v1/toolchains'),
  notFound: () => get('/v1/does-not-exist', 404),
  short: pkgs.map((p) => get(`/v1/packages?short=${q(shortOf(p))}`)),
  shortRepo: pkgs.map((p) => get(`/v1/packages?short=${q(p.repo)}`)),
  multiShort: windows(pkgs, 5, CAP.multiShort).map((w) => get(`/v1/packages?${w.map((p) => `short=${q(shortOf(p))}`).join('&')}`)),
  noShort: get('/v1/packages?short=no-such-package-zz'),
  qSearch: uniq(pkgs.flatMap((p) => { const s = shortOf(p).toLowerCase(); return [s.slice(0, 1), s.slice(0, 2), s.slice(0, 3), s]; })).sort().map((t) => get(`/v1/packages?q=${q(t)}`)),
  releases: pkgs.map((p) => get(`/v1/packages/${p.owner}/${p.repo}/releases`)),
  releaseGroup: groups.map((g) => get(`/v1/releases?group=${q(g)}`)),
  artifact: hashes.map((h) => get(`/v1/artifacts/${h}`)),
  artifactCompat: hashes.map((h) => get(`/v1/artifacts/${h}/compat`)),
  closureOne: groups.map((g) => post('/v1/closure', { groups: [grp(g)], hashes: [] }, 200)),
  closureFew: windows(groups, 4, CAP.multi).map((w, i) => post('/v1/closure', { groups: w.map(grp), hashes: i % 2 ? [] : hashes.slice(i, i + 2), ...(i % 3 === 0 ? { compilers: window2 } : {}) }, 200)),
  closureAll: post('/v1/closure', { groups: groups.slice(0, 300).map(grp), hashes: [], compilers: window2 }, 200),
  audit: get('/v1/compat_hints?audit=100'),
  sweeps: tags.slice(-CAP.sweeps).reverse().map((t) => get(`/v1/sweeps/${t}`)),
  hint: (n, k) => post('/v1/compat', { talon_version: '0.4.1', rows: Array.from({ length: n }, (_, i) => { const p = hintPairs.length ? hintPairs[(k * 7 + i) % hintPairs.length] : { hash: hashes[(k + i) % hashes.length], nightly: hintTags[(k + i) % hintTags.length] }; return { hash: p.hash, nightly: p.nightly, target: 'any', result: 'pass' }; }) }, 201, { 'content-type': 'application/json', 'talon-contributor': '{{uniq}}' }),
};

const files = {};
files.small = [reqs.toolchains(), reqs.notFound()];
files.search = [
  ...sample(reqs.short, CAP.shorts), ...reqs.multiShort, reqs.noShort,
  ...sample(reqs.shortRepo.filter((_, i) => shortOf(pkgs[i]) !== pkgs[i].repo), 10), ...reqs.qSearch.slice(0, 40),
];
files.releases = [
  ...sample(reqs.releases, CAP.releases), get('/v1/packages/nobody-zz/none-zz/releases', 404),
  ...sample(reqs.releaseGroup, CAP.groupReads), get('/v1/releases?after=0'),
];
files.closure = [...sample(reqs.closureOne, CAP.single), ...reqs.closureFew, reqs.closureAll];
files.compat = [
  reqs.audit, get('/v1/compat_hints?audit=1000'),
  ...reqs.sweeps, get('/v1/sweeps/nightly-2020-01-01-0000000', 404),
  ...sample(reqs.artifact, CAP.artifacts), get('/v1/artifacts/not-a-hash', 404),
  ...sample(reqs.artifactCompat, CAP.compat),
];
files.hints = [...Array.from({ length: CAP.hints }, (_, k) => reqs.hint(1 + (k % 3) * 4, k)), post('/v1/compat', { talon_version: '0.4.1', rows: [] }, 200, { 'content-type': 'application/json', 'talon-contributor': '{{uniq}}' })];

// The mixed scenario: classes with weights (percent). The weights are a judgment: the registry has no traffic log yet.
//   closure is the one route that each resolve calls (CLI 7.3, R-AP3), so it is the largest class: 12 + 20 + 3.
//   toolchains and short matches come with each add and resolve. Release, artifact and compat reads are the lookups of tln info and probe.
//   Hint posts follow a build with a probe. The bot reads (sweeps, audit) are about 1 a day each, so 1.
const CLASSES = [
  ['closure, 1 group (tln add)', 12, () => zipf(reqs.closureOne)],
  ['closure, 3 to 4 groups (resolve)', 20, () => zipf(reqs.closureFew)],
  ['closure, all groups (tln outdated)', 3, () => reqs.closureAll],
  ['toolchains', 15, reqs.toolchains],
  ['short match', 15, () => zipf(reqs.short)],
  ['q search', 3, () => zipf(reqs.qSearch)],
  ['releases of a package', 10, () => zipf(reqs.releases)],
  ['artifact', 8, () => zipf(reqs.artifact)],
  ['artifact compat', 5, () => zipf(reqs.artifactCompat)],
  ['hint post (write)', 4, () => reqs.hint(1 + Math.floor(rnd() * 8), Math.floor(rnd() * 1000))],
  ['compat_hints audit', 1, () => reqs.audit],
  ['sweeps', 1, () => zipf(reqs.sweeps)],
  ['404', 3, reqs.notFound],
];
const mix = (classes) => {
  const total = classes.reduce((a, c) => a + c[1], 0);
  return Array.from({ length: mixedSize }, () => {
    let x = rnd() * total;
    for (const c of classes) { x -= c[1]; if (x <= 0) return c[2](); }
    return classes[classes.length - 1][2]();
  });
};
files.mixed = mix(CLASSES);
files['mixed-ro'] = mix(CLASSES.filter((c) => !c[0].includes('(write)')));

mkdirSync(outDir, { recursive: true });
for (const [name, lines] of Object.entries(files)) writeFileSync(join(outDir, `${name}.jsonl`), lines.map((l) => JSON.stringify(l)).join('\n') + '\n');
const info = {
  base, generated_at: new Date().toISOString(), seed, mixed_size: mixedSize, discovery_requests: corpus.requests,
  corpus: { releases: releases.length, groups: groups.length, github_packages: pkgs.length, hashes: hashes.length, toolchain_rows: toolchains.length, nightly_tags: tags.length, latest_tag: latest },
  mixed_weights: CLASSES.map(([name, weight]) => ({ class: name, weight })),
  lines: Object.fromEntries(Object.entries(files).map(([k, v]) => [k, v.length])),
  write_scenarios: Object.keys(files).filter((k) => files[k].some((l) => isWrite(l.method, l.path))),
};
writeFileSync(join(outDir, 'corpus.json'), JSON.stringify(info, null, 2) + '\n');
console.log(`corpus of ${base}: ${releases.length} releases, ${groups.length} groups, ${pkgs.length} GitHub packages, ${hashes.length} hashes, ${tags.length} nightly tags (${toolchains.length} toolchain rows)`);
for (const [k, v] of Object.entries(info.lines)) console.log(`  ${k.padEnd(8)} ${String(v).padStart(4)} requests`);
