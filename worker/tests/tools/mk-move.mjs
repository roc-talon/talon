// The W2 cases of slice 247 (the move routes `PUT` and `DELETE /v1/packages/{owner}/{repo}/successor`, Registry R-AP31, R-TP14, R-TP15, R-TP13, R-RE11, R-RE15, R-AP32, R-AP33, R-AP41, R-AP45;
// docs/slices/247-move.md section 4).
//   node worker/tests/tools/mk-move.mjs     writes worker/tests/cases/move/*/ (seed.sql, requests.jsonl, tokens.json, settings.json, expect/, rules, notes.txt)
// The files are tracked. Run the script again only when a case changes. The ids (R-IK2), the version columns (R-IK5), the hashes and the recorded claims (R-TP6) are computed here with node, not with the Roc code.
// There is no GitHub read in a move: the checks read D1 only (R-AP41). The fake GitHub has only the JWKS of the tokens (worker/tests/oidc/jwks.json).
// The texts of the `detail` of the problems are the proposals of the slice file section 5 (TW24): this file is the one place where a case has them.
import { createHash } from 'node:crypto';
import { mkdirSync, writeFileSync, rmSync, readFileSync, cpSync, appendFileSync, existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const casesDir = join(here, '..', 'cases', 'move');
const baseClaims = JSON.parse(readFileSync(join(here, '..', 'oidc', 'claims-publish.json'), 'utf8'));
const JWKS = readFileSync(join(here, '..', 'oidc', 'jwks.json'), 'utf8');

// ---- the facts of the design, in JS ----
const B58 = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
function b58encode(buf) {
  let n = 0n;
  for (const b of buf) n = n * 256n + BigInt(b);
  let s = '';
  while (n > 0n) { s = B58[Number(n % 58n)] + s; n /= 58n; }
  for (const b of buf) { if (b === 0) s = `1${s}`; else break; }
  return s;
}
const nameId = (kind, bytes) => createHash('sha256').update(Buffer.concat([Buffer.from([kind]), Buffer.from(bytes)])).digest().readBigInt64BE(0).toString(); // R-IK2
const textId = (kind, t) => nameId(kind, Buffer.from(t, 'utf8'));
const repoId = (name) => textId(3, name.toLowerCase());
const fakeHash = (note) => b58encode(createHash('sha256').update(note).digest());
const hashId = (h) => { const B = [...h]; let n = 0n; for (const c of B) n = n * 58n + BigInt(B58.indexOf(c)); const out = []; while (n > 0n) { out.unshift(Number(n & 255n)); n >>= 8n; } for (const c of B) { if (c === '1') out.unshift(0); else break; } return nameId(1, Buffer.from(out)); };
const hexOf = (h) => { let n = 0n; for (const c of h) n = n * 58n + BigInt(B58.indexOf(c)); return n.toString(16).padStart(64, '0').toUpperCase(); };
const versionCol = (v) => { const [a, b, c] = v.split('.').map(BigInt); return BigInt.asIntN(64, ((a << 48n) | (b << 32n) | (c << 16n) | 0xFFFFn) ^ (1n << 63n)).toString(); }; // R-IK5
const sq = (s) => `'${String(s).replace(/'/g, "''")}'`;

// ---- constants of the cases ----
const NOW = 1767225630000; // the clock of a request (inside nbf and exp of the test tokens)
const SEED_T = 1767000000000;
const PUB_MS = Date.parse('2026-10-20T12:00:00Z');
const HOUR = 3600000;
const AUD = 'https://registry.example';
const KIND = { app: 0, package: 1, platform: 2 };
const STATE = { active: 0, missing: 1, moved: 2 };
const SUCCESSOR_SET = 6;
const SUCCESSOR_REMOVED = 7;
const OFFER = 8;
const UA = { 'user-agent': 'tln/0.5.0' };

// The recorded claims of R-TP6 (R-TP13: the claims of a token on the events): 8 members in this order, a missing claim is null (Design Q298, as slice 114).
const CLAIMS_KEYS = ['workflow_ref', 'workflow_sha', 'job_workflow_ref', 'event_name', 'run_id', 'run_attempt', 'actor_id', 'runner_environment'];
const claimsJson = (c) => `{${CLAIMS_KEYS.map((k) => `${JSON.stringify(k)}:${c[k] === undefined ? 'null' : JSON.stringify(c[k])}`).join(',')}}`;

const T = {
  missingToken: 'the request has no Authorization header: this route needs a GitHub OIDC token',
  notBearer: 'the Authorization header must be "Bearer <token>"',
  notJwt: 'the token is not a valid JWT',
  badSignature: 'the token signature is not valid',
  roleOther: (repo, old, name) => `token claim repository is "${repo}": it is not ${old} and it is not ${name}`,
  roleOwner: (owner, old, name) => `token claim repository_owner_id is "${owner}": it is not the owner of ${old}, and ${old} has no offer for ${name}`,
  roleState: (repo, old, state) => `token claim repository is "${repo}": the old repository ${old} is in the state ${state}, an offer needs the state active`,
  delNoSucc: (repo, old) => `token claim repository is "${repo}": it is not ${old}`,
  delOther: (repo, old) => `token claim repository is "${repo}": it is not ${old} and it is not the successor of ${old}`,
  visibility: (v) => `token claim repository_visibility is "${v}", expected "public"`,
  event: (e) => `token claim event_name is "${e}", expected "workflow_dispatch"`,
  noRepo: (name) => `no package named ${name} has a repos row`,
  tooLarge: 'the body of the move request is larger than its limit of 262144',
  index: (n) => `the successor ${n} fails the Index check: it needs a github.com name with a repos row in the state active and at least one release that is a candidate`,
  kind: (n) => `the successor ${n} fails the Kind check: the newest candidate of the successor is not the same kind as the newest release of the old name`,
  exposes: (n, mods) => `the successor ${n} fails the exposes check: the newest candidate of the successor does not expose the modules ${mods.join(', ')}`,
  chain: (n) => `the successor ${n} fails the Chain check: the successor chain from the successor comes back to the old name`,
};

class Case {
  constructor(name, rules) { this.name = name; this.rules = rules; this.reqs = []; this.exp = []; this.calls = []; this.log = []; this.seed = []; this.db = ''; this.notes = []; this.tokens = {}; this.claims = {}; this.settings = { AUDIENCE: AUD }; this.forms = new Set(); this.nextLog = 1; this.hashes = new Set(); this.ids = new Map(); }
  jwks() { this.log.push('GET https://token.actions.githubusercontent.com/.well-known/jwks'); }
  // A token by name: the claims of the publish base with the changes. A manual run (`workflow_dispatch`) of a public repository: a branch ref (R-TP15 needs rows 1 to 3, 6 and `event_name` only).
  token(tname, repository, rid, owner, extra = {}, spec = {}) {
    const changes = { repository, repository_id: String(rid), repository_owner_id: String(owner), event_name: 'workflow_dispatch', ref: 'refs/heads/main', ref_type: 'branch', run_id: String(900 + Object.keys(this.tokens).length), ...extra };
    const claims = { ...baseClaims };
    for (const [k, v] of Object.entries(changes)) { if (v === null) delete claims[k]; else claims[k] = v; }
    this.tokens[tname] = { base: 'publish', claims: changes, ...spec };
    this.claims[tname] = claims;
    return tname;
  }
  recorded(tname) { return claimsJson(this.claims[tname]); }
  // A repository: the `names` row, the `repos` row (with the successor and the offer names), the `repo_checks` row and the event bind (seq 1, claims NULL), as an earlier path wrote them.
  repo(name, { id, owner, state = 'active', successor = null, offer = null, stateAt = SEED_T }) {
    this.ids.set(name, { id, owner });
    this.seed.push(
      `INSERT OR IGNORE INTO names (id, kind, value) VALUES (${repoId(name)}, 3, ${sq(name)});`,
      ...[successor, offer].filter(Boolean).map((n) => `INSERT OR IGNORE INTO names (id, kind, value) VALUES (${repoId(n)}, 3, ${sq(n)});`),
      `INSERT INTO repos (repo, repository_id, repository_owner_id, state, successor, state_at, time, offer) VALUES (${repoId(name)}, ${id}, ${owner}, ${STATE[state]}, ${successor ? repoId(successor) : 'NULL'}, ${stateAt}, ${SEED_T}, ${offer ? repoId(offer) : 'NULL'});`,
      `INSERT INTO repo_checks (repo, etag, checked_at, next_check_at, fail_count, app_installed) VALUES (${repoId(name)}, NULL, NULL, ${SEED_T + HOUR}, 0, 0);`,
      `INSERT INTO repo_events (repo, seq, action, repository_id_before, repository_id_after, owner_id_before, owner_id_after, successor, claims, time) VALUES (${repoId(name)}, 1, 0, NULL, ${id}, NULL, ${owner}, NULL, NULL, ${SEED_T});`,
    );
  }
  // A release of a name: the artifact (kind, exposes), the log leaf, the release row (yanked, withdrawn) and an ingest provenance row. The log index is the next number.
  release(name, version, { kind = 'package', exposes = ['Alpha'], yanked = 0, withdrawn = null } = {}) {
    const idx = this.nextLog++;
    const tag = version;
    const hash = fakeHash(`slice 247 ${name} ${version}`);
    const form = `github.com/${name}/releases/download/{v}/`;
    const stmts = [];
    stmts.push(`INSERT OR IGNORE INTO names (id, kind, value) VALUES (${hashId(hash)}, 1, X'${hexOf(hash)}');`);
    if (!this.forms.has(form)) { this.forms.add(form); stmts.push(`INSERT INTO names (id, kind, value) VALUES (${textId(2, form)}, 2, ${sq(form)});`); }
    stmts.push(
      `INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (${hashId(hash)}, ${KIND[kind]}, ${sq(JSON.stringify(exposes))}, NULL, NULL, 999);`,
      `INSERT INTO log (idx, grp, version, hash, time) VALUES (${idx}, ${sq(form)}, ${sq(version)}, ${sq(hash)}, ${SEED_T});`,
      `INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (${idx}, ${textId(2, form)}, ${versionCol(version)}, '', ${hashId(hash)}, ${repoId(name)}, ${sq(`https://github.com/${name}/releases/download/${tag}/${hash}.tar.zst`)}, ${sq(tag)}, NULL, ${PUB_MS}, ${yanked}, ${withdrawn ? sq(withdrawn) : 'NULL'}, ${withdrawn ? SEED_T : 'NULL'});`,
      `INSERT INTO provenance (release, via, claims, time) VALUES (${idx}, 3, NULL, ${SEED_T});`,
    );
    this.seed.push(...stmts);
    return idx;
  }
  // The old package of most cases: 2.0.0 (log 1) exposes Alpha and Beta, 1.0.0 (log 2) exposes Alpha, Beta and Gamma. The newest release by version is 2.0.0 (not the last in the log, not the first by version).
  oldPackage(name = 'olduser/roc-json', { id = 100, owner = 10, state = 'active', successor = null, offer = null } = {}) {
    this.repo(name, { id, owner, state, successor, offer });
    this.release(name, '2.0.0', { exposes: ['Alpha', 'Beta'] });
    this.release(name, '1.0.0', { exposes: ['Alpha', 'Beta', 'Gamma'] });
  }
  // A good successor: an active name with one candidate of kind package that exposes Alpha, Beta and Delta.
  goodSuccessor(name, id, owner) {
    this.repo(name, { id, owner });
    this.release(name, '1.0.0', { exposes: ['Alpha', 'Beta', 'Delta'] });
  }
  // An event of an earlier path (slice 247b: R-TP13): the ids are the ids of the row, claims NULL. `action` is the code of R-RE15 (transfer 1, recreate 3, found 5).
  event(name, seq, action, time) {
    const { id, owner } = this.ids.get(name);
    this.seed.push(`INSERT INTO repo_events (repo, seq, action, repository_id_before, repository_id_after, owner_id_before, owner_id_after, successor, claims, time) VALUES (${repoId(name)}, ${seq}, ${action}, ${id}, ${id}, ${owner}, ${owner}, NULL, NULL, ${time});`);
  }
  // A line that is not a request: {"sql":[..]} or {"wait_ms":N}. It has no answer line, no D1 count and no note.
  raw(spec) { this.reqs.push(spec); }
  req(comment, spec, expect, calls) { this.reqs.push(spec); this.exp.push(expect); this.calls.push(String(calls)); this.notes.push(comment); }
  write() {
    const dir = join(casesDir, this.name);
    rmSync(dir, { recursive: true, force: true });
    mkdirSync(join(dir, 'expect'), { recursive: true });
    if (Object.keys(this.tokens).length) {
      mkdirSync(join(dir, 'github', 'token.actions.githubusercontent.com', '.well-known'), { recursive: true });
      writeFileSync(join(dir, 'github', 'token.actions.githubusercontent.com', '.well-known', 'jwks'), JWKS);
      writeFileSync(join(dir, 'tokens.json'), `${JSON.stringify(this.tokens, null, 1)}\n`);
    }
    writeFileSync(join(dir, 'rules'), `${this.rules}\n`);
    writeFileSync(join(dir, 'settings.json'), `${JSON.stringify(this.settings)}\n`);
    writeFileSync(join(dir, 'requests.jsonl'), this.reqs.map((r) => JSON.stringify(r)).join('\n') + '\n');
    writeFileSync(join(dir, 'notes.txt'), this.notes.map((n, i) => `${i + 1}: ${n}`).join('\n') + '\n');
    writeFileSync(join(dir, 'expect', 'responses.jsonl'), this.exp.map((r) => JSON.stringify(r)).join('\n') + '\n');
    writeFileSync(join(dir, 'expect', 'd1-calls'), this.calls.join('\n') + '\n');
    if (this.log.length) writeFileSync(join(dir, 'expect', 'github.log'), this.log.join('\n') + '\n');
    writeFileSync(join(dir, 'seed.sql'), this.seed.join('\n') + '\n');
    writeFileSync(join(dir, 'expect', 'db.tsv'), this.db);
  }
}

// ---- requests and answers ----
const OLD_PATH = '/v1/packages/olduser/roc-json/successor';
const put = (token, name, extra = {}, path = OLD_PATH) => ({ method: 'PUT', path, headers: UA, json: { name }, token, now: NOW, ...extra });
const del = (token, extra = {}, path = OLD_PATH) => ({ method: 'DELETE', path, headers: UA, token, now: NOW, ...extra });
const item = (name, state, successor, stateAt) => ({ name, state, successor, state_at: stateAt });
const ok = (status, json) => ({ status, headers: { 'content-type': 'application/json', 'cache-control': 'no-store' }, d1_session: 'first-primary', headers_set: ['talon-bookmark'], json });
const problem = (status, type, detail) => ({ status, problem: detail === undefined ? { type } : { type, detail } });
const forbidden = (detail) => problem(403, '/errors/forbidden', detail);
const unauth = (detail) => problem(401, '/errors/unauthenticated', detail);
const mismatch = (detail) => problem(422, '/errors/successor-mismatch', detail);
const notFound = (detail) => problem(404, '/errors/not-found', detail);
const bad = () => problem(400, '/errors/bad-request');

// ---- the db.tsv blocks. The names are text (a join with `names`), so the file reads without the ids. NULL is \N (run.mjs). ----
const Q = {
  repos: 'SELECT n.value, r.repository_id, r.repository_owner_id, r.state, (SELECT s.value FROM names s WHERE s.id = r.successor), (SELECT o.value FROM names o WHERE o.id = r.offer), r.state_at, r.time FROM repos r JOIN names n ON n.id = r.repo ORDER BY n.value',
  // The columns of a delete and of an offer that Q247-2 and Q247-8 leave open (the state after a removal, the successor column of the event of a removal and of an offer) are not in these blocks.
  reposOpen: 'SELECT n.value, r.repository_id, r.repository_owner_id, (SELECT s.value FROM names s WHERE s.id = r.successor), (SELECT o.value FROM names o WHERE o.id = r.offer), r.state_at, r.time FROM repos r JOIN names n ON n.id = r.repo ORDER BY n.value',
  events: 'SELECT n.value, e.seq, e.action, e.repository_id_before, e.repository_id_after, e.owner_id_before, e.owner_id_after, (SELECT s.value FROM names s WHERE s.id = e.successor), e.claims, e.time FROM repo_events e JOIN names n ON n.id = e.repo ORDER BY n.value, e.seq',
  eventsOpen: 'SELECT n.value, e.seq, e.action, e.repository_id_before, e.repository_id_after, e.owner_id_before, e.owner_id_after, e.claims, e.time FROM repo_events e JOIN names n ON n.id = e.repo ORDER BY n.value, e.seq',
  setSuccessor: 'SELECT n.value, e.seq, (SELECT s.value FROM names s WHERE s.id = e.successor) FROM repo_events e JOIN names n ON n.id = e.repo WHERE e.action = 6 ORDER BY n.value, e.seq',
  names: 'SELECT kind, COUNT(*) FROM names GROUP BY kind ORDER BY kind',
  releases: 'SELECT log_index, yanked, withdrawn FROM releases ORDER BY log_index',
};
const block = (q, rows) => `@ ${q}\n${rows.map((r) => r.map((c) => (c === null ? '\\N' : String(c))).join('\t')).join('\n')}${rows.length ? '\n' : ''}`;
const seededRepo = (name, id, owner, state = 'active', successor = null, offer = null) => [name, id, owner, STATE[state], successor, offer, SEED_T, SEED_T];
const seededBind = (name, id, owner) => [name, 1, 0, null, id, null, owner, null, null, SEED_T];
const byName = (rows) => rows.sort((a, b) => (a[0] < b[0] ? -1 : a[0] > b[0] ? 1 : 0) || (a[1] - b[1]));
const kindRows = (c) => { const ids = new Set(); const kinds = new Map(); for (const s of c.seed) { const m = s.match(/INSERT (?:OR IGNORE )?INTO names \(id, kind, value\) VALUES \((-?\d+), (\d)/); if (m && !ids.has(m[1])) { ids.add(m[1]); kinds.set(m[2], (kinds.get(m[2]) ?? 0) + 1); } } return [...kinds.entries()].sort((a, b) => a[0] - b[0]).map(([k, n]) => [Number(k), n]); };

// ---- case 1: the main flow: set (201), the same again (200), a new successor (200), the reads, remove (200), remove again (200) ----
function putDelete() {
  const c = new Case('ap31-put-delete', 'R-AP31 R-TP14 R-TP15 R-TP13 R-RE11 R-RE15 R-AP32 R-AP33 R-AP41 R-AP21 R-PU28 R-PU29 R-SN8');
  c.oldPackage();
  c.goodSuccessor('acme/roc-json', 200, 10);
  c.goodSuccessor('acme/second', 201, 10);
  c.token('t-acme', 'acme/roc-json', 200, 10);
  c.token('t-second', 'acme/second', 201, 10);
  c.token('t-old', 'olduser/roc-json', 100, 10);
  c.jwks();
  const t1 = NOW; const t2 = NOW + 2000; const t3 = NOW + 3000;
  c.req('PUT with the token of the successor (the owner id of the old row): no successor yet, so 201. The row is moved, the successor is the new name, state_at is the clock. D1 calls: the read and the write batch.', put('t-acme', 'acme/roc-json'), ok(201, item('olduser/roc-json', 'moved', 'acme/roc-json', t1)), 2);
  c.req('The same PUT again: the successor is the current one, so 200, nothing is written (no event, state_at stays). One D1 call.', put('t-acme', 'acme/roc-json', { now: NOW + 1000 }), ok(200, item('olduser/roc-json', 'moved', 'acme/roc-json', t1)), 1);
  c.req('R-AP1 read of the old name: its `repos` item is moved with the successor (R-AP32, R-PU28).', { method: 'GET', path: '/v1/packages/olduser/roc-json/releases', headers: UA, now: NOW + 1500 }, { status: 200, json_at: { 'repos.0.name': 'olduser/roc-json', 'repos.0.state': 'moved', 'repos.0.successor': 'acme/roc-json', 'repos.0.state_at': t1 }, json_len: { repos: 1 } }, 1);
  c.req('R-AP33, R-PU29: the short name roc-json matches 2 names: the old name is replaced by the end of its chain, so there is one match, acme/roc-json, moved from olduser/roc-json.', { method: 'GET', path: '/v1/packages?short=roc-json', headers: UA, now: NOW + 1600 }, { status: 200, json_len: { 'matches.0.matches': 1 }, json_at: { 'matches.0.matches.0.name': 'acme/roc-json', 'matches.0.matches.0.moved_from': 'olduser/roc-json', 'matches.0.matches.0.state': 'active' } }, 1);
  c.req('PUT of another successor (the token of acme/second): the old row has a successor, so the answer is 200 and the successor changes, state_at is the new clock. 2 D1 calls.', put('t-second', 'acme/second', { now: t2 }), ok(200, item('olduser/roc-json', 'moved', 'acme/second', t2)), 2);
  c.req('The read again, with Cache-Control: no-cache (R-AP43): the successor is acme/second.', { method: 'GET', path: '/v1/packages/olduser/roc-json/releases', headers: { ...UA, 'cache-control': 'no-cache' }, now: NOW + 2500 }, { status: 200, json_at: { 'repos.0.successor': 'acme/second', 'repos.0.state_at': t2 } }, 1);
  c.req('DELETE with the token of the successor (acme/second, any owner id): the successor is removed, 200, the answer has successor null. 2 D1 calls. (The state after the removal is Q247-2: not in the case.)', del('t-second', { now: t3 }), { status: 200, headers: { 'content-type': 'application/json', 'cache-control': 'no-store' }, headers_set: ['talon-bookmark'], json: { name: 'olduser/roc-json', successor: null, state_at: t3 } }, 2);
  c.req('DELETE again, now with the token of the old repository: no successor, so 200 and nothing is written (1 D1 call).', del('t-old', { now: t3 + 1000 }), { status: 200, headers: { 'content-type': 'application/json', 'cache-control': 'no-store' }, headers_set: ['talon-bookmark'], json: { name: 'olduser/roc-json', successor: null, state_at: t3 } }, 1);
  // The events: the 3 seeded binds and the events of the 3 changes of the old name (claims of the token that caused each one).
  const rows = byName([
    ['acme/roc-json', 1, 0, null, 200, null, 10, null, SEED_T],
    ['acme/second', 1, 0, null, 201, null, 10, null, SEED_T],
    ['olduser/roc-json', 1, 0, null, 100, null, 10, null, SEED_T],
    ['olduser/roc-json', 2, SUCCESSOR_SET, 100, 100, 10, 10, c.recorded('t-acme'), t1],
    ['olduser/roc-json', 3, SUCCESSOR_SET, 100, 100, 10, 10, c.recorded('t-second'), t2],
    ['olduser/roc-json', 4, SUCCESSOR_REMOVED, 100, 100, 10, 10, c.recorded('t-second'), t3],
  ]);
  c.db = block(Q.reposOpen, byName([
    ['acme/roc-json', 200, 10, null, null, SEED_T, SEED_T],
    ['acme/second', 201, 10, null, null, SEED_T, SEED_T],
    ['olduser/roc-json', 100, 10, null, null, t3, SEED_T],
  ])) + block(Q.eventsOpen, rows) + block(Q.setSuccessor, [['olduser/roc-json', 2, 'acme/roc-json'], ['olduser/roc-json', 3, 'acme/second']]) + block(Q.names, kindRows(c));
  c.write();
}

// ---- case 2: the checks of R-AP31, in their order, and the good successor at the end ----
function checks() {
  const c = new Case('ap31-checks', 'R-AP31 R-TP14 R-AP21 R-AP41 R-RE1 R-RE2 R-RE11 R-IK5 R-PU17 R-YK4 R-TP15');
  c.oldPackage();
  // Each successor is a name of the same owner (10), so its own token passes the role table of R-TP15. Only the check of the successor decides.
  c.repo('chk/missing', { id: 301, owner: 10, state: 'missing' });
  c.release('chk/missing', '1.0.0', { exposes: ['Alpha', 'Beta'], withdrawn: 'repo-missing' });
  c.repo('chk/moved', { id: 302, owner: 10, state: 'moved', successor: 'acme/roc-json' });
  c.release('chk/moved', '1.0.0', { exposes: ['Alpha', 'Beta'] });
  c.repo('chk/yanked', { id: 303, owner: 10 });
  c.release('chk/yanked', '1.0.0', { exposes: ['Alpha', 'Beta'], yanked: 1 });
  c.repo('chk/withdrawn', { id: 304, owner: 10 });
  c.release('chk/withdrawn', '1.0.0', { exposes: ['Alpha', 'Beta'], withdrawn: 'deleted' });
  c.repo('chk/kind', { id: 305, owner: 10 });
  c.release('chk/kind', '1.0.0', { kind: 'app', exposes: [] });
  c.repo('chk/exposes', { id: 306, owner: 10 });
  c.release('chk/exposes', '1.0.0', { exposes: ['Alpha'] });
  c.repo('chk/both', { id: 307, owner: 10 });
  c.release('chk/both', '1.0.0', { kind: 'app', exposes: [] });
  // The newest candidate is 3.0.0 (it exposes what the old name needs). A yanked 4.0.0 of another kind and a later log entry 0.9.0 of another kind are not the newest candidate.
  c.repo('chk/newest', { id: 308, owner: 10 });
  c.release('chk/newest', '1.0.0', { exposes: ['Alpha'] });
  c.release('chk/newest', '3.0.0', { exposes: ['Alpha', 'Beta'] });
  c.release('chk/newest', '4.0.0', { kind: 'app', exposes: [], yanked: 1 });
  c.release('chk/newest', '0.9.0', { kind: 'platform', exposes: [] });
  const names = ['chk/none', 'chk/missing', 'chk/moved', 'chk/yanked', 'chk/withdrawn', 'chk/kind', 'chk/exposes', 'chk/both', 'chk/newest'];
  names.forEach((n, i) => c.token(`t-${n.slice(4)}`, n, 300 + i, 10));
  c.jwks();
  const go = (comment, n, expect, calls = 1) => c.req(comment, put(`t-${n.slice(4)}`, n), expect, calls);
  go('The successor has no repos row: check Index.', 'chk/none', mismatch(T.index('chk/none')));
  go('The successor is missing (its release is withdrawn): Index.', 'chk/missing', mismatch(T.index('chk/missing')));
  go('The successor is moved: Index (an active row is needed).', 'chk/moved', mismatch(T.index('chk/moved')));
  go('The successor is active, and its only release is yanked: no candidate, Index.', 'chk/yanked', mismatch(T.index('chk/yanked')));
  go('The successor is active, and its only release is withdrawn: no candidate, Index.', 'chk/withdrawn', mismatch(T.index('chk/withdrawn')));
  go('The newest candidate of the successor is an app, the old name has a package: Kind.', 'chk/kind', mismatch(T.kind('chk/kind')));
  go('The successor exposes Alpha only. The newest release of the old name is 2.0.0 (Alpha, Beta), not 1.0.0 (Alpha, Beta, Gamma) that is last in the log: the missing module is Beta.', 'chk/exposes', mismatch(T.exposes('chk/exposes', ['Beta'])));
  go('The successor fails Kind and exposes: the first check that fails is Kind.', 'chk/both', mismatch(T.kind('chk/both')));
  go('The newest candidate is 3.0.0 (a yanked 4.0.0 and a platform 0.9.0 that is last in the log do not count): all checks pass, 201.', 'chk/newest', ok(201, item('olduser/roc-json', 'moved', 'chk/newest', NOW)), 2);
  const repoRows = [
    seededRepo('chk/both', 307, 10), seededRepo('chk/exposes', 306, 10), seededRepo('chk/kind', 305, 10), seededRepo('chk/missing', 301, 10, 'missing'),
    seededRepo('chk/moved', 302, 10, 'moved', 'acme/roc-json'), seededRepo('chk/newest', 308, 10), seededRepo('chk/withdrawn', 304, 10), seededRepo('chk/yanked', 303, 10),
    ['olduser/roc-json', 100, 10, STATE.moved, 'chk/newest', null, NOW, SEED_T],
  ];
  const ev = repoRows.map((r) => seededBind(r[0], r[1], r[2]));
  ev.push(['olduser/roc-json', 2, SUCCESSOR_SET, 100, 100, 10, 10, 'chk/newest', c.recorded('t-newest'), NOW]);
  c.db = block(Q.repos, byName(repoRows)) + block(Q.events, byName(ev)) + block(Q.releases, [[1, 0, null], [2, 0, null], [3, 0, 'repo-missing'], [4, 0, null], [5, 1, null], [6, 0, 'deleted'], [7, 0, null], [8, 0, null], [9, 0, null], [10, 0, null], [11, 0, null], [12, 1, null], [13, 0, null]]);
  c.write();
}

// ---- case 3: the refusals of R-TP15: the role table, the token claims, the token form (the claims are checked before D1) ----
function refusals() {
  const c = new Case('tp15-refusals', 'R-TP15 R-TP3 R-AP31 R-AP21 R-AP41 R-AP26');
  c.oldPackage();
  c.goodSuccessor('acme/roc-json', 200, 10);
  c.goodSuccessor('acme/other', 202, 10);
  c.goodSuccessor('third/lib', 300, 30);
  c.repo('olduser/gone', { id: 150, owner: 10, state: 'moved', successor: 'acme/roc-json' });
  c.release('olduser/gone', '1.0.0', { exposes: ['Alpha', 'Beta'] });
  c.token('t-acme-owner20', 'acme/roc-json', 200, 20);
  c.token('t-third', 'third/lib', 300, 30);
  c.token('t-other', 'acme/other', 202, 10);
  c.token('t-gone', 'olduser/gone', 150, 10);
  c.token('t-acme', 'acme/roc-json', 200, 10);
  c.token('t-private', 'acme/roc-json', 200, 10, { repository_visibility: 'private' });
  c.token('t-push', 'acme/roc-json', 200, 10, { event_name: 'push' });
  c.token('t-tamper', 'acme/roc-json', 200, 10, {}, { tamper: 'signature' });
  c.tokens['t-raw'] = { raw: 'not.a.jwt' };
  c.jwks();
  const body = { name: 'acme/roc-json' };
  c.req('The token of the successor name, but the owner id 20 is not the owner of the old row (10), and there is no offer: 403.', put('t-acme-owner20', 'acme/roc-json'), forbidden(T.roleOwner('20', 'olduser/roc-json', 'acme/roc-json')), 1);
  c.req('The token of another account (third/lib): not the old repository, not the successor: 403.', put('t-third', 'acme/roc-json'), forbidden(T.roleOther('third/lib', 'olduser/roc-json', 'acme/roc-json')), 1);
  c.req('A repository of the same account (owner id 10) that is not the named successor: 403.', put('t-other', 'acme/roc-json'), forbidden(T.roleOther('acme/other', 'olduser/roc-json', 'acme/roc-json')), 1);
  c.req('The token of an old repository whose row is moved: an offer needs the state active: 403.', put('t-gone', 'acme/roc-json', {}, '/v1/packages/olduser/gone/successor'), forbidden(T.roleState('olduser/gone', 'olduser/gone', 'moved')), 1);
  c.req('DELETE on a row with no successor, with the token of another repository: 403 (only the old repository has a say).', del('t-acme'), forbidden(T.delNoSucc('acme/roc-json', 'olduser/roc-json')), 1);
  c.req('DELETE on a row with a successor, with the token of a repository that is neither the old one nor the successor: 403.', del('t-other', {}, '/v1/packages/olduser/gone/successor'), forbidden(T.delOther('acme/other', 'olduser/gone')), 1);
  c.req('The repository of the token is private: 403, no D1 call (R-TP3 row 6).', put('t-private', 'acme/roc-json'), forbidden(T.visibility('private')), 0);
  c.req('The event of the token is push, not workflow_dispatch: 403, no D1 call.', put('t-push', 'acme/roc-json'), forbidden(T.event('push')), 0);
  c.req('No Authorization header: 401.', { method: 'PUT', path: OLD_PATH, headers: UA, json: body, now: NOW }, unauth(T.missingToken), 0);
  c.req('The Authorization scheme is Basic: 401, never a read.', { method: 'PUT', path: OLD_PATH, headers: { ...UA, authorization: 'Basic abc' }, json: body, now: NOW }, unauth(T.notBearer), 0);
  c.req('A token that is no JWT: 401.', put('t-raw', 'acme/roc-json'), unauth(T.notJwt), 0);
  c.req('A token with a changed signature: 401.', put('t-tamper', 'acme/roc-json'), unauth(T.badSignature), 0);
  c.req('DELETE with no Authorization header: 401.', { method: 'DELETE', path: OLD_PATH, headers: UA, now: NOW }, unauth(T.missingToken), 0);
  const repoRows = [seededRepo('acme/other', 202, 10), seededRepo('acme/roc-json', 200, 10), seededRepo('olduser/gone', 150, 10, 'moved', 'acme/roc-json'), seededRepo('olduser/roc-json', 100, 10), seededRepo('third/lib', 300, 30)];
  c.db = block(Q.repos, repoRows) + block(Q.events, byName(repoRows.map((r) => seededBind(r[0], r[1], r[2]))));
  c.write();
}

// ---- case 4: the offer: the old repository offers, the successor of another account accepts (R-TP15 rows 2, 3) ----
function offer() {
  const c = new Case('tp15-offer', 'R-TP15 R-AP31 R-RE11 R-RE15 R-TP13 R-AP41 R-AP21');
  c.oldPackage();
  c.goodSuccessor('newowner/roc-json', 400, 40);
  c.goodSuccessor('third/lib', 500, 50);
  c.token('t-old', 'olduser/roc-json', 100, 10);
  c.token('t-new', 'newowner/roc-json', 400, 40);
  c.token('t-third', 'third/lib', 500, 50);
  c.jwks();
  const name = 'newowner/roc-json';
  const t5 = NOW + 5000;
  c.req('The successor is in another account (owner id 40) and there is no offer: 403.', put('t-new', name), forbidden(T.roleOwner('40', 'olduser/roc-json', name)), 1);
  c.req('The token of the old repository (state active): an offer. 202, the answer is the row of the old name: still active, no successor, state_at unchanged. 2 D1 calls.', put('t-old', name, { now: NOW + 1000 }), ok(202, item('olduser/roc-json', 'active', null, SEED_T)), 2);
  c.req('A third account cannot use the offer: 403 (not the old repository, not the offered name).', put('t-third', name, { now: NOW + 2000 }), forbidden(T.roleOther('third/lib', 'olduser/roc-json', name)), 1);
  c.req('The third account names itself: the offer is for another name, so 403.', put('t-third', 'third/lib', { now: NOW + 3000 }), forbidden(T.roleOwner('50', 'olduser/roc-json', 'third/lib')), 1);
  c.req('The offered successor accepts with its own token (owner id 40): the move is done, 201, the offer is cleared.', put('t-new', name, { now: t5 }), ok(201, item('olduser/roc-json', 'moved', name, t5)), 2);
  const ev = [
    ['newowner/roc-json', 1, 0, null, 400, null, 40, null, SEED_T],
    ['olduser/roc-json', 1, 0, null, 100, null, 10, null, SEED_T],
    ['olduser/roc-json', 2, OFFER, 100, 100, 10, 10, c.recorded('t-old'), NOW + 1000],
    ['olduser/roc-json', 3, SUCCESSOR_SET, 100, 100, 10, 10, c.recorded('t-new'), t5],
    ['third/lib', 1, 0, null, 500, null, 50, null, SEED_T],
  ];
  c.db = block(Q.reposOpen, byName([
    ['newowner/roc-json', 400, 40, null, null, SEED_T, SEED_T],
    ['olduser/roc-json', 100, 10, name, null, t5, SEED_T],
    ['third/lib', 500, 50, null, null, SEED_T, SEED_T],
  ])) + block(Q.eventsOpen, byName(ev)) + block(Q.setSuccessor, [['olduser/roc-json', 3, name]]);
  c.write();
}

// ---- case 5: the operator key (R-TP15, R-YK2): no token, no claims, no role table; the checks of R-AP31 still apply ----
function operator() {
  const c = new Case('tp15-operator', 'R-TP15 R-YK2 R-AP31 R-RE15 R-TP13 R-AP41 R-AP21 R-TP12');
  c.settings.OPERATOR_KEY = 'op-key-1';
  c.oldPackage();
  c.goodSuccessor('newowner/roc-json', 400, 40);
  const op = { authorization: 'Bearer op-key-1' };
  const name = 'newowner/roc-json';
  const t2 = NOW + 2000; const t5 = NOW + 5000;
  const opPut = (n, extra = {}) => ({ method: 'PUT', path: OLD_PATH, headers: { ...UA, ...op }, json: { name: n }, now: NOW, ...extra });
  c.req('The operator names the old name as the successor: all checks pass except Chain (the old name is the start of the walk): 422. No JWKS read.', opPut('olduser/roc-json'), mismatch(T.chain('olduser/roc-json')), 1);
  c.req('The operator names a text that is not an owner/repo name: the check Index fails (the checks of R-AP31 apply to the operator): 422.', opPut('not a name'), mismatch(T.index('not a name')), 1);
  c.req('The operator sets a successor in another account (no offer): 201. No claims on the event.', opPut(name, { now: t2 }), ok(201, item('olduser/roc-json', 'moved', name, t2)), 2);
  c.req('The same again: 200, no write.', opPut(name, { now: t2 + 1000 }), ok(200, item('olduser/roc-json', 'moved', name, t2)), 1);
  c.req('A text that is not the operator key is a token: it is no JWT, 401 (no JWKS read).', { method: 'PUT', path: OLD_PATH, headers: { ...UA, authorization: 'Bearer op-key-2' }, json: { name }, now: NOW }, unauth(T.notJwt), 0);
  c.req('DELETE by the operator: the successor is removed, 200.', { method: 'DELETE', path: OLD_PATH, headers: { ...UA, ...op }, now: t5 }, { status: 200, headers: { 'content-type': 'application/json', 'cache-control': 'no-store' }, headers_set: ['talon-bookmark'], json: { name: 'olduser/roc-json', successor: null, state_at: t5 } }, 2);
  c.req('DELETE by the operator again: 200, no write.', { method: 'DELETE', path: OLD_PATH, headers: { ...UA, ...op }, now: t5 + 1000 }, { status: 200, json: { name: 'olduser/roc-json', successor: null } }, 1);
  const ev = [
    ['newowner/roc-json', 1, 0, null, 400, null, 40, null, SEED_T],
    ['olduser/roc-json', 1, 0, null, 100, null, 10, null, SEED_T],
    ['olduser/roc-json', 2, SUCCESSOR_SET, 100, 100, 10, 10, null, t2],
    ['olduser/roc-json', 3, SUCCESSOR_REMOVED, 100, 100, 10, 10, null, t5],
  ];
  c.db = block(Q.reposOpen, byName([
    ['newowner/roc-json', 400, 40, null, null, SEED_T, SEED_T],
    ['olduser/roc-json', 100, 10, null, null, t5, SEED_T],
  ])) + block(Q.eventsOpen, byName(ev)) + block(Q.setSuccessor, [['olduser/roc-json', 2, name]]);
  c.write();
}

// ---- case 6: bad requests: the old name has no row (404), the body (400), the size (413) ----
function errors() {
  const c = new Case('ap31-errors', 'R-AP31 R-AP21 R-AP46 R-AP51 R-AP41 R-AP48');
  c.oldPackage();
  c.goodSuccessor('acme/roc-json', 200, 10);
  c.token('t-acme', 'acme/roc-json', 200, 10);
  c.jwks();
  const raw = (body, extra = {}) => ({ method: 'PUT', path: OLD_PATH, headers: { ...UA, 'content-type': 'application/json' }, body, token: 't-acme', now: NOW, ...extra });
  c.req('The old name has no repos row: 404. (It reads the token first: this request fills the JWKS memo, so the next requests do not depend on the order of the body check and the token check, Q247-1.)', put('t-acme', 'acme/roc-json', {}, '/v1/packages/nobody/nothing/successor'), notFound(T.noRepo('nobody/nothing')), 1);
  c.req('DELETE of a name with no repos row: 404.', del('t-acme', {}, '/v1/packages/nobody/nothing/successor'), notFound(T.noRepo('nobody/nothing')), 1);
  c.req('The body is not JSON: 400.', raw('this is not json'), bad(), 0);
  c.req('The body is a JSON object with no name: 400.', raw('{}'), bad(), 0);
  c.req('The name is null: 400.', raw('{"name":null}'), bad(), 0);
  c.req('The name is a number: 400.', raw('{"name":42}'), bad(), 0);
  c.req('The body is a JSON list: 400.', raw('["acme/roc-json"]'), bad(), 0);
  c.req('A PUT with no body: 400.', { method: 'PUT', path: OLD_PATH, headers: UA, token: 't-acme', now: NOW }, bad(), 0);
  c.req('A body larger than 256 KB: 413 too-large, field body, limit 262144, no D1 call.', { method: 'PUT', path: OLD_PATH, headers: { ...UA, 'content-type': 'application/json' }, body_pad: { prefix: '{"name":"', total: 262145, suffix: '"}' }, token: 't-acme', now: NOW }, { status: 413, problem: { type: '/errors/too-large', detail: T.tooLarge }, json: { field: 'body', limit: 262144 } }, 0);
  c.req('A body with another media type (text/plain): 415 before the handler.', { method: 'PUT', path: OLD_PATH, headers: { ...UA, 'content-type': 'text/plain' }, body: '{"name":"acme/roc-json"}', token: 't-acme', now: NOW }, problem(415, '/errors/unsupported-media-type'), 0);
  c.req('POST on the route: 405 with Allow: DELETE, PUT.', { method: 'POST', path: OLD_PATH, headers: { ...UA, 'content-type': 'application/json' }, body: '{}', now: NOW }, { status: 405, headers: { allow: 'DELETE, PUT' }, problem: { type: '/errors/method-not-allowed' } }, 0);
  c.req('GET on the route: 405 with Allow: DELETE, PUT.', { method: 'GET', path: OLD_PATH, headers: UA, now: NOW }, { status: 405, headers: { allow: 'DELETE, PUT' }, problem: { type: '/errors/method-not-allowed' } }, 0);
  c.req('A path with an extra part: 404.', { method: 'PUT', path: `${OLD_PATH}/x`, headers: UA, json: { name: 'acme/roc-json' }, now: NOW }, problem(404, '/errors/not-found'), 0);
  const repoRows = [seededRepo('acme/roc-json', 200, 10), seededRepo('olduser/roc-json', 100, 10)];
  c.db = block(Q.repos, repoRows) + block(Q.events, byName(repoRows.map((r) => seededBind(r[0], r[1], r[2]))));
  c.write();
}

// ---- case 7: MIN_TLN_WRITE covers the move routes (R-AP45) ----
function minWrite() {
  const c = new Case('ap45-min-write', 'R-AP45 R-AP41 R-AP31 R-AP48');
  c.settings.MIN_TLN_WRITE = '0.5.0';
  c.oldPackage();
  const old = { problem: { type: '/errors/unsupported-client', minimum: '0.5.0' } };
  c.req('PUT with tln/0.4.1: 400 unsupported-client with the minimum, before any token or body check.', { method: 'PUT', path: OLD_PATH, headers: { 'user-agent': 'tln/0.4.1' }, json: { name: 'acme/roc-json' }, now: NOW }, { status: 400, ...old }, 0);
  c.req('DELETE with tln/0.4.1: 400 unsupported-client.', { method: 'DELETE', path: OLD_PATH, headers: { 'user-agent': 'tln/0.4.1' }, now: NOW }, { status: 400, ...old }, 0);
  c.req('PUT with tln/0.5.0 (equal to the minimum) and no token: the version passes, 401.', { method: 'PUT', path: OLD_PATH, headers: { 'user-agent': 'tln/0.5.0' }, json: { name: 'acme/roc-json' }, now: NOW }, unauth(T.missingToken), 0);
  c.req('PUT with curl/8 (not checked) and no token: 401.', { method: 'PUT', path: OLD_PATH, headers: { 'user-agent': 'curl/8.5.0' }, json: { name: 'acme/roc-json' }, now: NOW }, unauth(T.missingToken), 0);
  c.req('GET of the same path: 405 (the version of a read route is not the question here).', { method: 'GET', path: OLD_PATH, headers: { 'user-agent': 'tln/0.4.1' }, now: NOW }, { status: 405, problem: { type: '/errors/method-not-allowed' } }, 0);
  const repoRows = [seededRepo('olduser/roc-json', 100, 10)];
  c.db = block(Q.repos, repoRows);
  c.write();
}

// ---- case 8: the case of the names (R-IK2: the lower-case name is the key; GitHub names have no case) ----
function caseFold() {
  const c = new Case('ap31-case-fold', 'R-AP31 R-IK2 R-AP56 R-TP15 R-AP41');
  c.oldPackage();
  c.goodSuccessor('acme/roc-json', 200, 10);
  c.token('t-mixed', 'ACME/Roc-JSON', 200, 10);
  c.jwks();
  const t = NOW;
  c.req('The path, the body name and the claim repository have other case: the same names. 201, the answer has the lower-case names, no new names row.', put('t-mixed', 'Acme/ROC-json', {}, '/v1/packages/OldUser/Roc-Json/successor'), ok(201, item('olduser/roc-json', 'moved', 'acme/roc-json', t)), 2);
  const rows = byName([seededRepo('acme/roc-json', 200, 10), ['olduser/roc-json', 100, 10, STATE.moved, 'acme/roc-json', null, t, SEED_T]]);
  const ev = [seededBind('acme/roc-json', 200, 10), seededBind('olduser/roc-json', 100, 10), ['olduser/roc-json', 2, SUCCESSOR_SET, 100, 100, 10, 10, 'acme/roc-json', c.recorded('t-mixed'), t]];
  c.db = block(Q.repos, rows) + block(Q.events, byName(ev)) + block(Q.names, kindRows(c));
  c.write();
}

// ---- slice 247b: the member `owner_changed` of the `repos` item (R-AP32, R-PU30), the old-ids check (R-TP15, Q247-9), the cache drop (Q247-13) ----
const GROUP = (n) => `github.com/${n}/releases/download/{v}/`;
const enc = encodeURIComponent;
const T1 = 1767100000000; const T2 = 1767200000000; const T3 = 1767210000000; const T0 = 1767050000000;
const RELEASES = (n) => `/v1/packages/${n}/releases`;

// R-PU30: the member after a transfer and a recreate (R-TP9), and for a repo with none. The last event of action 1 or 3 decides, not the last event. One D1 call for each read (R-AP41).
function pu30Reads() {
  const c = new Case('pu30-reads', 'R-PU30 R-AP32 R-AP1 R-AP2 R-AP13 R-AP14 R-AP17 R-TP13 R-TP9 R-AP41');
  const mk = (n, id, owner) => { c.repo(n, { id, owner }); c.release(n, '1.0.0', { exposes: ['Alpha'] }); };
  mk('acme/lib', 500, 50); mk('acme/two', 501, 50); mk('acme/none', 502, 50);
  // acme/lib: transfer, then recreate, then found. The newest of 1 and 3 is the recreate at T2 (a later `found` does not hide it).
  c.event('acme/lib', 2, 1, T1); c.event('acme/lib', 3, 3, T2); c.event('acme/lib', 4, 5, T3);
  // acme/two: recreate, then transfer: the newest is the transfer at T1.
  c.event('acme/two', 2, 3, T0); c.event('acme/two', 3, 1, T1);
  const lib = { action: 'recreate', at: T2 }; const two = { action: 'transfer', at: T1 };
  c.req('R-AP1 of acme/lib: owner_changed is the recreate at T2 (the last event of action 1 or 3; the later found at T3 does not count). One D1 call.', { method: 'GET', path: RELEASES('acme/lib'), headers: UA, now: NOW }, { status: 200, json_at: { 'repos.0.name': 'acme/lib', 'repos.0.owner_changed': lib } }, 1);
  c.req('R-AP1 of acme/two: owner_changed is the transfer at T1 (the older recreate at T0 does not count).', { method: 'GET', path: RELEASES('acme/two'), headers: UA, now: NOW }, { status: 200, json_at: { 'repos.0.owner_changed': two } }, 1);
  c.req('R-AP1 of acme/none: no event of action 1 or 3 (only the bind): the member is present and null (not missing).', { method: 'GET', path: RELEASES('acme/none'), headers: UA, now: NOW }, { status: 200, json_at: { 'repos.0.owner_changed': null } }, 1);
  const h2 = fakeHash('slice 247 acme/two 1.0.0');
  c.req('R-AP2: the artifact of acme/two: the same member in its repos item. One D1 call.', { method: 'GET', path: `/v1/artifacts/${h2}`, headers: UA, now: NOW }, { status: 200, json_at: { 'repos.0.name': 'acme/two', 'repos.0.owner_changed': two } }, 1);
  c.req('R-AP13: the group of acme/none: null. One D1 call.', { method: 'GET', path: `/v1/releases?group=${enc(GROUP('acme/none'))}`, headers: UA, now: NOW }, { status: 200, json_at: { 'repos.0.name': 'acme/none', 'repos.0.owner_changed': null } }, 1);
  c.req('R-AP14: the page of all releases: 3 repos, by name, each with its own member. One D1 call.', { method: 'GET', path: '/v1/releases?after=0', headers: UA, now: NOW }, { status: 200, json_len: { repos: 3 }, json_at: { 'repos.0.name': 'acme/lib', 'repos.0.owner_changed': lib, 'repos.1.name': 'acme/none', 'repos.1.owner_changed': null, 'repos.2.name': 'acme/two', 'repos.2.owner_changed': two } }, 1);
  c.req('R-AP17: the closure of 2 groups: the repos of the answer carry the member. One D1 call.', { method: 'POST', path: '/v1/closure', headers: UA, json: { groups: [{ group: GROUP('acme/lib') }, { group: GROUP('acme/none') }], hashes: [] }, now: NOW }, { status: 200, json_at: { 'repos.0.name': 'acme/lib', 'repos.0.owner_changed': lib, 'repos.1.name': 'acme/none', 'repos.1.owner_changed': null } }, 1);
  c.db = '';
  c.write();
}

// R-PU30: the move answer carries the member too (R-AP32).
function pu30MoveAnswer() {
  const c = new Case('pu30-move-answer', 'R-PU30 R-AP32 R-AP31 R-TP13 R-AP41');
  c.oldPackage();
  c.event('olduser/roc-json', 2, 1, T1);
  c.repo('other/old', { id: 300, owner: 30 });
  c.release('other/old', '1.0.0', { exposes: ['Alpha', 'Beta'] });
  c.event('other/old', 2, 3, T2);
  c.goodSuccessor('acme/roc-json', 200, 10);
  c.goodSuccessor('newowner/other', 400, 40);
  c.token('t-acme', 'acme/roc-json', 200, 10);
  c.token('t-other-succ', 'newowner/other', 400, 30);
  c.token('t-oldother', 'other/old', 300, 30);
  c.jwks();
  const xfer = { action: 'transfer', at: T1 }; const rec = { action: 'recreate', at: T2 };
  const withMember = (status, name, state, succ, sa, oc) => ok(status, { name, state, successor: succ, state_at: sa, owner_changed: oc });
  c.req('PUT 201: the answer has owner_changed = the transfer at T1 (the move event 6 does not replace it).', put('t-acme', 'acme/roc-json'), withMember(201, 'olduser/roc-json', 'moved', 'acme/roc-json', NOW, xfer), 2);
  c.req('The same PUT again: 200, same member.', put('t-acme', 'acme/roc-json', { now: NOW + 1000 }), withMember(200, 'olduser/roc-json', 'moved', 'acme/roc-json', NOW, xfer), 1);
  c.req('DELETE by the successor token: 200, same member.', del('t-acme', { now: NOW + 2000 }, OLD_PATH), { status: 200, json_at: { owner_changed: xfer, successor: null } }, 2);
  c.req('An offer on other/old (owner 30, recreated at T2) by its own token: 202, the member is the recreate.', put('t-oldother', 'newowner/other', { now: NOW + 3000 }, '/v1/packages/other/old/successor'), withMember(202, 'other/old', 'active', null, SEED_T, rec), 2);
  c.db = '';
  c.write();
}

// R-PU30 with the real events of R-TP9: the publish of tp9-four-rows writes the transfer and the recreate; the reads then show them.
function pu30RealEvents() {
  const src = join(here, '..', 'cases', 'identity', 'tp9-four-rows');
  const dir = join(casesDir, 'pu30-real-events');
  rmSync(dir, { recursive: true, force: true });
  cpSync(src, dir, { recursive: true });
  const t = 1767225630000;
  const reads = [['xfer/repo', { action: 'transfer', at: t }], ['again/repo', { action: 'recreate', at: t }], ['same/repo', null]];
  const reqs = reads.map(([n]) => ({ method: 'GET', path: RELEASES(n), now: t + 1000, headers: { 'cache-control': 'no-cache' } }));
  appendFileSync(join(dir, 'requests.jsonl'), reqs.map((r) => JSON.stringify(r)).join('\n') + '\n');
  const resp = reads.map(([n, oc]) => ({ status: 200, json_at: { 'repos.0.name': n, 'repos.0.owner_changed': oc } }));
  appendFileSync(join(dir, 'expect', 'responses.jsonl'), resp.map((r) => JSON.stringify(r)).join('\n') + '\n');
  appendFileSync(join(dir, 'expect', 'd1-calls'), '1\n1\n1\n');
  const n0 = readFileSync(join(dir, 'notes.txt'), 'utf8').trim().split('\n').length;
  appendFileSync(join(dir, 'notes.txt'), reads.map(([n, oc], i) => `${n0 + i + 1}: R-AP1 of ${n} after the publish: owner_changed is ${oc ? `${oc.action} at the clock of the publish` : 'null (the same ids: no transfer, no recreate)'}.`).join('\n') + '\n');
  writeFileSync(join(dir, 'rules'), `${readFileSync(join(dir, 'rules'), 'utf8').trim()} R-PU30 R-AP32\n`);
}

// Q247-9, R-TP15: the check of the old ids. A token of the old name whose ids do not match the row ids is a 403 `repository-changed` (R-TP9 text), whatever the role.
function oldIds() {
  const c = new Case('tp15-old-ids', 'R-TP15 R-TP9 R-AP31 R-AP21 R-AP41 R-TP19');
  c.settings.ISSUES_URL = 'https://github.com/roc-talon/talon/issues';
  c.oldPackage();
  c.repo('olduser/gone2', { id: 150, owner: 15, state: 'moved', successor: 'acme/roc-json' });
  c.release('olduser/gone2', '1.0.0', { exposes: ['Alpha', 'Beta'] });
  c.repo('olduser/other', { id: 160, owner: 16 });
  c.release('olduser/other', '1.0.0', { exposes: ['Alpha', 'Beta'] });
  c.goodSuccessor('acme/roc-json', 200, 10);
  c.token('t-stranger', 'olduser/roc-json', 999, 99);
  c.token('t-stranger2', 'olduser/gone2', 998, 98);
  c.token('t-sameowner', 'olduser/roc-json', 999, 10);
  c.token('t-samerepo', 'olduser/other', 160, 99);
  c.jwks();
  const detail = (n, id) => `the name ${n} is bound to another GitHub account (repository id ${id})`;
  const refuse = (n, id) => ({ status: 403, problem: { type: '/errors/repository-changed', title: 'Repository changed', detail: detail(n, id) }, json: { issues_url: c.settings.ISSUES_URL } });
  const strip = (r) => r;
  c.req('An offer PUT with the token of olduser/roc-json whose ids (999, 99) match neither id of the row (100, 10): 403 repository-changed, with the issues_url. 1 D1 call, nothing written.', put('t-stranger', 'acme/roc-json'), strip(refuse('olduser/roc-json', 100)), 1);
  c.req('DELETE on the moved name olduser/gone2 with a token of that name and ids (998, 98) that do not match (150, 15): 403 repository-changed. 1 D1 call.', del('t-stranger2', {}, '/v1/packages/olduser/gone2/successor'), strip(refuse('olduser/gone2', 150)), 1);
  c.req('The token has the other id of the row (the owner id 10 equals the row owner, the repository id does not): not changed, so the offer goes on. The offer is for acme/roc-json (owner 10): all checks pass, 202. 2 D1 calls.', put('t-sameowner', 'acme/roc-json', { now: NOW + 1000 }), ok(202, item('olduser/roc-json', 'active', null, SEED_T)), 2);
  c.req('A token of olduser/other with the same repository id (160) and another owner id (99): not changed. The offer is not accepted by the role table only when the ids are wrong; here the old repository offers, 202 (the offered name acme/roc-json is checked by Index, Kind, exposes: it passes).', put('t-samerepo', 'acme/roc-json', { now: NOW + 2000 }, '/v1/packages/olduser/other/successor'), ok(202, item('olduser/other', 'active', null, SEED_T)), 2);
  c.db = '';
  c.write();
}

// Q247-13: a move drops the R-AP1 cache key of the old name. Read, move, read again (no no-cache): the second read sees `moved`.
function cacheDrop() {
  const c = new Case('ap31-cache-drop', 'R-AP31 R-AP1 R-AP43 R-AP32 R-AP41');
  c.oldPackage();
  c.goodSuccessor('acme/roc-json', 200, 10);
  c.token('t-acme', 'acme/roc-json', 200, 10);
  c.jwks();
  const rd = (now) => ({ method: 'GET', path: RELEASES('olduser/roc-json'), headers: UA, now });
  c.req('R-AP1 read of the old name: active, no successor. The answer is cached.', rd(NOW - 5000), { status: 200, json_at: { 'repos.0.state': 'active', 'repos.0.successor': null } }, 1);
  c.req('The same read: from the cache (no D1 call).', rd(NOW - 4000), { status: 200, json_at: { 'repos.0.state': 'active' } }, 0);
  c.req('The move: 201.', put('t-acme', 'acme/roc-json'), ok(201, item('olduser/roc-json', 'moved', 'acme/roc-json', NOW)), 2);
  c.raw({ wait_ms: 300 });
  c.req('The read again with no Cache-Control: no-cache: the key of the old name was dropped after the move, so the answer is new: moved, with the successor (1 D1 call).', rd(NOW + 1000), { status: 200, json_at: { 'repos.0.state': 'moved', 'repos.0.successor': 'acme/roc-json' } }, 1);
  c.db = '';
  c.write();
}

putDelete();
checks();
refusals();
offer();
operator();
errors();
minWrite();
caseFold();
pu30Reads();
pu30MoveAnswer();
pu30RealEvents();
oldIds();
cacheDrop();
