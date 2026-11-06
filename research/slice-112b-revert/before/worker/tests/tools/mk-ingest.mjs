// The W2 cases of slice 112 (the ingest `POST /v1/releases` with no token, Registry R-AP9, R-PU4; docs/slices/112-ingest.md section 4).
//   node worker/tests/tools/mk-ingest.mjs     writes worker/tests/cases/ingest/*/ (github/, seed.sql, requests.jsonl, expect/, rules)
// The files are tracked. Run the script again only when a case changes: the hashes are in the names and in the expected files.
// The expected values come from the design (R-AP49, R-RE1 to R-RE20, R-IK2, R-IK5, R-SG8) and the proposals of the slice file section 5, computed here
// with no Roc code: name_id (R-IK2), the version column (R-IK5), the BLAKE3 hash (Design 2).
import { createHash } from 'node:crypto';
import { mkdirSync, writeFileSync, rmSync, existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { tar, zstd } from './mk-bundle.mjs';
import { rocHash, blake3, base58 } from './blake3.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const casesDir = join(here, '..', 'cases', 'ingest');

// ---- the facts of the design, in JS ----
const B58 = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
function b58decode(s) {
  let n = 0n;
  for (const c of s) n = n * 58n + BigInt(B58.indexOf(c));
  const out = [];
  while (n > 0n) { out.unshift(Number(n & 255n)); n >>= 8n; }
  for (const c of s) { if (c === '1') out.unshift(0); else break; }
  return Buffer.from(out);
}
// R-IK2: the first 8 bytes of SHA-256(kind byte, bytes), big-endian, signed.
const nameId = (kind, bytes) => {
  const d = createHash('sha256').update(Buffer.concat([Buffer.from([kind]), Buffer.from(bytes)])).digest();
  return d.readBigInt64BE(0).toString();
};
const hashId = (h) => nameId(1, b58decode(h));
const textId = (kind, t) => nameId(kind, Buffer.from(t, 'utf8'));
// R-IK5: the key of an exact X.Y.Z (pre-release code 0xFFFF), XOR 2^63, as a signed integer.
const versionCol = (v) => {
  const [a, b, c] = v.split('.').map(BigInt);
  const key = (a << 48n) | (b << 32n) | (c << 16n) | 0xFFFFn;
  return BigInt.asIntN(64, key ^ (1n << 63n)).toString();
};
const series = (v) => { const [a, b] = v.split('.'); return a === '0' ? `0.${b}` : a; };
const hex = (h) => b58decode(h).toString('hex').toUpperCase();

// ---- the made bundles ----
const SEMVER_H = 'BzgH68Q1yBkg7F1ZpFsiEg73ZwkaBrFdcLpX2pUkay9i';
const SEMVER = `https://github.com/Karakatiza666/roc-semver/releases/download/0.2.0/${SEMVER_H}.tar.zst`;
const CBOR_H = 'Cn5TmeqTbMewyChxexex2F3izTnMriXRv5ZMLVV3eUYb';
const CBOR = `https://github.com/Karakatiza666/roc-cbor/releases/download/0.2.2/${CBOR_H}.tar.zst`;
const EXTRA_H = 'C6Jtcve7FRNtkwgmuyRBJnZfJyTrfJWhDcLp6gk4w4Gz';
const EXTRA = `https://example.com/pkgs/${EXTRA_H}.tar.zst`;
const mod = (name) => `${name} :: [].{\n\tx : U64\n\tx = 1\n}\n`;
const pkgBundle = (note) => zstd(tar([
  { path: 'main.roc', data: `## ${note}\npackage\n\t[\n\t\tZeta,\n\t\tAlpha,\n\t]\n\t{\n\t\tsemver: "${SEMVER}",\n\t\textra: "${EXTRA}",\n\t}\n` },
  { path: 'Zeta.roc', data: mod('Zeta') }, { path: 'Alpha.roc', data: mod('Alpha') },
]));
const platBundle = zstd(tar([
  { path: 'main.roc', data: `platform ""\n\trequires {\n\t\tmain! : List(Str) => Try({}, [Exit(I32)])\n\t}\n\texposes [Stdout, Arg]\n\tpackages {\n\t\tcbor: "${CBOR}",\n\t}\n\tprovides { "roc_main": main_for_host! }\n\ttargets: {\n\t\tfiles: "targets/",\n\t\texe: {\n\t\t\tx64mac: ["libhost.a", app],\n\t\t\tzz9new: ["host.o", app],\n\t\t},\n\t}\n` },
  { path: 'Stdout.roc', data: mod('Stdout') }, { path: 'Arg.roc', data: mod('Arg') },
  { path: 'targets/x64mac/libhost.a', data: 'host' }, { path: 'targets/zz9new/host.o', data: 'host' },
]));
const PLAT_H = rocHash(platBundle);
const appBundle = zstd(tar([
  { path: 'main.roc', data: `app [main!] {\n\tpf: platform "https://github.com/acme/plat/releases/download/v0.3.0/${PLAT_H}.tar.zst",\n\troc: "nightly-2026-10-31-f7bef6b",\n}\n\nmain! = |_args| Ok({})\n` },
]));

// ---- a case ----
const NOW = 1767225630000; // the clock of each request (not published_at: R-SG8 row 2)
const PUB = '2026-10-20T12:00:00Z';
const PUB_MS = Date.parse(PUB);
const HOUR = 3600000;
const gh = (owner, repo, tag, hash) => `https://github.com/${owner}/${repo}/releases/download/${tag}/${hash}.tar.zst`;
const repoJson = (full, id, ownerId, visibility = 'public') => JSON.stringify({ id, name: full.split('/')[1], full_name: full, private: visibility !== 'public', owner: { login: full.split('/')[0], id: ownerId, type: 'Organization' }, description: null, visibility, default_branch: 'main' });
const releaseJson = (tag, assets, { draft = false, prerelease = false, published_at = PUB } = {}) => JSON.stringify({ id: 1, tag_name: tag, name: null, draft, prerelease, created_at: PUB, published_at, body: null, assets: assets.map((name, i) => ({ id: i + 1, name, label: null, content_type: 'application/octet-stream', state: 'uploaded', size: 10, digest: null })) });
const post = (url, extra = {}) => ({ method: 'POST', path: '/v1/releases', json: { url }, now: NOW, ...extra });
const problem = (status, type, detail) => ({ status, problem: detail === undefined ? { type } : { type, detail } });
const ok = (status, release, hash) => ({
  status,
  headers: { 'content-type': 'application/json', 'cache-control': 'no-store', 'x-d1-session': 'first-primary', location: status === 201 ? `/v1/artifacts/${hash}` : null },
  headers_set: ['talon-bookmark'],
  json: { release },
});
const wire = (log_index, { hash, form, version, url, tag, roc_version, repo }) => ({ log_index, hash, group: form, series: series(version), version, url, tag, roc_version, repo, published_at: PUB_MS, yanked: false, yank_reason: null, withdrawn: null });

class Case {
  constructor(name, rules) { this.name = name; this.rules = rules; this.files = new Map(); this.reqs = []; this.exp = []; this.calls = []; this.log = []; this.seed = ''; this.db = ''; }
  file(url, body, meta) {
    const u = new URL(url);
    const enc = (s) => s.replace(/[%?:\\*<>|"]/g, (c) => `%${c.charCodeAt(0).toString(16).toUpperCase().padStart(2, '0')}`);
    const parts = [enc(u.host), ...u.pathname.split('/').filter(Boolean).map(enc)];
    if (u.search) parts[parts.length - 1] += `%3F${enc(u.search.slice(1))}`;
    const p = parts.join('/');
    this.files.set(p, body);
    if (meta) this.files.set(`${p}.meta.json`, JSON.stringify(meta));
    return p;
  }
  // The GitHub of one release: the repository, the release by tag, the asset, `.roc-version` (a text, or null for a 404).
  release({ owner, repo, tag, asset, repoId, ownerId, rocVersion = null, assets }) {
    const hash = rocHash(asset);
    this.file(`https://api.github.com/repos/${owner}/${repo}`, repoJson(`${owner}/${repo}`, repoId, ownerId));
    this.file(`https://api.github.com/repos/${owner}/${repo}/releases/tags/${tag}`, releaseJson(tag, assets ?? [`${hash}.tar.zst`]));
    this.file(gh(owner, repo, tag, hash), asset);
    if (rocVersion === null) this.file(`https://raw.githubusercontent.com/${owner}/${repo}/${tag}/.roc-version`, 'Not Found', { status: 404 });
    else this.file(`https://raw.githubusercontent.com/${owner}/${repo}/${tag}/.roc-version`, rocVersion);
    return hash;
  }
  reads(owner, repo, tag, hash) {
    this.log.push(`GET https://api.github.com/repos/${owner}/${repo}`, `GET https://api.github.com/repos/${owner}/${repo}/releases/tags/${tag}`, `GET ${gh(owner, repo, tag, hash)}`, `GET https://raw.githubusercontent.com/${owner}/${repo}/${tag}/.roc-version`);
  }
  sql(comment, stmts) { this.reqs.push({ sql: stmts }); this.notes = [...(this.notes ?? []), `(sql) ${comment}`]; }
  req(comment, spec, expect, calls) { this.reqs.push(spec); this.exp.push(expect); this.calls.push(String(calls)); this.notes = [...(this.notes ?? []), comment]; }
  write() {
    const dir = join(casesDir, this.name);
    rmSync(dir, { recursive: true, force: true });
    // A file whose path is also a dir (the repository beside its releases) is the file `%2F` in that dir (run.mjs).
    const keys = [...this.files.keys()];
    for (const [k, v] of this.files) {
      const base = k.replace(/(\.\d+)?(\.meta\.json|\.sql)?$/, '');
      const isDir = keys.some((o) => o.startsWith(`${base}/`));
      const name = isDir ? `${base}/%2F${k.slice(base.length)}` : k;
      mkdirSync(dirname(join(dir, 'github', name)), { recursive: true });
      writeFileSync(join(dir, 'github', name), v);
    }
    mkdirSync(join(dir, 'expect'), { recursive: true });
    writeFileSync(join(dir, 'rules'), `${this.rules}\n`);
    writeFileSync(join(dir, 'requests.jsonl'), this.reqs.map((r) => JSON.stringify(r)).join('\n') + '\n');
    writeFileSync(join(dir, 'notes.txt'), this.notes.map((n, i) => `${i + 1}: ${n}`).join('\n') + '\n');
    writeFileSync(join(dir, 'expect', 'responses.jsonl'), this.exp.map((r) => JSON.stringify(r)).join('\n') + '\n');
    writeFileSync(join(dir, 'expect', 'd1-calls'), this.calls.join('\n') + '\n');
    if (this.log.length) writeFileSync(join(dir, 'expect', 'github.log'), this.log.join('\n') + '\n');
    if (this.seed) writeFileSync(join(dir, 'seed.sql'), this.seed);
    if (this.db) writeFileSync(join(dir, 'expect', 'db.tsv'), this.db);
  }
}

// The db.tsv blocks that show all rows that an ingest writes (R-PU32: for a refused ingest each block is empty).
const Q = {
  names: "SELECT CAST(id AS TEXT), kind, CASE kind WHEN 1 THEN hex(value) ELSE value END FROM names ORDER BY kind, 3",
  artifacts: 'SELECT CAST(artifact AS TEXT), kind, exposes, CAST(platform AS TEXT), roc_pin, size FROM artifacts ORDER BY kind',
  deps: 'SELECT CAST(artifact AS TEXT), alias, CAST(dep AS TEXT), CAST(form AS TEXT), CAST(version AS TEXT), version_text, url FROM deps ORDER BY alias',
  targets: 'SELECT CAST(a.artifact AS TEXT), t.target, t.name FROM artifact_targets a JOIN targets t ON t.target = a.target ORDER BY t.target',
  newTargets: 'SELECT target, name FROM targets WHERE target >= 36 ORDER BY target',
  releases: 'SELECT log_index, CAST(form AS TEXT), CAST(version AS TEXT), version_text, CAST(artifact AS TEXT), CAST(repo AS TEXT), url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at FROM releases ORDER BY log_index',
  log: 'SELECT idx, grp, version, hash, time FROM log ORDER BY idx',
  provenance: 'SELECT release, via, claims, time FROM provenance ORDER BY release, via',
  repos: 'SELECT CAST(repo AS TEXT), repository_id, repository_owner_id, state, successor, state_at, time FROM repos ORDER BY repository_id',
  checks: 'SELECT CAST(repo AS TEXT), etag, checked_at, next_check_at, fail_count, app_installed FROM repo_checks ORDER BY 1',
};
const N = '\\N';
const block = (q, rows) => `@ ${q}\n${rows.map((r) => r.map((c) => (c === null ? N : String(c))).join('\t')).join('\n')}${rows.length ? '\n' : ''}`;
const allEmpty = () => Object.values(Q).map((q) => block(q, [])).join('');

// ---- case 1: three kinds, the rows of each table, the same request again, the read route after it ----
function kinds() {
  const c = new Case('pu4-index-kinds', 'R-AP68 R-AP9 R-AP8 R-AP41 R-PU4 R-PU6 R-PU14 R-PU15 R-PU26 R-PU31 R-TP5 R-SG8 R-IK2 R-IK3 R-IK5 R-IK7 R-RE1 R-RE2 R-RE9 R-RE11 R-RE14 R-RE19 R-RE20 R-AP49 R-AP50 R-DI4 R-DI5');
  const pkg = pkgBundle('A made package of slice 112.');
  const P = { owner: 'acme', repo: 'roc-thing', tag: '1.2.0', form: 'github.com/acme/roc-thing/releases/download/{v}/', version: '1.2.0', repoId: 501, ownerId: 9001 };
  P.hash = c.release({ ...P, asset: pkg, rocVersion: '  nightly-2026-10-31-f7bef6b\n' });
  const L = { owner: 'acme', repo: 'plat', tag: 'v0.3.0', form: 'github.com/acme/plat/releases/download/v{v}/', version: '0.3.0', repoId: 502, ownerId: 9001 };
  L.hash = c.release({ ...L, asset: platBundle, assets: ['docs.tar.gz', `${PLAT_H}.tar.zst`, `${PLAT_H}.tar.zst.intoto.jsonl`] });
  const A = { owner: 'acme', repo: 'app', tag: '2.0.0', form: 'github.com/acme/app/releases/download/{v}/', version: '2.0.0', repoId: 503, ownerId: 9001 };
  A.hash = c.release({ ...A, asset: appBundle, rocVersion: 'nightly-2026-10-14-38a3029' });
  const rel = (x, i, roc) => wire(i, { hash: x.hash, form: x.form, version: x.version, url: gh(x.owner, x.repo, x.tag, x.hash), tag: x.tag, roc_version: roc, repo: `${x.owner}/${x.repo}` });
  // # R-AP68 rows 4, 6, 8 to 11 (Q156, Q159, Q165), R-AP9, R-AP8, R-PU4, R-PU6: a new package release: 201, Location, the record, Talon-Bookmark, 2 D1 calls (R-AP41), the 4 GitHub reads in order
  c.req('package: 201', post(gh(P.owner, P.repo, P.tag, P.hash)), ok(201, rel(P, 1, 'nightly-2026-10-31-f7bef6b'), P.hash), 2);
  c.reads(P.owner, P.repo, P.tag, P.hash);
  // # R-DI4: docs.tar.gz and <hash>.tar.zst.intoto.jsonl are not package assets; R-AP49: no .roc-version is null; a tag with text around the run is its own group (R-DI5)
  c.req('platform: 201', post(gh(L.owner, L.repo, L.tag, L.hash)), ok(201, rel(L, 2, null), L.hash), 2);
  c.reads(L.owner, L.repo, L.tag, L.hash);
  c.req('app: 201', post(gh(A.owner, A.repo, A.tag, A.hash)), ok(201, rel(A, 3, 'nightly-2026-10-14-38a3029'), A.hash), 2);
  c.reads(A.owner, A.repo, A.tag, A.hash);
  // # R-AP68 row 4, R-PU14: the same label with the same hash again: 200, the same record, 1 D1 call, no GitHub read, nothing new
  c.req('package again: 200', post(gh(P.owner, P.repo, P.tag, P.hash), { now: NOW + 5000 }), ok(200, rel(P, 1, 'nightly-2026-10-31-f7bef6b'), P.hash), 1);
  // # R-AP2 (slice 106) reads what the ingest wrote: the artifact record of R-AP49
  c.req('read the app artifact', { method: 'GET', path: `/v1/artifacts/${A.hash}`, now: NOW }, {
    status: 200,
    json: { artifact: { hash: A.hash, kind: 'app', exposed: [], platform_hash: PLAT_H, roc_pin: 'nightly-2026-10-31-f7bef6b', size: appBundle.length, deps: [], target_names: [] }, releases: [rel(A, 3, 'nightly-2026-10-14-38a3029')], repos: [{ name: 'acme/app', state: 'active', successor: null }] },
  }, 1);
  c.req('read the package artifact', { method: 'GET', path: `/v1/artifacts/${P.hash}`, now: NOW }, {
    status: 200,
    json: { artifact: { hash: P.hash, kind: 'package', exposed: ['Zeta', 'Alpha'], platform_hash: null, roc_pin: null, size: pkg.length, target_names: [],
      deps: [
        { alias: 'extra', hash: EXTRA_H, group: 'example.com/pkgs/', series: null, version: null, url: EXTRA },
        { alias: 'semver', hash: SEMVER_H, group: 'github.com/Karakatiza666/roc-semver/releases/download/{v}/', series: '0.2', version: '0.2.0', url: SEMVER },
      ] } },
  }, 1);
  const semForm = 'github.com/Karakatiza666/roc-semver/releases/download/{v}/';
  const cborForm = 'github.com/Karakatiza666/roc-cbor/releases/download/{v}/';
  const names = [
    ...[P.hash, L.hash, A.hash, SEMVER_H, CBOR_H, EXTRA_H].map((h) => [hashId(h), 1, hex(h)]),
    ...[P.form, L.form, A.form, semForm, cborForm].map((f) => [textId(2, f), 2, f]),
    ...['acme/roc-thing', 'acme/plat', 'acme/app'].map((n) => [textId(3, n), 3, n]),
  ].sort((a, b) => a[1] - b[1] || (a[2] < b[2] ? -1 : a[2] > b[2] ? 1 : 0));
  c.db = [
    block(Q.names, names),
    block(Q.artifacts, [
      [hashId(A.hash), 0, '[]', hashId(PLAT_H), 'nightly-2026-10-31-f7bef6b', appBundle.length],
      [hashId(P.hash), 1, '["Zeta","Alpha"]', null, null, pkg.length],
      [hashId(L.hash), 2, '["Stdout","Arg"]', null, null, platBundle.length],
    ]),
    block(Q.deps, [
      [hashId(L.hash), 'cbor', hashId(CBOR_H), textId(2, cborForm), versionCol('0.2.2'), '', CBOR],
      [hashId(P.hash), 'extra', hashId(EXTRA_H), null, null, null, EXTRA],
      [hashId(P.hash), 'semver', hashId(SEMVER_H), textId(2, semForm), versionCol('0.2.0'), '', SEMVER],
    ]),
    block(Q.targets, [[hashId(L.hash), 1, 'x64mac'], [hashId(L.hash), 36, 'zz9new']]),
    block(Q.newTargets, [[36, 'zz9new']]),
    block(Q.releases, [P, L, A].map((x, i) => [i + 1, textId(2, x.form), versionCol(x.version), '', hashId(x.hash), textId(3, `${x.owner}/${x.repo}`), gh(x.owner, x.repo, x.tag, x.hash), x.tag, [ 'nightly-2026-10-31-f7bef6b', null, 'nightly-2026-10-14-38a3029'][i], PUB_MS, 0, null, null])),
    block(Q.log, [P, L, A].map((x, i) => [i + 1, x.form, x.version, x.hash, NOW])),
    block(Q.provenance, [[1, 3, null, NOW], [2, 3, null, NOW], [3, 3, null, NOW]]),
    block(Q.repos, [P, L, A].map((x) => [textId(3, `${x.owner}/${x.repo}`), x.repoId, x.ownerId, 0, null, NOW, NOW])),
    block(Q.checks, [P, L, A].map((x) => [textId(3, `${x.owner}/${x.repo}`), null, null, NOW + HOUR, 0, 0]).sort((a, b) => (a[0] < b[0] ? -1 : 1))),
  ].join('');
  c.write();
}

// ---- case 2: the URL rules, the visibility, the candidate rules, the GitHub faults: nothing is written ----
function notCandidates() {
  const c = new Case('pu6-not-candidates', 'R-AP68 R-PU40 R-PU6 R-PU31 R-PU32 R-PU34 R-DI3 R-DI4 R-DI5 R-AP9 R-AP21 R-AP41 R-PU38');
  const H = rocHash(pkgBundle('the hash of the URL rules'));
  const bad = (u) => problem(422, '/errors/not-a-candidate', `the url is not a GitHub release asset URL with a version and a hash (https://github.com/<owner>/<repo>/releases/download/<tag>/<hash>.tar.zst): ${u}`);
  // # R-AP68 row 2, R-PU34 row 4, R-PU40 (Q155), R-DI5: the URL rules, before any D1 call and any GitHub call. Another host is refused (R-PU40).
  for (const [why, u] of [
    ['http', `http://github.com/t/r/releases/download/1.0.0/${H}.tar.zst`],
    ['no .tar.zst', `https://github.com/t/r/releases/download/1.0.0/${H}`],
    ['a hash of 31 bytes', `https://github.com/t/r/releases/download/1.0.0/${base58(Buffer.alloc(31, 7))}.tar.zst`],
    ['not releases/download', `https://github.com/t/r/releases/tag/1.0.0/${H}.tar.zst`],
    ['a path part more', `https://github.com/t/r/x/releases/download/1.0.0/${H}.tar.zst`],
    ['no version', `https://github.com/t/r/releases/download/latest/${H}.tar.zst`],
    ['two versions', `https://github.com/t/r-2.0.0/releases/download/1.0.0/${H}.tar.zst`],
    ['0.0.0', `https://github.com/t/r/releases/download/0.0.0/${H}.tar.zst`],
    ['a query', `https://github.com/t/r/releases/download/1.0.0/${H}.tar.zst?x=1`],
    ['another host (R-PU40)', `https://gitlab.com/acme/lib/-/releases/1.0.0/downloads/${H}.tar.zst`],
    ['www.github.com (R-PU40)', `https://www.github.com/acme/lib/releases/download/1.0.0/${H}.tar.zst`],
  ]) c.req(`url: ${why}`, post(u), bad(u), 0);
  const fresh = (repo, tag, h = H) => gh('t', repo, tag, h);
  const notPublic = problem(422, '/errors/not-a-candidate', 'repository not found or not public');
  // # R-AP68 row 6, R-PU31, R-PU32: a 404, private and internal give the one answer; no row is written (db.tsv), 1 D1 call (the pre-read)
  c.file('https://api.github.com/repos/t/gone', '{"message":"Not Found"}', { status: 404 });
  c.req('repository 404', post(fresh('gone', '1.0.0')), notPublic, 1); c.log.push('GET https://api.github.com/repos/t/gone');
  c.file('https://api.github.com/repos/t/secret', repoJson('t/secret', 601, 77, 'private'));
  // # R-AP68 (Q165): a problem answer has no talon-bookmark
  c.req('private', post(fresh('secret', '1.0.0')), { ...notPublic, headers: { 'talon-bookmark': null } }, 1); c.log.push('GET https://api.github.com/repos/t/secret');
  c.file('https://api.github.com/repos/t/inner', repoJson('t/inner', 602, 77, 'internal'));
  c.req('internal', post(fresh('inner', '1.0.0')), notPublic, 1); c.log.push('GET https://api.github.com/repos/t/inner');
  c.file('https://api.github.com/repos/t/flaky', '{"message":"boom"}', { status: 500 });
  c.req('repository 500', post(fresh('flaky', '1.0.0')), problem(502, '/errors/upstream', 'the GitHub repository read failed with status 500'), 1); c.log.push('GET https://api.github.com/repos/t/flaky');
  // # R-AP68 row 8, R-PU6, R-DI3, R-DI4, Q160: the release rules, after the visibility read
  const rel = (repo, tag, body, meta, expect, comment) => {
    c.file(`https://api.github.com/repos/t/${repo}`, repoJson(`t/${repo}`, 700 + c.reqs.length, 77));
    c.file(`https://api.github.com/repos/t/${repo}/releases/tags/${tag}`, body, meta);
    c.req(comment, post(fresh(repo, tag)), expect, 1);
    c.log.push(`GET https://api.github.com/repos/t/${repo}`, `GET https://api.github.com/repos/t/${repo}/releases/tags/${tag}`);
  };
  const nac = (d) => problem(422, '/errors/not-a-candidate', d);
  rel('nr', '1.0.0', '{"message":"Not Found"}', { status: 404 }, nac('the repository has no published release with the tag 1.0.0'), 'release 404');
  rel('dr', '1.0.0', releaseJson('1.0.0', [`${H}.tar.zst`], { draft: true, published_at: null }), null, nac('the release 1.0.0 is a draft'), 'draft');
  rel('pr', '1.0.0', releaseJson('1.0.0', [`${H}.tar.zst`], { prerelease: true }), null, nac('the release 1.0.0 is a prerelease'), 'prerelease');
  rel('na', '1.0.0', releaseJson('1.0.0', ['docs.tar.gz', `${H}.tar.zst.intoto.jsonl`]), null, nac('the release 1.0.0 has no package asset <hash>.tar.zst'), 'no package asset');
  rel('two', '1.0.0', releaseJson('1.0.0', [`${H}.tar.zst`, `${EXTRA_H}.tar.zst`]), null, nac('the release 1.0.0 has 2 package assets <hash>.tar.zst, not 1'), 'two package assets');
  rel('other', '1.0.0', releaseJson('1.0.0', [`${EXTRA_H}.tar.zst`]), null, nac(`the package asset of the release 1.0.0 is ${EXTRA_H}.tar.zst, not the asset of the url`), 'another asset');
  rel('nopub', '1.0.0', releaseJson('1.0.0', [`${H}.tar.zst`], { published_at: null }), null, problem(502, '/errors/upstream', 'the GitHub release answer is not valid'), 'published_at null');
  rel('rel500', '1.0.0', '{"message":"boom"}', { status: 503 }, problem(502, '/errors/upstream', 'the GitHub release read failed with status 503'), 'release 503');
  // # R-PU38 row 8 (slice 111 through the ingest): the asset at the URL has another hash
  const wrong = pkgBundle('not the bytes of the URL');
  c.file('https://api.github.com/repos/t/hm', repoJson('t/hm', 801, 77));
  c.file('https://api.github.com/repos/t/hm/releases/tags/1.0.0', releaseJson('1.0.0', [`${H}.tar.zst`]));
  c.file(fresh('hm', '1.0.0'), wrong);
  c.req('hash mismatch', post(fresh('hm', '1.0.0')), nac(`the BLAKE3 hash of the asset is ${rocHash(wrong)}, not the hash ${H} of the URL`), 1);
  c.log.push('GET https://api.github.com/repos/t/hm', 'GET https://api.github.com/repos/t/hm/releases/tags/1.0.0', `GET ${fresh('hm', '1.0.0')}`);
  // # R-AP68 row 9 (Q162): the release lists the asset, the asset read answers 404: 502, nothing written
  c.file('https://api.github.com/repos/t/a404', repoJson('t/a404', 803, 77));
  c.file('https://api.github.com/repos/t/a404/releases/tags/1.0.0', releaseJson('1.0.0', [`${H}.tar.zst`]));
  c.file(fresh('a404', '1.0.0'), 'Not Found', { status: 404 });
  c.req('asset 404', post(fresh('a404', '1.0.0')), problem(502, '/errors/upstream', 'the asset read failed with status 404'), 1);
  c.log.push('GET https://api.github.com/repos/t/a404', 'GET https://api.github.com/repos/t/a404/releases/tags/1.0.0', `GET ${fresh('a404', '1.0.0')}`);
  // # R-AP68 row 10 (Q161): a .roc-version read that fails is 502, and nothing is written
  const good = pkgBundle('a good package');
  const G = rocHash(good);
  c.file('https://api.github.com/repos/t/rv', repoJson('t/rv', 802, 77));
  c.file('https://api.github.com/repos/t/rv/releases/tags/1.0.0', releaseJson('1.0.0', [`${G}.tar.zst`]));
  c.file(gh('t', 'rv', '1.0.0', G), good);
  c.file('https://raw.githubusercontent.com/t/rv/1.0.0/.roc-version', 'boom', { status: 500 });
  c.req('.roc-version 500', post(gh('t', 'rv', '1.0.0', G)), problem(502, '/errors/upstream', 'the GitHub .roc-version read failed with status 500'), 1);
  c.reads('t', 'rv', '1.0.0', G);
  c.db = allEmpty();
  c.write();
}

// ---- case 3: an existing label: provenance, conflicts, the same version in another group, a race ----
function labels() {
  const c = new Case('pu14-pu19-labels', 'R-AP68 R-PU14 R-PU15 R-PU19 R-AP41 R-AP9 R-AP8 R-IK5 R-DI5 R-SG8 R-RE9 R-AP21');
  const A = rocHash(pkgBundle('label hash A'));
  const bundleB = pkgBundle('label hash B');
  const B = rocHash(bundleB);
  const form = 'github.com/acme/lib/releases/download/{v}/';
  const urlA = gh('acme', 'lib', '1.0.0', A);
  const repoName = 'acme/lib';
  // The seed: the label (form, 1.0.0) with hash A, indexed by the webhook (via 1), log leaf 1.
  c.seed = [
    `INSERT INTO names (id, kind, value) VALUES (${hashId(A)}, 1, X'${hex(A)}'), (${textId(2, form)}, 2, '${form}'), (${textId(3, repoName)}, 3, '${repoName}');`,
    `INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (${hashId(A)}, 1, '["Zeta","Alpha"]', NULL, NULL, 999);`,
    `INSERT INTO log (idx, grp, version, hash, time) VALUES (1, '${form}', '1.0.0', '${A}', 1767000000000);`,
    `INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (1, ${textId(2, form)}, ${versionCol('1.0.0')}, '', ${hashId(A)}, ${textId(3, repoName)}, '${urlA}', '1.0.0', NULL, ${PUB_MS}, 0, NULL, NULL);`,
    `INSERT INTO provenance (release, via, claims, time) VALUES (1, 1, NULL, 1767000000000);`,
    `INSERT INTO repos (repo, repository_id, repository_owner_id, state, successor, state_at, time) VALUES (${textId(3, repoName)}, 900, 9100, 0, NULL, 1767000000000, 1767000000000);`,
    `INSERT INTO repo_checks (repo, etag, checked_at, next_check_at, fail_count, app_installed) VALUES (${textId(3, repoName)}, NULL, NULL, 1767003600000, 0, 1);`,
  ].join('\n') + '\n';
  const recA = wire(1, { hash: A, form, version: '1.0.0', url: urlA, tag: '1.0.0', roc_version: null, repo: repoName });
  // The repository answer, read by requests 1, 5, 6, 7 and 8 (`%2F`, `%2F.2`, `%2F.3`, `%2F.4` private, `%2F.5`). Before the 3rd answer, "another request" writes the label 2.0.0 (race).
  c.file('https://api.github.com/repos/acme/lib', repoJson(repoName, 900, 9100));
  c.file('https://api.github.com/repos/acme/lib.2', repoJson(repoName, 900, 9100));
  c.file('https://api.github.com/repos/acme/lib.3', repoJson(repoName, 900, 9100));
  const D = rocHash(pkgBundle('the hash of the race'));
  c.files.set('api.github.com/repos/acme/lib.3.sql', [
    `INSERT INTO names (id, kind, value) VALUES (${hashId(D)}, 1, X'${hex(D)}');`,
    `INSERT INTO log (idx, grp, version, hash, time) VALUES (3, '${form}', '2.0.0', '${D}', 1767225600000);`,
    `INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (3, ${textId(2, form)}, ${versionCol('2.0.0')}, '', ${hashId(D)}, ${textId(3, repoName)}, '${gh('acme', 'lib', '2.0.0', D)}', '2.0.0', NULL, ${PUB_MS}, 0, NULL, NULL);`,
  ].join('\n') + '\n');
  // # R-AP68 row 7 (Q157), R-PU14, R-PU15: the label with the same hash and no ingest row: the visibility read only, then the provenance row; 200, 2 D1 calls
  c.req('same hash, new via: 200', post(urlA), ok(200, recA, A), 2);
  c.log.push('GET https://api.github.com/repos/acme/lib');
  // # R-PU14: again: 200, 1 D1 call, no GitHub read
  c.req('same hash again: 200', post(urlA), ok(200, recA, A), 1);
  // # R-AP68 row 4 (Q156), R-PU19: the tag released again with another hash: 409, no GitHub read, nothing written
  const conflict = (u) => problem(409, '/errors/label-conflict', `the label ${form} 1.0.0 has the hash ${A} in the index, not ${B}: release a new version`);
  // # R-AP68 (Q165): a problem answer has no talon-bookmark
  c.req('another hash: 409', post(gh('acme', 'lib', '1.0.0', B)), { ...conflict(), headers: { 'talon-bookmark': null } }, 1);
  // # R-IK5: 01.0.0 is the label 1.0.0 (roc compares the numbers): 409 too
  c.req('01.0.0: 409', post(gh('acme', 'lib', '01.0.0', B)), conflict(), 1);
  // # R-DI5: v1.0.0 is another group: no conflict, 201 with leaf 2
  const formV = 'github.com/acme/lib/releases/download/v{v}/';
  c.file('https://api.github.com/repos/acme/lib/releases/tags/v1.0.0', releaseJson('v1.0.0', [`${B}.tar.zst`]));
  c.file(gh('acme', 'lib', 'v1.0.0', B), bundleB);
  c.file('https://raw.githubusercontent.com/acme/lib/v1.0.0/.roc-version', 'Not Found', { status: 404 });
  c.req('v1.0.0: 201', post(gh('acme', 'lib', 'v1.0.0', B)), ok(201, wire(2, { hash: B, form: formV, version: '1.0.0', url: gh('acme', 'lib', 'v1.0.0', B), tag: 'v1.0.0', roc_version: null, repo: repoName }), B), 2);
  c.log.push('GET https://api.github.com/repos/acme/lib', 'GET https://api.github.com/repos/acme/lib/releases/tags/v1.0.0', `GET ${gh('acme', 'lib', 'v1.0.0', B)}`, 'GET https://raw.githubusercontent.com/acme/lib/v1.0.0/.roc-version');
  // # R-AP41 row 3, R-AP68 row 11 (Q164), R-SG8 rows 3 and 4: another request writes the label 2.0.0 (hash D) between the pre-read and the batch: 409, no leaf of this request
  const bundleC = pkgBundle('label hash C');
  const C = rocHash(bundleC);
  c.file('https://api.github.com/repos/acme/lib/releases/tags/2.0.0', releaseJson('2.0.0', [`${C}.tar.zst`]));
  c.file(gh('acme', 'lib', '2.0.0', C), bundleC);
  c.file('https://raw.githubusercontent.com/acme/lib/2.0.0/.roc-version', 'Not Found', { status: 404 });
  c.req('race: 409', post(gh('acme', 'lib', '2.0.0', C)), problem(409, '/errors/label-conflict', `the label ${form} 2.0.0 has another hash in the index, not ${C}: release a new version`), 2);
  c.reads('acme', 'lib', '2.0.0', C);
  // # R-AP68 row 7 (Q157): the label 3.0.0 (hash E) is in the index with webhook provenance only, and the repository is now private: 422, no provenance row
  const E = rocHash(pkgBundle('label hash E'));
  c.sql('the label 3.0.0 with hash E, webhook provenance', [
    `INSERT INTO names (id, kind, value) VALUES (${hashId(E)}, 1, X'${hex(E)}')`,
    `INSERT INTO log (idx, grp, version, hash, time) VALUES (4, '${form}', '3.0.0', '${E}', 1767100000000)`,
    `INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (4, ${textId(2, form)}, ${versionCol('3.0.0')}, '', ${hashId(E)}, ${textId(3, repoName)}, '${gh('acme', 'lib', '3.0.0', E)}', '3.0.0', NULL, ${PUB_MS}, 0, NULL, NULL)`,
    `INSERT INTO provenance (release, via, claims, time) VALUES (4, 1, NULL, 1767100000000)`,
  ]);
  c.file('https://api.github.com/repos/acme/lib.4', repoJson(repoName, 900, 9100, 'private'));
  c.req('known label, now private: 422', post(gh('acme', 'lib', '3.0.0', E)), { ...problem(422, '/errors/not-a-candidate', 'repository not found or not public'), headers: { 'talon-bookmark': null } }, 1);
  c.log.push('GET https://api.github.com/repos/acme/lib');
  // # R-SG8 rows 3, 4, R-AP41 row 3, Q86: another request writes the same label 5.0.0 with the same hash F between the pre-read and the batch (the 5th repository answer).
  // The leaf statement and the release statement skip by their WHERE NOT EXISTS: no second leaf, no second release. The batch adds the ingest provenance row: 200.
  const bundleF = pkgBundle('label hash F, same-hash race');
  const F = rocHash(bundleF);
  const urlF = gh('acme', 'lib', '5.0.0', F);
  c.file('https://api.github.com/repos/acme/lib.5', repoJson(repoName, 900, 9100));
  c.files.set('api.github.com/repos/acme/lib.5.sql', [
    `INSERT INTO names (id, kind, value) VALUES (${hashId(F)}, 1, X'${hex(F)}');`,
    `INSERT INTO log (idx, grp, version, hash, time) VALUES (5, '${form}', '5.0.0', '${F}', 1767225600000);`,
    `INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (5, ${textId(2, form)}, ${versionCol('5.0.0')}, '', ${hashId(F)}, ${textId(3, repoName)}, '${urlF}', '5.0.0', NULL, ${PUB_MS}, 0, NULL, NULL);`,
  ].join('\n') + '\n');
  c.file('https://api.github.com/repos/acme/lib/releases/tags/5.0.0', releaseJson('5.0.0', [`${F}.tar.zst`]));
  c.file(urlF, bundleF);
  c.file('https://raw.githubusercontent.com/acme/lib/5.0.0/.roc-version', 'Not Found', { status: 404 });
  c.req('same-hash race: 200', post(urlF), ok(200, wire(5, { hash: F, form, version: '5.0.0', url: urlF, tag: '5.0.0', roc_version: null, repo: repoName }), F), 2);
  c.reads('acme', 'lib', '5.0.0', F);
  c.db = [
    block(Q.log, [[1, form, '1.0.0', A, 1767000000000], [2, formV, '1.0.0', B, NOW], [3, form, '2.0.0', D, 1767225600000], [4, form, '3.0.0', E, 1767100000000], [5, form, '5.0.0', F, 1767225600000]]),
    block('SELECT log_index, CAST(artifact AS TEXT), tag FROM releases ORDER BY log_index', [[1, hashId(A), '1.0.0'], [2, hashId(B), 'v1.0.0'], [3, hashId(D), '2.0.0'], [4, hashId(E), '3.0.0'], [5, hashId(F), '5.0.0']]),
    block(Q.provenance, [[1, 1, null, 1767000000000], [1, 3, null, NOW], [2, 3, null, NOW], [4, 1, null, 1767100000000], [5, 3, null, NOW]]),
    // R-TP5, R-PU26: the rows of a known name do not change
    block(Q.repos, [[textId(3, repoName), 900, 9100, 0, null, 1767000000000, 1767000000000]]),
    block(Q.checks, [[textId(3, repoName), null, null, 1767003600000, 0, 1]]),
    // A, D (the race), B and the 2 dep hashes of B; nothing of C (the batch of the race rolled back)
    block("SELECT hex(value) FROM names WHERE kind = 1 ORDER BY 1", [A, B, D, E, F, SEMVER_H, EXTRA_H].map(hex).sort().map((h) => [h])),
  ].join('');
  c.write();
}

// ---- case 4: an id collision (R-IK3): 409 with the detail read (D1 call 3), nothing written ----
function collision() {
  const c = new Case('ik3-id-collision', 'R-AP68 R-IK3 R-AP21 R-AP41 R-AP9');
  const bundle = pkgBundle('the collision package');
  const H = rocHash(bundle);
  const Z = base58(Buffer.alloc(32, 0));
  // The seed: a name with the id of the hash H and another value (32 zero bytes), and a name with the id of the GitHub name acme/coll2 and another text.
  c.seed = [
    `INSERT INTO names (id, kind, value) VALUES (${hashId(H)}, 1, X'${'00'.repeat(32)}');`,
    `INSERT INTO names (id, kind, value) VALUES (${textId(3, 'acme/coll2')}, 3, 'someone/else');`,
  ].join('\n') + '\n';
  c.release({ owner: 'acme', repo: 'coll', tag: '1.0.0', asset: bundle, repoId: 1, ownerId: 2 });
  c.req('hash id taken', post(gh('acme', 'coll', '1.0.0', H)), problem(409, '/errors/id-collision', `the hash ${H} has the id ${hashId(H)} of the hash ${Z} in the index`), 3);
  c.reads('acme', 'coll', '1.0.0', H);
  const bundle2 = pkgBundle('the second collision package');
  const H2 = c.release({ owner: 'acme', repo: 'coll2', tag: '1.0.0', asset: bundle2, repoId: 3, ownerId: 2 });
  c.req('repository id taken', post(gh('acme', 'coll2', '1.0.0', H2)), problem(409, '/errors/id-collision', `the repository acme/coll2 has the id ${textId(3, 'acme/coll2')} of the repository someone/else in the index`), 3);
  c.reads('acme', 'coll2', '1.0.0', H2);
  c.db = [
    block(Q.names, [[hashId(H), 1, '00'.repeat(32)], [textId(3, 'acme/coll2'), 3, 'someone/else']]),
    ...['artifacts', 'deps', 'releases', 'log', 'provenance', 'repos', 'checks'].map((k) => block(Q[k], [])),
  ].join('');
  c.write();
}

// ---- case 5: the body and the route (R-AP26, R-AP48, R-AP51): no D1 call, no GitHub call ----
function body() {
  const c = new Case('ap26-body-and-route', 'R-AP68 R-AP26 R-AP48 R-AP51 R-AP21 R-AP23 R-AP41 R-AP9');
  const u = `https://github.com/t/r/releases/download/1.0.0/${EXTRA_H}.tar.zst`;
  const badBody = (why) => problem(400, '/errors/bad-request', `the body must be a JSON object with the member url (text): ${why}`);
  const notObj = badBody('the body is not a JSON object with a text member url');
  c.req('compat with no token', post(u, { json: { url: u, compat: [{ nightly: 'nightly-2026-10-31-f7bef6b', target: 'x64musl', result: 'pass' }] } }), problem(401, '/errors/unauthenticated', 'a body with compat needs a GitHub OIDC token (tln publish)'), 0);
  c.req('compat empty list', post(u, { json: { url: u, compat: [] } }), problem(401, '/errors/unauthenticated'), 0);
  // R-AP51: compat null is no value, so this is an ingest; the URL rule then refuses it (no D1 call)
  const nov = 'https://github.com/t/r/releases/download/latest/x.tar.zst';
  c.req('compat null', post(nov, { json: { url: nov, compat: null } }), problem(422, '/errors/not-a-candidate'), 0);
  c.req('no body', { method: 'POST', path: '/v1/releases', now: NOW }, badBody('the body is empty'), 0);
  c.req('{}', { method: 'POST', path: '/v1/releases', json: {}, now: NOW }, notObj, 0);
  c.req('url null', { method: 'POST', path: '/v1/releases', json: { url: null }, now: NOW }, notObj, 0);
  c.req('url a number', { method: 'POST', path: '/v1/releases', json: { url: 5 }, now: NOW }, notObj, 0);
  c.req('an array', { method: 'POST', path: '/v1/releases', json: [u], now: NOW }, notObj, 0);
  c.req('not JSON', { method: 'POST', path: '/v1/releases', body: 'url=x', headers: { 'content-type': 'application/json' }, now: NOW }, notObj, 0);
  c.req('text/plain', { method: 'POST', path: '/v1/releases', body: JSON.stringify({ url: u }), headers: { 'content-type': 'text/plain' }, now: NOW }, problem(415, '/errors/unsupported-media-type'), 0);
  c.req('PATCH', { method: 'PATCH', path: '/v1/releases', now: NOW }, { status: 405, headers: { allow: 'GET, POST' }, problem: { type: '/errors/method-not-allowed' } }, 0);
  c.req('unknown members are ignored (R-AP44)', post(nov, { json: { url: nov, extra: { a: 1 } } }), problem(422, '/errors/not-a-candidate'), 0);
  c.write();
}

rmSync(casesDir, { recursive: true, force: true });
mkdirSync(casesDir, { recursive: true });
kinds();
notCandidates();
labels();
collision();
body();
console.log(`wrote ${casesDir}`);
