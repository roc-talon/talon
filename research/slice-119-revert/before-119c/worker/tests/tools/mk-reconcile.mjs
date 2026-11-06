// The W2 cases of slice 119b (the reconcile cron: Registry R-PU21 to R-PU25, R-PU27, R-PU35 to R-PU37, R-RE14; docs/slices/119-reconcile.md section 5).
//   node worker/tests/tools/mk-reconcile.mjs     writes worker/tests/cases/reconcile/*/ (github/, seed.sql, requests.jsonl, settings.json, expect/, rules, notes.txt)
// The files are tracked. Run the script again only when a case changes. The ids (R-IK2) and the hashes come from node, never from the Roc code.
// Order of the rows in a run: the claim gives its rows in no promised order (slice file Q370). Each case gives `next_check_at` in the order of the `repo` ids, so the oldest first and the order of the ids
// are the same order, and the expected GitHub log holds for both readings.
import { createHash } from 'node:crypto';
import { mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { tar, zstd } from './mk-bundle.mjs';
import { rocHash } from './blake3.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const casesDir = join(here, '..', 'cases', 'reconcile');

// ---- the facts of the design, in JS (as mk-webhook.mjs) ----
const nameId = (kind, bytes) => createHash('sha256').update(Buffer.concat([Buffer.from([kind]), Buffer.from(bytes)])).digest().readBigInt64BE(0).toString(); // R-IK2
const textId = (kind, t) => nameId(kind, Buffer.from(t, 'utf8'));
const repoId = (name) => textId(3, name);
const B58 = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
const b58encode = (buf) => { let n = BigInt(`0x${buf.toString('hex')}`); let s = ''; while (n > 0n) { s = B58[Number(n % 58n)] + s; n /= 58n; } return s; };
const fillHash = (fill) => b58encode(Buffer.alloc(32, fill));
const versionCol = (v) => { const [a, b, c] = v.split('.').map(BigInt); return BigInt.asIntN(64, ((a << 48n) | (b << 32n) | (c << 16n) | 0xFFFFn) ^ (1n << 63n)).toString(); }; // R-IK5
const sq = (s) => `'${String(s).replace(/'/g, "''")}'`;

const NOW = 1767225600000;
const SEED_T = 1767000000000;
const MIN = 60000;
const HOUR = 3600000;
const DAY = 86400000;
const CRON = '*/5 * * * *';
const API = 'https://api.github.com';
const PUB = '2026-10-20T12:00:00Z';
const UA = 'talon-registry';
const ACCEPT = 'application/vnd.github+json';

const repoUrl = (id) => `${API}/repositories/${id}`;
const listUrl = (full) => `${API}/repos/${full}/releases?per_page=100`;
const relUrl = (full, id) => `${API}/repos/${full}/releases/${id}`;
const tagUrl = (full, tag) => `${API}/repos/${full}/releases/tags/${tag}`;
const assetUrl = (full, tag, hash) => `https://github.com/${full}/releases/download/${tag}/${hash}.tar.zst`;
const rocVersionUrl = (full, tag) => `https://raw.githubusercontent.com/${full}/${tag}/.roc-version`;
const NOT_FOUND = '{"message":"Not Found"}';
const repoJson = (id, fullName, owner, visibility = 'public') => JSON.stringify({ id, node_id: 'R_x', name: fullName.split('/')[1], full_name: fullName, private: visibility !== 'public', owner: { login: fullName.split('/')[0], id: owner, type: 'Organization' }, description: null, visibility, default_branch: 'main' });
const releaseObj = (id, tag, { draft = false, prerelease = false, assets = [] } = {}) => ({ url: `${API}/repos/x/y/releases/${id}`, id, tag_name: tag, target_commitish: 'main', name: null, draft, prerelease, created_at: PUB, published_at: draft ? null : PUB, author: { login: 'someone', id: 5 }, assets: assets.map((n, k) => ({ id: k + 1, name: n, label: null, content_type: 'application/octet-stream', state: 'uploaded', size: 10, digest: null })), body: null });
const zst = (h) => `${h}.tar.zst`;
const pollMsg = (repository_id, release_id) => ({ event: 'poll', action: 'published', installation_id: 0, repository_id, release_id, repository_ids: [] });
const sent = (body) => ({ body, delay_s: 0 });
const cron = (now, extra = {}) => ({ cron: CRON, time: now, now, ...extra });
const okRun = (queue_sent = []) => ({ status: 200, json: { outcome: 'ok' }, queue_sent });
const rate = (remaining, reset = 1767229200) => ({ 'x-ratelimit-limit': '5000', 'x-ratelimit-remaining': String(remaining), 'x-ratelimit-reset': String(reset), 'x-ratelimit-used': String(5000 - remaining), 'x-ratelimit-resource': 'core' });
const mod = (n) => `${n} :: [].{\n\tx : U64\n\tx = 1\n}\n`;
const EXTRA_H = 'C6Jtcve7FRNtkwgmuyRBJnZfJyTrfJWhDcLp6gk4w4Gz';
const pkg = (note) => zstd(tar([
  { path: 'main.roc', data: `## ${note}\npackage\n\t[\n\t\tAlpha,\n\t]\n\t{\n\t\textra: "https://example.com/pkgs/${EXTRA_H}.tar.zst",\n\t}\n` },
  { path: 'Alpha.roc', data: mod('Alpha') },
]));

// The db.tsv blocks, by name (a join with `names`), as the cases of slices 113 and 118.
const Q = {
  repos: 'SELECT n.value, r.repository_id, r.repository_owner_id, r.state, (SELECT s.value FROM names s WHERE s.id = r.successor), r.state_at, r.time FROM repos r JOIN names n ON n.id = r.repo ORDER BY n.value',
  events: 'SELECT n.value, e.seq, e.action, e.repository_id_before, e.repository_id_after, e.owner_id_before, e.owner_id_after, (SELECT s.value FROM names s WHERE s.id = e.successor), e.claims, e.time FROM repo_events e JOIN names n ON n.id = e.repo ORDER BY n.value, e.seq',
  checks: 'SELECT n.value, c.etag, c.checked_at, c.next_check_at, c.fail_count, c.app_installed FROM repo_checks c JOIN names n ON n.id = c.repo ORDER BY n.value',
  releases: 'SELECT r.log_index, n.value, r.tag, r.withdrawn, r.withdrawn_at FROM releases r JOIN names n ON n.id = r.repo ORDER BY r.log_index',
  log: 'SELECT idx, grp, version, hash, time FROM log ORDER BY idx',
  provenance: 'SELECT release, via, claims, time FROM provenance ORDER BY release, via',
};
const block = (q, rows) => `@ ${q}\n${rows.map((r) => r.map((c) => (c === null ? '\\N' : String(c))).join('\t')).join('\n')}${rows.length ? '\n' : ''}`;
const seedEvent = (name, id, owner) => [name, 1, 0, null, id, null, owner, null, null, SEED_T];

class Case {
  constructor(name, rules, settings = {}) {
    this.name = name; this.rules = rules; this.settings = settings;
    this.forms = new Set(); this.files = new Map(); this.reqs = []; this.exp = []; this.calls = []; this.log = []; this.auth = []; this.seed = []; this.db = ''; this.notes = []; this.logs = [];
  }
  file(url, body, meta, suffix = '') {
    const u = new URL(url);
    const enc = (s) => s.replace(/[%?:\\*<>|"]/g, (c) => `%${c.charCodeAt(0).toString(16).toUpperCase().padStart(2, '0')}`);
    let p = [enc(u.host), ...u.pathname.split('/').filter(Boolean).map(enc)].join('/');
    if (u.search) p += `%3F${enc(u.search.slice(1))}`;
    this.files.set(`${p}${suffix}`, body);
    if (meta) this.files.set(`${p}${suffix}.meta.json`, JSON.stringify(meta));
  }
  req(comment, spec, expect, calls) { this.reqs.push(spec); this.exp.push(expect); this.calls.push(String(calls)); this.notes.push(comment); }
  sql(stmts) { this.reqs.push({ sql: stmts }); }
  queue(comment, messages, expect, now) { this.reqs.push({ queue: 'talon-index', ...(now === undefined ? {} : { now }), messages }); this.exp.push({ outcome: 'ok', ...expect }); this.calls.push('-'); this.notes.push(comment); }
  // A GitHub read of the run: github.log, and auth.log for api.github.com (the token of slice 119a: the first default token, the user agent, the accept header).
  read(url) { this.log.push(`GET ${url}`); if (url.startsWith(`${API}/`)) this.auth.push(`GET ${url} token=1 ua=${UA} accept=${ACCEPT}`); }
  write() {
    const dir = join(casesDir, this.name);
    rmSync(dir, { recursive: true, force: true });
    const keys = [...this.files.keys()];
    for (const [k, v] of this.files) {
      const base = k.replace(/(\.meta\.json)?$/, '');
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
    writeFileSync(join(dir, 'expect', 'github.log'), this.log.length ? `${this.log.join('\n')}\n` : '');
    if (this.auth.length) writeFileSync(join(dir, 'expect', 'auth.log'), `${this.auth.join('\n')}\n`);
    if (this.seed.length) writeFileSync(join(dir, 'seed.sql'), this.seed.join('\n') + '\n');
    if (this.db) writeFileSync(join(dir, 'expect', 'db.tsv'), this.db);
    if (this.logs.length) writeFileSync(join(dir, 'expect', 'logs.jsonl'), this.logs.map((l) => JSON.stringify(l)).join('\n') + '\n');
  }
  // A bound name: the `names`, `repos` and `repo_checks` rows and the event bind (seq 1), as an ingest wrote them.
  bound(name, { id, owner, state = 0, successor = null, nextCheck, etag = null, checkedAt = null, fail = 0, installed = 0 }) {
    const s = successor === null ? 'NULL' : repoId(successor);
    this.seed.push(
      `INSERT INTO names (id, kind, value) VALUES (${repoId(name)}, 3, ${sq(name)});`,
      `INSERT INTO repos (repo, repository_id, repository_owner_id, state, successor, state_at, time) VALUES (${repoId(name)}, ${id}, ${owner}, ${state}, ${s}, ${SEED_T}, ${SEED_T});`,
      `INSERT INTO repo_checks (repo, etag, checked_at, next_check_at, fail_count, app_installed) VALUES (${repoId(name)}, ${etag === null ? 'NULL' : sq(etag)}, ${checkedAt === null ? 'NULL' : checkedAt}, ${nextCheck}, ${fail}, ${installed});`,
      `INSERT INTO repo_events (repo, seq, action, repository_id_before, repository_id_after, owner_id_before, owner_id_after, successor, claims, time) VALUES (${repoId(name)}, 1, 0, NULL, ${id}, NULL, ${owner}, NULL, NULL, ${SEED_T});`,
    );
  }
  // A release of `name` with the label `tag`, the hash of 32 bytes `fill`, the log leaf and a provenance row.
  indexed(name, tag, idx, fill, { withdrawn = null, at = null, via = 1 } = {}) {
    const bytes = Buffer.alloc(32, fill);
    const hash = b58encode(bytes);
    const form = `github.com/${name}/releases/download/{v}/`;
    const hid = nameId(1, bytes);
    const fid = textId(2, form);
    const known = this.forms.has(fid);
    this.forms.add(fid);
    this.seed.push(
      `INSERT INTO names (id, kind, value) VALUES (${hid}, 1, X'${bytes.toString('hex').toUpperCase()}')${known ? '' : `, (${fid}, 2, ${sq(form)})`};`,
      `INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (${hid}, 1, '["Alpha"]', NULL, NULL, 999);`,
      `INSERT INTO log (idx, grp, version, hash, time) VALUES (${idx}, ${sq(form)}, ${sq(tag)}, ${sq(hash)}, ${SEED_T});`,
      `INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (${idx}, ${fid}, ${versionCol(tag)}, '', ${hid}, ${repoId(name)}, ${sq(assetUrl(name, tag, hash))}, ${sq(tag)}, NULL, ${SEED_T}, 0, ${withdrawn === null ? 'NULL' : sq(withdrawn)}, ${at === null ? 'NULL' : at});`,
      `INSERT INTO provenance (release, via, claims, time) VALUES (${idx}, ${via}, NULL, ${SEED_T});`,
    );
    return hash;
  }
}

// The names of a case in the order of their `repo` id (signed 64-bit), and a due time for each in that order (the oldest first: see the head comment).
const byId = (names) => [...names].sort((a, b) => (BigInt(repoId(a)) < BigInt(repoId(b)) ? -1 : 1));
const dueTimes = (names, last = NOW - MIN) => new Map(byId(names).map((n, i, all) => [n, last - (all.length - 1 - i) * MIN]));
const repoFile = (c, id, full, owner, visibility = 'public', meta = undefined, suffix = '') => c.file(repoUrl(id), repoJson(id, full, owner, visibility), meta, suffix);
const listFile = (c, full, items, meta, suffix = '') => c.file(listUrl(full), JSON.stringify(items), meta, suffix);
const rowFailed = (repository_id, fail_count) => ({ level: 'warn', msg: 'reconcile row failed', job: 'reconcile', repository_id, fail_count });

// ---- case 1: one run over 4 due rows and 1 row that is not due (R-PU23, R-PU24, R-PU17, R-PU20, R-PU22, R-PU31, R-PU35, R-PU36, R-PU37 rows 1 and 5, R-RE14, R-PU25 token) ----
function list() {
  const c = new Case('pu23-list', 'R-PU21 R-PU22 R-PU23 R-PU24 R-PU25 R-PU27 R-PU31 R-PU33 R-PU35 R-PU36 R-PU37 R-PU17 R-PU19 R-PU20 R-RE14 R-TP11 R-PU15');
  const due = ['acme/same', 'acme/lib', 'acme/gone', 'acme/priv'];
  const t = dueTimes(due);
  const ids = { 'acme/same': 500, 'acme/lib': 600, 'acme/gone': 700, 'acme/priv': 800 };
  c.bound('acme/same', { id: 500, owner: 50, nextCheck: t.get('acme/same'), etag: 'W/"e-same"', checkedAt: SEED_T });
  c.bound('acme/lib', { id: 600, owner: 60, nextCheck: t.get('acme/lib'), installed: 1 });
  c.bound('acme/lib-old', { id: 600, owner: 60, state: 2, successor: 'acme/lib', nextCheck: NOW + DAY });
  c.bound('acme/gone', { id: 700, owner: 70, nextCheck: t.get('acme/gone') });
  c.bound('acme/priv', { id: 800, owner: 80, nextCheck: t.get('acme/priv') });
  c.bound('acme/later', { id: 900, owner: 90, nextCheck: NOW + 1 });
  const W1 = SEED_T + 10, W2 = SEED_T + 20, W3 = SEED_T + 30, W4 = SEED_T + 40;
  const h = {};
  h[1] = c.indexed('acme/lib', '1.0.0', 1, 1);
  h[2] = c.indexed('acme/lib', '2.0.0', 2, 2);
  h[3] = c.indexed('acme/lib', '3.0.0', 3, 3);
  h[4] = c.indexed('acme/lib', '4.0.0', 4, 4);
  h[5] = c.indexed('acme/lib', '5.0.0', 5, 5);
  h[6] = c.indexed('acme/lib', '6.0.0', 6, 6, { withdrawn: 'unpublished', at: W1 });
  h[7] = c.indexed('acme/lib', '7.0.0', 7, 7, { withdrawn: 'repo-missing', at: W2 });
  h[8] = c.indexed('acme/lib', '11.0.0', 8, 8, { withdrawn: 'deleted', at: W3 });
  c.indexed('acme/lib-old', '0.9.0', 9, 10);
  c.indexed('acme/same', '1.0.0', 10, 11);
  c.indexed('acme/gone', '1.0.0', 11, 12);
  c.indexed('acme/gone', '2.0.0', 12, 13, { withdrawn: 'deleted', at: W4 });
  c.indexed('acme/priv', '1.0.0', 13, 14);
  c.indexed('acme/later', '1.0.0', 14, 15);
  const [h9, h16, h17, h18] = [fillHash(9), fillHash(16), fillHash(17), fillHash(18)];
  repoFile(c, 500, 'acme/same', 50);
  c.file(listUrl('acme/same'), '', { status: 304, headers: { etag: 'W/"e-same"', ...rate(4990) }, require: { 'if-none-match': 'W/"e-same"' } });
  repoFile(c, 600, 'acme/lib', 60);
  listFile(c, 'acme/lib', [
    releaseObj(9101, '1.0.0', { assets: [zst(h[1]), 'notes.txt'] }),
    releaseObj(9102, '2.0.0', { prerelease: true, assets: [zst(h[2])] }),
    releaseObj(9104, '4.0.0', { draft: true, assets: [zst(h[4])] }),
    releaseObj(9105, '5.0.0', { assets: [zst(h9)] }),
    releaseObj(9106, '6.0.0', { assets: [zst(h[6])] }),
    releaseObj(9107, '7.0.0', { assets: [zst(h[7])] }),
    releaseObj(9108, '8.0.0', { assets: [zst(h16), `${zst(h16)}.intoto.jsonl`] }),
    releaseObj(9110, '9.0.0', { prerelease: true, assets: [zst(h17)] }),
    releaseObj(9111, 'nightly', { assets: [zst(h17)] }),
    releaseObj(9112, '10.0.0', { assets: [zst(h17), zst(h18)] }),
    releaseObj(9114, '15.0.0', { draft: true, assets: [zst(h17)] }),
  ], { headers: { etag: 'W/"e-lib-2"', ...rate(4989) }, require: { 'if-none-match': null } });
  c.file(repoUrl(700), NOT_FOUND, { status: 404 });
  repoFile(c, 800, 'acme/priv', 80, 'private');
  for (const n of byId(due)) {
    c.read(repoUrl(ids[n]));
    if (n === 'acme/same' || n === 'acme/lib') c.read(listUrl(n));
  }
  c.req('run 1: the claim takes the 4 due rows (acme/later is due 1 ms later: not taken, no read, R-PU35). For each: the visibility read by id, then the list of the public ones. acme/same: 304 with If-None-Match = the stored etag: only checked_at and next_check_at (1 h). acme/lib (App, 24 h): 200 with no If-None-Match (no etag stored): the new etag, prereleased, deleted (not in the list, a draft again, also the release of the moved name acme/lib-old), asset-replaced, the clear of unpublished, repo-missing and deleted kept, ONE message for 8.0.0 (the only candidate). acme/gone: 404, acme/priv: private: missing, the event, repo-missing on the releases that have no value. 1 + 4 D1 calls',
    cron(NOW), okRun([sent(pollMsg(600, 9108))]), 5);
  c.req('run 2 with the same planned time (R-PU36): every row has a next_check_at after now: the claim takes no row, no GitHub read, no send, 1 D1 call', cron(NOW), okRun([]), 1);
  c.db = [
    block(Q.checks, [
      ['acme/gone', null, NOW, NOW + HOUR, 0, 0],
      ['acme/later', null, null, NOW + 1, 0, 0],
      ['acme/lib', 'W/"e-lib-2"', NOW, NOW + DAY, 0, 1],
      ['acme/lib-old', null, null, NOW + DAY, 0, 0],
      ['acme/priv', null, NOW, NOW + HOUR, 0, 0],
      ['acme/same', 'W/"e-same"', NOW, NOW + HOUR, 0, 0],
    ]),
    block(Q.releases, [
      [1, 'acme/lib', '1.0.0', null, null],
      [2, 'acme/lib', '2.0.0', 'prereleased', NOW],
      [3, 'acme/lib', '3.0.0', 'deleted', NOW],
      [4, 'acme/lib', '4.0.0', 'deleted', NOW],
      [5, 'acme/lib', '5.0.0', 'asset-replaced', NOW],
      [6, 'acme/lib', '6.0.0', null, null],
      [7, 'acme/lib', '7.0.0', 'repo-missing', W2],
      [8, 'acme/lib', '11.0.0', 'deleted', W3],
      [9, 'acme/lib-old', '0.9.0', 'deleted', NOW],
      [10, 'acme/same', '1.0.0', null, null],
      [11, 'acme/gone', '1.0.0', 'repo-missing', NOW],
      [12, 'acme/gone', '2.0.0', 'deleted', W4],
      [13, 'acme/priv', '1.0.0', 'repo-missing', NOW],
      [14, 'acme/later', '1.0.0', null, null],
    ]),
    block(Q.repos, [
      ['acme/gone', 700, 70, 1, null, NOW, SEED_T],
      ['acme/later', 900, 90, 0, null, SEED_T, SEED_T],
      ['acme/lib', 600, 60, 0, null, SEED_T, SEED_T],
      ['acme/lib-old', 600, 60, 2, 'acme/lib', SEED_T, SEED_T],
      ['acme/priv', 800, 80, 1, null, NOW, SEED_T],
      ['acme/same', 500, 50, 0, null, SEED_T, SEED_T],
    ]),
    block(Q.events, [
      seedEvent('acme/gone', 700, 70), ['acme/gone', 2, 4, 700, 700, 70, 70, null, null, NOW],
      seedEvent('acme/later', 900, 90), seedEvent('acme/lib', 600, 60), seedEvent('acme/lib-old', 600, 60),
      seedEvent('acme/priv', 800, 80), ['acme/priv', 2, 4, 800, 800, 80, 80, null, null, NOW],
      seedEvent('acme/same', 500, 50),
    ]),
  ].join('');
  return c;
}

// ---- case 2: a failed row does not stop the run, the backoff and its cap, 0 after a pass (R-PU37 rows 2 to 4) ----
function backoff() {
  const c = new Case('pu37-backoff', 'R-PU37 R-PU23 R-PU22 R-PU35 R-RE14');
  const names = ['acme/a', 'acme/b', 'acme/c', 'acme/d', 'acme/e'];
  const order = byId(names);
  const t = dueTimes(names);
  // The roles go to the names in the order of the ids, so "A" is the oldest row.
  const [A, B, C, D, E] = order;
  const id = { [A]: 501, [B]: 502, [C]: 503, [D]: 504, [E]: 505 };
  c.bound(A, { id: id[A], owner: 50, nextCheck: t.get(A), checkedAt: SEED_T });
  c.bound(B, { id: id[B], owner: 50, nextCheck: t.get(B), etag: 'W/"b"', checkedAt: SEED_T, fail: 2 }); // Design Q374: a 304 is a pass, fail_count 2 becomes 0
  c.bound(C, { id: id[C], owner: 50, nextCheck: t.get(C) });
  c.bound(D, { id: id[D], owner: 50, nextCheck: t.get(D), fail: 4, checkedAt: SEED_T });
  c.bound(E, { id: id[E], owner: 50, nextCheck: t.get(E) });
  for (const n of order) if (n !== E) repoFile(c, id[n], n, 50);
  c.file(repoUrl(id[E]), '{"message":"Server Error"}', { status: 502 });
  repoFile(c, id[E], E, 50, 'public', undefined, '.2');
  c.file(listUrl(A), '{"message":"Server Error"}', { status: 500 });
  c.file(listUrl(A), '{"message":"Server Error"}', { status: 500 }, '.2');
  c.file(listUrl(A), '[]', { headers: { etag: 'W/"a3"' } }, '.3');
  c.file(listUrl(B), '', { status: 304, headers: { etag: 'W/"b"' }, require: { 'if-none-match': 'W/"b"' } });
  c.file(listUrl(C), '[]', { headers: { etag: 'W/"c"' } });
  c.file(listUrl(D), '{"message":"Server Error"}', { status: 500 });
  c.file(listUrl(E), '[]', { headers: { etag: 'W/"e"' } });
  for (const n of order) { c.read(repoUrl(id[n])); if (n !== E) c.read(listUrl(n)); }
  c.req(`run 1: ${A} (the oldest) gets 500 for its list: fail_count 1, next_check_at now + 5 min, checked_at stays; the run goes on: ${B} (304, fail_count 2 before: 0 after, the interval, Design Q374) and ${C} (200) pass; ${D} had fail_count 4 and fails again: 5, and 5 min x 2^4 = 80 min is capped at the interval (1 h); ${E}: the visibility read gives 502: fail_count 1, no list read. One log line for each failed row (no name). The outcome is ok. 1 + 5 D1 calls`, cron(NOW), okRun([]), 6);
  const T2 = NOW + 5 * MIN;
  c.read(repoUrl(id[A])); c.read(listUrl(A)); c.read(repoUrl(id[E])); c.read(listUrl(E));
  c.req(`run 2 at now + 5 min: only ${A} and ${E} are due. ${A} fails again: fail_count 2, next_check_at + 10 min. ${E} passes: fail_count 0, the interval. 1 + 2 D1 calls`, cron(T2), okRun([]), 3);
  const T3 = T2 + 10 * MIN;
  c.read(repoUrl(id[A])); c.read(listUrl(A));
  c.req(`run 3 at now + 15 min: ${A} passes: fail_count 0, next_check_at + 1 h, the etag. 1 + 1 D1 calls`, cron(T3), okRun([]), 2);
  c.logs.push(rowFailed(id[A], 1), rowFailed(id[D], 5), rowFailed(id[E], 1), rowFailed(id[A], 2));
  const rows = new Map([
    [A, [A, 'W/"a3"', T3, T3 + HOUR, 0, 0]],
    [B, [B, 'W/"b"', NOW, NOW + HOUR, 0, 0]],
    [C, [C, 'W/"c"', NOW, NOW + HOUR, 0, 0]],
    [D, [D, null, SEED_T, NOW + HOUR, 5, 0]],
    [E, [E, 'W/"e"', T2, T2 + HOUR, 0, 0]],
  ]);
  c.db = block(Q.checks, [...names].sort().map((n) => rows.get(n)));
  return c;
}

// ---- case 3: the effects go with the etag (R-PU37 row 5): a failed send, a failed batch ----
function etagEffects() {
  const c = new Case('pu37-etag-effects', 'R-PU37 R-PU23 R-PU21 R-PU13 R-PU36 R-RE14', { TEST_INDEX_FAIL_SENDS: '1' });
  const names = ['acme/lib', 'acme/two'];
  const t = dueTimes(names);
  c.bound('acme/lib', { id: 500, owner: 50, nextCheck: t.get('acme/lib'), etag: 'W/"old"', checkedAt: SEED_T });
  c.bound('acme/two', { id: 600, owner: 60, nextCheck: t.get('acme/two') });
  c.indexed('acme/lib', '1.0.0', 1, 1);
  c.indexed('acme/two', '1.0.0', 2, 3);
  c.seed.push(`CREATE TRIGGER test_etag_refused BEFORE UPDATE OF etag ON repo_checks WHEN NEW.etag = 'W/"boom"' BEGIN SELECT RAISE(ABORT, 'test: the etag write is refused'); END;`);
  repoFile(c, 500, 'acme/lib', 50);
  repoFile(c, 600, 'acme/two', 60);
  listFile(c, 'acme/lib', [releaseObj(9002, '2.0.0', { assets: [zst(fillHash(2))] })], { headers: { etag: 'W/"new"' }, require: { 'if-none-match': 'W/"old"' } });
  listFile(c, 'acme/two', [], { headers: { etag: 'W/"boom"' }, require: { 'if-none-match': null } });
  const reads = () => { for (const n of byId(names)) { c.read(repoUrl(n === 'acme/lib' ? 500 : 600)); c.read(listUrl(n)); } };
  reads();
  c.req('run 1: acme/lib has a new candidate (2.0.0) and 1.0.0 is gone. The send comes first and fails (TEST_INDEX_FAIL_SENDS): the row fails, NOTHING of the list is written (no deleted, the old etag stays), fail_count 1. acme/two: its batch (deleted and the etag W/"boom") fails on the trigger: D1 rolls back the batch, so 1.0.0 stays and no etag is stored; the row fails. 1 claim + 1 (acme/lib) + 2 (acme/two: the batch, then the failure update) D1 calls', cron(NOW), okRun([]), 4);
  c.sql(['DROP TRIGGER test_etag_refused']);
  const T2 = NOW + 5 * MIN;
  reads();
  c.req('run 2 at now + 5 min: both rows are due again (the backoff). The list is the same and the old etag is sent again, so GitHub gives 200 again (not 304): the send passes (the message of 2.0.0), then the batch with deleted and the new etag. acme/two: deleted and W/"boom". 1 + 2 D1 calls', cron(T2), okRun([sent(pollMsg(500, 9002))]), 3);
  c.logs.push(rowFailed(500, 1), rowFailed(600, 1));
  c.db = [
    block(Q.checks, [['acme/lib', 'W/"new"', T2, T2 + HOUR, 0, 0], ['acme/two', 'W/"boom"', T2, T2 + HOUR, 0, 0]]),
    block(Q.releases, [[1, 'acme/lib', '1.0.0', 'deleted', T2], [2, 'acme/two', '1.0.0', 'deleted', T2]]),
  ].join('');
  return c;
}

// ---- case 4: 2 runs at once, and the same planned time 2 times (R-PU36, R-PU37 row 1) ----
function overlap() {
  const c = new Case('pu36-overlap', 'R-PU36 R-PU37 R-PU35 R-PU23');
  const names = ['acme/x', 'acme/y', 'acme/z'];
  const t = dueTimes(names);
  const id = { 'acme/x': 500, 'acme/y': 600, 'acme/z': 700 };
  for (const n of names) {
    c.bound(n, { id: id[n], owner: 50, nextCheck: t.get(n), etag: `W/"${n}"`, checkedAt: SEED_T });
    repoFile(c, id[n], n, 50);
    c.file(listUrl(n), '', { status: 304, headers: { etag: `W/"${n}"` }, require: { 'if-none-match': `W/"${n}"` } });
  }
  for (const n of byId(names)) { c.read(repoUrl(id[n])); c.read(listUrl(n)); }
  c.req('2 scheduled runs at the same time: the claim of one run takes the 3 rows, the claim of the other takes none (D1 runs one write at a time). Each repository is read once. 2 claims + 3 batches', cron(NOW, { copies: 2 }), okRun([]), 5);
  c.req('the same planned time again: no row, no read, 1 D1 call', cron(NOW), okRun([]), 1);
  c.db = block(Q.checks, names.map((n) => [n, `W/"${n}"`, NOW, NOW + HOUR, 0, 0]));
  return c;
}

// ---- case 5: the rate limit reserve (R-PU25) ----
function reserve() {
  const c = new Case('pu25-reserve', 'R-PU25 R-PU23 R-PU37 R-PU35');
  const names = ['acme/p', 'acme/q', 'acme/r'];
  const order = byId(names);
  const t = dueTimes(names);
  const [P, Qn, R] = order;
  const id = { [P]: 501, [Qn]: 502, [R]: 503 };
  c.bound(P, { id: id[P], owner: 50, nextCheck: t.get(P) });
  c.bound(Qn, { id: id[Qn], owner: 50, nextCheck: t.get(Qn), fail: 2, checkedAt: SEED_T });
  c.bound(R, { id: id[R], owner: 50, nextCheck: t.get(R), etag: 'W/"r"', checkedAt: SEED_T });
  const RESET = 1767229800;
  repoFile(c, id[P], P, 50, 'public', { headers: rate(499, RESET) });
  c.file(listUrl(P), '[]', { headers: { etag: 'W/"p"', ...rate(498, RESET) } });
  c.read(repoUrl(id[P])); c.read(listUrl(P));
  c.req(`run 1: the visibility answer of ${P} says 499 of 5000 remain (under 10 %). Design Q377: ${P} still does all its work (its list read, the etag, the interval), then the 2 rows that were not started move to the reset time (${RESET} s), with their fail_count (2 stays), and are not read. 1 claim + 1 batch + 1 move`, cron(NOW), okRun([]), 3);
  c.logs.push({ level: 'warn', msg: 'reconcile rate reserve', moved: 2 });
  const rows = new Map([
    [P, [P, 'W/"p"', NOW, NOW + HOUR, 0, 0]],
    [Qn, [Qn, null, SEED_T, RESET * 1000, 2, 0]],
    [R, [R, 'W/"r"', SEED_T, RESET * 1000, 0, 0]],
  ]);
  c.db = block(Q.checks, [...names].sort().map((n) => rows.get(n)));
  return c;
}

// ---- case 6: the index job of a candidate of the reconcile: the provenance poll (R-PU21, R-PU15, R-PU13, R-PU14) ----
function pollJob() {
  const c = new Case('pu21-poll-job', 'R-PU21 R-PU15 R-PU13 R-PU14 R-PU23 R-PU31 R-RE9');
  c.bound('acme/lib', { id: 500, owner: 10, nextCheck: NOW + HOUR });
  const h1 = c.indexed('acme/lib', '1.0.0', 1, 1, { via: 3 });
  repoFile(c, 500, 'acme/lib', 10);
  c.file(relUrl('acme/lib', 9001), JSON.stringify(releaseObj(9001, '1.0.0', { assets: [zst(h1)] })));
  const asset = pkg('slice 119b polled package');
  const hash = rocHash(asset);
  c.file(relUrl('acme/lib', 9002), JSON.stringify(releaseObj(9002, '2.0.0', { assets: [zst(hash)] })));
  c.file(tagUrl('acme/lib', '2.0.0'), JSON.stringify(releaseObj(9002, '2.0.0', { assets: [zst(hash)] })));
  c.file(assetUrl('acme/lib', '2.0.0', hash), asset);
  c.file(rocVersionUrl('acme/lib', '2.0.0'), 'Not Found', { status: 404 });
  const job = (mid, release) => ({ id: mid, attempts: 1, body: pollMsg(500, release) });
  c.queue('the message of the reconcile for 1.0.0, which an ingest indexed with the same hash: the job reads the repository by id and the release by id, then adds ONLY the provenance row poll (via 2). Acked', [job('m1', 9001)], { acked: ['m1'], retried: [] });
  c.read(repoUrl(500)); c.read(relUrl('acme/lib', 9001));
  c.queue('the same message again (a message sent 2 times is not a fault, R-PU14): the row of via 2 exists, nothing is written. Acked', [job('m2', 9001)], { acked: ['m2'], retried: [] });
  c.read(repoUrl(500)); c.read(relUrl('acme/lib', 9001));
  c.queue('the message for a new candidate 2.0.0: the shared flow indexes it with the provenance poll (via 2), no installation: repo_checks stays. Acked', [job('m3', 9002)], { acked: ['m3'], retried: [] });
  c.read(repoUrl(500)); c.read(relUrl('acme/lib', 9002)); c.read(tagUrl('acme/lib', '2.0.0')); c.read(assetUrl('acme/lib', '2.0.0', hash)); c.read(rocVersionUrl('acme/lib', '2.0.0'));
  c.db = [
    block(Q.provenance, [[1, 2, null, NOW], [1, 3, null, SEED_T], [2, 2, null, NOW]]),
    block(Q.releases, [[1, 'acme/lib', '1.0.0', null, null], [2, 'acme/lib', '2.0.0', null, null]]),
    block(Q.log, [[1, 'github.com/acme/lib/releases/download/{v}/', '1.0.0', h1, SEED_T], [2, 'github.com/acme/lib/releases/download/{v}/', '2.0.0', hash, NOW]]),
    block(Q.checks, [['acme/lib', null, null, NOW + HOUR, 0, 0]]),
  ].join('');
  return c;
}

// ---- case 7: a webhook job writes the rows between the claim and the batch (R-PU36, Design Q339, Q360): the writes of the run are guarded by state ----
function clearGuard() {
  const c = new Case('pu36-state-guard', 'R-PU36 R-PU23 R-PU17 R-PU24 R-PU37');
  c.bound('acme/lib', { id: 500, owner: 50, nextCheck: NOW - MIN });
  const h1 = c.indexed('acme/lib', '1.0.0', 1, 1, { withdrawn: 'unpublished', at: SEED_T + 10 });
  c.indexed('acme/lib', '2.0.0', 2, 2);
  repoFile(c, 500, 'acme/lib', 50);
  listFile(c, 'acme/lib', [releaseObj(9001, '1.0.0', { assets: [zst(h1)] })], { headers: { etag: 'W/"g"' } });
  // The fake runs these statements just before it answers the list read: a job `privatized` and a webhook `edited` that came during the run (github/<file>.sql of run.mjs).
  c.files.set('api.github.com/repos/acme/lib/releases%3Fper_page=100.sql', `UPDATE releases SET withdrawn = 'repo-missing', withdrawn_at = ${SEED_T + 50} WHERE log_index = 1;\nUPDATE releases SET withdrawn = 'edited', withdrawn_at = ${SEED_T + 60} WHERE log_index = 2;\n`);
  c.read(repoUrl(500)); c.read(listUrl('acme/lib'));
  c.req('the claim saw 1.0.0 as unpublished and 2.0.0 with no value. Before the list answer, other jobs set 1.0.0 to repo-missing and 2.0.0 to edited. The list has 1.0.0 (a candidate: the run wants to clear it) and not 2.0.0 (the run wants deleted). Both writes are guarded by state: repo-missing and edited stay with their times. The etag and the pass are written', cron(NOW), okRun([]), 2);
  c.db = [
    block(Q.releases, [[1, 'acme/lib', '1.0.0', 'repo-missing', SEED_T + 50], [2, 'acme/lib', '2.0.0', 'edited', SEED_T + 60]]),
    block(Q.checks, [['acme/lib', 'W/"g"', NOW, NOW + HOUR, 0, 0]]),
  ].join('');
  return c;
}

const cases = [list(), backoff(), etagEffects(), overlap(), reserve(), pollJob(), clearGuard()];
for (const c of cases) c.write();
console.log(`wrote ${cases.length} cases in ${casesDir}`);
