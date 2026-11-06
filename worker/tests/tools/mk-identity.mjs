// The W2 cases of slice 113 (repository identity of an ingest: Registry 7.3 R-TP9 to R-TP13; docs/slices/113-repo-identity.md section 4).
//   node worker/tests/tools/mk-identity.mjs     writes worker/tests/cases/identity/*/ (github/, seed.sql, requests.jsonl, settings.json, expect/, rules, notes.txt)
// The files are tracked. Run the script again only when a case changes: the hashes are in the names and in the expected files.
// The ids (R-IK2), the version columns (R-IK5) and the hashes are computed here with node (SHA-256, BigInt, BLAKE3), not with the Roc code.
import { createHash } from 'node:crypto';
import { mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { tar, zstd } from './mk-bundle.mjs';
import { rocHash } from './blake3.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const casesDir = join(here, '..', 'cases', 'identity');

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
const hex = (h) => b58decode(h).toString('hex').toUpperCase();
const sq = (s) => `'${String(s).replace(/'/g, "''")}'`;

// ---- the made bundle: one package for each release, a note makes the hash ----
const EXTRA_H = 'C6Jtcve7FRNtkwgmuyRBJnZfJyTrfJWhDcLp6gk4w4Gz';
const mod = (name) => `${name} :: [].{\n\tx : U64\n\tx = 1\n}\n`;
const pkg = (note) => zstd(tar([
  { path: 'main.roc', data: `## ${note}\npackage\n\t[\n\t\tAlpha,\n\t]\n\t{\n\t\textra: "https://example.com/pkgs/${EXTRA_H}.tar.zst",\n\t}\n` },
  { path: 'Alpha.roc', data: mod('Alpha') },
]));

// ---- constants of the cases ----
const NOW = 1767225630000; // the clock of each request
const SEED_T = 1767000000000; // the time of the seeded rows
const PUB = '2026-10-20T12:00:00Z';
const PUB_MS = Date.parse(PUB);
const HOUR = 3600000;
const AFTER_NOW = 1767312000000; // a time after the clock of the requests
const ISSUES = 'https://github.com/roc-talon/talon/issues';
const gh = (name, tag, hash) => `https://github.com/${name}/releases/download/${tag}/${hash}.tar.zst`;
const formOf = (name, tag) => `github.com/${name}/releases/download/${tag.startsWith('v') ? 'v' : ''}{v}/`;
const repoJson = (full, id, ownerId) => JSON.stringify({ id, name: full.split('/')[1], full_name: full, private: false, owner: { login: full.split('/')[0], id: ownerId, type: 'Organization' }, description: null, visibility: 'public', default_branch: 'main' });
const releaseJson = (tag, hash) => JSON.stringify({ id: 1, tag_name: tag, name: null, draft: false, prerelease: false, created_at: PUB, published_at: PUB, body: null, assets: [{ id: 1, name: `${hash}.tar.zst`, label: null, content_type: 'application/octet-stream', state: 'uploaded', size: 10, digest: null }] });
const post = (url, extra = {}) => ({ method: 'POST', path: '/v1/releases', json: { url }, now: NOW, ...extra });
const NOT_NULL_BOOKMARK = ['talon-bookmark'];

class Case {
  constructor(name, rules) { this.name = name; this.rules = rules; this.files = new Map(); this.reqs = []; this.exp = []; this.calls = []; this.log = []; this.seed = []; this.db = ''; this.notes = []; this.settings = { ISSUES_URL: ISSUES }; }
  file(url, body, meta, suffix = '') {
    const u = new URL(url);
    const enc = (s) => s.replace(/[%?:\\*<>|"]/g, (c) => `%${c.charCodeAt(0).toString(16).toUpperCase().padStart(2, '0')}`);
    const p = [enc(u.host), ...u.pathname.split('/').filter(Boolean).map(enc)].join('/');
    this.files.set(`${p}${suffix}`, body);
    if (meta) this.files.set(`${p}${suffix}.meta.json`, JSON.stringify(meta));
  }
  // The answer to the n-th request of a URL (run.mjs `<file>.<n>`), and the SQL that runs just before the first answer (`<file>.sql`).
  nth(url, n, body) { this.file(url, body, null, `.${n}`); }
  hook(url, sql) { this.file(url, sql, null, '.sql'); }
  // The GitHub of one release of `name` (the URL path is the name as sent): the repository answer (id, owner id, full_name), the release by tag, the asset, `.roc-version` (404).
  release({ name, tag, repoAnswer, note }) {
    const asset = pkg(note);
    const hash = rocHash(asset);
    const [o, r] = name.split('/');
    if (repoAnswer) this.file(`https://api.github.com/repos/${name}`, repoAnswer);
    this.file(`https://api.github.com/repos/${name}/releases/tags/${tag}`, releaseJson(tag, hash));
    this.file(gh(name, tag, hash), asset);
    this.file(`https://raw.githubusercontent.com/${o}/${r}/${tag}/.roc-version`, 'Not Found', { status: 404 });
    return hash;
  }
  reads(name, tag, hash, { repo = true, extra = [] } = {}) {
    const [o, r] = name.split('/');
    if (repo) this.log.push(`GET https://api.github.com/repos/${name}`);
    this.log.push(...extra);
    this.log.push(`GET https://api.github.com/repos/${name}/releases/tags/${tag}`, `GET ${gh(name, tag, hash)}`, `GET https://raw.githubusercontent.com/${o}/${r}/${tag}/.roc-version`);
  }
  req(comment, spec, expect, calls) { this.reqs.push(spec); this.exp.push(expect); this.calls.push(String(calls)); this.notes.push(comment); }
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
    writeFileSync(join(dir, 'settings.json'), `${JSON.stringify(this.settings)}\n`);
    writeFileSync(join(dir, 'requests.jsonl'), this.reqs.map((r) => JSON.stringify(r)).join('\n') + '\n');
    writeFileSync(join(dir, 'notes.txt'), this.notes.map((n, i) => `${i + 1}: ${n}`).join('\n') + '\n');
    writeFileSync(join(dir, 'expect', 'responses.jsonl'), this.exp.map((r) => JSON.stringify(r)).join('\n') + '\n');
    writeFileSync(join(dir, 'expect', 'd1-calls'), this.calls.join('\n') + '\n');
    writeFileSync(join(dir, 'expect', 'github.log'), this.log.join('\n') + '\n');
    writeFileSync(join(dir, 'seed.sql'), this.seed.join('\n') + '\n');
    writeFileSync(join(dir, 'expect', 'db.tsv'), this.db);
  }
  // A bound name before the case: the `names` row, the `repos` row, the `repo_checks` row and the event bind (seq 1), as an ingest of slice 112 and 113 wrote them.
  // `events`: the rows of `repo_events` as [seq, action, id before, id after, owner before, owner after, successor name]; the default is the event bind (seq 1).
  bound(name, { id, owner, state = 0, successor = null, stateAt = SEED_T, nextCheck = SEED_T + HOUR, events = [[1, 0, null, id, null, owner, null]] }) {
    const s = successor === null ? 'NULL' : repoId(successor);
    const v = (x) => (x === null ? 'NULL' : x);
    this.seed.push(
      `INSERT INTO names (id, kind, value) VALUES (${repoId(name)}, 3, ${sq(name)});`,
      `INSERT INTO repos (repo, repository_id, repository_owner_id, state, successor, state_at, time) VALUES (${repoId(name)}, ${id}, ${owner}, ${state}, ${s}, ${stateAt}, ${SEED_T});`,
      `INSERT INTO repo_checks (repo, etag, checked_at, next_check_at, fail_count, app_installed) VALUES (${repoId(name)}, NULL, NULL, ${nextCheck}, 0, 0);`,
      ...events.map(([seq, action, ib, ia, ob, oa, succ]) => `INSERT INTO repo_events (repo, seq, action, repository_id_before, repository_id_after, owner_id_before, owner_id_after, successor, claims, time) VALUES (${repoId(name)}, ${seq}, ${action}, ${v(ib)}, ${v(ia)}, ${v(ob)}, ${v(oa)}, ${succ === null ? 'NULL' : repoId(succ)}, NULL, ${SEED_T});`),
    );
  }
  // A release of the label `tag` with the hash, with the log leaf and a webhook provenance row (via 1): a label that an earlier path indexed.
  indexed(name, tag, hash, { idx = 1, withdrawn = null, withdrawnAt = null } = {}) {
    const form = formOf(name, tag);
    const version = tag.replace(/^v/, '');
    this.seed.push(
      `INSERT INTO names (id, kind, value) VALUES (${hashId(hash)}, 1, X'${hex(hash)}'), (${textId(2, form)}, 2, ${sq(form)});`,
      `INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (${hashId(hash)}, 1, '["Alpha"]', NULL, NULL, 999);`,
      `INSERT INTO log (idx, grp, version, hash, time) VALUES (${idx}, ${sq(form)}, ${sq(version)}, ${sq(hash)}, ${SEED_T});`,
      `INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (${idx}, ${textId(2, form)}, ${versionCol(version)}, '', ${hashId(hash)}, ${repoId(name)}, ${sq(gh(name, tag, hash))}, ${sq(tag)}, NULL, ${PUB_MS}, 0, ${withdrawn === null ? 'NULL' : sq(withdrawn)}, ${withdrawnAt ?? 'NULL'});`,
      `INSERT INTO provenance (release, via, claims, time) VALUES (${idx}, 1, NULL, ${SEED_T});`,
    );
  }
}

// The db.tsv blocks. The names are text (a join with `names`), so the file reads without the ids. NULL is \N (run.mjs).
const Q = {
  repos: 'SELECT n.value, r.repository_id, r.repository_owner_id, r.state, (SELECT s.value FROM names s WHERE s.id = r.successor), r.state_at, r.time FROM repos r JOIN names n ON n.id = r.repo ORDER BY n.value',
  events: 'SELECT n.value, e.seq, e.action, e.repository_id_before, e.repository_id_after, e.owner_id_before, e.owner_id_after, (SELECT s.value FROM names s WHERE s.id = e.successor), e.claims, e.time FROM repo_events e JOIN names n ON n.id = e.repo ORDER BY n.value, e.seq',
  checks: 'SELECT n.value, c.etag, c.checked_at, c.next_check_at, c.fail_count, c.app_installed FROM repo_checks c JOIN names n ON n.id = c.repo ORDER BY n.value',
  releases: 'SELECT r.log_index, n.value, r.tag, r.withdrawn, r.withdrawn_at FROM releases r JOIN names n ON n.id = r.repo ORDER BY r.log_index',
  forms: 'SELECT value FROM names WHERE kind = 2 ORDER BY value',
  provenance: 'SELECT release, via, claims, time FROM provenance ORDER BY release, via',
};
const block = (q, rows) => `@ ${q}\n${rows.map((r) => r.map((c) => (c === null ? '\\N' : String(c))).join('\t')).join('\n')}${rows.length ? '\n' : ''}`;
const byName = (a, b) => (a[0] < b[0] ? -1 : a[0] > b[0] ? 1 : 0) || (a[1] - b[1]);
const created = (name, id, owner, seq = 1) => [name, seq, 0, null, id, null, owner, null, null, NOW]; // the event bind
const repoRow = (name, id, owner, state = 0, successor = null, stateAt = SEED_T, time = SEED_T) => [name, id, owner, state, successor, stateAt, time];
const seeded = (name, id, owner) => created(name, id, owner, 1).slice(0, 9).concat([SEED_T]);
const ok201 = (name, tag, hash) => ({
  status: 201,
  headers: { 'content-type': 'application/json', 'cache-control': 'no-store', location: `/v1/artifacts/${hash}` },
  d1_session: 'first-primary',
  headers_set: NOT_NULL_BOOKMARK,
  json: { release: { hash, group: formOf(name, tag), version: tag.replace(/^v/, ''), tag, repo: name } },
});
const ok200 = (name, tag, hash) => ({ ...ok201(name, tag, hash), status: 200, headers: { 'content-type': 'application/json', location: null } });

// ---- case 1: the 4 rows of R-TP9, the states, the bind event; the answer 403 with issues_url; the label that is in the index ----
function fourRows() {
  const c = new Case('tp9-four-rows', 'R-TP9 R-TP5 R-TP11 R-TP12 R-TP13 R-RE11 R-RE15 R-PU31 R-PU32 R-AP68 R-AP41 R-AP21 R-AP9 R-AP8 R-TP19 R-TP18 R-AP68');
  const T = '1.0.0';
  const R = (name, id, owner) => ({ name, id, owner, answer: repoJson(name, id, owner) });
  // The seeded names: the bound repository (id, owner id), what GitHub shows now (id, owner id) and the expected result.
  const rows = {
    same: { ...R('same/repo', 1001, 11), seed: [1001, 11] },
    xfer: { ...R('xfer/repo', 2001, 22), seed: [2001, 21] },
    again: { ...R('again/repo', 3002, 31), seed: [3001, 31] },
    taken: { ...R('taken/repo', 4002, 42), seed: [4001, 41] },
    fresh: { ...R('fresh/repo', 5001, 51), seed: null },
    back: { ...R('back/repo', 6001, 61), seed: [6001, 61] },
    prov: { ...R('prov/repo', 7002, 72), seed: [7001, 71] },
  };
  for (const [k, x] of Object.entries(rows)) if (x.seed) c.bound(x.name, { id: x.seed[0], owner: x.seed[1], state: k === 'back' ? 1 : 0, stateAt: k === 'back' ? SEED_T - 5000 : SEED_T, nextCheck: k === 'back' ? AFTER_NOW : SEED_T + HOUR });
  const provHash = rocHash(pkg('the label that the webhook indexed'));
  c.indexed('prov/repo', T, provHash);
  // # R-TP19, Design Q264 (T5): an older release of back/repo is withdrawn `repo-missing`. The `found` of an ingest does not change it.
  const W_AT = SEED_T + 500;
  c.indexed('back/repo', '0.9.0', rocHash(pkg('slice 113 back: the old release')), { idx: 2, withdrawn: 'repo-missing', withdrawnAt: W_AT });
  const hashes = {};
  for (const [k, x] of Object.entries(rows)) if (k !== 'prov') hashes[k] = c.release({ name: x.name, tag: T, repoAnswer: x.answer, note: `slice 113 ${k}` });
  c.file('https://api.github.com/repos/prov/repo', rows.prov.answer);
  const reads = (k) => c.reads(rows[k].name, T, hashes[k]);
  const url = (k) => gh(rows[k].name, T, hashes[k]);
  const taken = {
    status: 403,
    headers: { 'talon-bookmark': null },
    problem: { type: '/errors/repository-changed', title: 'Repository changed', status: 403, detail: 'the name taken/repo is bound to another GitHub account (repository id 4001)' },
    json: { issues_url: ISSUES },
  };
  // # R-TP9 row 1, R-AP68: the same repository id and owner id. 201 as before; the row and the events do not change (no event for no change, R-TP13)
  c.req('same ids: 201', post(url('same')), ok201('same/repo', T, hashes.same), 2); reads('same');
  // # R-TP9 row 2 (R-TP13): the same repository id, another owner id. The row gets the new owner id; event 2 transfer
  c.req('transfer: 201', post(url('xfer')), ok201('xfer/repo', T, hashes.xfer), 2); reads('xfer');
  // # R-TP9 row 3: the same owner id, another repository id. The row gets the new repository id; event 3 recreate
  c.req('recreate: 201', post(url('again')), ok201('again/repo', T, hashes.again), 2); reads('again');
  // # R-TP9 row 4, R-TP12, R-AP68 row 6: both ids are different. 403 repository-changed with issues_url, no bookmark (Q165); the stop is after the repository read:
  // 1 D1 call (the pre-read), 1 GitHub read; nothing is written (the db blocks have no row of taken/repo except the seed)
  c.req('both ids different: 403', post(url('taken')), taken, 1); c.log.push('GET https://api.github.com/repos/taken/repo');
  // # R-TP5, R-TP13, Design Q163: no row is a new binding; event 0 bind with the ids after (seq 1)
  c.req('no row: 201 and bind', post(url('fresh')), ok201('fresh/repo', T, hashes.fresh), 2); reads('fresh');
  // # R-TP11: a missing row is active again (event 5 found, state_at is the clock) when a read of the same repository id succeeds.
  // # R-TP19, Q264: next_check_at of back/repo was after the clock and is now the clock (MIN); the old release is still `repo-missing` with its time
  c.req('missing row, same ids: 201 and found', post(url('back')), ok201('back/repo', T, hashes.back), 2); reads('back');
  // # R-TP9 row 4 on the path of a label that an earlier path indexed with the same hash (R-AP68 row 7): the visibility read, then 403. No provenance row is added.
  c.req('indexed label, both ids different: 403', post(gh('prov/repo', T, provHash)), { ...taken, problem: { ...taken.problem, detail: 'the name prov/repo is bound to another GitHub account (repository id 7001)' } }, 1);
  c.log.push('GET https://api.github.com/repos/prov/repo');
  const forms = ['same', 'xfer', 'again', 'fresh', 'back', 'prov'].map((k) => [formOf(rows[k].name, T)]).sort((a, b) => (a[0] < b[0] ? -1 : 1));
  c.db = [
    block(Q.repos, [
      repoRow('again/repo', 3002, 31), repoRow('back/repo', 6001, 61, 0, null, NOW), repoRow('fresh/repo', 5001, 51, 0, null, NOW, NOW), repoRow('prov/repo', 7001, 71),
      repoRow('same/repo', 1001, 11), repoRow('taken/repo', 4001, 41), repoRow('xfer/repo', 2001, 22),
    ]),
    block(Q.events, [
      seeded('again/repo', 3001, 31), ['again/repo', 2, 3, 3001, 3002, 31, 31, null, null, NOW],
      seeded('back/repo', 6001, 61), ['back/repo', 2, 5, 6001, 6001, 61, 61, null, null, NOW],
      created('fresh/repo', 5001, 51),
      seeded('prov/repo', 7001, 71), seeded('same/repo', 1001, 11), seeded('taken/repo', 4001, 41),
      seeded('xfer/repo', 2001, 21), ['xfer/repo', 2, 1, 2001, 2001, 21, 22, null, null, NOW],
    ]),
    block(Q.checks, ['again/repo', 'back/repo', 'prov/repo', 'same/repo', 'taken/repo', 'xfer/repo'].map((n) => [n, null, null, n === 'back/repo' ? NOW : SEED_T + HOUR, 0, 0]).concat([['fresh/repo', null, null, NOW + HOUR, 0, 0]]).sort((a, b) => (a[0] < b[0] ? -1 : 1))),
    block(Q.releases, [[1, 'prov/repo', T, null, null], [2, 'back/repo', '0.9.0', 'repo-missing', W_AT], [3, 'same/repo', T, null, null], [4, 'xfer/repo', T, null, null], [5, 'again/repo', T, null, null], [6, 'fresh/repo', T, null, null], [7, 'back/repo', T, null, null]]),
    block(Q.forms, forms),
    block(Q.provenance, [[1, 1, null, SEED_T], [2, 1, null, SEED_T], [3, 3, null, NOW], [4, 3, null, NOW], [5, 3, null, NOW], [6, 3, null, NOW], [7, 3, null, NOW]]),
  ].join('');
  c.write();
}

// ---- case 2: a rename: the new name has no row, a row of another name has the repository id (R-TP10); the read of the old name ----
function rename() {
  const c = new Case('tp10-rename', 'R-TP10 R-TP11 R-TP13 R-TP14 R-RE11 R-RE15 R-PU26 R-AP32 R-AP68 R-AP41');
  const OLD = 'acme/lib', NEW = 'acme/lib2';
  c.bound(OLD, { id: 100, owner: 10 });
  const oldHash = rocHash(pkg('slice 113 rename: the release of the old name'));
  c.indexed(OLD, '1.0.0', oldHash);
  const answer = repoJson(NEW, 100, 10);
  const h1 = c.release({ name: NEW, tag: '2.0.0', repoAnswer: answer, note: 'slice 113 rename: 2.0.0' });
  const h2 = c.release({ name: NEW, tag: '2.1.0', note: 'slice 113 rename: 2.1.0' });
  // # R-TP10: the new name has no row and the row of acme/lib has the same repository id: the row of acme/lib2 with the same ids (active), acme/lib is moved with the successor acme/lib2,
  // event 2 rename on both names (acme/lib seq 2 with the successor, acme/lib2 seq 1 with no ids before); R-PU26: the repo_checks row of the new name
  c.req('new name, known repository id: 201', post(gh(NEW, '2.0.0', h1)), ok201(NEW, '2.0.0', h1), 2); c.reads(NEW, '2.0.0', h1);
  // # R-TP10: a later release of the new name finds the row: no event, no change of state_at
  c.req('second release of the new name: 201', post(gh(NEW, '2.1.0', h2), { now: NOW + 5000 }), ok201(NEW, '2.1.0', h2), 2); c.reads(NEW, '2.1.0', h2);
  // # R-AP32 (slice 106): the read of the old name shows the state moved and the successor
  c.req('read the old name', { method: 'GET', path: `/v1/packages/${OLD}/releases`, now: NOW + 6000 }, { status: 200, json: { repos: [{ name: OLD, state: 'moved', successor: NEW }] } }, 1);
  c.req('read the new name', { method: 'GET', path: `/v1/packages/${NEW}/releases`, now: NOW + 6000 }, { status: 200, json: { repos: [{ name: NEW, state: 'active', successor: null }] } }, 1);
  const rename = (n, seq, before, succ) => [n, seq, 2, before ? 100 : null, 100, before ? 10 : null, 10, succ, null, NOW];
  c.db = [
    block(Q.repos, [repoRow(OLD, 100, 10, 2, NEW, NOW, SEED_T), repoRow(NEW, 100, 10, 0, null, NOW, NOW)].sort(byName)),
    block(Q.events, [seeded(OLD, 100, 10), rename(OLD, 2, true, NEW), rename(NEW, 1, false, null)].sort(byName)),
    block(Q.checks, [[OLD, null, null, SEED_T + HOUR, 0, 0], [NEW, null, null, NOW + HOUR, 0, 0]].sort(byName)),
  ].join('');
  c.write();
}

// ---- case 3: the 301 of the old name is followed (R-TP10); F is not U, U has a row: R-TP18 row 5, no row changes (T2) ----
function followed() {
  const c = new Case('tp10-301-followed', 'R-TP10 R-TP9 R-TP18 R-AP68 R-AP41');
  const OLD = 'acme/lib';
  c.bound(OLD, { id: 100, owner: 10 });
  const h = c.release({ name: OLD, tag: '1.1.0', repoAnswer: null, note: 'slice 113 301: 1.1.0' });
  // GitHub answers the read of the old name with a 301 to /repositories/{id}; the final answer is the repository with its new name (R-TP10). The Worker never sees the 301.
  c.file(`https://api.github.com/repos/${OLD}`, MOVED_BODY, { status: 301, headers: { location: 'https://api.github.com/repositories/100' } });
  c.file('https://api.github.com/repositories/100', repoJson('acme/lib2', 100, 10));
  // # R-TP10, R-TP9 row 1, R-TP18 row 5 (Q260): the ids of the final answer are the ids of the row of U: accepted, 201, the release is under U. The log has the 2 reads.
  // F (acme/lib2) is not U: no row changes and no row of F is written (the db blocks show only the seed)
  c.req('old name after a rename: 201', post(gh(OLD, '1.1.0', h)), ok201(OLD, '1.1.0', h), 2);
  c.reads(OLD, '1.1.0', h, { repo: true, extra: ['GET https://api.github.com/repositories/100'] });
  c.db = [
    block(Q.repos, [repoRow(OLD, 100, 10)]),
    block(Q.events, [seeded(OLD, 100, 10)]),
    block(Q.checks, [[OLD, null, null, SEED_T + HOUR, 0, 0]]),
    block(Q.releases, [[1, OLD, '1.1.0', null, null]]),
  ].join('');
  c.write();
}

const MOVED_BODY = '{"message":"Moved Permanently","url":"https://api.github.com/repositories/100","documentation_url":"https://docs.github.com/rest/reference/repos#get-a-repository"}';

// ---- case 4 (T3): F is not U and U has no row: R-TP18 row 6, the bind of U; the row of F is not changed ----
function noRow() {
  const c = new Case('tp18-301-no-row', 'R-TP18 R-TP10 R-TP5 R-TP13 R-PU26 R-AP68 R-AP41');
  const NEW = 'acme/new', OLD = 'acme/old';
  c.bound(NEW, { id: 100, owner: 10 });
  const h = c.release({ name: OLD, tag: '1.0.0', repoAnswer: null, note: 'slice 113 301 no row: 1.0.0' });
  c.file(`https://api.github.com/repos/${OLD}`, MOVED_BODY.replace('/repositories/100', '/repositories/100'), { status: 301, headers: { location: 'https://api.github.com/repositories/100' } });
  c.file('https://api.github.com/repositories/100', repoJson(NEW, 100, 10));
  // # R-TP18 row 6, Q260: acme/old has no row, the final answer is acme/new (F is not U). acme/old gets its row and the event bind (seq 1), a repo_checks row; acme/new does not change
  c.req('old name with no row: 201 and bind', post(gh(OLD, '1.0.0', h)), ok201(OLD, '1.0.0', h), 2);
  c.reads(OLD, '1.0.0', h, { repo: true, extra: ['GET https://api.github.com/repositories/100'] });
  c.db = [
    block(Q.repos, [repoRow(NEW, 100, 10), repoRow(OLD, 100, 10, 0, null, NOW, NOW)].sort(byName)),
    block(Q.events, [seeded(NEW, 100, 10), created(OLD, 100, 10)].sort(byName)),
    block(Q.checks, [[NEW, null, null, SEED_T + HOUR, 0, 0], [OLD, null, null, NOW + HOUR, 0, 0]].sort(byName)),
    block(Q.releases, [[1, OLD, '1.0.0', null, null]]),
  ].join('');
  c.write();
}

// ---- case 5 (T4): the repository has its old name again: the row of U is moved (R-TP18 rows 1, 3; Q261) ----
function renameBack() {
  const c = new Case('tp18-rename-back', 'R-TP18 R-TP10 R-TP13 R-TP14 R-RE11 R-RE15 R-AP68 R-AP41');
  const S0 = SEED_T;
  // The history of a chain: A was renamed to B, and B to C. A real history has the events: A bind, A rename (successor B); B rename (new name), B rename (successor C); C rename (new name).
  c.bound('acme/a', { id: 100, owner: 10, state: 2, successor: 'acme/b', stateAt: S0, events: [[1, 0, null, 100, null, 10, null], [2, 2, 100, 100, 10, 10, 'acme/b']] });
  c.bound('acme/b', { id: 100, owner: 10, state: 2, successor: 'acme/c', stateAt: S0, events: [[1, 2, null, 100, null, 10, null], [2, 2, 100, 100, 10, 10, 'acme/c']] });
  c.bound('acme/c', { id: 100, owner: 10, state: 0, stateAt: S0, events: [[1, 2, null, 100, null, 10, null]] });
  const answer = repoJson('acme/a', 100, 10); // a direct 200: the repository has the name acme/a again
  const h1 = c.release({ name: 'acme/a', tag: '3.0.0', repoAnswer: answer, note: 'slice 113 back: 3.0.0' });
  const h2 = c.release({ name: 'acme/a', tag: '3.1.0', note: 'slice 113 back: 3.1.0' });
  // # R-TP18 row 3, Q261: the row of acme/a (moved, the same repository id) is active again with no successor and state_at = now, and the event rename (ids equal, no successor);
  // the row acme/c (active) is moved with the successor acme/a and the event rename; acme/b (moved) stays: the chain a to b to c is now b to c to a
  c.req('rename back: 201', post(gh('acme/a', '3.0.0', h1)), ok201('acme/a', '3.0.0', h1), 2); c.reads('acme/a', '3.0.0', h1);
  // # R-TP18 row 4: a second release of the current name: R-TP9 only, no event, the same state_at
  c.req('second release: 201', post(gh('acme/a', '3.1.0', h2), { now: NOW + 5000 }), ok201('acme/a', '3.1.0', h2), 2); c.reads('acme/a', '3.1.0', h2);
  const seedEv = (n, seq, action, before, succ) => [n, seq, action, before ? 100 : null, 100, before ? 10 : null, 10, succ, null, SEED_T];
  c.db = [
    block(Q.repos, [repoRow('acme/a', 100, 10, 0, null, NOW, SEED_T), repoRow('acme/b', 100, 10, 2, 'acme/c', S0, SEED_T), repoRow('acme/c', 100, 10, 2, 'acme/a', NOW, SEED_T)]),
    block(Q.events, [
      seedEv('acme/a', 1, 0, false, null), seedEv('acme/a', 2, 2, true, 'acme/b'), ['acme/a', 3, 2, 100, 100, 10, 10, null, null, NOW],
      seedEv('acme/b', 1, 2, false, null), seedEv('acme/b', 2, 2, true, 'acme/c'),
      seedEv('acme/c', 1, 2, false, null), ['acme/c', 2, 2, 100, 100, 10, 10, 'acme/a', null, NOW],
    ]),
    block(Q.checks, ['acme/a', 'acme/b', 'acme/c'].map((n) => [n, null, null, SEED_T + HOUR, 0, 0])),
    block(Q.releases, [[1, 'acme/a', '3.0.0', null, null], [2, 'acme/a', '3.1.0', null, null]]),
  ].join('');
  c.write();
}

// ---- case 6 (T6): the visibility comes before the ids (R-AP68 row 6, Q263) ----
function privateFirst() {
  const c = new Case('tp9-private-first', 'R-AP68 R-PU31 R-PU32 R-TP9 R-TP12');
  const N = 'taken/repo';
  c.bound(N, { id: 4001, owner: 41 });
  const h0 = rocHash(pkg('slice 113 private: the indexed label'));
  c.indexed(N, '1.0.0', h0);
  const h2 = rocHash(pkg('slice 113 private: a new label'));
  const answer = (visibility) => JSON.stringify({ id: 9999, name: 'repo', full_name: N, private: visibility !== 'public', owner: { login: 'taken', id: 99, type: 'User' }, visibility, default_branch: 'main' });
  const url = `https://api.github.com/repos/${N}`;
  c.file(url, answer('private'));
  c.nth(url, 2, answer('private'));
  c.nth(url, 3, answer('public'));
  const notPublic = { status: 422, headers: { 'talon-bookmark': null }, problem: { type: '/errors/not-a-candidate', detail: 'repository not found or not public' } };
  // # R-AP68 row 6, Q263: the ids are both different, and the repository is not public: 422, not 403 (an ingest cannot learn if a private repository exists). 1 D1 call, 1 read, nothing written
  c.req('new label, other ids, private: 422', post(gh(N, '2.0.0', h2)), notPublic, 1);
  // # R-AP68 rows 6 and 7: the same on the path of the indexed label (no ingest row): 422, and no provenance row is added
  c.req('indexed label, other ids, private: 422', post(gh(N, '1.0.0', h0)), notPublic, 1);
  // # The control: the same ids and a public repository: 403 repository-changed (R-TP9 row 4)
  c.req('new label, other ids, public: 403', post(gh(N, '2.0.0', h2)), {
    status: 403, headers: { 'talon-bookmark': null },
    problem: { type: '/errors/repository-changed', title: 'Repository changed', status: 403, detail: 'the name taken/repo is bound to another GitHub account (repository id 4001)' },
    json: { issues_url: ISSUES },
  }, 1);
  c.log.push(`GET ${url}`, `GET ${url}`, `GET ${url}`);
  c.db = [
    block(Q.repos, [repoRow(N, 4001, 41)]),
    block(Q.events, [seeded(N, 4001, 41)]),
    block(Q.checks, [[N, null, null, SEED_T + HOUR, 0, 0]]),
    block(Q.releases, [[1, N, '1.0.0', null, null]]),
    block(Q.provenance, [[1, 1, null, SEED_T]]),
    block(Q.forms, [[formOf(N, '1.0.0')]]),
  ].join('');
  c.write();
}

// ---- case 7 (T7): a row that changes between the 2 D1 calls (R-AP41 row 3, Q262): no new check, the guarded UPDATE changes nothing ----
function rowRace() {
  const c = new Case('q262-row-race', 'R-AP41 R-TP9 R-TP13 R-TP19 R-AP68');
  const N = 'race/repo';
  c.bound(N, { id: 1, owner: 10 });
  const h = c.release({ name: N, tag: '1.0.0', repoAnswer: repoJson(N, 1, 12), note: 'slice 113 race' });
  // The hook runs after D1 call 1: another request moved the repository to the owner 11 and wrote the event transfer (seq 2)
  c.hook(`https://api.github.com/repos/${N}`, `UPDATE repos SET repository_owner_id = 11 WHERE repo = ${repoId(N)};\nINSERT INTO repo_events (repo, seq, action, repository_id_before, repository_id_after, owner_id_before, owner_id_after, successor, claims, time) VALUES (${repoId(N)}, 2, 1, 1, 1, 10, 11, NULL, NULL, ${NOW});\n`);
  // # R-AP41 row 3 (Q262): our request sees the ids (1, 12) against the old row (1, 10): its UPDATE has the old owner id in WHERE and changes 0 rows, so it adds no event; the release is written
  c.req('row changed between the calls: 201', post(gh(N, '1.0.0', h)), ok201(N, '1.0.0', h), 2); c.reads(N, '1.0.0', h);
  c.db = [
    block(Q.repos, [repoRow(N, 1, 11)]),
    block(Q.events, [seeded(N, 1, 10), [N, 2, 1, 1, 1, 10, 11, null, null, NOW]]),
    block(Q.releases, [[1, N, '1.0.0', null, null]]),
  ].join('');
  c.write();
}

fourRows();
rename();
followed();
noRow();
renameBack();
privateFirst();
rowRace();
