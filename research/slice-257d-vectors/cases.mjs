// Slice 257d: the W2 cases of the log read routes (worker/tests/cases/logread/), made with node:crypto only. The bytes of a tile are opaque to the read route (it does not check them),
// so the seeds are pseudo bytes (SHA-256 of a seed text and a counter): the expected size, SHA-256 and ETag (R2: the quoted MD5 of the bytes, probe research/slice-257d-vectors/probe-etag.mjs)
// come from this script, never from the code under test. The two checkpoint texts are the signed checkpoints of size 3 and size 7 that research/slice-257b-vectors/cases.mjs made
// (read from its case files: the same bytes as the writer of 257b makes).
// Usage (repo root): node research/slice-257d-vectors/cases.mjs   (writes the case dirs again; do not edit them by hand)
import { createHash } from 'node:crypto';
import { mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = join(HERE, '..', '..');
const CASES = join(ROOT, 'worker', 'tests', 'cases', 'logread');
const md5 = (b) => createHash('md5').update(b).digest('hex');
const sha256 = (b) => createHash('sha256').update(b).digest('hex');
const etag = (b) => `"${md5(b)}"`;

// Pseudo bytes of a given length.
function bytes(seed, n) {
  const out = [];
  for (let i = 0; out.reduce((a, b) => a + b.length, 0) < n; i++) out.push(createHash('sha256').update(`${seed}/${i}`).digest());
  return Buffer.concat(out).subarray(0, n);
}
const OCTET = 'application/octet-stream';
const TEXT = 'text/plain; charset=utf-8';
const obj = (key, buf, content_type = OCTET) => ({ key, buf, content_type });
const checkpointOf = (case_, size) => {
  const line = readFileSync(join(ROOT, 'worker/tests/cases/log', case_, 'expect', 'r2.jsonl'), 'utf8').split('\n').filter(Boolean).map((l) => JSON.parse(l)).find((o) => o.key === 'checkpoint');
  if (!line.text.split('\n')[1] === String(size)) throw new Error('checkpoint size');
  return Buffer.from(line.text, 'utf8');
};
const CP3 = checkpointOf('sg7-first-step', 3);
const CP7 = checkpointOf('sg7-growth-in-tile', 7);

// The objects.
const TILE_A = obj('tile/0/x001/234', bytes('tile-a', 8192));
const TILE_L1 = obj('tile/1/000', bytes('tile-l1', 8192));
const TILE_DEEP = obj('tile/2/x001/x234/067', bytes('tile-deep', 8192));
const TILE_P7 = obj('tile/0/000.p/7', bytes('tile-p7', 224));
const TILE_F0 = obj('tile/0/000', bytes('tile-f0', 8192));
const TILE_L1P1 = obj('tile/1/000.p/1', bytes('tile-l1p1', 32));
const TILE_P255 = obj('tile/0/x001/234.p/255', bytes('tile-p255', 255 * 32));
const ENT_FULL = obj('tile/entries/000', bytes('ent-full', 5000));
const ENT_P3 = obj('tile/entries/000.p/3', bytes('ent-p3', 327));
const ENT_P255 = obj('tile/entries/x001/234.p/255', bytes('ent-p255', 4000));
const CHECKPOINT3 = obj('checkpoint', CP3, TEXT);
const CHECKPOINT7 = obj('checkpoint', CP7, TEXT);

const r2Line = (o) => JSON.stringify({ key: o.key, base64: o.buf.toString('base64'), content_type: o.content_type });
const GET = (path, headers) => ({ method: 'GET', path: `/log/${path}`, ...(headers ? { headers } : {}) });
const req = (method, path, headers, extra) => ({ method, path, ...(headers ? { headers } : {}), ...(extra ?? {}) });
// An expected 200 of an object: the headers, the size and the SHA-256 of the body (or the text for the checkpoint).
const ok = (o, extra = {}) => {
  const cache = o.key === 'checkpoint' ? 'max-age=5' : 'max-age=31536000, immutable';
  const exp = { status: 200, headers: { 'content-type': o.content_type, 'cache-control': cache, etag: etag(o.buf) }, body_size: o.buf.length, body_sha256: sha256(o.buf), ...extra };
  if (o.key === 'checkpoint') exp.body = o.buf.toString('utf8');
  return exp;
};
const notModified = (o, extra = {}) => ({ status: 304, headers: { etag: etag(o.buf), 'cache-control': o.key === 'checkpoint' ? 'max-age=5' : 'max-age=31536000, immutable' }, body: '', ...extra });
const missing = (extra = {}) => ({ status: 404, problem: { type: '/errors/not-found', status: 404 }, ...extra });
const head200 = (o, extra = {}) => ({ ...ok(o, extra), body: '', body_size: undefined, body_sha256: undefined });
const seedLine = (...os) => ({ r2_seed: os.map((o) => ({ key: o.key, base64: o.buf.toString('base64'), content_type: o.content_type })) });

const cases = [];
const add = (name, rules, notes, o) => cases.push({ name, rules, notes, ...o });

add('ap11-checkpoint', ['R-AP11', 'R-AP23', 'R-AP24', 'R-AP41'],
  'A seeded checkpoint: GET gives 200, the stored content type (text/plain; charset=utf-8), max-age=5, the ETag of R2 (the quoted MD5 of the bytes), the exact text; one R2 read; no D1 call.',
  { seed: [CHECKPOINT3, TILE_P7], lines: [[GET('checkpoint'), ok(CHECKPOINT3, { r2_reads: ['checkpoint'] })]] });

add('ap11-checkpoint-absent', ['R-AP11', 'R-AP21', 'R-AP43'],
  'No checkpoint before the first leaf (Q257-16, Design Q636): 404 not-found (a problem), also when other objects exist; no 404 is kept, so a checkpoint that appears later is served at once.',
  { seed: [TILE_P7], lines: [
    [GET('checkpoint'), missing({ r2_reads: ['checkpoint'] })],
    [GET('checkpoint'), missing({ r2_reads: ['checkpoint'] })],
    [seedLine(CHECKPOINT3)],
    [GET('checkpoint'), ok(CHECKPOINT3, { r2_reads: ['checkpoint'] })],
  ] });

add('ap11-tile-full', ['R-AP11', 'R-AP23', 'R-AP24', 'R-SG4'],
  'Full hash tiles (level 0, 1, and a 3-group index): 200, application/octet-stream, max-age=31536000 immutable, the ETag of R2, the bytes (size and SHA-256), one R2 read at the key = the path after /log/.',
  { seed: [TILE_A, TILE_L1, TILE_DEEP, TILE_P7], lines: [
    [GET(TILE_A.key), ok(TILE_A, { r2_reads: [TILE_A.key] })],
    [GET(TILE_L1.key), ok(TILE_L1, { r2_reads: [TILE_L1.key] })],
    [GET(TILE_DEEP.key), ok(TILE_DEEP, { r2_reads: [TILE_DEEP.key] })],
  ] });

add('ap11-tile-partial', ['R-AP11', 'R-AP23', 'R-SG4'],
  'Partial tiles have the same headers as full tiles (R-AP11: also partial tiles are immutable). The path with .p/W reads the key with .p/W, never the full tile of the same index.',
  { seed: [TILE_P7, TILE_F0, TILE_L1P1, TILE_P255], lines: [
    [GET(TILE_P7.key), ok(TILE_P7, { r2_reads: [TILE_P7.key] })],
    [GET(TILE_F0.key), ok(TILE_F0, { r2_reads: [TILE_F0.key] })],
    [GET(TILE_L1P1.key), ok(TILE_L1P1, { r2_reads: [TILE_L1P1.key] })],
    [GET(TILE_P255.key), ok(TILE_P255, { r2_reads: [TILE_P255.key] })],
  ] });

add('ap11-entry-bundle', ['R-AP11', 'R-AP23', 'R-SG4'],
  'Entry bundles, full and partial: the same headers as a hash tile (application/octet-stream, immutable), the bytes as stored.',
  { seed: [ENT_FULL, ENT_P3, ENT_P255, TILE_F0], lines: [
    [GET(ENT_FULL.key), ok(ENT_FULL, { r2_reads: [ENT_FULL.key] })],
    [GET(ENT_P3.key), ok(ENT_P3, { r2_reads: [ENT_P3.key] })],
    [GET(ENT_P255.key), ok(ENT_P255, { r2_reads: [ENT_P255.key] })],
  ] });

add('ap11-tile-missing', ['R-AP11', 'R-AP21', 'R-AP43'],
  'A tile that is not in R2: 404 not-found (a problem). A 404 is not kept in the Cache API: after the tile is written, the next read gives 200 (the immutable header must never go with a 404).',
  { seed: [TILE_P7], lines: [
    [GET(TILE_F0.key), missing({ r2_reads: [TILE_F0.key] })],
    [GET('tile/0/000.p/8'), missing({ r2_reads: ['tile/0/000.p/8'] })],
    [GET(TILE_F0.key), missing({ r2_reads: [TILE_F0.key] })],
    [seedLine(TILE_F0)],
    [GET(TILE_F0.key), ok(TILE_F0, { r2_reads: [TILE_F0.key] })],
  ] });

// The bad paths: objects exist at the (bad) keys, so a Worker that read R2 for them would answer 200.
const BAD = ['tile/0/000.p/0', 'tile/0/000.p/256', 'tile/64/000', 'tile/00/000', 'tile/entries/x001', 'tile/0/x000/067', 'tile/0/x1000/001', 'tile/0/000.p/01', 'Checkpoint', 'tile/0/001/234', 'tile/entries/000.p/256', 'tile/Entries/000'];
add('ap11-bad-path', ['R-AP11', 'R-AP21', 'R-AP48', 'R-AP41'],
  'Paths that are not in the grammar are 404 not-found with no R2 read and no D1 call (R-AP48 row 1), also when R2 has an object at that name; also a POST on such a path (404 before 405), /log and /log/.',
  { seed: [CHECKPOINT3, ...BAD.map((k) => obj(k, bytes(`bad/${k}`, 40)))], lines: [
    ...BAD.map((k) => [GET(k), missing({ r2_reads: [] })]),
    [req('POST', '/log/tile/0/000.p/0', undefined, { body: 'x' }), missing({ r2_reads: [] })],
    [req('GET', '/log'), missing({ r2_reads: [] })],
    [req('GET', '/log/'), missing({ r2_reads: [] })],
    [req('GET', '/log/checkpoint/x'), missing({ r2_reads: [] })],
    [req('GET', '/Log/checkpoint'), missing({ r2_reads: [] })],
  ] });

add('ap11-path-slashes', ['R-AP11', 'R-AP48'],
  'Q257-19 (recommendation (a)): an extra or a trailing slash is dropped by Request.segments, as for every route, so /log//checkpoint, /log/checkpoint/ and /log/tile//0/000/ give the same answer as the plain path. Only status, body and headers are checked, not the reads.',
  { seed: [CHECKPOINT3, TILE_F0], lines: [
    [req('GET', '/log//checkpoint'), ok(CHECKPOINT3)],
    [req('GET', '/log/checkpoint/'), ok(CHECKPOINT3)],
    [req('GET', '/log/tile//0/000/'), ok(TILE_F0)],
  ] });

add('ap11-etag-checkpoint', ['R-AP11', 'R-AP24', 'R-AP54'],
  'The checkpoint with If-None-Match: the right ETag (also weak) gives 304 with no body and the headers etag and cache-control (max-age=5), from one R2 read; a wrong ETag gives 200 with the body.',
  { seed: [CHECKPOINT3], lines: [
    [GET('checkpoint', { 'if-none-match': etag(CHECKPOINT3.buf) }), notModified(CHECKPOINT3, { r2_reads: ['checkpoint'] })],
    [GET('checkpoint', { 'if-none-match': '"nope"' }), ok(CHECKPOINT3, { r2_reads: ['checkpoint'] })],
    [GET('checkpoint', { 'if-none-match': 'W/' + etag(CHECKPOINT3.buf) }), notModified(CHECKPOINT3, { r2_reads: ['checkpoint'] })],
    [GET('checkpoint', { 'if-none-match': etag(CHECKPOINT7.buf) }), ok(CHECKPOINT3, { r2_reads: ['checkpoint'] })],
    [GET('checkpoint'), ok(CHECKPOINT3, { r2_reads: ['checkpoint'] })],
  ] });

add('ap11-etag-tile', ['R-AP11', 'R-AP24', 'R-AP54'],
  'A tile with If-None-Match: the right ETag gives 304 with no body, the ETag and cache-control (immutable); a wrong ETag gives 200 with the bytes. The first line is a cold request. The reads of the later lines are not checked: an answer from the Cache API makes none.',
  { seed: [TILE_A], lines: [
    [GET(TILE_A.key, { 'if-none-match': etag(TILE_A.buf) }), notModified(TILE_A, { r2_reads: [TILE_A.key] })],
    [GET(TILE_A.key, { 'if-none-match': '"nope"' }), ok(TILE_A)],
    [GET(TILE_A.key, { 'if-none-match': etag(TILE_A.buf) }), notModified(TILE_A)],
    [GET(TILE_A.key, { 'if-none-match': 'W/' + etag(TILE_A.buf) }), notModified(TILE_A)],
    [GET(TILE_A.key, { 'if-none-match': '"nope"' }), ok(TILE_A)],
    [GET(TILE_A.key), ok(TILE_A)],
  ] });

add('ap11-head', ['R-AP11', 'R-AP24'],
  'HEAD gives the status and the headers of GET and no body: the checkpoint, a cold tile, a tile after a GET (Cache API), a 304 and a 404. The body of every HEAD answer is empty.',
  { seed: [CHECKPOINT3, TILE_A], lines: [
    [req('HEAD', '/log/checkpoint'), head200(CHECKPOINT3, { r2_reads: ['checkpoint'] })],
    [req('HEAD', `/log/${TILE_A.key}`), head200(TILE_A, { r2_reads: [TILE_A.key] })],
    [GET(TILE_A.key), ok(TILE_A)],
    [req('HEAD', `/log/${TILE_A.key}`), head200(TILE_A)],
    [req('HEAD', '/log/checkpoint', { 'if-none-match': etag(CHECKPOINT3.buf) }), notModified(CHECKPOINT3, { r2_reads: ['checkpoint'] })],
    [req('HEAD', '/log/tile/0/000'), { status: 404, body: '', r2_reads: ['tile/0/000'] }],
    [req('HEAD', '/log/tile/0/000.p/0'), { status: 404, body: '', r2_reads: [] }],
  ] });

add('ap11-method-405', ['R-AP11', 'R-AP21', 'R-AP48'],
  'POST, PUT, DELETE, PATCH, OPTIONS and a lower-case method on the log routes: 405 method-not-allowed with Allow: GET, HEAD, no R2 read and no write (R2 stays as seeded); a body with a media type that is not JSON is still 405 (not 415).',
  { seed: [CHECKPOINT3, TILE_A], lines: ['checkpoint', TILE_A.key].flatMap((k) => [
    ...['POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'].map((m) => [req(m, `/log/${k}`), { status: 405, problem: { type: '/errors/method-not-allowed', detail: `${m} is not allowed on /log/${k}` }, headers: { allow: 'GET, HEAD' }, r2_reads: [], r2_puts: [] }]),
    [req('POST', `/log/${k}`, { 'content-type': 'text/plain' }, { body: 'hello' }), { status: 405, problem: { type: '/errors/method-not-allowed' }, headers: { allow: 'GET, HEAD' }, r2_reads: [], r2_puts: [] }],
  ]), r2_final: [CHECKPOINT3, TILE_A] });

add('ap45-no-client-check', ['R-AP45', 'R-AP48', 'R-AP11'],
  'MIN_TLN and MIN_TLN_WRITE are set to 0.5.0. A User-Agent tln/0.0.1 gets 200 on /log/checkpoint and on a tile (also HEAD), and 405 (not 400 unsupported-client) for a POST; the same agent is refused on /v1/toolchains (400 unsupported-client): the settings are live.',
  { settings: { MIN_TLN: '0.5.0', MIN_TLN_WRITE: '0.5.0' }, seed: [CHECKPOINT3, TILE_A], lines: [
    [GET('checkpoint', { 'user-agent': 'tln/0.0.1' }), ok(CHECKPOINT3)],
    [GET(TILE_A.key, { 'user-agent': 'tln/0.0.1' }), ok(TILE_A)],
    [req('HEAD', '/log/checkpoint', { 'user-agent': 'tln/0.0.1' }), head200(CHECKPOINT3)],
    [req('POST', '/log/checkpoint', { 'user-agent': 'tln/0.0.1' }), { status: 405, problem: { type: '/errors/method-not-allowed' } }],
    [req('GET', '/log/tile/0/000.p/0', { 'user-agent': 'tln/0.0.1' }), missing()],
    [req('GET', '/v1/toolchains', { 'user-agent': 'tln/0.0.1' }), { status: 400, problem: { type: '/errors/unsupported-client' } }],
  ], d1: [0, 0, 0, 0, 0, '-'] });

add('ap11-range-ignored', ['R-AP11', 'R-AP43'],
  'Q257-22 (recommendation (a)): a Range header is ignored: the answer is 200 with the whole object (R-AP11 lists 200 only, and the Cache API cannot keep a 206). R2.respond! alone would give 206.',
  { seed: [CHECKPOINT3, TILE_A], lines: [
    [GET('checkpoint', { range: 'bytes=0-9' }), ok(CHECKPOINT3)],
    [GET(TILE_A.key, { range: 'bytes=0-9' }), ok(TILE_A)],
    [GET(TILE_A.key, { range: 'bytes=-16' }), ok(TILE_A)],
    [GET(TILE_A.key), ok(TILE_A)],
  ] });

add('ap11-read-fault', ['R-AP11', 'R-AP48', 'R-AP43'],
  'An R2 read fails (TEST_LOG_FAIL_GETS: the first read of each named key is refused): 500 internal (problem JSON, R-AP48), for a tile, an entry bundle and the checkpoint. No entry is kept in the Cache API: the next GET of the same key reads R2 again and gives 200. A fault is not a 404.',
  { settings: { TEST_LOG_FAIL_GETS: JSON.stringify([TILE_A.key, ENT_P3.key, 'checkpoint']) }, seed: [TILE_A, ENT_P3, CHECKPOINT3], lines: [
    [GET(TILE_A.key), { status: 500, problem: { type: '/errors/internal', status: 500 }, r2_reads: [TILE_A.key] }],
    [GET(TILE_A.key), ok(TILE_A, { r2_reads: [TILE_A.key] })],
    [GET(TILE_A.key), ok(TILE_A, { r2_reads: [] })],
    [GET(ENT_P3.key), { status: 500, problem: { type: '/errors/internal', status: 500 }, r2_reads: [ENT_P3.key] }],
    [GET(ENT_P3.key), ok(ENT_P3, { r2_reads: [ENT_P3.key] })],
    [GET('checkpoint'), { status: 500, problem: { type: '/errors/internal', status: 500 }, r2_reads: ['checkpoint'] }],
    [GET('checkpoint'), ok(CHECKPOINT3, { r2_reads: ['checkpoint'] })],
  ] });

add('ap43-tile-cache', ['R-AP11', 'R-AP43', 'R-AP55'],
  'A tile (full, partial, entry bundle) is kept in the Cache API of the colo: the second and third GET make no R2 read. The R2 object is then replaced: the answer is still the old bytes (it is the cache), so the proof does not depend on a count only. Another tile is read from R2.',
  { seed: [TILE_A, TILE_P7, ENT_P3, TILE_L1], lines: [
    [GET(TILE_A.key), ok(TILE_A, { r2_reads: [TILE_A.key] })],
    [GET(TILE_A.key), ok(TILE_A, { r2_reads: [] })],
    [GET(TILE_A.key), ok(TILE_A, { r2_reads: [] })],
    [seedLine(obj(TILE_A.key, bytes('other', 8192)))],
    [GET(TILE_A.key), ok(TILE_A, { r2_reads: [] })],
    [GET(TILE_P7.key), ok(TILE_P7, { r2_reads: [TILE_P7.key] })],
    [GET(TILE_P7.key), ok(TILE_P7, { r2_reads: [] })],
    [GET(ENT_P3.key), ok(ENT_P3, { r2_reads: [ENT_P3.key] })],
    [GET(ENT_P3.key), ok(ENT_P3, { r2_reads: [] })],
    [GET(TILE_L1.key), ok(TILE_L1, { r2_reads: [TILE_L1.key] })],
    [req('HEAD', `/log/${TILE_A.key}`), head200(TILE_A)],
  ] });

add('ap43-checkpoint-fresh', ['R-AP11', 'R-AP43'],
  'The checkpoint is NOT in the Cache API: each GET is one R2 read, and a checkpoint that R2 got a moment ago is seen at once (max-age=5 is for the client; the Worker never serves an old checkpoint from its colo).',
  { seed: [CHECKPOINT3], lines: [
    [GET('checkpoint'), ok(CHECKPOINT3, { r2_reads: ['checkpoint'] })],
    [GET('checkpoint'), ok(CHECKPOINT3, { r2_reads: ['checkpoint'] })],
    [seedLine(CHECKPOINT7)],
    [GET('checkpoint'), ok(CHECKPOINT7, { r2_reads: ['checkpoint'] })],
    [GET('checkpoint', { 'if-none-match': etag(CHECKPOINT3.buf) }), ok(CHECKPOINT7, { r2_reads: ['checkpoint'] })],
    [GET('checkpoint', { 'if-none-match': etag(CHECKPOINT7.buf) }), notModified(CHECKPOINT7, { r2_reads: ['checkpoint'] })],
  ] });

add('ap43-query-ignored', ['R-AP11', 'R-AP43', 'R-AP55'],
  'Q257-20 (recommendation (a)): a query string is ignored, and the Cache API key of a tile has no query, so a client cannot make R2 reads with ?a=1, ?a=2. The checkpoint with a query is the checkpoint.',
  { seed: [CHECKPOINT3, TILE_A], lines: [
    [req('GET', `/log/${TILE_A.key}?a=1`), ok(TILE_A, { r2_reads: [TILE_A.key] })],
    [req('GET', `/log/${TILE_A.key}?a=2`), ok(TILE_A, { r2_reads: [] })],
    [GET(TILE_A.key), ok(TILE_A, { r2_reads: [] })],
    [req('GET', '/log/checkpoint?x=1'), ok(CHECKPOINT3, { r2_reads: ['checkpoint'] })],
  ] });

add('ap43-tile-no-cache-ignored', ['R-AP11', 'R-AP43', 'R-AP55'],
  'Q257-21 (recommendation (a)): Cache-Control: no-cache and Pragma: no-cache (R-AP43, R-AP55) do not bypass the Cache API for a tile, which never changes; the answer is the cached one with no R2 read.',
  { seed: [TILE_A], lines: [
    [GET(TILE_A.key), ok(TILE_A, { r2_reads: [TILE_A.key] })],
    [GET(TILE_A.key, { 'cache-control': 'no-cache' }), ok(TILE_A, { r2_reads: [] })],
    [GET(TILE_A.key, { pragma: 'no-cache' }), ok(TILE_A, { r2_reads: [] })],
  ] });

// --- write ---
rmSync(CASES, { recursive: true, force: true });
const clean = (o) => JSON.parse(JSON.stringify(o)); // drops undefined members
for (const c of cases) {
  const dir = join(CASES, c.name);
  mkdirSync(join(dir, 'expect'), { recursive: true });
  writeFileSync(join(dir, 'rules'), c.rules.join('\n') + '\n');
  writeFileSync(join(dir, 'notes.txt'), `${c.notes}\nGenerated by research/slice-257d-vectors/cases.mjs (node:crypto, not the code under test). Do not edit: change the generator.\n`);
  writeFileSync(join(dir, 'r2.jsonl'), c.seed.map(r2Line).join('\n') + '\n');
  if (c.settings) writeFileSync(join(dir, 'settings.json'), JSON.stringify(c.settings) + '\n');
  const reqs = [];
  const exps = [];
  for (const [rq, ex] of c.lines) {
    reqs.push(JSON.stringify(rq));
    if (!rq.r2_seed) exps.push(JSON.stringify(clean(ex)));
  }
  writeFileSync(join(dir, 'requests.jsonl'), reqs.join('\n') + '\n');
  writeFileSync(join(dir, 'expect', 'responses.jsonl'), exps.join('\n') + '\n');
  writeFileSync(join(dir, 'expect', 'd1-calls'), (c.d1 ?? exps.map(() => 0)).join('\n') + '\n');
  const final = c.r2_final ?? null;
  if (final) writeFileSync(join(dir, 'expect', 'r2.jsonl'), final.map((o) => JSON.stringify({ key: o.key, sha256: sha256(o.buf), size: o.buf.length, content_type: o.content_type })).join('\n') + '\n');
}
console.log(`${cases.length} cases in ${CASES}`);
