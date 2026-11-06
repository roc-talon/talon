// The W2 cases of slice 118 (the GitHub webhook and the index queue: Registry R-AP12, R-PU3, R-PU11, R-PU13, R-PU26, R-PU33, R-PU35; docs/slices/118-webhook.md section 4).
//   node worker/tests/tools/mk-webhook.mjs     writes worker/tests/cases/webhook/*/ (github/, seed.sql, requests.jsonl, settings.json, expect/, rules, notes.txt)
// The files are tracked. Run the script again only when a case changes.
// The signatures are made here with node (crypto.createHmac) over the RAW bytes of each body, never with the Roc code. The ids (R-IK2) come from node too (SHA-256).
import { createHash, createHmac } from 'node:crypto';
import { mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { tar, zstd } from './mk-bundle.mjs';
import { rocHash } from './blake3.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const casesDir = join(here, '..', 'cases', 'webhook');

// ---- the facts of the design, in JS ----
const nameId = (kind, bytes) => createHash('sha256').update(Buffer.concat([Buffer.from([kind]), Buffer.from(bytes)])).digest().readBigInt64BE(0).toString(); // R-IK2
const textId = (kind, t) => nameId(kind, Buffer.from(t, 'utf8'));
const repoId = (name) => textId(3, name);
const B58 = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
const b58encode = (buf) => {
  let n = BigInt(`0x${buf.toString('hex')}`);
  let s = '';
  while (n > 0n) { s = B58[Number(n % 58n)] + s; n /= 58n; }
  return s;
};
const versionCol = (v) => { const [a, b, c] = v.split('.').map(BigInt); return BigInt.asIntN(64, ((a << 48n) | (b << 32n) | (c << 16n) | 0xFFFFn) ^ (1n << 63n)).toString(); }; // R-IK5
const sq = (s) => `'${String(s).replace(/'/g, "''")}'`;

// ---- constants of the cases ----
const SECRET = 'test-webhook-secret'; // a test value only (TW33): the real secret of the Talon Indexer App is never read or used
const NOW = 1767225600000; // the default clock of a request (run.mjs)
const SEED_T = 1767000000000;
const FUTURE = NOW + 7 * 86400000;
const HOOK = '/v1/webhooks/github';
const sign = (secret, body) => `sha256=${createHmac('sha256', secret).update(body).digest('hex')}`;

// A realistic `release` payload: members that the Worker does not read, nested objects, null values (GitHub sends `"body":null`, `"name":null`, `"label":null`).
// The text is not the compact form of JSON.stringify: it has white space, a non-ASCII escape and a member order that a parse and write would change.
const releasePayload = (action, { installation = true, repo = 100, release = 9001 } = {}) => `{
  "action": "${action}",
  "release": {"url": "https://api.github.com/repos/acme/lib/releases/${release}", "id": ${release}, "tag_name": "1.2.0", "name": null, "body": null,
    "draft": false, "prerelease": false, "published_at": "2026-10-20T12:00:00Z", "author": {"login": "caf\\u00e9", "id": 5},
    "assets": [{"id": 1, "name": "x.tar.zst", "label": null, "state": "uploaded", "size": 10}]},
  "repository": {"id": ${repo}, "full_name": "acme/lib", "private": false, "description": null, "owner": {"id": 10, "login": "acme"}}${installation ? ',\n  "installation": {"id": 55, "node_id": "MDIzOkludGVncmF0aW9u"}' : ''},
  "sender": {"login": "someone", "id": 5, "site_admin": false}
}`;
const repositoryPayload = (action, repo = 100) => `{"action":"${action}","repository":{"id":${repo},"full_name":"acme/lib","private":true,"description":null},"sender":{"id":5},"installation":{"id":55}}`;
const installationPayload = (action, ids) => `{"action":"${action}","installation":{"id":55,"account":{"id":3,"login":"acme"}},"repository_selection":"selected","repositories":[${ids.map((i) => `{"id":${i},"name":"r${i}","full_name":"acme/r${i}","private":${i % 2 === 1}}`).join(',')}],"sender":{"id":5}}`;
const reposPayload = (action, ids) => `{"action":"${action}","installation":{"id":55},"repository_selection":"selected","repositories_added":[${(action === 'added' ? ids : [777]).map((i) => `{"id":${i},"name":"r${i}"}`).join(',')}],"repositories_removed":[${(action === 'removed' ? ids : [888]).map((i) => `{"id":${i},"name":"r${i}"}`).join(',')}],"sender":{"id":5}}`;

const msg = (event, action, { installation_id = 55, repository_id = 0, release_id = 0, repository_ids = [] } = {}) => ({ event, action, installation_id, repository_id, release_id, repository_ids });
const sent = (body) => ({ body, delay_s: 0 });

// A signed request of the webhook. `sig` overrides the header (a string), `secret` the key, `signedOver` the bytes that are signed.
const hook = ({ event, body, pad: padTotal, sig, secret = SECRET, signedOver, headers = {}, now } = {}) => ({
  method: 'POST',
  path: HOOK,
  headers: {
    'content-type': 'application/json',
    'x-github-event': event,
    'x-github-delivery': '72d3162e-cc78-11e3-81ab-4c9367dc0958',
    ...(sig === null ? {} : { 'x-hub-signature-256': sig ?? sign(secret, signedOver ?? (padTotal === undefined ? body : padBody(padTotal))) }),
    'user-agent': 'GitHub-Hookshot/044aadd',
    ...headers,
  },
  ...(padTotal === undefined ? { body } : { body_pad: padSpec(padTotal) }),
  ...(now === undefined ? {} : { now }),
});

class Case {
  constructor(name, rules, settings = { GITHUB_WEBHOOK_SECRET: SECRET }) {
    this.name = name; this.rules = rules; this.settings = settings;
    this.forms = new Set(); this.files = new Map(); this.reqs = []; this.exp = []; this.calls = []; this.log = []; this.seed = []; this.db = ''; this.notes = []; this.logs = [];
  }
  file(url, body, meta, suffix = '') {
    const u = new URL(url);
    const enc = (s) => s.replace(/[%?:\\*<>|"]/g, (c) => `%${c.charCodeAt(0).toString(16).toUpperCase().padStart(2, '0')}`);
    const p = [enc(u.host), ...u.pathname.split('/').filter(Boolean).map(enc)].join('/');
    this.files.set(`${p}${suffix}`, body);
    if (meta) this.files.set(`${p}${suffix}.meta.json`, JSON.stringify(meta));
  }
  // A request line of the webhook (a fetch): the expected answer and the D1 call count.
  req(comment, spec, expect, calls = 0) { this.reqs.push(spec); this.exp.push(expect); this.calls.push(String(calls)); this.notes.push(comment); }
  // A queue line: the batch and the expected acks and retries. No D1 count (`-`).
  queue(comment, queue, messages, expect, now) { this.reqs.push({ queue, ...(now === undefined ? {} : { now }), messages }); this.exp.push({ outcome: 'ok', ...expect }); this.calls.push('-'); this.notes.push(comment); }
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
    if (this.seed.length) writeFileSync(join(dir, 'seed.sql'), this.seed.join('\n') + '\n');
    if (this.db) writeFileSync(join(dir, 'expect', 'db.tsv'), this.db);
    if (this.logs.length) writeFileSync(join(dir, 'expect', 'logs.jsonl'), this.logs.map((l) => JSON.stringify(l)).join('\n') + '\n');
  }
  // A bound name: the `names` row, the `repos` row, the `repo_checks` row and the event bind (seq 1), as an ingest of slices 112 and 113 wrote them.
  bound(name, { id, owner, state = 0, successor = null, stateAt = SEED_T, nextCheck = SEED_T + 3600000, installed = 0 }) {
    const s = successor === null ? 'NULL' : repoId(successor);
    this.seed.push(
      `INSERT INTO names (id, kind, value) VALUES (${repoId(name)}, 3, ${sq(name)});`,
      `INSERT INTO repos (repo, repository_id, repository_owner_id, state, successor, state_at, time) VALUES (${repoId(name)}, ${id}, ${owner}, ${state}, ${s}, ${stateAt}, ${SEED_T});`,
      `INSERT INTO repo_checks (repo, etag, checked_at, next_check_at, fail_count, app_installed) VALUES (${repoId(name)}, NULL, NULL, ${nextCheck}, 0, ${installed});`,
      `INSERT INTO repo_events (repo, seq, action, repository_id_before, repository_id_after, owner_id_before, owner_id_after, successor, claims, time) VALUES (${repoId(name)}, 1, 0, NULL, ${id}, NULL, ${owner}, NULL, NULL, ${SEED_T});`,
    );
  }
  // A release of `name` with the label `tag` and a made hash (the byte `fill` 32 times), with the log leaf and a webhook provenance row. `withdrawn` and `at` as the table.
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
      `INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (${idx}, ${fid}, ${versionCol(tag)}, '', ${hid}, ${repoId(name)}, ${sq(`https://github.com/${name}/releases/download/${tag}/${hash}.tar.zst`)}, ${sq(tag)}, NULL, ${SEED_T}, 0, ${withdrawn === null ? 'NULL' : sq(withdrawn)}, ${at === null ? 'NULL' : at});`,
      `INSERT INTO provenance (release, via, claims, time) VALUES (${idx}, ${via}, NULL, ${SEED_T});`,
    );
    return hash;
  }
}

// The db.tsv blocks, by name (a join with `names`), as the cases of slice 113.
const Q = {
  repos: 'SELECT n.value, r.repository_id, r.repository_owner_id, r.state, (SELECT s.value FROM names s WHERE s.id = r.successor), r.state_at, r.time FROM repos r JOIN names n ON n.id = r.repo ORDER BY n.value',
  events: 'SELECT n.value, e.seq, e.action, e.repository_id_before, e.repository_id_after, e.owner_id_before, e.owner_id_after, (SELECT s.value FROM names s WHERE s.id = e.successor), e.claims, e.time FROM repo_events e JOIN names n ON n.id = e.repo ORDER BY n.value, e.seq',
  checks: 'SELECT n.value, c.etag, c.checked_at, c.next_check_at, c.fail_count, c.app_installed FROM repo_checks c JOIN names n ON n.id = c.repo ORDER BY n.value',
  releases: 'SELECT r.log_index, n.value, r.tag, r.withdrawn, r.withdrawn_at FROM releases r JOIN names n ON n.id = r.repo ORDER BY r.log_index',
  log: 'SELECT idx, grp, version, hash, time FROM log ORDER BY idx',
  provenance: 'SELECT release, via, claims, time FROM provenance ORDER BY release, via',
  counts: "SELECT (SELECT COUNT(*) FROM names WHERE kind = 3), (SELECT COUNT(*) FROM repos), (SELECT COUNT(*) FROM repo_checks), (SELECT COUNT(*) FROM repo_events), (SELECT COUNT(*) FROM releases), (SELECT COUNT(*) FROM log), (SELECT COUNT(*) FROM provenance)",
};
const block = (q, rows) => `@ ${q}\n${rows.map((r) => r.map((c) => (c === null ? '\\N' : String(c))).join('\t')).join('\n')}${rows.length ? '\n' : ''}`;
const dbOf = (parts) => parts.join('');
const seedEvent = (name, id, owner) => [name, 1, 0, null, id, null, owner, null, null, SEED_T];

const ack202 = { status: 202, body: '', headers: { 'cache-control': 'no-store' }, timing_safe: 1 };
const unauth = (extra = {}) => ({ status: 401, problem: { type: '/errors/unauthenticated', status: 401 }, queue_sent: [], ...extra });

// ---- case 1: the signature (R-AP12), the checks of R-AP48 before it, the size ----
function signature() {
  const c = new Case('ap12-signature', 'R-AP12 R-AP79 R-AP48 R-AP46 R-AP23 R-AP21 R-PU11 R-PU3');
  const body = releasePayload('published');
  const m = msg('release', 'published', { repository_id: 100, release_id: 9001 });
  c.req('a good signature of the RAW bytes (white space, a non-ASCII escape, an order of members that a write would change): 202, no body, no-store, one message, one constant-time compare, no D1 call', hook({ event: 'release', body }), { ...ack202, queue_sent: [sent(m)] });
  c.req('the signature of the compact JSON (the body parsed and written again) is not the signature of the bytes: 401, nothing sent', hook({ event: 'release', body, signedOver: JSON.stringify(JSON.parse(body)) }), unauth({ timing_safe: 1 }));
  c.req('the signature made with another key: 401', hook({ event: 'release', body, secret: 'another-secret' }), unauth({ timing_safe: 1 }));
  const good = sign(SECRET, body);
  const flipped = good.slice(0, -1) + (good.endsWith('0') ? '1' : '0');
  c.req('the good signature with the last hex digit changed: 401 (the whole value is compared)', hook({ event: 'release', body, sig: flipped }), unauth({ timing_safe: 1 }));
  c.req('the signature of a body that is one byte longer: 401', hook({ event: 'release', body, signedOver: `${body} ` }), unauth({ timing_safe: 1 }));
  c.req('no signature header: 401', hook({ event: 'release', body, sig: null }), unauth());
  c.req('the old header form sha1= with 40 hex digits: 401', hook({ event: 'release', body, sig: `sha1=${'ab'.repeat(20)}` }), unauth());
  c.req('sha256= and 63 hex digits: 401', hook({ event: 'release', body, sig: good.slice(0, -1) }), unauth());
  c.req('64 hex digits with no sha256= prefix: 401', hook({ event: 'release', body, sig: good.slice(7) }), unauth());
  c.req('sha256= and a character that is not a hex digit: 401', hook({ event: 'release', body, sig: `${good.slice(0, -1)}g` }), unauth());
  const notJson = 'this is not json';
  c.req('a good signature of a body that is not JSON: 400 bad-request (R-AP48 row 6), nothing sent', hook({ event: 'release', body: notJson }), { status: 400, problem: { type: '/errors/bad-request', status: 400 }, queue_sent: [] });
  const noBody = hook({ event: 'release', body: undefined, sig: sign(SECRET, '') });
  c.req('no body (the signature of the empty body is good): 400 bad-request', noBody, { status: 400, problem: { type: '/errors/bad-request', status: 400 }, queue_sent: [] });
  c.req('a body of 1048576 bytes (R-AP46, Design Q326: 1 MiB is the limit of this route, it passes) with a good signature: 202, the event ping is ignored, nothing sent', hook({ event: 'ping', pad: 1048576 }), { ...ack202, queue_sent: [] });
  c.req('a body of 262145 bytes with a good signature: 202 (the old limit of 256 KB is gone)', hook({ event: 'ping', pad: 262145 }), { ...ack202, queue_sent: [] });
  c.req('a body of 1048577 bytes: 413 too-large with field body and limit 1048576, before the media type and the signature check (no compare)', hook({ event: 'ping', pad: 1048577, sig: null }), { status: 413, problem: { type: '/errors/too-large', status: 413 }, json: { field: 'body', limit: 1048576 }, queue_sent: [], timing_safe: 0 });
  c.req('the media type of a form (GitHub can send it by a setting) and a bad signature: 415 comes first (R-AP79 row 3 before row 5), no compare', hook({ event: 'release', body: 'payload=%7B%7D', headers: { 'content-type': 'application/x-www-form-urlencoded' }, sig: 'sha256=00' }), { status: 415, problem: { type: '/errors/unsupported-media-type', status: 415 }, queue_sent: [], timing_safe: 0 });
  c.req('GET: 405 with Allow: POST', { method: 'GET', path: HOOK }, { status: 405, headers: { allow: 'POST' }, problem: { type: '/errors/method-not-allowed', status: 405 } });
  c.req('a path below the route is no route: 404', { method: 'POST', path: `${HOOK}/extra`, headers: { 'content-type': 'application/json' }, body: '{}' }, { status: 404, problem: { type: '/errors/not-found', status: 404 } });
  const bad400 = { status: 400, problem: { type: '/errors/bad-request', status: 400 }, queue_sent: [] };
  c.req('(a) a good signature and no X-GitHub-Event header: 400 (R-AP79 row 6, Design Q321), nothing sent, the signature was checked first', hook({ event: undefined, body }), { ...bad400, timing_safe: 1 });
  c.req('(b) a good signature and an empty X-GitHub-Event header: 400', hook({ event: '', body }), bad400);
  c.req('(c) no event header and no signature: 401 (the signature comes before the event check)', hook({ event: undefined, body, sig: null }), unauth());
  c.req('(d) a body that is not JSON, a bad signature, the event release: 401 (Design Q320: the signature first, then the parse), one compare', hook({ event: 'release', body: notJson, sig: sign('another-secret', notJson) }), unauth({ timing_safe: 1 }));
  c.req('(e) a body that is not JSON, a good signature, the event ping: 202, no message (R-AP79 row 7: the body of an event that is not used is not read)', hook({ event: 'ping', body: notJson }), { ...ack202, queue_sent: [] });
  return c;
}
// A body of exactly `total` bytes (run.mjs `body_pad` makes the same bytes): the case file holds the numbers, not 1 MiB of text.
function padSpec(total) { return { prefix: '{"zen":"', fill: 'a', suffix: '"}', total }; }
function padBody(total) { const b = padSpec(total); return b.prefix + b.fill.repeat(total - b.prefix.length - b.suffix.length) + b.suffix; }

// ---- case 2 and 3: no secret, an empty secret (R-WH14): a Fault, never the empty key ----
function noSecret(name, settings, comment) {
  const c = new Case(name, 'R-AP12 R-AP79 R-WH14 R-AP48 R-AP46 R-AP23 R-AP21', settings);
  const body = releasePayload('published');
  const fault = { status: 500, problem: { type: '/errors/internal', status: 500 }, queue_sent: [] };
  c.req(`${comment}: a signature made with a made-up key: 500 internal, nothing sent`, hook({ event: 'release', body, secret: 'made-up' }), fault);
  c.req(`${comment}: a signature made with the empty key: 500 internal (an empty key must never accept a request), nothing sent`, hook({ event: 'release', body, secret: '' }), fault);
  c.req(`${comment}: no signature header: 500 internal (the secret is checked before the signature header, R-AP79 row 4, Design Q327)`, hook({ event: 'release', body, sig: null }), fault);
  c.req(`${comment}: a body of 1048577 bytes: 413 (the size check comes before the secret)`, hook({ event: 'ping', pad: 1048577, sig: null }), { status: 413, problem: { type: '/errors/too-large', status: 413 }, queue_sent: [] });
  c.req(`${comment}: the media type of a form: 415 (the media check comes before the secret)`, hook({ event: 'release', body: 'payload=%7B%7D', headers: { 'content-type': 'application/x-www-form-urlencoded' }, sig: null }), { status: 415, problem: { type: '/errors/unsupported-media-type', status: 415 }, queue_sent: [] });
  return c;
}

// ---- case 4: the events and the actions (R-PU11, R-PU3): the message of each event that the Worker uses, and 202 with no message for the others ----
function events() {
  const c = new Case('pu11-events', 'R-PU11 R-PU3 R-PU12 R-PU13 R-PU17 R-PU26 R-PU33 R-PU32 R-AP12 R-AP41 R-AP79');
  const ok = (messages) => ({ ...ack202, queue_sent: messages.map(sent) });
  for (const action of ['published', 'released', 'edited', 'prereleased', 'unpublished', 'deleted']) {
    c.req(`release ${action}: one message with the ids of the repository (100), the release (9001) and the installation (55), no name`, hook({ event: 'release', body: releasePayload(action) }), ok([msg('release', action, { repository_id: 100, release_id: 9001 })]));
  }
  c.req('release created (a draft): 202, ignored', hook({ event: 'release', body: releasePayload('created') }), ok([]));
  c.req('release with no installation member: the installation id is 0', hook({ event: 'release', body: releasePayload('published', { installation: false, repo: 101, release: 9002 }) }), ok([msg('release', 'published', { installation_id: 0, repository_id: 101, release_id: 9002 })]));
  c.req('repository privatized: one message with the repository id', hook({ event: 'repository', body: repositoryPayload('privatized') }), ok([msg('repository', 'privatized', { repository_id: 100 })]));
  c.req('repository publicized', hook({ event: 'repository', body: repositoryPayload('publicized', 102) }), ok([msg('repository', 'publicized', { repository_id: 102 })]));
  c.req('repository archived: ignored', hook({ event: 'repository', body: repositoryPayload('archived') }), ok([]));
  c.req('repository deleted: ignored (the reconcile finds it)', hook({ event: 'repository', body: repositoryPayload('deleted') }), ok([]));
  c.req('installation created with 3 repositories: one message with their ids (no names)', hook({ event: 'installation', body: installationPayload('created', [100, 101, 102]) }), ok([msg('installation', 'created', { repository_ids: [100, 101, 102] })]));
  c.req('installation deleted', hook({ event: 'installation', body: installationPayload('deleted', [100]) }), ok([msg('installation', 'deleted', { repository_ids: [100] })]));
  c.req('installation_repositories added: the ids of repositories_added only', hook({ event: 'installation_repositories', body: reposPayload('added', [200, 201]) }), ok([msg('installation_repositories', 'added', { repository_ids: [200, 201] })]));
  c.req('installation_repositories removed: the ids of repositories_removed only', hook({ event: 'installation_repositories', body: reposPayload('removed', [300]) }), ok([msg('installation_repositories', 'removed', { repository_ids: [300] })]));
  c.req('installation suspend (Design Q322): one message with the ids, as created', hook({ event: 'installation', body: installationPayload('suspend', [100]) }), ok([msg('installation', 'suspend', { repository_ids: [100] })]));
  c.req('installation unsuspend: one message with the ids', hook({ event: 'installation', body: installationPayload('unsuspend', [100]) }), ok([msg('installation', 'unsuspend', { repository_ids: [100] })]));
  c.req('installation new_permissions_accepted: 202, ignored', hook({ event: 'installation', body: installationPayload('new_permissions_accepted', [100]) }), ok([]));
  c.req('ping (the first event of a new webhook): 202, ignored', hook({ event: 'ping', body: '{"zen":"Design for failure.","hook_id":123,"hook":{"type":"App","events":["release"]}}' }), ok([]));
  c.req('an event that the App does not use, with a body that looks like a release: ignored', hook({ event: 'star', body: releasePayload('published') }), ok([]));
  c.req('a release body with no repository id: 400 bad-request, nothing sent', hook({ event: 'release', body: '{"action":"published","release":{"id":9001}}' }), { status: 400, problem: { type: '/errors/bad-request', status: 400 }, queue_sent: [] });
  return c;
}

// ---- case 5: the job `privatized` (R-PU33, R-PU31, R-PU12, R-PU24, R-PU32, R-PU36, R-TP11, R-TP19) ----
function privatized() {
  const c = new Case('pu33-privatized', 'R-PU33 R-PU31 R-PU12 R-PU24 R-PU32 R-PU36 R-PU35 R-TP11 R-TP13 R-TP19 R-RE11 R-RE15 R-PU11');
  c.bound('acme/lib', { id: 100, owner: 10 });
  c.bound('acme/old', { id: 100, owner: 10, state: 2, successor: 'acme/lib' });
  c.bound('other/pkg', { id: 200, owner: 20 });
  c.bound('stale/pkg', { id: 300, owner: 30 });
  c.bound('gone/pkg', { id: 400, owner: 40 });
  c.bound('boom/pkg', { id: 500, owner: 50 });
  c.bound('already/pkg', { id: 600, owner: 60, state: 1, stateAt: SEED_T + 500 });
  c.indexed('acme/lib', '1.0.0', 1, 1);
  c.indexed('acme/lib', '1.1.0', 2, 2, { withdrawn: 'deleted', at: SEED_T + 100 });
  c.indexed('acme/old', '0.9.0', 3, 3);
  c.indexed('other/pkg', '1.0.0', 4, 4);
  c.indexed('stale/pkg', '1.0.0', 5, 5);
  c.indexed('gone/pkg', '1.0.0', 6, 6);
  c.indexed('boom/pkg', '1.0.0', 7, 7);
  c.indexed('already/pkg', '1.0.0', 8, 8, { withdrawn: 'repo-missing', at: SEED_T + 500 });
  const repo = (id, visibility) => JSON.stringify({ id, name: 'x', full_name: `x/${id}`, private: visibility !== 'public', owner: { login: 'x', id: id / 10, type: 'User' }, description: null, visibility, default_branch: 'main' });
  const gh = (id) => `https://api.github.com/repositories/${id}`;
  c.file(gh(100), repo(100, 'private'));
  c.file(gh(300), repo(300, 'public'));
  c.file(gh(400), '{"message":"Not Found"}', { status: 404 });
  c.file(gh(500), '{"message":"Server Error"}', { status: 500 });
  c.file(gh(600), repo(600, 'internal'));
  c.file(gh(999), '{"message":"Not Found"}', { status: 404 });
  const job = (id, repo_id, attempts = 1) => ({ id, attempts, body: msg('repository', 'privatized', { repository_id: repo_id }) });
  const T2 = NOW + 1000;
  c.queue('privatized 100: GitHub shows it private. acme/lib becomes missing (state_at = the clock, event Missing seq 2), the releases of BOTH names of the repository (acme/lib 1.0.0 and acme/old 0.9.0) get repo-missing, 1.1.0 keeps its value deleted, the moved row acme/old keeps its state and gets no event', 'talon-index', [job('m1', 100)], { acked: ['m1'], retried: [] });
  c.queue('the same message again later, and 600 (already missing, GitHub shows internal): no row, no event and no release changes (the old state_at and withdrawn_at stay)', 'talon-index', [job('m2', 100), job('m3', 600)], { acked: ['m2', 'm3'], retried: [] }, T2);
  c.queue('privatized 300: GitHub shows it public (an old event): nothing is written', 'talon-index', [job('m4', 300)], { acked: ['m4'], retried: [] });
  c.queue('privatized 400: GitHub answers 404 (deleted, or private and not readable): withdrawn like the private case', 'talon-index', [job('m5', 400)], { acked: ['m5'], retried: [] }, T2);
  c.queue('privatized 999: no repos row (R-PU32). GitHub answers 404. Nothing is written, no row is added', 'talon-index', [job('m6', 999)], { acked: ['m6'], retried: [] });
  c.queue('privatized 500: GitHub answers 500. The job failed: retried after 60 s (attempt 1), nothing written, not acked', 'talon-index', [job('m7', 500)], { acked: [], retried: [{ id: 'm7', delay_s: 60 }] });
  c.log.push(...[100, 100, 600, 300, 400, 999, 500].map((i) => `GET ${gh(i)}`));
  const E = (name, seq, action, idb, ida, ob, oa, t) => [name, seq, action, idb, ida, ob, oa, null, null, t];
  c.db = dbOf([
    block(Q.repos, [
      ['acme/lib', 100, 10, 1, null, NOW, SEED_T],
      ['acme/old', 100, 10, 2, 'acme/lib', SEED_T, SEED_T],
      ['already/pkg', 600, 60, 1, null, SEED_T + 500, SEED_T],
      ['boom/pkg', 500, 50, 0, null, SEED_T, SEED_T],
      ['gone/pkg', 400, 40, 1, null, T2, SEED_T],
      ['other/pkg', 200, 20, 0, null, SEED_T, SEED_T],
      ['stale/pkg', 300, 30, 0, null, SEED_T, SEED_T],
    ]),
    block(Q.events, [
      seedEvent('acme/lib', 100, 10), E('acme/lib', 2, 4, 100, 100, 10, 10, NOW),
      seedEvent('acme/old', 100, 10),
      seedEvent('already/pkg', 600, 60),
      seedEvent('boom/pkg', 500, 50),
      seedEvent('gone/pkg', 400, 40), E('gone/pkg', 2, 4, 400, 400, 40, 40, T2),
      seedEvent('other/pkg', 200, 20),
      seedEvent('stale/pkg', 300, 30),
    ]),
    block(Q.checks, ['acme/lib', 'acme/old', 'already/pkg', 'boom/pkg', 'gone/pkg', 'other/pkg', 'stale/pkg'].map((n) => [n, null, null, SEED_T + 3600000, 0, 0])),
    block(Q.releases, [
      [1, 'acme/lib', '1.0.0', 'repo-missing', NOW],
      [2, 'acme/lib', '1.1.0', 'deleted', SEED_T + 100],
      [3, 'acme/old', '0.9.0', 'repo-missing', NOW],
      [4, 'other/pkg', '1.0.0', null, null],
      [5, 'stale/pkg', '1.0.0', null, null],
      [6, 'gone/pkg', '1.0.0', 'repo-missing', T2],
      [7, 'boom/pkg', '1.0.0', null, null],
      [8, 'already/pkg', '1.0.0', 'repo-missing', SEED_T + 500],
    ]),
    block(Q.counts, [[7, 7, 7, 9, 8, 8, 8]]),
  ]);
  return c;
}

// ---- case 6: the retry schedule and the failures (R-PU13, R-PU35): 1, 5, 15, 60 min, then the last attempt ----
function retrySchedule() {
  const c = new Case('pu35-retry-schedule', 'R-PU35 R-PU13 R-PU11 R-PU32');
  c.file('https://api.github.com/repositories/500', '{"message":"Server Error"}', { status: 500 });
  const job = (id, attempts) => ({ id, attempts, body: msg('repository', 'privatized', { repository_id: 500 }) });
  const delays = [60, 300, 900, 3600, null];
  delays.forEach((d, i) => c.queue(`attempt ${i + 1} fails (GitHub answers 500): ${d === null ? 'the last attempt: a retry with no delay (the platform moves the message to the dead letter queue because max_retries 4 is used up)' : `retried after ${d} s`}`, 'talon-index', [job(`a${i + 1}`, i + 1)], { acked: [], retried: [{ id: `a${i + 1}`, delay_s: d }] }));
  c.queue('attempt 6 (not possible with max_retries 4, but a changed config): no delay', 'talon-index', [job('a6', 6)], { acked: [], retried: [{ id: 'a6', delay_s: null }] });
  c.queue('a body that is not a message (attempt 2): a failure, retried after 300 s', 'talon-index', [{ id: 'u1', attempts: 2, body: { unexpected: true } }], { acked: [], retried: [{ id: 'u1', delay_s: 300 }] });
  c.queue('a message of an event or action that this Worker never writes (attempt 3): a failure, retried after 900 s', 'talon-index', [{ id: 'u2', attempts: 3, body: msg('repository', 'archived', { repository_id: 500 }) }], { acked: [], retried: [{ id: 'u2', delay_s: 900 }] });
  c.queue('one batch with 3 messages of different attempts: each has its own delay', 'talon-index', [job('b1', 1), job('b2', 3), job('b3', 5)], { acked: [], retried: [{ id: 'b1', delay_s: 60 }, { id: 'b2', delay_s: 900 }, { id: 'b3', delay_s: null }] });
  c.log.push(...Array.from({ length: 6 }, () => 'GET https://api.github.com/repositories/500'), ...Array.from({ length: 3 }, () => 'GET https://api.github.com/repositories/500'));
  return c;
}

// ---- case 7: the job `publicized` (R-PU33, Design Q324) ----
function publicized() {
  const c = new Case('pu33-publicized', 'R-PU33 R-PU24 R-PU32 R-TP11 R-TP19 R-PU11');
  c.bound('back/pkg', { id: 100, owner: 10, state: 1, stateAt: SEED_T + 200, nextCheck: FUTURE });
  c.bound('other/pkg', { id: 200, owner: 20, nextCheck: FUTURE });
  c.bound('acme/new', { id: 700, owner: 70, nextCheck: FUTURE });
  c.bound('acme/old', { id: 700, owner: 70, state: 2, successor: 'acme/new', nextCheck: FUTURE });
  c.indexed('back/pkg', '1.0.0', 1, 1, { withdrawn: 'repo-missing', at: SEED_T + 200 });
  const job = (id, repo) => ({ id, attempts: 1, body: msg('repository', 'publicized', { repository_id: repo }) });
  c.queue('publicized 100: next_check_at of the row becomes the clock. The state stays missing, the release stays repo-missing (the next reconcile clears them, R-PU24), no event. No GitHub read', 'talon-index', [job('p1', 100)], { acked: ['p1'], retried: [] });
  c.queue('publicized 999 (no row): nothing is written', 'talon-index', [job('p2', 999)], { acked: ['p2'], retried: [] });
  c.queue('publicized 700 (a rename: acme/new is active, acme/old is moved with the same repository id): next_check_at of acme/new becomes the clock, the moved row keeps its value (Design Q324)', 'talon-index', [job('p3', 700)], { acked: ['p3'], retried: [] });
  c.db = dbOf([
    block(Q.repos, [['acme/new', 700, 70, 0, null, SEED_T, SEED_T], ['acme/old', 700, 70, 2, 'acme/new', SEED_T, SEED_T], ['back/pkg', 100, 10, 1, null, SEED_T + 200, SEED_T], ['other/pkg', 200, 20, 0, null, SEED_T, SEED_T]]),
    block(Q.events, [seedEvent('acme/new', 700, 70), seedEvent('acme/old', 700, 70), seedEvent('back/pkg', 100, 10), seedEvent('other/pkg', 200, 20)]),
    block(Q.checks, [['acme/new', null, null, NOW, 0, 0], ['acme/old', null, null, FUTURE, 0, 0], ['back/pkg', null, null, NOW, 0, 0], ['other/pkg', null, null, FUTURE, 0, 0]]),
    block(Q.releases, [[1, 'back/pkg', '1.0.0', 'repo-missing', SEED_T + 200]]),
    block(Q.counts, [[4, 4, 4, 4, 1, 1, 1]]),
  ]);
  return c;
}

// ---- case 8: the jobs `installation` and `installation_repositories` (R-PU26, Design Q322, Q324) ----
function appInstalled() {
  const c = new Case('pu26-app-installed', 'R-PU26 R-PU22 R-PU32 R-PU11 R-RE14 R-TP19');
  c.bound('acme/a', { id: 100, owner: 10 });
  c.bound('acme/b', { id: 101, owner: 10 });
  c.bound('acme/c', { id: 200, owner: 10 });
  c.bound('acme/d', { id: 300, owner: 10, installed: 1 });
  c.bound('acme/new', { id: 700, owner: 70 });
  c.bound('acme/old', { id: 700, owner: 70, state: 2, successor: 'acme/new' });
  c.bound('acme/x', { id: 701, owner: 71, installed: 1 });
  c.bound('acme/y', { id: 701, owner: 71, state: 2, successor: 'acme/x', installed: 1 });
  const job = (id, event, action, ids) => ({ id, attempts: 1, body: msg(event, action, { repository_ids: ids }) });
  c.queue('installation created with 100, 101 and 999 (999 has no row): app_installed is 1 for 100 and 101. No row is added for 999. next_check_at does not change', 'talon-index', [job('i1', 'installation', 'created', [100, 101, 999])], { acked: ['i1'], retried: [] });
  c.queue('installation_repositories removed 101: app_installed is 0 again', 'talon-index', [job('i2', 'installation_repositories', 'removed', [101])], { acked: ['i2'], retried: [] });
  c.queue('installation_repositories added 200', 'talon-index', [job('i3', 'installation_repositories', 'added', [200])], { acked: ['i3'], retried: [] });
  c.queue('installation deleted 100 and 300: both 0', 'talon-index', [job('i4', 'installation', 'deleted', [100, 300])], { acked: ['i4'], retried: [] });
  c.queue('installation created with an empty list: nothing changes', 'talon-index', [job('i5', 'installation', 'created', [])], { acked: ['i5'], retried: [] });
  c.queue('installation suspend 200 (Design Q322): 1 becomes 0', 'talon-index', [job('i6', 'installation', 'suspend', [200])], { acked: ['i6'], retried: [] });
  c.queue('installation unsuspend 300: 0 becomes 1', 'talon-index', [job('i7', 'installation', 'unsuspend', [300])], { acked: ['i7'], retried: [] });
  c.queue('installation created 700 (a rename: acme/new active, acme/old moved): EVERY row of the repository id gets 1, also the moved row (Design Q324)', 'talon-index', [job('i8', 'installation', 'created', [700])], { acked: ['i8'], retried: [] });
  c.queue('installation_repositories removed 701 (two rows, both 1): both become 0', 'talon-index', [job('i9', 'installation_repositories', 'removed', [701])], { acked: ['i9'], retried: [] });
  const rows = [['acme/a', 100, 10, 0, null], ['acme/b', 101, 10, 0, null], ['acme/c', 200, 10, 0, null], ['acme/d', 300, 10, 0, null], ['acme/new', 700, 70, 0, null], ['acme/old', 700, 70, 2, 'acme/new'], ['acme/x', 701, 71, 0, null], ['acme/y', 701, 71, 2, 'acme/x']];
  const T = SEED_T + 3600000;
  const installed = { 'acme/a': 0, 'acme/b': 0, 'acme/c': 0, 'acme/d': 1, 'acme/new': 1, 'acme/old': 1, 'acme/x': 0, 'acme/y': 0 };
  c.db = dbOf([
    block(Q.repos, rows.map(([n, id, o, st, succ]) => [n, id, o, st, succ, SEED_T, SEED_T])),
    block(Q.events, rows.map(([n, id, o]) => seedEvent(n, id, o))),
    block(Q.checks, rows.map(([n]) => [n, null, null, T, 0, installed[n]])),
    block(Q.counts, [[8, 8, 8, 8, 0, 0, 0]]),
  ]);
  return c;
}

// ---- case 9: the dead letter queue (R-PU35): a log line for each message, acked ----
function dead() {
  const c = new Case('pu35-dead-letter', 'R-PU35 R-PU13 R-PU32');
  const m1 = msg('release', 'published', { repository_id: 100, release_id: 9001 });
  c.queue('the dead letter queue gets a message that failed 5 times, and one that is not a message: both acked, one error log line each (no name). Nothing is sent, no D1 row', 'talon-index-dlq', [{ id: 'd1', attempts: 1, body: m1 }, { id: 'd2', attempts: 1, body: { unexpected: true } }], { acked: ['d1', 'd2'], retried: [] });
  c.logs.push({ level: 'error', msg: 'index job dead', event: 'release', action: 'published', repository_id: 100, release_id: 9001 }, { level: 'error', msg: 'index job dead', readable: false });
  c.db = dbOf([block(Q.counts, [[0, 0, 0, 0, 0, 0, 0]])]);
  return c;
}

// ---- slice 118b: the job `release` (R-PU12, R-PU13, R-PU14, R-PU15, R-PU17, R-PU19, R-PU20, R-PU26, R-PU31, R-PU33; Design Q328, Q332 to Q335) ----
const PUB = '2026-10-20T12:00:00Z';
const PUB_MS = Date.parse(PUB);
const DAY = 86400000;
const HOUR = 3600000;
const mod = (n) => `${n} :: [].{\n\tx : U64\n\tx = 1\n}\n`;
// A made package: the note changes the bytes, so the hash. The made bundle has one module and the dep `extra`.
const EXTRA_H = 'C6Jtcve7FRNtkwgmuyRBJnZfJyTrfJWhDcLp6gk4w4Gz';
const pkg = (note) => zstd(tar([
  { path: 'main.roc', data: `## ${note}\npackage\n\t[\n\t\tAlpha,\n\t]\n\t{\n\t\textra: "https://example.com/pkgs/${EXTRA_H}.tar.zst",\n\t}\n` },
  { path: 'Alpha.roc', data: mod('Alpha') },
]));
const repoJson = (id, fullName, owner, visibility = 'public') => JSON.stringify({ id, node_id: 'R_x', name: fullName.split('/')[1], full_name: fullName, private: visibility !== 'public', owner: { login: fullName.split('/')[0], id: owner, type: 'Organization' }, description: null, visibility, default_branch: 'main' });
const releaseJson = (id, tag, { draft = false, prerelease = false, assets = [] } = {}) => JSON.stringify({ url: `https://api.github.com/repos/x/y/releases/${id}`, id, tag_name: tag, target_commitish: 'main', name: null, draft, prerelease, created_at: PUB, published_at: draft ? null : PUB, author: { login: 'someone', id: 5 }, assets: assets.map((n, k) => ({ id: k + 1, name: n, label: null, content_type: 'application/octet-stream', state: 'uploaded', size: 10, digest: null })), body: null });
const NOT_FOUND = '{"message":"Not Found"}';
const API = 'https://api.github.com';
const repoUrl = (id) => `${API}/repositories/${id}`;
const relUrl = (full, id) => `${API}/repos/${full}/releases/${id}`;
const tagUrl = (full, tag) => `${API}/repos/${full}/releases/tags/${tag}`;
const assetUrl = (full, tag, hash) => `https://github.com/${full}/releases/download/${tag}/${hash}.tar.zst`;
const rocVersionUrl = (full, tag) => `https://raw.githubusercontent.com/${full}/${tag}/.roc-version`;
const rjob = (id, action, repository_id, release_id, { attempts = 1, installation_id = 0 } = {}) => ({ id, attempts, body: msg('release', action, { installation_id, repository_id, release_id }) });
const formOf = (name) => `github.com/${name}/releases/download/{v}/`;
const ackAll = (ids) => ({ acked: ids, retried: [] });
const zeros = block(Q.counts, [[0, 0, 0, 0, 0, 0, 0]]);

// The GitHub of a repository and of a release: the repository by id, the release by id; with `full` the tag read, the asset and `.roc-version` when `asset` is given.
function gh(c, { id, full, owner, visibility = 'public' }) { c.file(repoUrl(id), repoJson(id, full, owner, visibility)); }
function ghRelease(c, { full, id, tag, draft = false, prerelease = false, assets = [], n = 0 }) { c.file(relUrl(full, id), releaseJson(id, tag, { draft, prerelease, assets: assets.map((h) => (h.includes('.') ? h : `${h}.tar.zst`)) }), null, n ? `.${n}` : ''); }

// ---- case 10: a new package, indexed by the job (R-PU12, R-PU13, R-PU15, R-PU26, Design Q328, Q335): the shared flow, the URL with the full name of GitHub, 5 GitHub reads, an installation, a row with 24 h ----
function releaseNew() {
  const c = new Case('pu13-index-new', 'R-PU11 R-PU12 R-PU13 R-PU15 R-PU26 R-PU31 R-PU22 R-TP5 R-TP13 R-SG8 R-IK3 R-RE9 R-RE14');
  const FULL = 'Acme/Lib';
  const NAME = 'acme/lib';
  const TAG = '1.0.0';
  const asset = pkg('slice 118b new package');
  const hash = rocHash(asset);
  gh(c, { id: 500, full: FULL, owner: 10 });
  ghRelease(c, { full: FULL, id: 9001, tag: TAG, assets: [hash] });
  c.file(tagUrl(FULL, TAG), releaseJson(9001, TAG, { assets: [`${hash}.tar.zst`] }));
  c.file(assetUrl(FULL, TAG, hash), asset);
  c.file(rocVersionUrl(FULL, TAG), 'Not Found', { status: 404 });
  c.queue('published, release 9001, repository 500, installation 55. The job reads the repository by id (public, full name Acme/Lib), the release by id, then the shared flow: the release by tag, the asset, .roc-version. The URL has the full name as GitHub gives it (Acme/Lib). Acked', 'talon-index', [rjob('m1', 'published', 500, 9001, { installation_id: 55 })], ackAll(['m1']));
  c.log.push(`GET ${repoUrl(500)}`, `GET ${relUrl(FULL, 9001)}`, `GET ${tagUrl(FULL, TAG)}`, `GET ${assetUrl(FULL, TAG, hash)}`, `GET ${rocVersionUrl(FULL, TAG)}`);
  const form = formOf(FULL);
  c.db = dbOf([
    // # R-PU14, R-RE2: one release, no withdrawn value
    block(Q.releases, [[1, NAME, TAG, null, null]]),
    block(Q.log, [[1, form, TAG, hash, NOW]]),
    // # R-PU15, R-RE9: one provenance row, via 1 (webhook), no claims, the clock
    block(Q.provenance, [[1, 1, null, NOW]]),
    // # R-TP5: the name is bound to the ids of the repository answer, the event bind (seq 1) has no claims
    block(Q.repos, [[NAME, 500, 10, 0, null, NOW, NOW]]),
    block(Q.events, [[NAME, 1, 0, null, 500, null, 10, null, null, NOW]]),
    // # R-PU26, Design Q335: installation 55: app_installed 1 and the interval of 24 h for the row that the job added
    block(Q.checks, [[NAME, null, null, NOW + DAY, 0, 1]]),
    block(Q.counts, [[1, 1, 1, 1, 1, 1, 1]]),
  ]);
  return c;
}

// ---- case 11: a release with no package asset (R-PU13, Design Q323): the retry with the delays, the asset on the 3rd read, the clock of the attempt ----
function releaseRetry() {
  const c = new Case('pu13-retry-no-asset', 'R-PU12 R-PU13 R-PU35 R-PU45 R-PU15 R-TP5');
  const FULL = 'acme/lib';
  const TAG = '1.0.0';
  const asset = pkg('slice 118b retried package');
  const hash = rocHash(asset);
  gh(c, { id: 500, full: FULL, owner: 10 });
  ghRelease(c, { full: FULL, id: 9001, tag: TAG, assets: [] });
  ghRelease(c, { full: FULL, id: 9001, tag: TAG, assets: [], n: 2 });
  ghRelease(c, { full: FULL, id: 9001, tag: TAG, assets: [hash], n: 3 });
  c.file(tagUrl(FULL, TAG), releaseJson(9001, TAG, { assets: [`${hash}.tar.zst`] }));
  c.file(assetUrl(FULL, TAG, hash), asset);
  c.file(rocVersionUrl(FULL, TAG), 'Not Found', { status: 404 });
  const T3 = NOW + 360000;
  c.queue('attempt 1: the release has no asset yet (the upload is slow). Not a fault, but a read again: retried after 60 s. Nothing is written', 'talon-index', [rjob('m1', 'published', 500, 9001)], { acked: [], retried: [{ id: 'm1', delay_s: 60 }] });
  c.queue('attempt 2 (1 min later): still no asset: retried after 300 s', 'talon-index', [rjob('m1', 'published', 500, 9001, { attempts: 2 })], { acked: [], retried: [{ id: 'm1', delay_s: 300 }] }, NOW + 60000);
  c.queue('attempt 3 (6 min after the event): the asset is there. The ingest runs with the clock of this attempt. Acked', 'talon-index', [rjob('m1', 'published', 500, 9001, { attempts: 3 })], ackAll(['m1']), T3);
  c.log.push(`GET ${repoUrl(500)}`, `GET ${relUrl(FULL, 9001)}`, `GET ${repoUrl(500)}`, `GET ${relUrl(FULL, 9001)}`, `GET ${repoUrl(500)}`, `GET ${relUrl(FULL, 9001)}`, `GET ${tagUrl(FULL, TAG)}`, `GET ${assetUrl(FULL, TAG, hash)}`, `GET ${rocVersionUrl(FULL, TAG)}`);
  c.db = dbOf([
    block(Q.releases, [[1, FULL, TAG, null, null]]),
    block(Q.log, [[1, formOf(FULL), TAG, hash, T3]]),
    block(Q.provenance, [[1, 1, null, T3]]),
    block(Q.repos, [[FULL, 500, 10, 0, null, T3, T3]]),
    // # installation_id 0 (no installation in the event): app_installed 0 and the interval of 1 h
    block(Q.checks, [[FULL, null, null, T3 + HOUR, 0, 0]]),
    block(Q.counts, [[1, 1, 1, 1, 1, 1, 1]]),
  ]);
  return c;
}

// ---- case 12: the end of the reads (Design Q334): attempt 4 retries after 60 min, attempt 5 with no asset is acked with an info line, attempt 5 with a fault is a retry with no delay ----
function releaseEnd() {
  const c = new Case('pu13-no-asset-end', 'R-PU13 R-PU45 R-PU35 R-PU12');
  const FULL = 'acme/lib';
  gh(c, { id: 500, full: FULL, owner: 10 });
  ghRelease(c, { full: FULL, id: 9001, tag: '1.0.0', assets: [] });
  ghRelease(c, { full: FULL, id: 9001, tag: '1.0.0', assets: [], n: 2 });
  c.file(relUrl(FULL, 9001), '{"message":"Server Error"}', { status: 500 }, '.3');
  c.queue('attempt 4, no asset: retried after 3600 s', 'talon-index', [rjob('m4', 'published', 500, 9001, { attempts: 4 })], { acked: [], retried: [{ id: 'm4', delay_s: 3600 }] });
  c.queue('attempt 5, no asset: NOT a fault (Design Q334). Acked, with the info line. The platform does not move it to the dead letter queue because it is acked', 'talon-index', [rjob('m5', 'published', 500, 9001, { attempts: 5 })], ackAll(['m5']));
  c.queue('attempt 5, GitHub answers 500 for the release: a fault. A retry with no delay (the platform moves it to the dead letter queue)', 'talon-index', [rjob('m6', 'published', 500, 9001, { attempts: 5 })], { acked: [], retried: [{ id: 'm6', delay_s: null }] });
  for (let i = 0; i < 3; i++) c.log.push(`GET ${repoUrl(500)}`, `GET ${relUrl(FULL, 9001)}`);
  c.logs.push({ level: 'info', msg: 'index job no asset', repository_id: 500, release_id: 9001 }, { level: 'warn', msg: 'index job failed', attempts: 5 });
  c.db = dbOf([zeros]);
  return c;
}

// ---- case 13: a release that is not a candidate, and one that is gone (R-PU13): no write, no retry ----
function releaseNot() {
  const c = new Case('pu13-not-candidate', 'R-PU13 R-PU12 R-PU6 R-DI4');
  const FULL = 'acme/lib';
  gh(c, { id: 500, full: FULL, owner: 10 });
  const [a, b] = [rocHash(pkg('slice 118b one')), rocHash(pkg('slice 118b two'))];
  ghRelease(c, { full: FULL, id: 9001, tag: '1.0.0', assets: [a, b, 'notes.txt'] });
  c.file(relUrl(FULL, 9002), NOT_FOUND, { status: 404 });
  c.queue('2 package assets: not a candidate (CLI 7.3, R-DI4). Acked, not read again, nothing written', 'talon-index', [rjob('m1', 'published', 500, 9001)], ackAll(['m1']));
  c.queue('the release is gone (404): the job stops. Acked, no retry', 'talon-index', [rjob('m2', 'published', 500, 9002)], ackAll(['m2']));
  c.queue('the same, on attempt 5', 'talon-index', [rjob('m3', 'edited', 500, 9002, { attempts: 5 })], ackAll(['m3']));
  c.log.push(`GET ${repoUrl(500)}`, `GET ${relUrl(FULL, 9001)}`, `GET ${repoUrl(500)}`, `GET ${relUrl(FULL, 9002)}`, `GET ${repoUrl(500)}`, `GET ${relUrl(FULL, 9002)}`);
  c.db = dbOf([zeros]);
  return c;
}

// ---- case 14: the labels (R-PU14, R-PU15, R-PU19, R-PU20, Design Q333): the same hash adds a provenance row only, a redelivery changes nothing, another hash writes no index, logs the conflict and withdraws the old asset ----
function releaseLabels() {
  const c = new Case('pu14-labels', 'R-PU14 R-PU15 R-PU19 R-PU20 R-PU13 R-PU12 R-RE9');
  const FULL = 'acme/lib';
  c.bound(FULL, { id: 500, owner: 10 });
  const h1 = c.indexed(FULL, '1.0.0', 1, 1, { via: 3 });
  c.indexed(FULL, '2.0.0', 2, 2, { via: 3 });
  const other = b58encode(Buffer.alloc(32, 9));
  gh(c, { id: 500, full: FULL, owner: 10 });
  ghRelease(c, { full: FULL, id: 9101, tag: '1.0.0', assets: [h1] });
  ghRelease(c, { full: FULL, id: 9102, tag: '2.0.0', assets: [other] });
  const T2 = NOW + 1000;
  c.queue('published 1.0.0 with the hash that the index has (indexed by an ingest, via 3): no artifact, release or log row; the job adds its provenance row (via 1). No read of the tag, the asset or .roc-version. Acked', 'talon-index', [rjob('m1', 'published', 500, 9101)], ackAll(['m1']));
  c.queue('the same event again (GitHub sends it again): the webhook row is there, nothing is written. Acked', 'talon-index', [rjob('m2', 'published', 500, 9101)], ackAll(['m2']), T2);
  c.queue('published 2.0.0 now shows another hash: 409 label-conflict in the other paths. The webhook path writes no index row and logs the conflict (Design Q333). R-PU20: the recorded asset of 2.0.0 is gone: withdrawn = asset-replaced with the clock. Acked, not retried', 'talon-index', [rjob('m3', 'published', 500, 9102)], ackAll(['m3']), T2);
  c.log.push(`GET ${repoUrl(500)}`, `GET ${relUrl(FULL, 9101)}`, `GET ${repoUrl(500)}`, `GET ${relUrl(FULL, 9101)}`, `GET ${repoUrl(500)}`, `GET ${relUrl(FULL, 9102)}`);
  c.logs.push({ level: 'warn', msg: 'index label conflict', repository_id: 500, release_id: 9102, group: formOf(FULL), version: '2.0.0' });
  c.db = dbOf([
    block(Q.releases, [[1, FULL, '1.0.0', null, null], [2, FULL, '2.0.0', 'asset-replaced', T2]]),
    block(Q.log, [[1, formOf(FULL), '1.0.0', b58encode(Buffer.alloc(32, 1)), SEED_T], [2, formOf(FULL), '2.0.0', b58encode(Buffer.alloc(32, 2)), SEED_T]]),
    block(Q.provenance, [[1, 1, null, NOW], [1, 3, null, SEED_T], [2, 3, null, SEED_T]]),
    block(Q.counts, [[1, 1, 1, 1, 2, 2, 3]]),
  ]);
  return c;
}

// ---- case 15: withdraw and clear (R-PU17, R-PU20, Design Q332): the state of the release on GitHub gives the value ----
function releaseWithdraw() {
  const c = new Case('pu17-withdraw-clear', 'R-PU17 R-PU20 R-PU13 R-PU12 R-RE2');
  const FULL = 'acme/lib';
  c.bound(FULL, { id: 500, owner: 10 });
  const hs = [1, 2, 3, 4, 5, 6, 7].map((k) => c.indexed(FULL, `${k}.0.0`, k, k, k === 4 ? { withdrawn: 'unpublished', at: SEED_T + 10 } : k === 5 ? { withdrawn: 'asset-replaced', at: SEED_T + 20 } : {}));
  gh(c, { id: 500, full: FULL, owner: 10 });
  const rel = (k, o) => ghRelease(c, { full: FULL, id: 9000 + k, tag: `${k}.0.0`, ...o });
  rel(1, { draft: true, assets: [hs[0]] });
  rel(2, { prerelease: true, assets: [hs[1]] });
  rel(3, { prerelease: true, assets: [hs[2]] });
  rel(4, { assets: [hs[3]] });
  rel(5, { assets: [hs[4], 'notes.txt'] });
  rel(6, { assets: [hs[5]] });
  rel(7, { assets: [] });
  const one = (k, action, comment, expect) => {
    c.queue(comment, 'talon-index', [rjob(`m${k}`, action, 500, 9000 + k)], expect);
    c.log.push(`GET ${repoUrl(500)}`, `GET ${relUrl(FULL, 9000 + k)}`);
  };
  one(1, 'unpublished', '1.0.0 is a draft again (unpublished): withdrawn = unpublished with the clock (R-PU17)', ackAll(['m1']));
  one(2, 'prereleased', '2.0.0 is a prerelease now (prereleased): withdrawn = prereleased', ackAll(['m2']));
  one(3, 'edited', '3.0.0 edited, and it is a prerelease now: withdrawn = edited (Design Q332)', ackAll(['m3']));
  one(4, 'published', '4.0.0 was withdrawn (unpublished) and is published again with the same asset: withdrawn and its time are cleared (R-PU17)', ackAll(['m4']));
  one(5, 'edited', '5.0.0 was asset-replaced and the asset is there again (edited): cleared (R-PU20)', ackAll(['m5']));
  one(6, 'edited', '6.0.0 edited, nothing wrong: no write (withdrawn stays NULL)', ackAll(['m6']));
  one(7, 'edited', '7.0.0 edited, and the release has no package asset now: the recorded asset is gone, withdrawn = asset-replaced (R-PU20); the release has no package asset, so the job reads again: retried after 60 s (R-PU13)', { acked: [], retried: [{ id: 'm7', delay_s: 60 }] });
  const L = formOf(FULL);
  c.db = dbOf([
    block(Q.releases, [
      [1, FULL, '1.0.0', 'unpublished', NOW],
      [2, FULL, '2.0.0', 'prereleased', NOW],
      [3, FULL, '3.0.0', 'edited', NOW],
      [4, FULL, '4.0.0', null, null],
      [5, FULL, '5.0.0', null, null],
      [6, FULL, '6.0.0', null, null],
      [7, FULL, '7.0.0', 'asset-replaced', NOW],
    ]),
    block(Q.provenance, [1, 2, 3, 4, 5, 6, 7].map((k) => [k, 1, null, SEED_T])),
    block(Q.counts, [[1, 1, 1, 1, 7, 7, 7]]),
  ]);
  void L;
  return c;
}

// ---- case 16: app_installed from a release job (Design Q335): all the rows of the repository, a moved row too; no installation in the message changes nothing; the interval stays ----
function releaseInstalled() {
  const c = new Case('pu26-release-installed', 'R-PU26 R-PU22 R-PU13 R-PU15 R-TP19 R-RE14');
  c.bound('acme/new', { id: 700, owner: 70 });
  c.bound('acme/old', { id: 700, owner: 70, state: 2, successor: 'acme/new' });
  c.bound('acme/other', { id: 701, owner: 71 });
  const h1 = c.indexed('acme/new', '1.0.0', 1, 1, { via: 3 });
  const h2 = c.indexed('acme/other', '1.0.0', 2, 2, { via: 3 });
  gh(c, { id: 700, full: 'acme/new', owner: 70 });
  gh(c, { id: 701, full: 'acme/other', owner: 71 });
  ghRelease(c, { full: 'acme/new', id: 9701, tag: '1.0.0', assets: [h1] });
  ghRelease(c, { full: 'acme/other', id: 9702, tag: '1.0.0', assets: [h2] });
  c.queue('published 700 with installation 55 (the same hash as the index: the provenance row is added): app_installed is 1 for BOTH rows of the repository (acme/new and the moved acme/old); next_check_at does not change', 'talon-index', [rjob('m1', 'published', 700, 9701, { installation_id: 55 })], ackAll(['m1']));
  c.queue('published 701 with no installation in the message (id 0): app_installed stays 0', 'talon-index', [rjob('m2', 'published', 701, 9702)], ackAll(['m2']));
  c.queue('the same event again for 701, now with installation 55 (nothing to write for the release): app_installed becomes 1', 'talon-index', [rjob('m3', 'published', 701, 9702, { installation_id: 55 })], ackAll(['m3']), NOW + 1000);
  c.log.push(`GET ${repoUrl(700)}`, `GET ${relUrl('acme/new', 9701)}`, `GET ${repoUrl(701)}`, `GET ${relUrl('acme/other', 9702)}`, `GET ${repoUrl(701)}`, `GET ${relUrl('acme/other', 9702)}`);
  c.db = dbOf([
    block(Q.provenance, [[1, 1, null, NOW], [1, 3, null, SEED_T], [2, 1, null, NOW], [2, 3, null, SEED_T]]),
    block(Q.checks, [['acme/new', null, null, SEED_T + HOUR, 0, 1], ['acme/old', null, null, SEED_T + HOUR, 0, 1], ['acme/other', null, null, SEED_T + HOUR, 0, 1]]),
    block(Q.counts, [[3, 3, 3, 3, 2, 2, 4]]),
  ]);
  return c;
}

// ---- case 17: a repository that is not public (R-PU31, R-PU32, R-PU33): no release read; a new name writes nothing; a known name gets R-PU33 ----
function releasePrivate() {
  const c = new Case('pu33-release-private', 'R-PU31 R-PU32 R-PU33 R-PU24 R-PU12 R-TP11 R-RE15');
  c.bound('acme/priv', { id: 601, owner: 61 });
  c.bound('acme/gone', { id: 602, owner: 62 });
  c.indexed('acme/priv', '1.0.0', 1, 1);
  c.indexed('acme/gone', '1.0.0', 2, 2);
  gh(c, { id: 600, full: 'acme/new', owner: 60, visibility: 'private' });
  gh(c, { id: 601, full: 'acme/priv', owner: 61, visibility: 'private' });
  c.file(repoUrl(602), NOT_FOUND, { status: 404 });
  c.queue('published 600: the repository is private and has no row (R-PU32): nothing is written, no release read, acked', 'talon-index', [rjob('m1', 'published', 600, 9601, { installation_id: 55 })], ackAll(['m1']));
  c.queue('published 601: private, a known name: R-PU33. The row is missing (event Missing, seq 2), its release gets repo-missing. No release read. Acked', 'talon-index', [rjob('m2', 'published', 601, 9602, { installation_id: 55 })], ackAll(['m2']));
  c.queue('published 602: GitHub answers 404 for the repository (deleted, or private and not readable): the same as private for a known name', 'talon-index', [rjob('m3', 'edited', 602, 9603)], ackAll(['m3']));
  c.log.push(`GET ${repoUrl(600)}`, `GET ${repoUrl(601)}`, `GET ${repoUrl(602)}`);
  const E = (name, seq, id, owner) => [name, seq, 4, id, id, owner, owner, null, null, NOW];
  c.db = dbOf([
    block(Q.repos, [['acme/gone', 602, 62, 1, null, NOW, SEED_T], ['acme/priv', 601, 61, 1, null, NOW, SEED_T]]),
    block(Q.events, [seedEvent('acme/gone', 602, 62), E('acme/gone', 2, 602, 62), seedEvent('acme/priv', 601, 61), E('acme/priv', 2, 601, 61)]),
    block(Q.checks, [['acme/gone', null, null, SEED_T + HOUR, 0, 0], ['acme/priv', null, null, SEED_T + HOUR, 0, 0]]),
    block(Q.releases, [[1, 'acme/priv', '1.0.0', 'repo-missing', NOW], [2, 'acme/gone', '1.0.0', 'repo-missing', NOW]]),
    block(Q.counts, [[2, 2, 2, 4, 2, 2, 2]]),
  ]);
  return c;
}

const cases = [
  signature(),
  noSecret('ap12-no-secret', {}, 'the secret GITHUB_WEBHOOK_SECRET is not set'),
  noSecret('ap12-empty-secret', { GITHUB_WEBHOOK_SECRET: '' }, 'the secret is the empty text'),
  events(),
  privatized(),
  retrySchedule(),
  publicized(),
  appInstalled(),
  dead(),
  releaseNew(),
  releaseRetry(),
  releaseEnd(),
  releaseNot(),
  releaseLabels(),
  releaseWithdraw(),
  releaseInstalled(),
  releasePrivate(),
];
for (const c of cases) c.write();
console.log(`wrote ${cases.length} cases in ${casesDir}`);
