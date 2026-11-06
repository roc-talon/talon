// The W2 case of slice 125 (the platform mark of a dep, Registry R-AP81, R-PU38 row 13, Design Q251, Q400): worker/tests/cases/ingest/pu38-platform-mark/.
//   node worker/tests/tools/mk-platform-mark.mjs     writes that one case dir (github/, requests.jsonl, notes.txt, rules, expect/)
// It writes only its own dir. mk-ingest.mjs is older than some hand edits of the ingest cases (slice 122 added `provenance`), so do not run it again.
// The expected values come from the design, computed here with no Roc code: name_id (R-IK2), the version column (R-IK5), the BLAKE3 hash (Design 2).
import { createHash } from 'node:crypto';
import { mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { tar, zstd } from './mk-bundle.mjs';
import { rocHash } from './blake3.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const dir = join(here, '..', 'cases', 'ingest', 'pu38-platform-mark');

const B58 = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
function b58decode(s) {
  let n = 0n;
  for (const c of s) n = n * 58n + BigInt(B58.indexOf(c));
  const out = [];
  while (n > 0n) { out.unshift(Number(n & 255n)); n >>= 8n; }
  for (const c of s) { if (c === '1') out.unshift(0); else break; }
  return Buffer.from(out);
}
const nameId = (kind, bytes) => createHash('sha256').update(Buffer.concat([Buffer.from([kind]), Buffer.from(bytes)])).digest().readBigInt64BE(0).toString();
const hashId = (h) => nameId(1, b58decode(h));
const textId = (kind, t) => nameId(kind, Buffer.from(t, 'utf8'));
const versionCol = (v) => {
  const [a, b, c] = v.split('.').map(BigInt);
  return BigInt.asIntN(64, ((a << 48n) | (b << 32n) | (c << 16n) | 0xFFFFn) ^ (1n << 63n)).toString();
};
const hex = (h) => b58decode(h).toString('hex').toUpperCase();

const SEMVER_H = 'BzgH68Q1yBkg7F1ZpFsiEg73ZwkaBrFdcLpX2pUkay9i';
const SEMVER = `https://github.com/Karakatiza666/roc-semver/releases/download/0.2.0/${SEMVER_H}.tar.zst`;
const SEMVER_FORM = 'github.com/Karakatiza666/roc-semver/releases/download/{v}/';
const PLAT_H = 'LGNEVuRQZ539pc52dydViRcsnjP2rUxEFyXNfRRESHk';
const PLAT = `https://github.com/acme/plat/releases/download/v0.3.0/${PLAT_H}.tar.zst`;
const PLAT_FORM = 'github.com/acme/plat/releases/download/v{v}/';
const OTHER_H = 'C6Jtcve7FRNtkwgmuyRBJnZfJyTrfJWhDcLp6gk4w4Gz';
const OTHER = `https://example.com/pkgs/${OTHER_H}.tar.zst`;
const mod = (name) => `${name} :: [].{\n\tx : U64\n\tx = 1\n}\n`;
// A package with a platform entry `pf` and a plain dep.
const pkg = zstd(tar([
  { path: 'main.roc', data: `## A made package of slice 125: one platform entry.\npackage\n\t[\n\t\tZeta,\n\t]\n\t{\n\t\tpf: platform "${PLAT}",\n\t\tsemver: "${SEMVER}",\n\t}\n` },
  { path: 'Zeta.roc', data: mod('Zeta') },
]));
// A package with 2 platform entries: roc refuses it (`multiple_platforms`).
const two = zstd(tar([
  { path: 'main.roc', data: `## A made package of slice 125: two platform entries.\npackage\n\t[\n\t\tZeta,\n\t]\n\t{\n\t\tpf: platform "${PLAT}",\n\t\tpf2: platform "${OTHER}",\n\t}\n` },
  { path: 'Zeta.roc', data: mod('Zeta') },
]));

const NOW = 1767225630000;
const PUB = '2026-10-20T12:00:00Z';
const PUB_MS = Date.parse(PUB);
const HOUR = 3600000;
const gh = (owner, repo, tag, hash) => `https://github.com/${owner}/${repo}/releases/download/${tag}/${hash}.tar.zst`;
const repoJson = (full, id, ownerId) => JSON.stringify({ id, name: full.split('/')[1], full_name: full, private: false, owner: { login: full.split('/')[0], id: ownerId, type: 'Organization' }, description: null, visibility: 'public', default_branch: 'main' });
const releaseJson = (tag, assets) => JSON.stringify({ id: 1, tag_name: tag, name: null, draft: false, prerelease: false, created_at: PUB, published_at: PUB, body: null, assets: assets.map((name, i) => ({ id: i + 1, name, label: null, content_type: 'application/octet-stream', state: 'uploaded', size: 10, digest: null })) });
const post = (url) => ({ method: 'POST', path: '/v1/releases', json: { url }, now: NOW });
const N = '\\N';
const block = (q, rows) => `@ ${q}\n${rows.map((r) => r.map((c) => (c === null ? N : String(c))).join('\t')).join('\n')}${rows.length ? '\n' : ''}`;
const Q = {
  names: 'SELECT CAST(id AS TEXT), kind, CASE kind WHEN 1 THEN hex(value) ELSE value END FROM names ORDER BY kind, 3',
  artifacts: 'SELECT CAST(artifact AS TEXT), kind, exposes, CAST(platform AS TEXT), roc_pin, size FROM artifacts ORDER BY kind',
  deps: 'SELECT CAST(artifact AS TEXT), alias, CAST(dep AS TEXT), CAST(form AS TEXT), CAST(version AS TEXT), version_text, url, platform FROM deps ORDER BY alias',
  targets: 'SELECT CAST(a.artifact AS TEXT), t.target, t.name FROM artifact_targets a JOIN targets t ON t.target = a.target ORDER BY t.target',
  newTargets: 'SELECT target, name FROM targets WHERE target >= 36 ORDER BY target',
  releases: 'SELECT log_index, CAST(form AS TEXT), CAST(version AS TEXT), version_text, CAST(artifact AS TEXT), CAST(repo AS TEXT), url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at FROM releases ORDER BY log_index',
  log: 'SELECT idx, grp, version, hash, time FROM log ORDER BY idx',
  provenance: 'SELECT release, via, claims, time FROM provenance ORDER BY release, via',
  repos: 'SELECT CAST(repo AS TEXT), repository_id, repository_owner_id, state, successor, state_at, time FROM repos ORDER BY repository_id',
  checks: 'SELECT CAST(repo AS TEXT), etag, checked_at, next_check_at, fail_count, app_installed FROM repo_checks ORDER BY 1',
};

const files = new Map();
const put = (url, body, meta) => {
  const u = new URL(url);
  const enc = (s) => s.replace(/[%?:\\*<>|"]/g, (c) => `%${c.charCodeAt(0).toString(16).toUpperCase().padStart(2, '0')}`);
  const p = [enc(u.host), ...u.pathname.split('/').filter(Boolean).map(enc)].join('/');
  files.set(p, body);
  if (meta) files.set(`${p}.meta.json`, JSON.stringify(meta));
};
const log = [];
const reads = (owner, repo, tag, hash, withRocVersion) => {
  log.push(`GET https://api.github.com/repos/${owner}/${repo}`, `GET https://api.github.com/repos/${owner}/${repo}/releases/tags/${tag}`, `GET ${gh(owner, repo, tag, hash)}`);
  if (withRocVersion) log.push(`GET https://raw.githubusercontent.com/${owner}/${repo}/${tag}/.roc-version`);
};

// Request 1: the package with a platform entry. Request 2: its record. Request 3: the package with 2 platform entries.
const P = { owner: 'acme', repo: 'pfpkg', tag: '1.0.0', form: 'github.com/acme/pfpkg/releases/download/{v}/', repoId: 511, ownerId: 9001 };
P.hash = rocHash(pkg);
put(`https://api.github.com/repos/${P.owner}/${P.repo}`, repoJson('acme/pfpkg', P.repoId, P.ownerId));
put(`https://api.github.com/repos/${P.owner}/${P.repo}/releases/tags/${P.tag}`, releaseJson(P.tag, [`${P.hash}.tar.zst`]));
put(gh(P.owner, P.repo, P.tag, P.hash), pkg);
put(`https://raw.githubusercontent.com/${P.owner}/${P.repo}/${P.tag}/.roc-version`, 'Not Found', { status: 404 });
const T = { owner: 'acme', repo: 'twopf', tag: '1.0.0', repoId: 512, ownerId: 9001 };
T.hash = rocHash(two);
put(`https://api.github.com/repos/${T.owner}/${T.repo}`, repoJson('acme/twopf', T.repoId, T.ownerId));
put(`https://api.github.com/repos/${T.owner}/${T.repo}/releases/tags/${T.tag}`, releaseJson(T.tag, [`${T.hash}.tar.zst`]));
put(gh(T.owner, T.repo, T.tag, T.hash), two);

const release = { log_index: 1, provenance: ['ingest'], hash: P.hash, group: P.form, series: '1', version: '1.0.0', url: gh(P.owner, P.repo, P.tag, P.hash), tag: P.tag, roc_version: null, repo: 'acme/pfpkg', published_at: PUB_MS, yanked: false, yank_reason: null, withdrawn: null };
const reqs = [
  post(gh(P.owner, P.repo, P.tag, P.hash)),
  { method: 'GET', path: `/v1/artifacts/${P.hash}`, now: NOW },
  post(gh(T.owner, T.repo, T.tag, T.hash)),
];
const notes = ['package with a platform entry: 201', 'read the package artifact: pf has the mark, semver has not', 'package with 2 platform entries: 422 not-a-candidate'];
const exp = [
  { status: 201, headers: { 'content-type': 'application/json', 'cache-control': 'no-store', 'x-d1-session': 'first-primary', location: `/v1/artifacts/${P.hash}` }, headers_set: ['talon-bookmark'], json: { release } },
  {
    status: 200,
    json: {
      artifact: {
        hash: P.hash, kind: 'package', exposed: ['Zeta'], platform_hash: null, roc_pin: null, size: pkg.length, target_names: [],
        deps: [
          { alias: 'pf', hash: PLAT_H, group: PLAT_FORM, is_platform: true, series: '0.3', version: '0.3.0', url: PLAT },
          { alias: 'semver', hash: SEMVER_H, group: SEMVER_FORM, is_platform: false, series: '0.2', version: '0.2.0', url: SEMVER },
        ],
      },
      releases: [release],
      repos: [{ name: 'acme/pfpkg', state: 'active', successor: null }],
    },
  },
  { status: 422, problem: { type: '/errors/not-a-candidate', detail: 'main.roc has more than one platform entry (roc refuses it: multiple_platforms): pf, pf2' } },
];
const calls = [2, 1, 1];
reads(P.owner, P.repo, P.tag, P.hash, true);
reads(T.owner, T.repo, T.tag, T.hash, false);

// Rows after the 3 requests: only the first package is written (a refused ingest writes nothing, R-PU32).
const byKind = (a, b) => a[1] - b[1] || (a[2] < b[2] ? -1 : a[2] > b[2] ? 1 : 0);
const names = [
  ...[P.hash, PLAT_H, SEMVER_H].map((h) => [hashId(h), 1, hex(h)]),
  ...[P.form, PLAT_FORM, SEMVER_FORM].map((f) => [textId(2, f), 2, f]),
  [textId(3, 'acme/pfpkg'), 3, 'acme/pfpkg'],
].sort(byKind);
const db = [
  block(Q.names, names),
  block(Q.artifacts, [[hashId(P.hash), 1, '["Zeta"]', null, null, pkg.length]]),
  block(Q.deps, [
    [hashId(P.hash), 'pf', hashId(PLAT_H), textId(2, PLAT_FORM), versionCol('0.3.0'), '', PLAT, 1],
    [hashId(P.hash), 'semver', hashId(SEMVER_H), textId(2, SEMVER_FORM), versionCol('0.2.0'), '', SEMVER, 0],
  ]),
  block(Q.targets, []),
  block(Q.newTargets, []),
  block(Q.releases, [[1, textId(2, P.form), versionCol('1.0.0'), '', hashId(P.hash), textId(3, 'acme/pfpkg'), gh(P.owner, P.repo, P.tag, P.hash), P.tag, null, PUB_MS, 0, null, null]]),
  block(Q.log, [[1, P.form, '1.0.0', P.hash, NOW]]),
  block(Q.provenance, [[1, 3, null, NOW]]),
  block(Q.repos, [[textId(3, 'acme/pfpkg'), P.repoId, P.ownerId, 0, null, NOW, NOW]]),
  block(Q.checks, [[textId(3, 'acme/pfpkg'), null, null, NOW + HOUR, 0, 0]]),
].join('');

rmSync(dir, { recursive: true, force: true });
for (const [k, v] of files) {
  // A file whose path is also a dir (the repository beside its releases) is the file `%2F` in that dir (run.mjs).
  const base = k.replace(/(\.meta\.json)?$/, '');
  const isDir = [...files.keys()].some((o) => o.startsWith(`${base}/`));
  const name = isDir ? `${base}/%2F${k.slice(base.length)}` : k;
  mkdirSync(dirname(join(dir, 'github', name)), { recursive: true });
  writeFileSync(join(dir, 'github', name), v);
}
mkdirSync(join(dir, 'expect'), { recursive: true });
writeFileSync(join(dir, 'rules'), 'R-AP81 R-PU38 R-RE19 R-AP49 R-AP2 R-AP68 R-AP9 R-AP41 R-AP21 R-PU32 R-IK2 R-IK3 R-IK5\n');
writeFileSync(join(dir, 'requests.jsonl'), reqs.map((r) => JSON.stringify(r)).join('\n') + '\n');
writeFileSync(join(dir, 'notes.txt'), notes.map((n, i) => `${i + 1}: ${n}`).join('\n') + '\n');
writeFileSync(join(dir, 'expect', 'responses.jsonl'), exp.map((r) => JSON.stringify(r)).join('\n') + '\n');
writeFileSync(join(dir, 'expect', 'd1-calls'), calls.join('\n') + '\n');
writeFileSync(join(dir, 'expect', 'github.log'), log.join('\n') + '\n');
writeFileSync(join(dir, 'expect', 'db.tsv'), db);
console.log(`wrote ${dir}`);

