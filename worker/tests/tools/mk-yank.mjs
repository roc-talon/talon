// The W2 cases of slice 246 (the yank routes `PUT` and `DELETE /v1/releases/{log_index}/yank`, Registry R-YK1 to R-YK7, R-TP8, R-RE10; docs/slices/246-yank.md section 4).
//   node worker/tests/tools/mk-yank.mjs     writes worker/tests/cases/yank/*/ (seed.sql, requests.jsonl, tokens.json, settings.json, expect/, rules, notes.txt)
// The files are tracked. Run the script again only when a case changes. The ids (R-IK2), the version columns (R-IK5) and the recorded claims (R-TP6) are computed here with node, not with the Roc code.
import { createHash } from 'node:crypto';
import { mkdirSync, writeFileSync, rmSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const casesDir = join(here, '..', 'cases', 'yank');
const baseClaims = JSON.parse(readFileSync(join(here, '..', 'oidc', 'claims-publish.json'), 'utf8'));

// ---- the facts of the design, in JS (as mk-publish.mjs) ----
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
const hex = (h) => b58decode(h).toString('hex').toUpperCase();
const sq = (s) => `'${String(s).replace(/'/g, "''")}'`;
const series = (v) => { const [a, b] = v.split('.'); return a === '0' ? `0.${b}` : a; };
const enc = (t) => [...Buffer.from(t, 'utf8')].map((b) => (/[A-Za-z0-9\-._~]/.test(String.fromCharCode(b)) ? String.fromCharCode(b) : `%${b.toString(16).toUpperCase().padStart(2, '0')}`)).join('');

// ---- constants ----
const NOW = 1767225630000; // inside nbf and exp of the test tokens (exp is 270 s later)
const SEED_T = 1767000000000;
const PUB_MS = Date.parse('2026-10-20T12:00:00Z');
const HOUR = 3600000;
const ISSUES = 'https://github.com/roc-talon/talon/issues';
const AUD = 'https://registry.example';
const KEY = 'op-key-7f3a9c1e5b2d4086';
const H1 = '3g6pdQ6Y66osX1c5BJXrWnGNJWpqTrXCLT3cSfANdbdg';
const H2 = 'FfhdJC6hjGYxLT2it8N1ipqaofCXs4K6AQLt9zzEKNLG';
const H4 = 'BRmpv6YTMiaiZ2QGbqkS1vu2JQgvDtAU1fQgneszmsG5';
const H5 = '7g5vLtvCFggx7WD6fr6GMEcXV4X2e8gt3dUrksZhJFC6';
const gh = (name, tag, hash) => `https://github.com/${name}/releases/download/${tag}/${hash}.tar.zst`;
const formOf = (name) => `github.com/${name}/releases/download/{v}/`;
const CLAIMS_KEYS = ['workflow_ref', 'workflow_sha', 'job_workflow_ref', 'event_name', 'run_id', 'run_attempt', 'actor_id', 'runner_environment'];
const claimsJson = (c) => `{${CLAIMS_KEYS.map((k) => `${JSON.stringify(k)}:${c[k] === undefined ? 'null' : JSON.stringify(c[k])}`).join(',')}}`;
const JWKS_LINE = 'GET https://token.actions.githubusercontent.com/.well-known/jwks';

// The releases of the world (the seed). idx: log index. `repo` null: another host.
const REL = {
  1: { idx: 1, name: 'acme/lib', tag: '1.0.0', hash: H1 },
  2: { idx: 2, name: 'acme/lib', tag: '2.0.0', hash: H2 },
  4: { idx: 4, name: 'acme/other', tag: '1.0.0', hash: H4 },
  5: { idx: 5, name: null, tag: null, hash: H5, host: 'example.com/pkg', version: '1.0.0' },
};
const relUrl = (r) => (r.name === null ? `https://${r.host}/${r.version}/${r.hash}.tar.zst` : gh(r.name, r.tag, r.hash));
const relForm = (r) => (r.name === null ? `${r.host}/{v}/` : formOf(r.name));
const relVersion = (r) => (r.name === null ? r.version : r.tag);
const GROUP1 = enc(formOf('acme/lib'));

class Case {
  constructor(name, rules, settings = {}) {
    this.name = name; this.rules = rules; this.reqs = []; this.exp = []; this.calls = []; this.notes = []; this.seed = []; this.log = []; this.db = ''; this.tokens = {}; this.claims = {};
    this.settings = { AUDIENCE: AUD, ISSUES_URL: ISSUES, OPERATOR_KEY: KEY, ...settings };
    this.yanked = new Map(); // log index -> { yanked, reason }: the state that the cases expect in the answers
  }
  // A token for the repository `name`: the publish base with the claims of a manual run (R-TP8: workflow_dispatch, a branch ref).
  token(tname, changes = {}) {
    const all = { repository: 'acme/lib', repository_id: '900', repository_owner_id: '9100', event_name: 'workflow_dispatch', ref: 'refs/heads/main', ref_type: 'branch', ...changes };
    const claims = { ...baseClaims };
    for (const [k, v] of Object.entries(all)) { if (v === null) delete claims[k]; else claims[k] = v; }
    this.tokens[tname] = { base: 'publish', claims: all };
    this.claims[tname] = claims;
  }
  recorded(tname) { return claimsJson(this.claims[tname]); }
  bound(name, id, owner) {
    this.seed.push(
      `INSERT INTO names (id, kind, value) VALUES (${repoId(name)}, 3, ${sq(name)});`,
      `INSERT INTO repos (repo, repository_id, repository_owner_id, state, successor, state_at, time) VALUES (${repoId(name)}, ${id}, ${owner}, 0, NULL, ${SEED_T}, ${SEED_T});`,
      `INSERT INTO repo_checks (repo, etag, checked_at, next_check_at, fail_count, app_installed) VALUES (${repoId(name)}, NULL, NULL, ${SEED_T + HOUR}, 0, 0);`,
      `INSERT INTO repo_events (repo, seq, action, repository_id_before, repository_id_after, owner_id_before, owner_id_after, successor, claims, time) VALUES (${repoId(name)}, 1, 0, NULL, ${id}, NULL, ${owner}, NULL, NULL, ${SEED_T});`,
    );
  }
  release(r) {
    const form = relForm(r);
    const version = relVersion(r);
    this.seed.push(
      `INSERT OR IGNORE INTO names (id, kind, value) VALUES (${textId(2, form)}, 2, ${sq(form)});`,
      `INSERT INTO names (id, kind, value) VALUES (${hashId(r.hash)}, 1, X'${hex(r.hash)}');`,
      `INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (${hashId(r.hash)}, 1, '["Alpha"]', NULL, NULL, 999);`,
      `INSERT INTO log (idx, grp, version, hash, time) VALUES (${r.idx}, ${sq(form)}, ${sq(version)}, ${sq(r.hash)}, ${SEED_T});`,
      `INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (${r.idx}, ${textId(2, form)}, ${versionCol(version)}, '', ${hashId(r.hash)}, ${r.name === null ? 'NULL' : repoId(r.name)}, ${sq(relUrl(r))}, ${r.tag === null ? 'NULL' : sq(r.tag)}, NULL, ${PUB_MS}, 0, NULL, NULL);`,
      `INSERT INTO provenance (release, via, claims, time) VALUES (${r.idx}, 3, NULL, ${SEED_T});`,
    );
  }
  // A log leaf that is no release (a compiler leaf, R-YK1 404).
  leaf(idx) {
    this.seed.push(`INSERT INTO log (idx, grp, version, hash, time) VALUES (${idx}, 'roc-lang/nightlies:linux_x86_64', 'nightly-2026-10-31-f7bef6b', 'sha256:${'ab'.repeat(32)}', ${SEED_T});`);
  }
  world(indexes) {
    this.bound('acme/lib', 900, 9100);
    this.bound('acme/other', 800, 8100);
    for (const i of indexes) this.release(REL[i]);
  }
  req(comment, spec, expect, calls) { this.reqs.push(spec); this.exp.push(expect); this.calls.push(String(calls)); this.notes.push(comment); }
  wait(ms = 300) { this.reqs.push({ wait_ms: ms }); this.notes.push(`(wait ${ms} ms: the cache drop after the answer)`); }
  jwks() { this.log.push(JWKS_LINE); }
  write() {
    const dir = join(casesDir, this.name);
    rmSync(dir, { recursive: true, force: true });
    mkdirSync(join(dir, 'expect'), { recursive: true });
    writeFileSync(join(dir, 'rules'), `${this.rules}\n`);
    writeFileSync(join(dir, 'settings.json'), `${JSON.stringify(this.settings)}\n`);
    writeFileSync(join(dir, 'tokens.json'), `${JSON.stringify(this.tokens, null, 1)}\n`);
    writeFileSync(join(dir, 'requests.jsonl'), this.reqs.map((r) => JSON.stringify(r)).join('\n') + '\n');
    writeFileSync(join(dir, 'notes.txt'), this.notes.map((n, i) => `${i + 1}: ${n}`).join('\n') + '\n');
    writeFileSync(join(dir, 'expect', 'responses.jsonl'), this.exp.map((r) => JSON.stringify(r)).join('\n') + '\n');
    writeFileSync(join(dir, 'expect', 'd1-calls'), this.calls.join('\n') + '\n');
    writeFileSync(join(dir, 'expect', 'github.log'), this.log.length ? this.log.join('\n') + '\n' : '');
    writeFileSync(join(dir, 'seed.sql'), this.seed.join('\n') + '\n');
    writeFileSync(join(dir, 'expect', 'db.tsv'), this.db);
    // The case dir has the github/ dir with the JWKS (the fake GitHub): the same file as the publish cases.
    mkdirSync(join(dir, 'github', 'token.actions.githubusercontent.com', '.well-known'), { recursive: true });
    writeFileSync(join(dir, 'github', 'token.actions.githubusercontent.com', '.well-known', 'jwks'), readFileSync(join(here, '..', 'oidc', 'jwks.json'), 'utf8'));
  }
}

// ---- requests and answers ----
const path = (idx) => `/v1/releases/${idx}/yank`;
const put = (idx, who, json, now) => ({ method: 'PUT', path: path(idx), ...(json === undefined ? {} : { json }), ...auth(who), now });
const del = (idx, who, now) => ({ method: 'DELETE', path: path(idx), ...auth(who), now });
const auth = (who) => (who === 'op' ? { headers: { authorization: `Bearer ${KEY}` } } : who === undefined ? {} : { token: who });
const problem = (status, type, detail, extra = {}) => ({ status, problem: detail === undefined ? { type } : { type, detail }, ...extra });
// The release record of R-AP49 for the seed release `i`, with the yank state.
const record = (i, yanked, reason) => {
  const r = REL[i];
  const version = relVersion(r);
  return { log_index: i, provenance: ['ingest'], hash: r.hash, group: relForm(r), series: series(version), version, tag: r.tag, repo: r.name, url: relUrl(r), published_at: PUB_MS, roc_version: null, withdrawn: null, yanked, yank_reason: reason };
};
const ok = (i, yanked, reason) => ({
  status: 200,
  headers: { 'content-type': 'application/json', 'cache-control': 'no-store' },
  d1_session: 'first-primary',
  headers_set: ['talon-bookmark'],
  json: { release: record(i, yanked, reason) },
});
const reads = (c, label, yanked, reason) => {
  const g = `/v1/releases?group=${GROUP1}`;
  const want = { 'releases.0.yanked': yanked, 'releases.0.yank_reason': reason };
  c.req(`${label}: the group read`, { method: 'GET', path: g }, { status: 200, json_len: { releases: 1 }, json_at: want }, '-');
  c.req(`${label}: the group and series read`, { method: 'GET', path: `${g}&series=1` }, { status: 200, json_len: { releases: 1 }, json_at: want }, '-');
  c.req(`${label}: the repository read`, { method: 'GET', path: '/v1/packages/acme/lib/releases' }, { status: 200, json_len: { releases: 1 }, json_at: want }, '-');
  c.req(`${label}: the artifact read`, { method: 'GET', path: `/v1/artifacts/${H1}` }, { status: 200, json_len: { releases: 1 }, json_at: want }, '-');
};
const block = (query, rows) => `@ ${query}\n${rows.map((r) => r.map((x) => (x === null ? '\\N' : String(x))).join('\t')).join('\n')}${rows.length ? '\n' : ''}`;
const Q = {
  yanked: 'SELECT log_index, yanked FROM releases ORDER BY log_index',
  yanks: 'SELECT release, seq, action, by, claims, reason, time FROM yanks ORDER BY release, seq',
  counts: "SELECT (SELECT count(*) FROM provenance), (SELECT count(*) FROM log), (SELECT count(*) FROM repo_events), (SELECT count(*) FROM releases)",
  repos: 'SELECT n.value, r.repository_id, r.repository_owner_id, r.state, r.state_at, r.time FROM repos r JOIN names n ON n.id = r.repo ORDER BY n.value',
  reasons: 'SELECT release, length(CAST(reason AS BLOB)) FROM yanks ORDER BY release, seq',
};
const AC = 'R-YK1 R-YK2 R-YK4 R-YK7 R-TP8 R-RE10 R-AP41 R-AP49 R-AP69 R-AP43 R-RE6';

// ---- case 1: an author yanks and unyanks; idempotence; the 4 cache keys of each change; the rows of yanks ----
function yankUnyank() {
  const c = new Case('yk1-yank-unyank', `${AC} R-YK5 R-AP2 R-AP1 R-AP13`);
  c.world([1]);
  for (const [n, run] of [['a1', '301'], ['a2', '302'], ['a3', '303'], ['a4', '304'], ['a5', '305']]) c.token(n, { run_id: run });
  c.jwks();
  reads(c, 'before', false, null);
  c.req('PUT with a reason, an author token (workflow_dispatch, a branch ref): 200, yanked, the reason, 2 D1 calls', put(1, 'a1', { reason: 'broken build' }, NOW + 1000), ok(1, true, 'broken build'), 2);
  c.wait();
  reads(c, 'after the yank (R-YK7: the 4 keys of R-AP69 are dropped)', true, 'broken build');
  c.req('PUT again with another reason: 200, nothing changes (the reason stays), 1 D1 call, no row', put(1, 'a2', { reason: 'other' }, NOW + 2000), ok(1, true, 'broken build'), 1);
  c.req('DELETE: 200, not yanked, the reason is null, 2 D1 calls', del(1, 'a3', NOW + 3000), ok(1, false, null), 2);
  c.wait();
  reads(c, 'after the unyank (R-YK7: a DELETE drops the 4 keys too)', false, null);
  c.req('DELETE again: 200, nothing changes, 1 D1 call, no row', del(1, 'a4', NOW + 4000), ok(1, false, null), 1);
  c.req('PUT with {} (no reason is valid, R-YK6): 200, yanked, reason null, 2 D1 calls', put(1, 'a5', {}, NOW + 5000), ok(1, true, null), 2);
  c.db = [
    block(Q.yanked, [[1, 1]]),
    // R-YK4: the rows are only added. seq 1, 2, 3. by author (0). The claims of the token of each request (run_id 301, 303, 305). The no-change requests (a2, a4) have no row.
    block(Q.yanks, [[1, 1, 0, 0, c.recorded('a1'), 'broken build', NOW + 1000], [1, 2, 1, 0, c.recorded('a3'), null, NOW + 3000], [1, 3, 0, 0, c.recorded('a5'), null, NOW + 5000]]),
    // R-YK4: a yank adds no log leaf and no release; R-RE6: no other table changes (a token that matches the row writes no repos event: the count stays 2, the 2 seeded binds).
    block(Q.counts, [[1, 1, 2, 1]]),
  ].join('');
  c.write();
}

// ---- case 2: the operator key: no token, no JWKS read; a release on another host; 404; a key that is not the key ----
function operator() {
  const c = new Case('yk2-operator', `${AC} R-YK2 R-AP26 R-AP21`);
  c.world([1, 5]);
  c.leaf(3);
  c.req('operator PUT on the release of another host (repo NULL): 200', put(5, 'op', { reason: 'mirror compromised' }, NOW + 1000), ok(5, true, 'mirror compromised'), 2);
  c.req('operator PUT {} on a GitHub release: 200', put(1, 'op', {}, NOW + 2000), ok(1, true, null), 2);
  c.req('operator DELETE on the release of another host: 200', del(5, 'op', NOW + 3000), ok(5, false, null), 2);
  c.req('operator DELETE again: 200, nothing changes, 1 D1 call', del(5, 'op', NOW + 4000), ok(5, false, null), 1);
  c.req('operator PUT on a log index that no release has: 404, 1 D1 call', put(999, 'op', {}, NOW + 5000), problem(404, '/errors/not-found', 'no release has the log index 999'), 1);
  c.req('operator PUT on a compiler leaf (the log index 3 has no release): 404', put(3, 'op', {}, NOW + 6000), problem(404, '/errors/not-found', 'no release has the log index 3'), 1);
  c.req('a bearer that is not the key (the key and 1 more byte): 401, no D1 call, no JWKS read', { method: 'PUT', path: path(1), json: {}, headers: { authorization: `Bearer ${KEY}0` }, now: NOW + 7000 }, problem(401, '/errors/unauthenticated'), 0);
  c.req('a bearer that is not the key (the key without its last byte): 401', { method: 'PUT', path: path(1), json: {}, headers: { authorization: `Bearer ${KEY.slice(0, -1)}` }, now: NOW + 8000 }, problem(401, '/errors/unauthenticated'), 0);
  c.req('a bearer that is the key in other case: 401', { method: 'PUT', path: path(1), json: {}, headers: { authorization: `Bearer ${KEY.toUpperCase()}` }, now: NOW + 9000 }, problem(401, '/errors/unauthenticated'), 0);
  c.req('no Authorization header: 401', put(1, undefined, {}, NOW + 10000), problem(401, '/errors/unauthenticated'), 0);
  c.req('Authorization Basic with the key: 401', { method: 'PUT', path: path(1), json: {}, headers: { authorization: `Basic ${KEY}` }, now: NOW + 11000 }, problem(401, '/errors/unauthenticated'), 0);
  c.req('DELETE with a bad bearer: 401', { method: 'DELETE', path: path(1), headers: { authorization: 'Bearer nope' }, now: NOW + 12000 }, problem(401, '/errors/unauthenticated'), 0);
  c.db = [
    block(Q.yanked, [[1, 1], [5, 0]]),
    // by operator (1): claims NULL. The no-change DELETE and every refusal have no row.
    block(Q.yanks, [[1, 1, 0, 1, null, null, NOW + 2000], [5, 1, 0, 1, null, 'mirror compromised', NOW + 1000], [5, 2, 1, 1, null, null, NOW + 3000]]),
    block(Q.counts, [[2, 3, 2, 2]]),
  ].join('');
  c.write(); // github.log is empty: the operator key needs no JWKS read
}

// ---- case 3: an author and the operator on one release: R-YK2 "an author cannot remove a yank of the operator" ----
function roles() {
  const c = new Case('yk3-roles', `${AC} R-YK2 R-TP8`);
  c.world([1, 4]);
  c.token('au1', { run_id: '401' });
  c.token('au2', { run_id: '402' });
  c.token('au3', { run_id: '403' });
  c.token('au4', { run_id: '404' });
  c.token('b1', { repository: 'acme/other', repository_id: '800', repository_owner_id: '8100', run_id: '405' });
  c.jwks();
  c.req('operator PUT: 200 (by operator)', put(1, 'op', { reason: 'security' }, NOW + 1000), ok(1, true, 'security'), 2);
  c.req('author PUT on a yanked release: 200, nothing changes, the reason stays "security", 1 D1 call', put(1, 'au1', { reason: 'mine' }, NOW + 2000), ok(1, true, 'security'), 1);
  c.req('author DELETE of a yank of the operator: 403 forbidden (R-YK2), 1 D1 call', del(1, 'au2', NOW + 3000), problem(403, '/errors/forbidden', 'the release is yanked by the operator: only the operator can remove this yank'), 1);
  c.req('operator DELETE: 200, not yanked', del(1, 'op', NOW + 4000), ok(1, false, null), 2);
  c.req('author PUT after the operator removed the yank: 200, yanked (by author)', put(1, 'au3', { reason: 'author reason' }, NOW + 5000), ok(1, true, 'author reason'), 2);
  c.req('operator PUT on a yank of an author: 200, nothing changes (the yank stays the yank of the author), 1 D1 call', put(1, 'op', { reason: 'late' }, NOW + 6000), ok(1, true, 'author reason'), 1);
  c.req('operator DELETE of a yank of an author: 200, not yanked', del(1, 'op', NOW + 7000), ok(1, false, null), 2);
  c.req('author PUT on a release of another repository, with a token of this repository: 403 (R-TP8 repository), the state stays', put(4, 'au4', { reason: 'x' }, NOW + 8000), problem(403, '/errors/forbidden', 'token claim repository is "acme/lib", expected "acme/other"'), 1);
  c.req('author of the other repository PUT then DELETE its own release: 200, 200', put(4, 'b1', { reason: 'mine' }, NOW + 9000), ok(4, true, 'mine'), 2);
  c.req('...DELETE: the yank is the yank of an author, so the author removes it', del(4, 'b1', NOW + 10000), ok(4, false, null), 2);
  c.db = [
    block(Q.yanked, [[1, 0], [4, 0]]),
    block(Q.yanks, [
      [1, 1, 0, 1, null, 'security', NOW + 1000],
      [1, 2, 1, 1, null, null, NOW + 4000],
      [1, 3, 0, 0, c.recorded('au3'), 'author reason', NOW + 5000],
      [1, 4, 1, 1, null, null, NOW + 7000],
      [4, 1, 0, 0, c.recorded('b1'), 'mine', NOW + 9000],
      [4, 2, 1, 0, c.recorded('b1'), null, NOW + 10000],
    ]),
  ].join('');
  c.write();
}

// ---- case 4: the token check R-TP8 and the order of the checks (0 D1 calls before the release read, 1 after) ----
function tokens() {
  const c = new Case('tp8-token', `${AC} R-TP3 R-TP9 R-TP12 R-TP16 R-AP48 R-AP75 R-AP26`);
  c.world([1, 4]);
  c.leaf(3);
  c.tokens.tamper = { base: 'publish', claims: { repository: 'acme/lib', event_name: 'workflow_dispatch' }, tamper: 'signature' };
  c.token('aud_slash', { aud: `${AUD}/` });
  c.token('good', { run_id: '501' });
  c.token('good_tag', { run_id: '502', ref: 'refs/tags/1.0.0', ref_type: 'tag' });
  c.token('other_repo', { repository: 'acme/other', repository_id: '800', repository_owner_id: '8100' });
  c.token('private', { repository_visibility: 'private' });
  c.token('push', { event_name: 'push' });
  c.token('release_event', { event_name: 'release' });
  c.token('bad_id', { repository_id: '12a' });
  c.token('no_owner', { repository_owner_id: null });
  c.token('both', { repository_id: '1', repository_owner_id: '2' });
  c.token('xfer', { run_id: '503', repository_owner_id: '777' });
  c.token('recreate', { run_id: '504', repository_id: '901' });
  c.jwks();
  c.req('no Authorization: 401, 0 D1 calls', put(1, undefined, {}, NOW + 1000), problem(401, '/errors/unauthenticated'), 0);
  c.req('Authorization Basic: 401', { method: 'PUT', path: path(1), json: {}, headers: { authorization: 'Basic abc' }, now: NOW + 2000 }, problem(401, '/errors/unauthenticated'), 0);
  c.req('a token with a changed signature, for a log index that does not exist: 401 comes before the 404 (the token check is before the D1 read)', put(999, 'tamper', {}, NOW + 3000), problem(401, '/errors/unauthenticated', 'the token signature is not valid'), 0);
  c.req('aud with a "/" at the end: 401', put(1, 'aud_slash', {}, NOW + 4000), problem(401, '/errors/unauthenticated'), 0);
  c.req('a good token, a log index that no release has: 404, 1 D1 call', put(999, 'good', {}, NOW + 5000), problem(404, '/errors/not-found', 'no release has the log index 999'), 1);
  c.req('a good token, a compiler leaf: 404', put(3, 'good', {}, NOW + 6000), problem(404, '/errors/not-found', 'no release has the log index 3'), 1);
  c.req('a token of another repository, a log index that does not exist: 404 (the claims need the release), 1 D1 call', put(999, 'other_repo', {}, NOW + 7000), problem(404, '/errors/not-found'), 1);
  c.req('a token of acme/other on a release of acme/lib: 403, the detail names the claim repository', put(1, 'other_repo', {}, NOW + 8000), problem(403, '/errors/forbidden', 'token claim repository is "acme/other", expected "acme/lib"'), 1);
  c.req('a private repository: 403 repository_visibility (R-TP3 row 6)', put(1, 'private', {}, NOW + 9000), problem(403, '/errors/forbidden', 'token claim repository_visibility is "private", expected "public"'), 1);
  c.req('event_name push: 403 (R-TP8: only workflow_dispatch)', put(1, 'push', {}, NOW + 10000), problem(403, '/errors/forbidden', 'token claim event_name is "push", expected "workflow_dispatch"'), 1);
  c.req('event_name release: 403', put(1, 'release_event', {}, NOW + 11000), problem(403, '/errors/forbidden', 'token claim event_name is "release", expected "workflow_dispatch"'), 1);
  c.req('repository_id that is not a number: 403 (as the publish, Q293)', put(1, 'bad_id', {}, NOW + 12000), problem(403, '/errors/forbidden', 'token claim repository_id is "12a", expected a number'), 1);
  c.req('repository_owner_id missing: 403', put(1, 'no_owner', {}, NOW + 13000), problem(403, '/errors/forbidden', 'token claim repository_owner_id is missing'), 1);
  c.req('both ids differ from the repos row: 403 repository-changed with issues_url (R-TP3 row 5, R-TP12), 1 D1 call', put(1, 'both', {}, NOW + 14000), { status: 403, problem: { type: '/errors/repository-changed', detail: 'the name acme/lib is bound to another GitHub account (repository id 900)' }, json: { issues_url: ISSUES } }, 1);
  c.req('R-TP8: a token of a tag push ref (rows 7 and 8 do not apply), workflow_dispatch: 200', put(1, 'good_tag', { reason: 'tag ref' }, NOW + 15000), ok(1, true, 'tag ref'), 2);
  c.req('DELETE with a token of a transfer (the owner id differs, the repository id is equal): 200, nothing is recorded in repos (Q246-4)', del(1, 'xfer', NOW + 16000), ok(1, false, null), 2);
  c.req('PUT with a token of a recreate (the repository id differs, the owner id is equal): 200', put(1, 'recreate', {}, NOW + 17000), ok(1, true, null), 2);
  c.db = [
    block(Q.yanked, [[1, 1], [4, 0]]),
    block(Q.yanks, [[1, 1, 0, 0, c.recorded('good_tag'), 'tag ref', NOW + 15000], [1, 2, 1, 0, c.recorded('xfer'), null, NOW + 16000], [1, 3, 0, 0, c.recorded('recreate'), null, NOW + 17000]]),
    // R-TP9 rows 2 and 3 are not applied by a yank: the repos row keeps the old ids and the state, and there is no new event (the count is 2: the 2 seeded binds).
    block(Q.repos, [['acme/lib', 900, 9100, 0, SEED_T, SEED_T], ['acme/other', 800, 8100, 0, SEED_T, SEED_T]]),
    block(Q.counts, [[2, 3, 2, 2]]),
  ].join('');
  c.write();
}

// ---- case 5: the body of a PUT (R-YK6, R-AP48 rows 4 to 6: before the token) ----
function bodies() {
  const c = new Case('yk6-body', `${AC} R-YK6 R-AP48 R-AP51 R-AP23 R-AP66`);
  c.world([1, 2, 4]);
  const junk = { headers: { authorization: 'Bearer not.a.token' } };
  const reasonBad = (text) => ({ method: 'PUT', path: path(1), json: { reason: text }, ...junk, now: NOW + 1000 });
  c.req('501 bytes: 400 before the token (a junk token, no JWKS read, 0 D1 calls)', reasonBad('a'.repeat(501)), problem(400, '/errors/bad-request', 'the reason of the yank request is more than 500 bytes'), 0);
  c.req('251 characters of 2 bytes (502 bytes): 400', reasonBad('é'.repeat(251)), problem(400, '/errors/bad-request', 'the reason of the yank request is more than 500 bytes'), 0);
  c.req('a new line in the reason: 400', reasonBad('a\nb'), problem(400, '/errors/bad-request', 'the reason of the yank request has a control character'), 0);
  c.req('a tab in the reason: 400', reasonBad('a\tb'), problem(400, '/errors/bad-request', 'the reason of the yank request has a control character'), 0);
  c.req('a NUL in the reason: 400', { method: 'PUT', path: path(1), body: '{"reason":"a\\u0000b"}', headers: { 'content-type': 'application/json', ...junk.headers }, now: NOW + 5000 }, problem(400, '/errors/bad-request', 'the reason of the yank request has a control character'), 0);
  c.req('a reason that is a number: 400', { method: 'PUT', path: path(1), json: { reason: 5 }, ...junk, now: NOW + 6000 }, problem(400, '/errors/bad-request'), 0);
  c.req('a body that is not JSON: 400', { method: 'PUT', path: path(1), body: 'not json', headers: { 'content-type': 'application/json', ...junk.headers }, now: NOW + 7000 }, problem(400, '/errors/bad-request'), 0);
  c.req('a body that is a list: 400', { method: 'PUT', path: path(1), json: [], ...junk, now: NOW + 8000 }, problem(400, '/errors/bad-request'), 0);
  c.req('a body of another media type: 415 before the token (R-AP48 row 5)', { method: 'PUT', path: path(1), body: '{"reason":"x"}', headers: { 'content-type': 'text/plain', ...junk.headers }, now: NOW + 9000 }, problem(415, '/errors/unsupported-media-type'), 0);
  const a500 = 'a'.repeat(500);
  c.req('500 bytes of ASCII with the operator key: 200 (the limit is in bytes, 500 is good)', put(1, 'op', { reason: a500 }, NOW + 10000), ok(1, true, a500), 2);
  const e250 = 'é'.repeat(250);
  c.req('250 characters of 2 bytes (500 bytes): 200', put(2, 'op', { reason: e250 }, NOW + 11000), ok(2, true, e250), 2);
  c.req('{"reason":null}: 200, no reason', put(4, 'op', { reason: null }, NOW + 12000), ok(4, true, null), 2);
  c.req('{"later":1} (an unknown member is ignored, R-AP44): 200 on a yanked release, nothing changes', put(4, 'op', { later: 1, reason: 'ignored' }, NOW + 13000), ok(4, true, null), 1);
  c.db = [
    block(Q.yanked, [[1, 1], [2, 1], [4, 1]]),
    block(Q.reasons, [[1, 500], [2, 500], [4, null]]),
  ].join('');
  c.write();
}

// ---- case 6: the route and the client checks (R-AP45 on a write, R-AP48 rows 1 to 3) ----
function routeChecks() {
  const c = new Case('yk1-route-checks', 'R-YK1 R-AP45 R-AP48 R-AP21 R-AP41', { MIN_TLN: '0.3.0', MIN_TLN_WRITE: '0.5.0' });
  c.world([1]);
  const ua = (v) => ({ 'user-agent': v });
  c.req('PUT from tln 0.4.1: 400 unsupported-client with minimum, 0 D1 calls (MIN_TLN_WRITE covers the yank routes)', { method: 'PUT', path: path(1), json: {}, headers: { ...ua('tln/0.4.1'), authorization: `Bearer ${KEY}` }, now: NOW + 1000 }, problem(400, '/errors/unsupported-client', undefined, { json: { minimum: '0.5.0' } }), 0);
  c.req('DELETE from tln 0.4.1: 400 unsupported-client', { method: 'DELETE', path: path(1), headers: { ...ua('tln/0.4.1 (linux)'), authorization: `Bearer ${KEY}` }, now: NOW + 2000 }, problem(400, '/errors/unsupported-client', undefined, { json: { minimum: '0.5.0' } }), 0);
  c.req('the client check comes before the body check: a bad body from tln 0.4.1 is 400 unsupported-client', { method: 'PUT', path: path(1), body: 'not json', headers: { 'content-type': 'application/json', ...ua('tln/0.4.1'), authorization: `Bearer ${KEY}` }, now: NOW + 3000 }, problem(400, '/errors/unsupported-client', undefined, { json: { minimum: '0.5.0' } }), 0);
  c.req('a read from tln 0.4.1 is not refused (MIN_TLN is 0.3.0)', { method: 'GET', path: '/v1/packages/acme/lib/releases', headers: ua('tln/0.4.1') }, { status: 200, json_len: { releases: 1 } }, '-');
  c.req('PUT from tln 0.5.0: 200', { method: 'PUT', path: path(1), json: { reason: 'r' }, headers: { ...ua('tln/0.5.0 (linux)'), authorization: `Bearer ${KEY}` }, now: NOW + 5000 }, ok(1, true, 'r'), 2);
  c.req('PUT from a client that is not tln (curl): not checked, 200 (no change)', { method: 'PUT', path: path(1), json: { reason: 'r' }, headers: { ...ua('curl/8.4.0'), authorization: `Bearer ${KEY}` }, now: NOW + 6000 }, ok(1, true, 'r'), 1);
  c.req('GET on the yank path: 405 with Allow: DELETE, PUT', { method: 'GET', path: path(1) }, { status: 405, headers: { allow: 'DELETE, PUT' }, problem: { type: '/errors/method-not-allowed', detail: 'GET is not allowed on /v1/releases/1/yank' } }, 0);
  c.req('POST on the yank path: 405', { method: 'POST', path: path(1), json: {} }, { status: 405, headers: { allow: 'DELETE, PUT' }, problem: { type: '/errors/method-not-allowed' } }, 0);
  c.req('a longer path: 404', { method: 'PUT', path: `${path(1)}/x`, json: {}, headers: { authorization: `Bearer ${KEY}` } }, problem(404, '/errors/not-found'), 0);
  c.req('the release path with no /yank: 404', { method: 'DELETE', path: '/v1/releases/1', headers: { authorization: `Bearer ${KEY}` } }, problem(404, '/errors/not-found'), 0);
  c.db = [block(Q.yanked, [[1, 1]]), block(Q.yanks, [[1, 1, 0, 1, null, 'r', NOW + 5000]])].join('');
  c.write();
}


// ---- case 7: the yank state in the answers of R-AP1, R-AP2, R-AP13, R-AP14 and R-AP17 (R-YK7, R-AP49, R-YK4): the state is seeded, so this case tests the reads alone ----
function readsOfYanks() {
  const c = new Case('yk7-reads', 'R-YK7 R-YK4 R-AP49 R-AP1 R-AP2 R-AP13 R-AP14 R-AP17 R-RE10 R-YK5');
  c.world([1, 2, 4]);
  const claims = '{"workflow_ref":"acme/lib/.github/workflows/yank.yml@refs/heads/main","workflow_sha":null,"job_workflow_ref":null,"event_name":"workflow_dispatch","run_id":"1","run_attempt":"1","actor_id":"2","runner_environment":"github-hosted"}';
  const row = (rel, seq, action, by, reason, t) => `INSERT INTO yanks (release, seq, action, by, claims, reason, time) VALUES (${rel}, ${seq}, ${action}, ${by}, ${by === 0 ? sq(claims) : 'NULL'}, ${reason === null ? 'NULL' : sq(reason)}, ${t});`;
  c.seed.push(
    'UPDATE releases SET yanked = 1 WHERE log_index IN (1, 2);',
    // release 1: one yank by an author. Release 2: yank, unyank, yank again: the reason is the reason of the LAST yank (R-YK1, R-AP49). Release 4: yank then unyank: yanked is false and the reason is null.
    row(1, 1, 0, 0, 'broken build', SEED_T + 1),
    row(2, 1, 0, 1, 'first', SEED_T + 2), row(2, 2, 1, 1, null, SEED_T + 3), row(2, 3, 0, 0, 'second', SEED_T + 4),
    row(4, 1, 0, 0, 'old', SEED_T + 5), row(4, 2, 1, 0, null, SEED_T + 6),
  );
  const g = `/v1/releases?group=${GROUP1}`;
  c.req('R-AP13 series 1: the release 1 is yanked with its reason', { method: 'GET', path: `${g}&series=1` }, { status: 200, json_len: { releases: 1 }, json_at: { 'releases.0.log_index': 1, 'releases.0.yanked': true, 'releases.0.yank_reason': 'broken build' } }, '-');
  c.req('R-AP13 series 2: the release 2 has the reason of the last yank', { method: 'GET', path: `${g}&series=2` }, { status: 200, json_len: { releases: 1 }, json_at: { 'releases.0.log_index': 2, 'releases.0.yanked': true, 'releases.0.yank_reason': 'second' } }, '-');
  c.req('R-AP2: the artifact of the release 2', { method: 'GET', path: `/v1/artifacts/${H2}` }, { status: 200, json_len: { releases: 1 }, json_at: { 'releases.0.yanked': true, 'releases.0.yank_reason': 'second' } }, '-');
  c.req('R-AP2: the release 4 was yanked and unyanked: not yanked, no reason', { method: 'GET', path: `/v1/artifacts/${H4}` }, { status: 200, json_len: { releases: 1 }, json_at: { 'releases.0.yanked': false, 'releases.0.yank_reason': null } }, '-');
  c.req('R-AP1: the repository acme/lib has the 2 yanked releases', { method: 'GET', path: '/v1/packages/acme/lib/releases' }, { status: 200, json_len: { releases: 2 } }, '-');
  c.req('R-AP14: the page of all releases in log index order', { method: 'GET', path: '/v1/releases?after=0' }, { status: 200, json_len: { releases: 3 }, json_at: { 'releases.0.yank_reason': 'broken build', 'releases.1.yank_reason': 'second', 'releases.2.yank_reason': null, 'releases.2.yanked': false } }, '-');
  c.req('R-AP17: the closure answer has the release 1 with its yank state', { method: 'POST', path: '/v1/closure', json: { groups: [{ group: formOf('acme/lib'), series: '1' }], hashes: [] } }, { status: 200, json_len: { releases: 1 }, json_at: { 'releases.0.log_index': 1, 'releases.0.yanked': true, 'releases.0.yank_reason': 'broken build' } }, '-');
  c.db = block(Q.yanks, [[1, 1, 0, 0, claims, 'broken build', SEED_T + 1], [2, 1, 0, 1, null, 'first', SEED_T + 2], [2, 2, 1, 1, null, null, SEED_T + 3], [2, 3, 0, 0, claims, 'second', SEED_T + 4], [4, 1, 0, 0, claims, 'old', SEED_T + 5], [4, 2, 1, 0, claims, null, SEED_T + 6]]);
  c.write();
}

// ---- slice 246b: the answers of a publish and an ingest for a yanked release (Q246-11), and a yanked release with no `yanks` row (500) ----
const ingest = (idx, now) => ({ method: 'POST', path: '/v1/releases', json: { url: gh(REL[idx].name, REL[idx].tag, REL[idx].hash) }, now });
const publishOf = (idx, who, compat, now) => ({ method: 'POST', path: '/v1/releases', json: compat === undefined ? { url: gh(REL[idx].name, REL[idx].tag, REL[idx].hash) } : { url: gh(REL[idx].name, REL[idx].tag, REL[idx].hash), compat }, token: who, now });
const FACT = { nightly: 'nightly-2026-10-31-f7bef6b', target: 'any', result: 'pass', error_digest: null };
const yankedAnswer = (i, reason) => ({ status: 200, headers: { 'content-type': 'application/json', 'cache-control': 'no-store' }, headers_set: ['talon-bookmark'], json: { release: { log_index: i, yanked: true, yank_reason: reason } } });
const internal = { status: 500, problem: { type: '/errors/internal' } };

function answersOfYanked() {
  const c = new Case('yk8-answers', 'R-AP49 R-AP41 R-AP8 R-AP9 R-YK4 R-YK7 R-RE10 R-PU14 R-PU16');
  c.world([1, 2]);
  c.token('p1', { ref: 'refs/tags/1.0.0', ref_type: 'tag', event_name: 'release', run_id: '601' });
  c.token('p2', { ref: 'refs/tags/2.0.0', ref_type: 'tag', event_name: 'release', run_id: '602' });
  const row = (rel, seq, action, reason) => `INSERT INTO yanks (release, seq, action, by, claims, reason, time) VALUES (${rel}, ${seq}, ${action}, 1, NULL, ${reason === null ? 'NULL' : sq(reason)}, ${SEED_T + seq});`;
  c.seed.push(
    'UPDATE releases SET yanked = 1 WHERE log_index IN (1, 2);',
    // release 1: indexed by an ingest only (provenance 3). Release 2: also has the oidc row (via 0), and was yanked, unyanked and yanked again: the reason is the last one.
    row(1, 1, 0, 'broken build'),
    `INSERT INTO provenance (release, via, claims, time) VALUES (2, 0, NULL, ${SEED_T});`,
    row(2, 1, 0, 'first'), row(2, 2, 1, null), row(2, 3, 0, 'second'),
  );
  c.jwks();
  c.req('ingest of a yanked label with the same hash: 200 with the reason in the first D1 batch: 1 D1 call (Q246-11)', ingest(1, NOW + 1000), yankedAnswer(1, 'broken build'), 1);
  c.req('ingest of the label of release 2 (the reason of the last yank): 200, 1 D1 call', ingest(2, NOW + 2000), yankedAnswer(2, 'second'), 1);
  c.req('publish with no facts, label with the oidc row: 200 from the pre-read, 1 D1 call', publishOf(2, 'p2', undefined, NOW + 3000), yankedAnswer(2, 'second'), 1);
  c.req('publish with a fact, label that has only the ingest row: the write batch, 2 D1 calls (not 3), the reason in the answer', publishOf(1, 'p1', [FACT], NOW + 4000), yankedAnswer(1, 'broken build'), 2);
  c.req('the same publish again: 200 with the reason, 2 D1 calls (a repeat with facts writes again, as slice 114)', publishOf(1, 'p1', [FACT], NOW + 5000), yankedAnswer(1, 'broken build'), 2);
  c.db = block(Q.yanked, [[1, 1], [2, 1]]) + block('SELECT release, via FROM provenance ORDER BY release, via', [[1, 0], [1, 3], [2, 0], [2, 3]]);
  c.write();
}

function yankedNoRow() {
  const c = new Case('yk9-no-yank-row', 'R-AP49 R-AP48 R-AP41 R-YK4 R-RE10');
  c.world([1, 2]);
  c.seed.push('UPDATE releases SET yanked = 1 WHERE log_index = 1;', `INSERT INTO provenance (release, via, claims, time) VALUES (1, 0, NULL, ${SEED_T});`);
  c.token('p1', { ref: 'refs/tags/1.0.0', ref_type: 'tag', event_name: 'release', run_id: '701' });
  c.jwks();
  const g = `/v1/releases?group=${GROUP1}`;
  c.req('control: a release that is not yanked is read as before (series 2)', { method: 'GET', path: `${g}&series=2` }, { status: 200, json_len: { releases: 1 }, json_at: { 'releases.0.yanked': false } }, '-');
  c.req('R-AP13: release 1 is yanked and has no yanks row: 500 internal', { method: 'GET', path: `${g}&series=1` }, internal, '-');
  c.req('R-AP1: the repository answer holds release 1: 500', { method: 'GET', path: '/v1/packages/acme/lib/releases' }, internal, '-');
  c.req('R-AP2: the artifact of release 1: 500', { method: 'GET', path: `/v1/artifacts/${H1}` }, internal, '-');
  c.req('R-AP14: the page that holds release 1: 500', { method: 'GET', path: '/v1/releases?after=0' }, internal, '-');
  c.req('R-AP17: the closure with release 1: 500', { method: 'POST', path: '/v1/closure', json: { groups: [{ group: formOf('acme/lib'), series: '1' }], hashes: [] } }, internal, '-');
  c.req('ingest of the label of release 1 (it has the ingest row): the answer would hold the release: 500, 1 D1 call', ingest(1, NOW + 1000), internal, 1);
  c.req('publish with no facts, the label has the oidc row: 500, 1 D1 call', publishOf(1, 'p1', undefined, NOW + 2000), internal, 1);
  c.req('operator DELETE of the release: 500, 1 D1 call, nothing written', del(1, 'op', NOW + 3000), internal, 1);
  c.req('operator PUT of the release: 500, 1 D1 call', put(1, 'op', {}, NOW + 4000), internal, 1);
  c.req('publish with one fact for label 1 (the write path): refused at the first batch, 500, 1 D1 call, nothing written (Q246b-1, Design Q627 item 3)', publishOf(1, 'p1', [FACT], NOW + 5000), internal, 1);
  c.db = block(Q.yanked, [[1, 1], [2, 0]]) + block('SELECT count(*) FROM yanks', [[0]]) + block('SELECT count(*) FROM compat', [[0]]) + block('SELECT release, via, time FROM provenance ORDER BY release, via', [[1, 0, SEED_T], [1, 3, SEED_T], [2, 3, SEED_T]]);
  c.write();
}

mkdirSync(casesDir, { recursive: true });
yankUnyank();
operator();
roles();
tokens();
bodies();
routeChecks();
readsOfYanks();
answersOfYanked();
yankedNoRow();
console.log('yank: 9 cases written to', casesDir);
