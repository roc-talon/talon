// The W2 cases of slice 114 (the publish `POST /v1/releases` with an OIDC token, Registry R-AP8, R-AP26, R-AP71, R-PU1, R-PU2, R-PU5, R-PU16, R-TP3, R-TP5, R-TP6, R-TP17, R-MX5, R-RE3;
// docs/slices/114-publish.md section 4).
//   node worker/tests/tools/mk-publish.mjs     writes worker/tests/cases/publish/*/ (github/, seed.sql, requests.jsonl, tokens.json, settings.json, expect/, rules, notes.txt)
// The files are tracked. Run the script again only when a case changes: the hashes are in the names and in the expected files.
// The ids (R-IK2), the version columns (R-IK5), the nightly ids (R-IK4), the hashes (BLAKE3) and the recorded claims (R-TP6) are computed here with node, not with the Roc code.
import { createHash } from 'node:crypto';
import { mkdirSync, writeFileSync, rmSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { tar, zstd } from './mk-bundle.mjs';
import { rocHash } from './blake3.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const casesDir = join(here, '..', 'cases', 'publish');
const baseClaims = JSON.parse(readFileSync(join(here, '..', 'oidc', 'claims-publish.json'), 'utf8'));
const botClaims = JSON.parse(readFileSync(join(here, '..', 'oidc', 'claims-bot.json'), 'utf8'));
const JWKS = readFileSync(join(here, '..', 'oidc', 'jwks.json'), 'utf8');

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
const nameId = (kind, bytes) => createHash('sha256').update(Buffer.concat([Buffer.from([kind]), Buffer.from(bytes)])).digest().readBigInt64BE(0).toString(); // R-IK2
const hashId = (h) => nameId(1, b58decode(h));
const textId = (kind, t) => nameId(kind, Buffer.from(t, 'utf8'));
const repoId = (name) => textId(3, name);
const versionCol = (v) => { const [a, b, c] = v.split('.').map(BigInt); return BigInt.asIntN(64, ((a << 48n) | (b << 32n) | (c << 16n) | 0xFFFFn) ^ (1n << 63n)).toString(); }; // R-IK5
const nightlyId = (t) => { const [, y, m, d, s] = t.split('-'); return Number(BigInt(Math.round(Date.UTC(+y, +m - 1, +d) / 86400000)) * 268435456n + BigInt(parseInt(s, 16))); }; // R-IK4
const hex = (h) => b58decode(h).toString('hex').toUpperCase();
const sq = (s) => `'${String(s).replace(/'/g, "''")}'`;
const series = (v) => { const [a, b] = v.split('.'); return a === '0' ? `0.${b}` : a; };
const enc = (t) => [...Buffer.from(t, 'utf8')].map((b) => (/[A-Za-z0-9\-._~]/.test(String.fromCharCode(b)) ? String.fromCharCode(b) : `%${b.toString(16).toUpperCase().padStart(2, '0')}`)).join('');

// ---- the made bundles: one package for each release, a note makes the hash ----
const EXTRA_H = 'C6Jtcve7FRNtkwgmuyRBJnZfJyTrfJWhDcLp6gk4w4Gz';
const mod = (name) => `${name} :: [].{\n\tx : U64\n\tx = 1\n}\n`;
const pkg = (note) => zstd(tar([
  { path: 'main.roc', data: `## ${note}\npackage\n\t[\n\t\tAlpha,\n\t]\n\t{\n\t\textra: "https://example.com/pkgs/${EXTRA_H}.tar.zst",\n\t}\n` },
  { path: 'Alpha.roc', data: mod('Alpha') },
]));

// ---- constants of the cases ----
const NOW = 1767225630000; // the clock of each request (inside nbf and exp of the test tokens)
const SEED_T = 1767000000000;
const PUB = '2026-10-20T12:00:00Z';
const PUB_MS = Date.parse(PUB);
const HOUR = 3600000;
const ISSUES = 'https://github.com/roc-talon/talon/issues';
const AUD = 'https://registry.example';
const N1 = 'nightly-2026-10-31-f7bef6b';
const N2 = 'nightly-2026-10-14-38a3029';
const N3 = 'nightly-2026-10-09-258ab27';
const gh = (name, tag, hash) => `https://github.com/${name}/releases/download/${tag}/${hash}.tar.zst`;
const formOf = (name, tag) => `github.com/${name}/releases/download/${tag.startsWith('v') ? 'v' : ''}{v}/`;
const releaseJson = (tag, hash, { draft = false } = {}) => JSON.stringify({ id: 1, tag_name: tag, name: null, draft, prerelease: false, created_at: PUB, published_at: draft ? null : PUB, body: null, assets: [{ id: 1, name: `${hash}.tar.zst`, label: null, content_type: 'application/octet-stream', state: 'uploaded', size: 10, digest: null }] });
const NOT_FOUND = '{"message":"Not Found"}';
const ISSUES_HEADER = { 'talon-bookmark': null };

// The recorded claims of R-TP6 as the Worker writes them (Q298, the text of the slice file section 5): 8 members in this order, a missing claim is null.
const CLAIMS_KEYS = ['workflow_ref', 'workflow_sha', 'job_workflow_ref', 'event_name', 'run_id', 'run_attempt', 'actor_id', 'runner_environment'];
const claimsJson = (c) => `{${CLAIMS_KEYS.map((k) => `${JSON.stringify(k)}:${c[k] === undefined ? 'null' : JSON.stringify(c[k])}`).join(',')}}`;

// A fact of the body (R-AP71) and the same fact as a row of `compat`.
const fact = (nightly, result, digest = null, target = 'any') => ({ nightly, target, result, error_digest: digest });
const RESULT = { pass: 0, fail: 1, hang: 2, crash: 3 };

class Case {
  constructor(name, rules) { this.name = name; this.rules = rules; this.files = new Map(); this.reqs = []; this.exp = []; this.calls = []; this.log = []; this.seed = []; this.db = ''; this.notes = []; this.tokens = {}; this.settings = { AUDIENCE: AUD, ISSUES_URL: ISSUES }; this.claims = {}; }
  file(url, body, meta, suffix = '') {
    const u = new URL(url);
    const e = (s) => s.replace(/[%?:\\*<>|"]/g, (c) => `%${c.charCodeAt(0).toString(16).toUpperCase().padStart(2, '0')}`);
    const p = [e(u.host), ...u.pathname.split('/').filter(Boolean).map(e)].join('/');
    this.files.set(`${p}${suffix}`, body);
    if (meta) this.files.set(`${p}${suffix}.meta.json`, JSON.stringify(meta));
  }
  hook(url, sql) { this.file(url, sql, null, '.sql'); }
  // A token by name: the claims of the publish base with the changes (null removes a claim). The merged claims are kept for the expected `claims` text.
  token(name, changes = {}, spec = {}) {
    const claims = { ...baseClaims };
    for (const [k, v] of Object.entries(changes)) { if (v === null) delete claims[k]; else claims[k] = v; }
    this.tokens[name] = { base: 'publish', claims: changes, ...spec };
    this.claims[name] = claims;
    return claims;
  }
  // The token of a repository release: repository, ref and ids as a GitHub token has them. `extra` changes more claims.
  tokenFor(name, repository, tag, rid, oid, extra = {}) {
    return this.token(name, { repository, ref: `refs/tags/${tag}`, repository_id: String(rid), repository_owner_id: String(oid), ...extra });
  }
  recorded(name) { return claimsJson(this.claims[name]); }
  // The GitHub of one release: the release by tag, the asset, `.roc-version` (404). No repository read (the visibility is a claim, R-PU31).
  release({ name, tag, note, draft = false }) {
    const asset = pkg(note);
    const hash = rocHash(asset);
    const [o, r] = name.split('/');
    this.file(`https://api.github.com/repos/${name}/releases/tags/${tag}`, releaseJson(tag, hash, { draft }));
    this.file(gh(name, tag, hash), asset);
    this.file(`https://raw.githubusercontent.com/${o}/${r}/${tag}/.roc-version`, 'Not Found', { status: 404 });
    return hash;
  }
  jwks() { this.log.push('GET https://token.actions.githubusercontent.com/.well-known/jwks'); }
  reads(name, tag, hash) {
    const [o, r] = name.split('/');
    this.log.push(`GET https://api.github.com/repos/${name}/releases/tags/${tag}`, `GET ${gh(name, tag, hash)}`, `GET https://raw.githubusercontent.com/${o}/${r}/${tag}/.roc-version`);
  }
  req(comment, spec, expect, calls) { this.reqs.push(spec); this.exp.push(expect); this.calls.push(String(calls)); this.notes.push(comment); }
  write() {
    const dir = join(casesDir, this.name);
    rmSync(dir, { recursive: true, force: true });
    this.file('https://token.actions.githubusercontent.com/.well-known/jwks', JWKS);
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
    writeFileSync(join(dir, 'settings.json'), `${JSON.stringify(this.settings)}\n`);
    writeFileSync(join(dir, 'tokens.json'), `${JSON.stringify(this.tokens, null, 1)}\n`);
    writeFileSync(join(dir, 'requests.jsonl'), this.reqs.map((r) => JSON.stringify(r)).join('\n') + '\n');
    writeFileSync(join(dir, 'notes.txt'), this.notes.map((n, i) => `${i + 1}: ${n}`).join('\n') + '\n');
    writeFileSync(join(dir, 'expect', 'responses.jsonl'), this.exp.map((r) => JSON.stringify(r)).join('\n') + '\n');
    writeFileSync(join(dir, 'expect', 'd1-calls'), this.calls.join('\n') + '\n');
    writeFileSync(join(dir, 'expect', 'github.log'), this.log.join('\n') + '\n');
    if (this.seed.length) writeFileSync(join(dir, 'seed.sql'), this.seed.join('\n') + '\n');
    writeFileSync(join(dir, 'expect', 'db.tsv'), this.db);
  }
  // A bound name before the case: the `names` row, the `repos` row, the `repo_checks` row and the event bind (seq 1) of an earlier path (claims NULL).
  bound(name, { id, owner, state = 0, stateAt = SEED_T }) {
    this.seed.push(
      `INSERT INTO names (id, kind, value) VALUES (${repoId(name)}, 3, ${sq(name)});`,
      `INSERT INTO repos (repo, repository_id, repository_owner_id, state, successor, state_at, time) VALUES (${repoId(name)}, ${id}, ${owner}, ${state}, NULL, ${stateAt}, ${SEED_T});`,
      `INSERT INTO repo_checks (repo, etag, checked_at, next_check_at, fail_count, app_installed) VALUES (${repoId(name)}, NULL, NULL, ${SEED_T + HOUR}, 0, 0);`,
      `INSERT INTO repo_events (repo, seq, action, repository_id_before, repository_id_after, owner_id_before, owner_id_after, successor, claims, time) VALUES (${repoId(name)}, 1, 0, NULL, ${id}, NULL, ${owner}, NULL, NULL, ${SEED_T});`,
    );
  }
  // A release of the label with the hash, the log leaf, and a provenance row of `via` (1 webhook, 3 ingest): a label that an earlier path indexed.
  indexed(name, tag, hash, { idx = 1, via = 3 } = {}) {
    const form = formOf(name, tag);
    const version = tag.replace(/^v/, '');
    this.seed.push(
      `INSERT INTO names (id, kind, value) VALUES (${hashId(hash)}, 1, X'${hex(hash)}'), (${textId(2, form)}, 2, ${sq(form)});`,
      `INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (${hashId(hash)}, 1, '["Alpha"]', NULL, NULL, 999);`,
      `INSERT INTO log (idx, grp, version, hash, time) VALUES (${idx}, ${sq(form)}, ${sq(version)}, ${sq(hash)}, ${SEED_T});`,
      `INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (${idx}, ${textId(2, form)}, ${versionCol(version)}, '', ${hashId(hash)}, ${repoId(name)}, ${sq(gh(name, tag, hash))}, ${sq(tag)}, NULL, ${PUB_MS}, 0, NULL, NULL);`,
      `INSERT INTO provenance (release, via, claims, time) VALUES (${idx}, ${via}, NULL, ${SEED_T});`,
    );
  }
}

// ---- requests and answers ----
const publish = (token, url, compat, extra = {}) => ({ method: 'POST', path: '/v1/releases', json: compat === undefined ? { url } : { url, compat }, token, now: NOW, ...extra });
const problem = (status, type, detail) => ({ status, problem: detail === undefined ? { type } : { type, detail } });
const wire = (log_index, { hash, form, version, tag, repo }) => ({ log_index, hash, group: form, series: series(version), version, tag, repo });
const okRelease = (status, release) => ({
  status,
  headers: { 'content-type': 'application/json', 'cache-control': 'no-store', 'x-d1-session': 'first-primary', location: status === 201 ? `/v1/artifacts/${release.hash}` : null },
  headers_set: ['talon-bookmark'],
  json: { release },
});
const changed = (name, id) => ({
  status: 403,
  headers: ISSUES_HEADER,
  problem: { type: '/errors/repository-changed', title: 'Repository changed', status: 403, detail: `the name ${name} is bound to another GitHub account (repository id ${id})` },
  json: { issues_url: ISSUES },
});

// The db.tsv blocks. The names are text (a join with `names`), so the file reads without the ids. NULL is \N (run.mjs).
const Q = {
  releases: 'SELECT r.log_index, n.value, r.tag, r.withdrawn FROM releases r JOIN names n ON n.id = r.repo ORDER BY r.log_index',
  log: 'SELECT idx, grp, version, hash, time FROM log ORDER BY idx',
  provenance: 'SELECT release, via, claims, time FROM provenance ORDER BY release, via',
  compat: 'SELECT CAST(artifact AS TEXT), nightly, target, source, result, error_digest, time, log_index FROM compat ORDER BY nightly, target, source',
  repos: 'SELECT n.value, r.repository_id, r.repository_owner_id, r.state, (SELECT s.value FROM names s WHERE s.id = r.successor), r.state_at, r.time FROM repos r JOIN names n ON n.id = r.repo ORDER BY n.value',
  events: 'SELECT n.value, e.seq, e.action, e.repository_id_before, e.repository_id_after, e.owner_id_before, e.owner_id_after, (SELECT s.value FROM names s WHERE s.id = e.successor), e.claims, e.time FROM repo_events e JOIN names n ON n.id = e.repo ORDER BY n.value, e.seq',
  checks: 'SELECT n.value, c.etag, c.checked_at, c.next_check_at, c.fail_count, c.app_installed FROM repo_checks c JOIN names n ON n.id = c.repo ORDER BY n.value',
  kinds: 'SELECT kind, COUNT(*) FROM names GROUP BY kind ORDER BY kind',
};
const block = (q, rows) => `@ ${q}\n${rows.map((r) => r.map((c) => (c === null ? '\\N' : String(c))).join('\t')).join('\n')}${rows.length ? '\n' : ''}`;
const byName = (a, b) => (a[0] < b[0] ? -1 : a[0] > b[0] ? 1 : 0) || (a[1] - b[1]);
const seededRepo = (name, id, owner) => [name, id, owner, 0, null, SEED_T, SEED_T];
const seededBind = (name, id, owner) => [name, 1, 0, null, id, null, owner, null, null, SEED_T];

// ---- case 1: a publish of a new package with facts, the same publish again, a new fact, the cache drop ----
function publishPackage() {
  const c = new Case('pu1-publish-package', 'R-AP8 R-AP26 R-AP41 R-AP75 R-AP69 R-AP43 R-AP71 R-PU1 R-PU2 R-PU5 R-PU15 R-PU26 R-TP3 R-TP5 R-TP6 R-TP13 R-TP17 R-MX5 R-RE3 R-RE9 R-RE15 R-IK5 R-SG8');
  const NAME = 'acme/roc-json';
  const TAG = '1.2.0';
  const form = formOf(NAME, TAG);
  const hash = c.release({ name: NAME, tag: TAG, note: 'slice 114 package' });
  const url = gh(NAME, TAG, hash);
  // # R-TP3 row 4: the repository claim is compared with no case (Acme/Roc-Json is acme/roc-json). The ids 812345 and 612345 are the claims of the base token.
  c.token('pub', { repository: 'Acme/Roc-Json' });
  const f1 = fact(N1, 'pass');
  const f2 = fact(N2, 'fail', 'boom: E0001');
  const rec = wire(1, { hash, form, version: TAG, tag: TAG, repo: NAME });
  const groupPath = `/v1/releases?group=${enc(form)}`;
  const get = (path, extra = {}) => ({ method: 'GET', path, now: NOW, ...extra });
  // # R-AP69, R-AP43: the group read before the publish is an empty list; the Cache API keeps it for 60 s
  c.req('read the group: empty', get(groupPath), { status: 200, json_len: { releases: 0 } }, 1);
  // # R-AP8, R-PU2, R-PU1: a publish of a new release: 201, Location, the record, the bookmark, 2 D1 calls (R-AP41); the GitHub reads are the JWKS, the release, the asset, .roc-version
  // (no GET of the repository: the ids and the visibility are claims, R-PU31, R-TP5). R-PU5, R-AP71: 3 facts, 2 distinct keys
  c.req('package with facts: 201', publish('pub', url, [f1, f2, f1]), okRelease(201, rec), 2);
  c.jwks();
  c.reads(NAME, TAG, hash);
  c.reqs.push({ wait_ms: 300 });
  // # R-AP69: the 201 dropped the cache entry of the group (Response.after): the next read has the release
  c.req('read the group: the release', get(groupPath), { status: 200, json_len: { releases: 1 } }, 1);
  // # R-PU14, R-AP71 (R-RE13 row 1): the same publish again, the same facts: 200 with the same record, 2 D1 calls (the facts are written again and change nothing), no GitHub read
  c.req('same publish again: 200', publish('pub', url, [f1, f2, f1]), okRelease(200, rec), 2);
  // # R-PU14: no facts, an oidc row there: the answer of the pre-read, 1 D1 call, no write
  c.req('no facts: 200 and 1 D1 call', publish('pub', url), okRelease(200, rec), 1);
  // # R-AP71, R-RE13 row 1: the first write of a key wins. N3 is a new key; N1 has another result now (hang) and is not changed. 200, 2 D1 calls, a later time
  c.req('a new fact and an old key: 200', publish('pub', url, [fact(N3, 'crash', 'x'), fact(N1, 'hang')], { now: NOW + 5000 }), okRelease(200, rec), 2);
  const claims = c.recorded('pub');
  const rid = hashId(hash);
  c.db = [
    block(Q.releases, [[1, NAME, TAG, null]]),
    block(Q.log, [[1, form, TAG, hash, NOW]]),
    // # R-PU15, R-TP6, R-RE9: one provenance row, via 0 (oidc), with the 8 claims; R-PU14: the repeats added no row
    block(Q.provenance, [[1, 0, claims, NOW]]),
    // # R-PU5, R-RE3, R-MX5: the author facts: source 1, the hash of the asset, the log index of the release, the time of the request that wrote the key (N3 later), the first result of N1
    block(Q.compat, [[rid, nightlyId(N3), 0, 1, RESULT.crash, 'x', NOW + 5000, 1], [rid, nightlyId(N2), 0, 1, RESULT.fail, 'boom: E0001', NOW, 1], [rid, nightlyId(N1), 0, 1, RESULT.pass, null, NOW, 1]]),
    // # R-TP5, R-TP13, Q163: the first release of the name binds it to the ids of the claims; the event bind carries the claims of the token (R-TP13)
    block(Q.repos, [[NAME, 812345, 612345, 0, null, NOW, NOW]]),
    block(Q.events, [[NAME, 1, 0, null, 812345, null, 612345, null, claims, NOW]]),
    block(Q.checks, [[NAME, null, null, NOW + HOUR, 0, 0]]),
  ].join('');
  c.write();
}

// ---- case 2: a label that an ingest indexed first (R-PU16), 409, the order of 403 and 409, a transfer, a draft, a 404, a race ----
function afterIngest() {
  const c = new Case('pu16-after-ingest', 'R-AP8 R-AP41 R-AP71 R-PU1 R-PU14 R-PU15 R-PU16 R-PU19 R-TP3 R-TP5 R-TP9 R-TP12 R-TP13 R-TP6 R-RE3 R-RE9 R-RE15 R-SG8 R-AP21');
  const NAME = 'acme/lib';
  const T = '1.0.0';
  const form = formOf(NAME, T);
  const A = rocHash(pkg('slice 114 label A'));
  const B = rocHash(pkg('slice 114 label B'));
  c.bound(NAME, { id: 900, owner: 9100 });
  c.indexed(NAME, T, A, { via: 3 });
  const rec = wire(1, { hash: A, form, version: T, tag: T, repo: NAME });
  c.tokenFor('ok', NAME, T, 900, 9100, { event_name: 'release', run_id: '201' });
  c.tokenFor('both', NAME, T, 1, 2, { run_id: '202' });
  c.tokenFor('xfer', NAME, T, 900, 777, { run_id: '203' });
  const urlA = gh(NAME, T, A);
  // # R-PU16, R-PU14, R-AP71: the label was indexed by an ingest; a publish with the same hash adds the oidc row and the facts and answers 200: 2 D1 calls, no GitHub read (the JWKS only)
  c.req('indexed label, same hash, a fact: 200', publish('ok', urlA, [fact(N1, 'pass')]), okRelease(200, rec), 2);
  c.jwks();
  // # R-PU14: now there is an oidc row and no fact: the answer of the pre-read, 1 D1 call
  c.req('again with no compat: 200 and 1 D1 call', publish('ok', urlA), okRelease(200, rec), 1);
  // # R-PU19, R-AP8: the label with another hash: 409, the detail names the hash in the index; 1 D1 call; no bookmark (Q165); no fact is written
  const conflict = { status: 409, headers: ISSUES_HEADER, problem: { type: '/errors/label-conflict', detail: `the label ${form} 1.0.0 has the hash ${A} in the index, not ${B}: release a new version` } };
  c.req('another hash: 409', publish('ok', gh(NAME, T, B), [fact(N2, 'pass')]), conflict, 1);
  // # R-TP3 row 5 (Q267), R-TP9 row 4: both ids of the token differ from the row: 403 repository-changed with issues_url, and this comes before the 409 of the label; 1 D1 call; no bookmark
  c.req('both ids differ, another hash: 403 before 409', publish('both', gh(NAME, T, B)), changed(NAME, 900), 1);
  // # R-TP3 row 5, R-TP9 row 2: one id equal (the repository id), the owner id is another: a transfer. The label has an oidc row and no fact, but the identity has an event, so there is a write:
  // 200, 2 D1 calls, the row gets the owner id 777, the event transfer carries the claims of this token
  c.req('transfer, indexed label: 200', publish('xfer', urlA), okRelease(200, rec), 2);
  // The next requests use the new owner id 777.
  c.tokenFor('draft', NAME, '2.0.0', 900, 777, { run_id: '204' });
  c.tokenFor('gone', NAME, '2.1.0', 900, 777, { run_id: '205' });
  c.tokenFor('race', NAME, '3.0.0', 900, 777, { run_id: '206' });
  // # R-PU16: a draft is 422 not-a-candidate; the detail says draft and what to do. The release read only (no asset read), 1 D1 call, nothing written
  const C = c.release({ name: NAME, tag: '2.0.0', note: 'slice 114 draft', draft: true });
  c.req('draft: 422', publish('draft', gh(NAME, '2.0.0', C)), problem(422, '/errors/not-a-candidate', 'the release 2.0.0 is a draft: publish the GitHub release before tln publish'), 1);
  c.log.push(`GET https://api.github.com/repos/${NAME}/releases/tags/2.0.0`);
  // # R-PU16: the Worker cannot see a draft of a repository that the App does not read: the release read is 404, and the detail names the draft
  c.file(`https://api.github.com/repos/${NAME}/releases/tags/2.1.0`, NOT_FOUND, { status: 404 });
  c.req('release 404: 422', publish('gone', gh(NAME, '2.1.0', C)), problem(422, '/errors/not-a-candidate', 'the repository has no published release with the tag 2.1.0: a draft is not published, so publish the GitHub release before tln publish'), 1);
  c.log.push(`GET https://api.github.com/repos/${NAME}/releases/tags/2.1.0`);
  // # R-AP41 row 3, R-SG8, Design Q164: another request writes the label 3.0.0 with hash E between D1 call 1 and the batch (the hook runs before the release answer). The trigger stops the batch:
  // 409 "another hash", 2 D1 calls, nothing of this request is written (no oidc row, no fact, no names row of D)
  const D = c.release({ name: NAME, tag: '3.0.0', note: 'slice 114 race D' });
  const E = rocHash(pkg('slice 114 race E'));
  const formR = formOf(NAME, '3.0.0');
  c.hook(`https://api.github.com/repos/${NAME}/releases/tags/3.0.0`, [
    `INSERT INTO names (id, kind, value) VALUES (${hashId(E)}, 1, X'${hex(E)}');`,
    `INSERT INTO log (idx, grp, version, hash, time) VALUES (2, ${sq(formR)}, '3.0.0', ${sq(E)}, ${NOW});`,
    `INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (2, ${textId(2, formR)}, ${versionCol('3.0.0')}, '', ${hashId(E)}, ${repoId(NAME)}, ${sq(gh(NAME, '3.0.0', E))}, '3.0.0', NULL, ${PUB_MS}, 0, NULL, NULL);`,
  ].join('\n') + '\n');
  c.req('race: 409 another hash', publish('race', gh(NAME, '3.0.0', D), [fact(N1, 'pass')]), { status: 409, headers: ISSUES_HEADER, problem: { type: '/errors/label-conflict', detail: `the label ${formR} 3.0.0 has another hash in the index, not ${D}: release a new version` } }, 2);
  c.reads(NAME, '3.0.0', D);
  c.db = [
    block(Q.releases, [[1, NAME, T, null], [2, NAME, '3.0.0', null]]),
    block(Q.log, [[1, form, T, A, SEED_T], [2, formR, '3.0.0', E, NOW]]),
    // # R-PU15: the label has both rows: the ingest row of the seed and the oidc row of the first request (the claims of the first token); R-PU16
    block(Q.provenance, [[1, 0, c.recorded('ok'), NOW], [1, 3, null, SEED_T]]),
    block(Q.compat, [[hashId(A), nightlyId(N1), 0, 1, RESULT.pass, null, NOW, 1]]),
    // # R-TP9 row 2: the owner id is 777 now; state_at does not change for a transfer. The row of the first binding is not changed otherwise.
    block(Q.repos, [[NAME, 900, 777, 0, null, SEED_T, SEED_T]]),
    block(Q.events, [seededBind(NAME, 900, 9100), [NAME, 2, 1, 900, 900, 9100, 777, null, c.recorded('xfer'), NOW]]),
    block(Q.checks, [[NAME, null, null, SEED_T + HOUR, 0, 0]]),
    // names of kind 1: the hashes A and E only (the failed batch wrote no name of D), kind 2: the one group (the label 3.0.0 has the same group), kind 3: the repository
    block(Q.kinds, [[1, 2], [2, 1], [3, 1]]),
  ].join('');
  c.write();
}

// ---- case 3: the checks before the token, and the claims against the URL and the ids: all refused with 0 D1 calls ----
function claimChecks() {
  const c = new Case('tp3-claims-vs-url', 'R-AP26 R-AP46 R-AP48 R-AP51 R-AP71 R-AP75 R-AP21 R-MX5 R-PU34 R-TP3 R-TP4 R-TP6 R-TP17 R-TP16 R-AP41');
  const NAME = 'acme/roc-json';
  const TAG = '1.2.0';
  const H = rocHash(pkg('slice 114 claims'));
  const url = gh(NAME, TAG, H);
  c.tokens.junk = { raw: 'not.a.token' };
  const withClaim = (name, changes, spec) => c.token(name, changes, spec);
  withClaim('tamper', {}, { tamper: 'signature' });
  withClaim('aud_slash', { aud: `${AUD}/` });
  withClaim('other_repo', { repository: 'acme/other' });
  c.tokens.bot = { base: 'bot' };
  withClaim('private', { repository_visibility: 'private' });
  withClaim('branch', { ref_type: 'branch' });
  withClaim('other_tag', { ref: 'refs/tags/9.9.9' });
  withClaim('pr_target', { event_name: 'pull_request_target' });
  withClaim('schedule', { event_name: 'schedule' });
  withClaim('bad_id', { repository_id: '12a' });
  withClaim('ref_and_id', { ref: 'refs/heads/main', repository_id: '12a' });
  withClaim('no_owner', { repository_owner_id: null });
  const f = fact(N1, 'pass');
  const bad = (type) => ({ status: type === 'too-large' ? 413 : type === 'not-a-candidate' ? 422 : 400, problem: { type: `/errors/${type}` } });
  // # The checks before the token (R-AP48 rows 4 to 6, R-AP66 Q144, R-AP71 "Order"): a request with a token that is no token gets the 400, 413 or 422 of its body, with no JWKS read
  c.req('static: no url (400)', publish('junk', undefined, undefined, { json: {} }), bad('bad-request'), 0);
  c.req('static: 501 facts (413)', publish('junk', url, Array.from({ length: 501 }, () => f)), { ...bad('too-large'), json: { field: 'compat', limit: 500 }, problem: { type: '/errors/too-large', detail: 'the compat member of the publish request has more than 500 facts' } }, 0);
  const hashFact = { ...f, hash: H };
  // # R-AP71, R-MX5 (Q176): a fact with hash or source, with any value, an escaped key too: 400, the detail names the members
  const named = problem(400, '/errors/bad-request', 'the publish request body is not valid: member hash or source is not allowed in a fact');
  c.req('static: hash in a fact (400)', publish('junk', url, [hashFact]), named, 0);
  c.reqs.push({ ...publish('junk', url), json: undefined, body: `{"url":"${url}","compat":[{"nightly":"${N1}","target":"any","result":"pass","error_digest":null,"so\\u0075rce":"bot"}]}`, headers: { 'content-type': 'application/json' } });
  c.exp.push(named); c.calls.push('0'); c.notes.push('static: an escaped source key in a fact (400)');
  c.req('static: a bad result (400)', publish('junk', url, [fact(N1, 'bogus')]), problem(400, '/errors/bad-request', 'the result bogus of a fact is not pass, fail, hang or crash'), 0);
  c.req('static: target not any (400)', publish('junk', url, [fact(N1, 'pass', null, 'linux_x64')]), problem(400, '/errors/bad-request', 'the target linux_x64 of a fact is not any'), 0);
  // # R-PU34 row 4: the URL rules, before the token as in the ingest (Q290, R-AP75 row 6): another host is 422 not-a-candidate
  const urlBad = `https://gitlab.com/acme/lib/-/releases/1.0.0/downloads/${H}.tar.zst`;
  c.req('static: another host (422)', publish('junk', urlBad), problem(422, '/errors/not-a-candidate', `the url is not a GitHub release asset URL with a version and a hash (https://github.com/<owner>/<repo>/releases/download/<tag>/<hash>.tar.zst): ${urlBad}`), 0);
  // # R-AP26: an Authorization header that is not "Bearer <token>" is 401, never an ingest
  c.req('Basic: 401', { ...publish('junk', url), token: undefined, headers: { authorization: 'Basic abc' } }, problem(401, '/errors/unauthenticated', 'the Authorization header must be "Bearer <token>"'), 0);
  const unauth = (d) => problem(401, '/errors/unauthenticated', d);
  c.req('not a JWT: 401', publish('junk', url), unauth('the token is not a valid JWT'), 0);
  // # R-TP3 row 1: a changed signature (the first JWKS read); R-TP17, R-TP3 row 2: aud with a trailing / is not the AUDIENCE
  c.req('bad signature: 401', publish('tamper', url), unauth('the token signature is not valid'), 0);
  c.jwks();
  c.req('aud with /: 401', publish('aud_slash', url), unauth(`token claim aud is "${AUD}/", expected "${AUD}"`), 0);
  const forbidden = (d) => problem(403, '/errors/forbidden', d);
  // # R-TP3 row 4: the repository claim is not the repository of the URL; R-MX5, R-TP7: a token of the compat bot cannot publish
  c.req('other repository: 403', publish('other_repo', url), forbidden('token claim repository is "acme/other", expected "acme/roc-json"'), 0);
  c.req('bot token: 403', publish('bot', url), forbidden(`token claim repository is "${botClaims.repository}", expected "acme/roc-json"`), 0);
  // # R-TP3 rows 6 to 8 (R-TP4): visibility, ref_type, ref, event_name
  c.req('private: 403', publish('private', url), forbidden('token claim repository_visibility is "private", expected "public"'), 0);
  c.req('branch: 403', publish('branch', url), forbidden('token claim ref_type is "branch", expected "tag"'), 0);
  c.req('other tag: 403', publish('other_tag', url), forbidden('token claim ref is "refs/tags/9.9.9", expected "refs/tags/1.2.0"'), 0);
  const events = 'expected "release", "push" or "workflow_dispatch"';
  c.req('pull_request_target: 403', publish('pr_target', url), forbidden(`token claim event_name is "pull_request_target", ${events}`), 0);
  c.req('schedule: 403', publish('schedule', url), forbidden(`token claim event_name is "schedule", ${events}`), 0);
  // # R-TP3 row 5: the ids are claims; one that is not a number, and one that is missing, are 403 (Q293, R-AP75 row 8), before any D1 call
  c.req('repository_id not a number: 403', publish('bad_id', url), forbidden('token claim repository_id is "12a", expected a number'), 0);
  c.req('repository_owner_id missing: 403', publish('no_owner', url), forbidden('token claim repository_owner_id is missing'), 0);
  // # R-AP75 rows 5, 6 (Q290, Q295): the fact values come before the URL rules. A bad result and a URL of another host: the 400 of the result, not the 422
  c.req('static: a bad result and another host (400)', publish('junk', urlBad, [fact(N1, 'bogus')]), problem(400, '/errors/bad-request', 'the result bogus of a fact is not pass, fail, hang or crash'), 0);
  // # R-AP75 rows 7, 8 (Q293): the claim rows 4 to 8 come before the form of the id claims. A ref that is not the tag and a repository_id that is not a number: the 403 of ref
  c.req('ref wrong and id not a number: 403 of ref', publish('ref_and_id', url), forbidden('token claim ref is "refs/heads/main", expected "refs/tags/1.2.0"'), 0);
  c.db = [block(Q.releases, []), block(Q.provenance, []), block(Q.compat, []), block(Q.repos, [])].join('');
  c.write();
}

// ---- case 4: the identity of the repository with the ids of the claims (R-TP9, R-TP10, R-TP13): a transfer, a recreate, a rename, a new binding, 403 ----
function identity() {
  const c = new Case('tp9-claim-ids', 'R-TP3 R-TP5 R-TP6 R-TP9 R-TP10 R-TP12 R-TP13 R-TP18 R-RE11 R-RE15 R-PU26 R-AP8 R-AP41 R-AP21');
  const T = '1.0.0';
  c.bound('xfer/repo', { id: 2001, owner: 21 });
  c.bound('again/repo', { id: 3001, owner: 31 });
  c.bound('taken/repo', { id: 4001, owner: 41 });
  c.bound('old/repo', { id: 6001, owner: 61 });
  const rows = [
    { name: 'xfer/repo', rid: 2001, oid: 22, run: '301' },
    { name: 'again/repo', rid: 3002, oid: 31, run: '302' },
    { name: 'taken/repo', rid: 9999, oid: 99, run: '303' },
    { name: 'fresh/repo', rid: 5001, oid: 51, run: '304' },
    { name: 'new/repo', rid: 6001, oid: 61, run: '305' },
  ];
  const hashes = {};
  for (const x of rows) {
    c.tokenFor(x.name, x.name, T, x.rid, x.oid, { run_id: x.run });
    if (x.name !== 'taken/repo') hashes[x.name] = c.release({ name: x.name, tag: T, note: `slice 114 identity ${x.name}` });
  }
  const takenHash = rocHash(pkg('slice 114 identity taken'));
  const [xfer, again, taken, fresh, rename] = rows;
  // # R-TP9 row 2: the same repository id, another owner id (claims): 201, the owner id changes, event 2 transfer with the claims of the token. 2 D1 calls. The JWKS is read once.
  c.req('transfer: 201', publish(xfer.name, gh(xfer.name, T, hashes[xfer.name])), okRelease(201, wire(1, { hash: hashes[xfer.name], form: formOf(xfer.name, T), version: T, tag: T, repo: xfer.name })), 2);
  c.jwks(); c.reads(xfer.name, T, hashes[xfer.name]);
  // # R-TP9 row 3: the same owner id, another repository id: 201, the row gets the new repository id, event 3 recreate with the claims
  c.req('recreate: 201', publish(again.name, gh(again.name, T, hashes[again.name])), okRelease(201, wire(2, { hash: hashes[again.name], form: formOf(again.name, T), version: T, tag: T, repo: again.name })), 2);
  c.reads(again.name, T, hashes[again.name]);
  // # R-TP9 row 4, R-TP3 row 5 (Q267), R-TP12: both ids differ: 403 repository-changed with issues_url, 1 D1 call, no GitHub read, no bookmark, nothing written
  c.req('both ids differ: 403', publish(taken.name, gh(taken.name, T, takenHash)), changed(taken.name, 4001), 1);
  // # R-TP5, R-TP13, Q163: no row: the first release binds the name to the ids of the claims, event 0 bind with the claims, a repo_checks row (R-PU26)
  c.req('no row: 201 and bind', publish(fresh.name, gh(fresh.name, T, hashes[fresh.name])), okRelease(201, wire(3, { hash: hashes[fresh.name], form: formOf(fresh.name, T), version: T, tag: T, repo: fresh.name })), 2);
  c.reads(fresh.name, T, hashes[fresh.name]);
  // # R-TP10, R-TP18 row 1 (the claim `repository` is the current name, so F is U): new/repo has no row and old/repo has the repository id: new/repo is active with a rename event, old/repo is moved
  // with the successor new/repo and a rename event; the events carry the claims of the token
  c.req('rename: 201', publish(rename.name, gh(rename.name, T, hashes[rename.name])), okRelease(201, wire(4, { hash: hashes[rename.name], form: formOf(rename.name, T), version: T, tag: T, repo: rename.name })), 2);
  c.reads(rename.name, T, hashes[rename.name]);
  const cl = (n) => c.recorded(n);
  c.db = [
    block(Q.releases, [[1, xfer.name, T, null], [2, again.name, T, null], [3, fresh.name, T, null], [4, rename.name, T, null]]),
    block(Q.repos, [
      ['again/repo', 3002, 31, 0, null, SEED_T, SEED_T], ['fresh/repo', 5001, 51, 0, null, NOW, NOW], ['new/repo', 6001, 61, 0, null, NOW, NOW],
      ['old/repo', 6001, 61, 2, 'new/repo', NOW, SEED_T], ['taken/repo', 4001, 41, 0, null, SEED_T, SEED_T], ['xfer/repo', 2001, 22, 0, null, SEED_T, SEED_T],
    ]),
    block(Q.events, [
      seededBind('again/repo', 3001, 31), ['again/repo', 2, 3, 3001, 3002, 31, 31, null, cl('again/repo'), NOW],
      ['fresh/repo', 1, 0, null, 5001, null, 51, null, cl('fresh/repo'), NOW],
      ['new/repo', 1, 2, null, 6001, null, 61, null, cl('new/repo'), NOW],
      seededBind('old/repo', 6001, 61), ['old/repo', 2, 2, 6001, 6001, 61, 61, 'new/repo', cl('new/repo'), NOW],
      seededBind('taken/repo', 4001, 41),
      seededBind('xfer/repo', 2001, 21), ['xfer/repo', 2, 1, 2001, 2001, 21, 22, null, cl('xfer/repo'), NOW],
    ].sort(byName)),
    block(Q.checks, ['again/repo', 'old/repo', 'taken/repo', 'xfer/repo'].map((n) => [n, null, null, SEED_T + HOUR, 0, 0]).concat([['fresh/repo', null, null, NOW + HOUR, 0, 0], ['new/repo', null, null, NOW + HOUR, 0, 0]]).sort(byName)),
    block(Q.provenance, [1, 2, 3, 4].map((i, k) => [i, 0, cl(['xfer/repo', 'again/repo', 'fresh/repo', 'new/repo'][k]), NOW])),
  ].join('');
  c.write();
}

rmSync(casesDir, { recursive: true, force: true });
mkdirSync(casesDir, { recursive: true });
publishPackage();
afterIngest();
claimChecks();
identity();
console.log(`wrote ${casesDir}`);
