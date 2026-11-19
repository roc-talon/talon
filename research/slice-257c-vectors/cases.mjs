// Slice 257c: the W2 cases of the tile step after a write (worker/tests/cases/logafter/), made with node:crypto only (not with the code under test).
// The formats, the throwaway test key and the R2 objects are those of research/slice-257b-vectors/cases.mjs (the functions are copied here, so that file and its cases do not change).
// Each case is an OLD case of another slice (the "base": its requests, its fake GitHub, its tokens, its seed, its expected answers, D1 rows, GitHub log) with:
//   - the setting LOG_KEY (and the fault settings of the case),
//   - on each line "r2_puts" (the step: the tiles of the growth, then the checkpoint) or "r2_reads": [] (no step: no R2 call at all),
//   - expect/r2.jsonl: the R2 objects after the last line,
//   - expect/logs.jsonl: the log lines of the steps (added to the lines of the base), expect/logs-not: texts that no Worker log line may have.
// The D1 call counts (expect/d1-calls) are the counts of the base: the step is after the answer, so its D1 call is not a D1 call of the request (R-AP41).
// The leaves (grp, version, hash, time) come from the block `@ SELECT idx, grp, version, hash, time FROM log ORDER BY idx` of expect/db.tsv of the base: a fixture of the old slice.
// Usage (repo root): node research/slice-257c-vectors/cases.mjs   (each case dir is made again; do not edit the case dirs by hand)
import { createHash, createPrivateKey, createPublicKey, sign, verify } from 'node:crypto';
import { cpSync, existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = join(HERE, '..', '..');
const CASES_ROOT = join(ROOT, 'worker', 'tests', 'cases');
const OUT = join(CASES_ROOT, 'logafter');
const sha = (...b) => createHash('sha256').update(Buffer.concat(b.map((x) => Buffer.from(x)))).digest();
const hex = (b) => Buffer.from(b).toString('hex');
const b64 = (b) => Buffer.from(b).toString('base64');
const leafHash = (e) => sha([0], e);
const nodeHash = (l, r) => sha([1], l, r);
function mth(hs) {
  if (hs.length === 0) return sha([]);
  if (hs.length === 1) return hs[0];
  let k = 1;
  while (k * 2 < hs.length) k *= 2;
  return nodeHash(mth(hs.slice(0, k)), mth(hs.slice(k)));
}
function nPath(n) {
  let s = String(n);
  while (s.length % 3) s = '0' + s;
  const g = s.match(/.../g);
  return g.map((x, i) => (i < g.length - 1 ? 'x' + x : x)).join('/');
}
const pathOf = (t) => (t.level === 'E' ? 'tile/entries/' : `tile/${t.level}/`) + nPath(t.index) + (t.width === 256 ? '' : `.p/${t.width}`);
function tilesOf(s) {
  const out = [];
  const add = (level, count) => {
    for (let n = 0; n < Math.floor(count / 256); n++) out.push({ level, index: n, width: 256 });
    if (count % 256) out.push({ level, index: Math.floor(count / 256), width: count % 256 });
  };
  add('E', s);
  for (let L = 0, c = s; c > 0; L++, c = Math.floor(c / 256)) add(L, c);
  return out;
}
const growth = (S, N) => {
  const old = new Set(tilesOf(S).map(pathOf));
  return tilesOf(N).filter((t) => !old.has(pathOf(t)));
};
const bundle = (es) => Buffer.concat(es.flatMap((e) => { const p = Buffer.alloc(2); p.writeUInt16BE(e.length); return [p, e]; }));
function tileBytes(t, entries) {
  const hashes = entries.map(leafHash);
  if (t.level === 'E') return bundle(entries.slice(t.index * 256, t.index * 256 + t.width));
  const span = 256 ** t.level;
  const out = [];
  for (let k = t.index * 256; k < t.index * 256 + t.width; k++) out.push(mth(hashes.slice(k * span, (k + 1) * span)));
  return Buffer.concat(out);
}

// The key of 257a and 257b (a seed from a fixed text; it signs nothing outside the tests).
const PKCS8_PREFIX = Buffer.from('302e020100300506032b657004220420', 'hex');
const ORIGIN = 'registry.roc-talon.org/log';
const seed = sha(Buffer.from('talon slice 257a throwaway test key, never used outside the tests'));
const priv = createPrivateKey({ key: Buffer.concat([PKCS8_PREFIX, seed]), format: 'der', type: 'pkcs8' });
const pub = Buffer.from(priv.export({ format: 'jwk' }).x, 'base64url');
const id = sha(Buffer.from(ORIGIN, 'utf8'), [0x0a, 0x01], pub).subarray(0, 4);
const LOG_KEY = `PRIVATE+KEY+${ORIGIN}+${hex(id)}+${b64(Buffer.concat([Buffer.from([1]), seed]))}`;
if (LOG_KEY !== 'PRIVATE+KEY+registry.roc-talon.org/log+ef85463f+AbN3kDu1rU6Ae40mYF0tNdIAM2JAE1z1OV3ZGBWh44Zk') throw new Error('not the key of 257b');
const checkpointOf = (size, root) => {
  const body = `${ORIGIN}\n${size}\n${b64(root)}\n`;
  const sig = sign(null, Buffer.from(body), priv);
  if (!verify(null, Buffer.from(body), createPublicKey(priv), sig)) throw new Error('signature');
  return `${body}\n— ${ORIGIN} ${b64(Buffer.concat([id, sig]))}\n`;
};
const CT_TILE = 'application/octet-stream';
const CT_CK = 'text/plain; charset=utf-8';

// The leaves of a base: the log block of its expect/db.tsv (R-SG2: `<grp> <version> <hash> <time>\n`, tlog index idx - 1).
function leavesOf(base) {
  const tsv = readFileSync(join(CASES_ROOT, base, 'expect', 'db.tsv'), 'utf8').split('\n');
  const i = tsv.indexOf('@ SELECT idx, grp, version, hash, time FROM log ORDER BY idx');
  if (i < 0) throw new Error(`${base}: no log block in expect/db.tsv`);
  const out = [];
  for (const line of tsv.slice(i + 1)) {
    if (line.startsWith('@') || line === '') break;
    const [idx, grp, version, hash, time] = line.split('\t');
    if (Number(idx) !== out.length + 1) throw new Error(`${base}: idx ${idx} is not ${out.length + 1}`);
    out.push(Buffer.from(`${grp} ${version} ${hash} ${time}\n`, 'utf8'));
  }
  return out;
}
// The R2 objects of the size N (every tile of a tree of N leaves, and its checkpoint), and of the tiles only.
const tileObjs = (ts, entries) => ts.map((t) => ({ key: pathOf(t), bytes: tileBytes(t, entries), ct: CT_TILE }));
const ckObj = (n, entries) => { const text = checkpointOf(n, mth(entries.slice(0, n).map(leafHash))); return { key: 'checkpoint', bytes: Buffer.from(text, 'utf8'), ct: CT_CK, text }; };
const stateOf = (n, entries) => (n === 0 ? [] : [...tileObjs(tilesOf(n), entries), ckObj(n, entries)]);
const merge = (...lists) => { const m = new Map(); for (const l of lists) for (const o of l) m.set(o.key, o); return [...m.values()]; };
const expectLine = (o) => JSON.stringify({ key: o.key, sha256: hex(sha(o.bytes)), size: o.bytes.length, content_type: o.ct, ...(o.text !== undefined ? { text: o.text } : {}) });

const NOW = 1767225600000;
const CRON = { cron: '2-59/5 * * * *', time: NOW, now: NOW };
const ERR_LOG = { level: 'error', msg: 'log step failed' };
const wrote = (from, size) => ({ level: 'info', msg: 'log wrote', from, size, tiles: growth(from, size).length });
// The line checks: a step from S to N (the checkpoint before it: absent for S = 0, else the etag), or no step.
const step = (S, N) => ({ r2_puts: [growth(S, N).map(pathOf), [S === 0 ? 'checkpoint?absent' : 'checkpoint?etag']] });
const none = { r2_reads: [], r2_puts: [] };
const AFTER_FAILED = 'after respond'; // the platform line of a work after the answer that gives Err (cloudflare-workers/API.md 10.2): R-SG7 wants only the log line

const lines = (f) => (existsSync(f) ? readFileSync(f, 'utf8').split('\n').filter((l) => l.trim() !== '') : []);
const cases = [];
const add = (c) => cases.push(c);

// c: { name, base, rules, notes, settings (added to the settings of the base), checks: one object for each line of the base (added to its expected line),
//      extra: [[request, expected, d1]] lines after the base lines, final: the R2 objects at the end, logs: added log lines, logsNot: texts }
const KEY = { LOG_KEY };

{
  const e = leavesOf('publish/pu1-publish-package');
  add({ name: 'pu1-publish-step', base: 'publish/pu1-publish-package', rules: ['R-SG7', 'R-PU1', 'R-AP41', 'R-SG4'],
    notes: 'R-PU1, R-SG7 (Design Q636 (8)): the publish that adds the leaf (line 2, 201) runs the step after its answer: the 2 partial tiles of size 1, then the checkpoint (R2.absent). The D1 calls of each line are those of slice 114: the D1 call of the step is after the answer (R-AP41). The reads (lines 1, 3) and the publishes of the indexed label (lines 4 to 6, 200: compat facts, nothing new) make no R2 call.',
    settings: KEY, checks: [none, step(0, 1), none, none, none, none], final: stateOf(1, e), logs: [wrote(0, 1)], logsNot: [AFTER_FAILED] });
}
{
  const e = leavesOf('ingest/pu4-index-kinds');
  add({ name: 'pu1-ingest-steps', base: 'ingest/pu4-index-kinds', rules: ['R-SG7', 'R-PU1', 'R-AP41', 'R-SG4'],
    notes: 'R-SG7 (Design Q636 (8)): each ingest that adds a leaf (lines 1 to 3, 201) runs one step after its answer: 0 to 1 (R2.absent), 1 to 2 and 2 to 3 (the etag of the checkpoint before). The ingest of the indexed label (line 4, 200) and the reads make no R2 call. D1 calls as slice 112.',
    settings: KEY, checks: [step(0, 1), step(1, 2), step(2, 3), none, none, none], final: merge(stateOf(1, e), stateOf(2, e), stateOf(3, e)), logs: [wrote(0, 1), wrote(1, 2), wrote(2, 3)], logsNot: [AFTER_FAILED] });
}
{
  const e = leavesOf('publish/pu15-ingest-then-publish');
  add({ name: 'pu1-ingest-then-publish', base: 'publish/pu15-ingest-then-publish', rules: ['R-SG7', 'R-PU1', 'R-AP41'],
    notes: 'R-SG7: the ingest (line 1, 201) adds the leaf and runs the step. The publish of the same label (line 3) and the second publish (line 8) WRITE (a provenance row, R-PU16) but add no leaf (200): no step, no R2 call. The ingest again (line 5, 200) and the reads: no R2 call.',
    settings: KEY, checks: [step(0, 1), none, none, none, none, none, none, none], final: stateOf(1, e), logs: [wrote(0, 1)], logsNot: [AFTER_FAILED] });
}
add({ name: 'pu1-refusals-no-step', base: 'publish/pu16-after-ingest', rules: ['R-SG7', 'R-AP48'],
  notes: 'R-SG7: no line adds a leaf by its own batch: 200 (a provenance or compat write), 409, 403, 422. No line makes an R2 call. Line 8 is a 409: "another request" (the github .sql hook) wrote the leaf idx 2 between the D1 calls; the answer of this request is not 201, so this request runs no step (the catch-up cron does it). D1 has 2 leaves from P2 and no tile: R2 stays empty.',
  settings: KEY, checks: [none, none, none, none, none, none, none, none], final: [], logsNot: [AFTER_FAILED] });
add({ name: 'pu1-ingest-refused-no-step', base: 'ingest/ap26-body-and-route', rules: ['R-SG7', 'R-AP48'],
  notes: 'R-SG7: 401, 400, 405, 415, 422 answers of the ingest route add no leaf: no R2 call (0 D1 calls as before).',
  settings: KEY, checks: Array(12).fill(none), final: [] });
{
  const e = leavesOf('toolchains/pu-new-tag');
  add({ name: 'pu1-toolchains-step', base: 'toolchains/pu-new-tag', rules: ['R-SG7', 'R-SG3', 'R-AP41'],
    notes: 'R-SG7 (Design Q636): `PUT /v1/toolchains/{tag}` that adds the 5 compiler leaves (201) runs one step after its answer: 0 to 5. The PUT again (200, the tag has rows) makes no R2 call. The leaf texts are the compiler leaves of R-SG3. D1 calls as slice 109.',
    settings: KEY, checks: [step(0, 5), none], final: stateOf(5, e), logs: [wrote(0, 5)], logsNot: [AFTER_FAILED] });
}
{
  const e = leavesOf('webhook/pu13-index-new');
  add({ name: 'pu13-queue-step', base: 'webhook/pu13-index-new', rules: ['R-SG7', 'R-PU13', 'R-AP41'],
    notes: 'R-SG7 (Design Q636): the index queue job that adds a leaf runs the step at the end of the job: 0 to 1. The acks do not change.',
    settings: KEY, checks: [step(0, 1)], final: stateOf(1, e), logs: [wrote(0, 1)] });
}
{
  const e = leavesOf('reconcile/pu21-poll-job');
  add({ name: 'pu21-poll-step', base: 'reconcile/pu21-poll-job', rules: ['R-SG7', 'R-PU21', 'R-PU14'],
    notes: 'R-SG7: the poll job (the queue job that the reconcile sends) of the indexed label adds only a provenance row (m1) or nothing (m2): no step, no R2 call. m3 adds the leaf idx 2: one step at the end of the job. D1 has the leaf idx 1 from P2 with no tile, so the step writes from size 0 to 2 (Design Q636 (11): the old leaves need no other backfill).',
    settings: KEY, checks: [none, none, step(0, 2)], final: stateOf(2, e), logs: [wrote(0, 2)] });
}
add({ name: 'pu14-queue-no-leaf', base: 'webhook/pu14-labels', rules: ['R-SG7', 'R-PU14', 'R-PU20'],
  notes: 'R-SG7: index queue jobs that write but add no leaf (a provenance row; nothing; a label conflict and a withdrawn value): no step, no R2 call.',
  settings: KEY, checks: [none, none, none], final: [] });
add({ name: 'pu23-reconcile-no-step', base: 'reconcile/pu23-list', rules: ['R-SG7', 'R-PU23'],
  notes: 'Q257-24 (recommendation, open): the reconcile run adds no leaf itself (a candidate goes to the queue as a poll message; the poll job runs the step, case pu21-poll-step), so the run makes no step and no R2 call, also with 14 leaves in D1 and no checkpoint. The tile catch-up is its own cron (257b).',
  settings: KEY, checks: [none, none], final: [] });
add({ name: 'ap12-webhook-no-step', base: 'webhook/pu11-events', rules: ['R-SG7', 'R-AP12'],
  notes: 'R-SG7: the webhook route (202) only sends a queue message; it adds no leaf: no step, no R2 call.',
  settings: KEY, checks: Array(lines(join(CASES_ROOT, 'webhook/pu11-events/requests.jsonl')).length).fill(none), final: [] });

// Faults after the answer (R-SG7, Design Q636 (17)): the answer does not change, one log line, the next trigger or the catch-up cron repairs.
{
  const e = leavesOf('publish/pu1-publish-package');
  const tiles1 = tileObjs(growth(0, 1), e);
  const c2 = { ...step(0, 1), r2: Object.fromEntries([['checkpoint', null], ...tiles1.map((o) => [o.key, { sha256: hex(sha(o.bytes)) }])]) };
  add({ name: 'sg7-after-fault-repair', base: 'publish/pu1-publish-package', rules: ['R-SG7', 'R-PU1', 'R-PU35'],
    notes: 'R-SG7 row 5, Design Q636 (17): the checkpoint put of the step after the publish fails (TEST_LOG_FAIL_PUTS). The answer is the 201 of slice 114 (status, headers, body, D1 calls): a failed R2 write does not change the answer. One log line `log step failed`, and no platform line `after respond: failed`. The tiles are there, no checkpoint. The repeats (200) run no step. Then the catch-up cron writes the checkpoint of 1.',
    settings: { LOG_KEY, TEST_LOG_FAIL_PUTS: JSON.stringify(['checkpoint']) }, checks: [none, c2, none, none, none, none],
    extra: [[CRON, { status: 200, json: { outcome: 'ok' }, ...step(0, 1) }, 1]], final: stateOf(1, e), logs: [ERR_LOG, wrote(0, 1)], logsNot: [AFTER_FAILED] });
}
{
  // The text of the key with the key id of another key (as wh14-log-key-wrong-id of 257b): the step fails at the key check, before any R2 call.
  const seed2 = sha(Buffer.from('talon slice 257b second throwaway test key, never used outside the tests'));
  const pub2 = Buffer.from(createPrivateKey({ key: Buffer.concat([PKCS8_PREFIX, seed2]), format: 'der', type: 'pkcs8' }).export({ format: 'jwk' }).x, 'base64url');
  const id2 = sha(Buffer.from(ORIGIN, 'utf8'), [0x0a, 0x01], pub2).subarray(0, 4);
  const wrongId = `PRIVATE+KEY+${ORIGIN}+${hex(id2)}+${b64(Buffer.concat([Buffer.from([1]), seed]))}`;
  add({ name: 'sg7-after-fault-key', base: 'ingest/pu4-index-kinds', rules: ['R-SG7', 'R-WH14'],
    notes: 'R-WH14, R-SG7, Design Q636 (17): LOG_KEY has a wrong key id. Each of the 3 ingests that add a leaf gives its 201 of slice 112 (the answer does not change: not a 500), and its step writes one line `log step failed` and makes no R2 call. No platform line `after respond: failed`.',
    settings: { LOG_KEY: wrongId }, checks: [none, none, none, none, none, none], final: [], logs: [ERR_LOG, ERR_LOG, ERR_LOG], logsNot: [AFTER_FAILED] });
}
{
  const e = leavesOf('ingest/pu4-index-kinds');
  add({ name: 'sg7-after-fault-read', base: 'ingest/pu4-index-kinds', rules: ['R-SG7', 'R-PU1'],
    notes: 'R-SG7 row 5: the checkpoint read of the step after ingest 1 fails (TEST_LOG_FAIL_GETS): the 201 does not change, one line `log step failed`, no put. The step after ingest 2 writes from size 0 to 2 (the work that was due), the step after ingest 3 from 2 to 3.',
    settings: { LOG_KEY, TEST_LOG_FAIL_GETS: JSON.stringify(['checkpoint']) }, checks: [{ r2_reads: ['checkpoint'], r2_puts: [] }, step(0, 2), step(2, 3), none, none, none],
    final: merge(stateOf(2, e), stateOf(3, e)), logs: [ERR_LOG, wrote(0, 2), wrote(2, 3)], logsNot: [AFTER_FAILED] });
}
{
  const e = leavesOf('webhook/pu13-index-new');
  add({ name: 'sg7-queue-fault', base: 'webhook/pu13-index-new', rules: ['R-SG7', 'R-PU13', 'R-PU35'],
    notes: 'R-SG7, Q257-23 (recommendation, open): a tile put of the step at the end of the queue job fails (TEST_LOG_FAIL_PUTS). The message is still acked (not retried: the leaf is in D1), the batch outcome is ok, one line `log step failed`, no line `index job failed`, no checkpoint. The catch-up cron then writes the size 1.',
    settings: { LOG_KEY, TEST_LOG_FAIL_PUTS: JSON.stringify(['tile/entries/000.p/1']) }, checks: [{ r2: { checkpoint: null, 'tile/entries/000.p/1': null } }],
    extra: [[CRON, { status: 200, json: { outcome: 'ok' }, ...step(0, 1) }, 1]], final: stateOf(1, e), logs: [ERR_LOG, wrote(0, 1)], logsNot: ['index job failed'] });
}

rmSync(OUT, { recursive: true, force: true });
for (const c of cases) {
  const src = join(CASES_ROOT, c.base);
  const d = join(OUT, c.name);
  cpSync(src, d, { recursive: true });
  const specs = lines(join(src, 'requests.jsonl'));
  const nreq = specs.filter((l) => { const s = JSON.parse(l); return s.sql === undefined && s.wait_ms === undefined && s.window_s === undefined && s.r2_seed === undefined; }).length;
  const exp = lines(join(src, 'expect', 'responses.jsonl')).map((l) => JSON.parse(l));
  if (exp.length !== nreq || c.checks.length !== nreq) throw new Error(`${c.name}: ${nreq} requests, ${exp.length} expected lines, ${c.checks.length} checks`);
  const extra = c.extra ?? [];
  writeFileSync(join(d, 'rules'), c.rules.join('\n') + '\n');
  writeFileSync(join(d, 'notes.txt'), `${c.notes}\nBase: worker/tests/cases/${c.base} (its requests, fixtures and expected answers, as they are). Generated by research/slice-257c-vectors/cases.mjs (node:crypto, not the code under test). Do not edit: change the generator.\n`);
  const settings = { ...JSON.parse(existsSync(join(src, 'settings.json')) ? readFileSync(join(src, 'settings.json'), 'utf8') : '{}'), ...c.settings };
  writeFileSync(join(d, 'settings.json'), JSON.stringify(settings) + '\n');
  writeFileSync(join(d, 'requests.jsonl'), [...specs, ...extra.map(([r]) => JSON.stringify(r))].join('\n') + '\n');
  writeFileSync(join(d, 'expect', 'responses.jsonl'), [...exp.map((x, i) => JSON.stringify({ ...x, ...c.checks[i] })), ...extra.map(([, x]) => JSON.stringify(x))].join('\n') + '\n');
  const d1 = lines(join(src, 'expect', 'd1-calls'));
  if (d1.length || extra.length) writeFileSync(join(d, 'expect', 'd1-calls'), [...(d1.length ? d1 : Array(nreq).fill('-')), ...extra.map(([, , n]) => String(n))].join('\n') + '\n');
  writeFileSync(join(d, 'expect', 'r2.jsonl'), c.final.map(expectLine).join('\n') + (c.final.length ? '\n' : ''));
  const logs = [...lines(join(src, 'expect', 'logs.jsonl')), ...(c.logs ?? []).map((l) => JSON.stringify(l))];
  if (logs.length) writeFileSync(join(d, 'expect', 'logs.jsonl'), logs.join('\n') + '\n');
  if (c.logsNot?.length) writeFileSync(join(d, 'expect', 'logs-not'), c.logsNot.join('\n') + '\n');
}
console.log(`wrote ${cases.length} cases under ${OUT}`);
