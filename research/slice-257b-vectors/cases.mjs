// Slice 257b: the W2 cases of the tile writer (worker/tests/cases/log/) and the W0 key vectors of worker/tests/unit/LogStepTest.roc, made with node:crypto only (not with the code under test).
// It extends research/slice-257a-vectors/vectors.mjs: the same formats (RFC 6962, C2SP tlog-tiles, tlog-checkpoint, signed-note), the same test leaves and the same throwaway test key
// (a seed from a fixed text; it signs nothing outside the tests). The functions are copied here, so that file and its output (the vector block of TlogTest.roc) do not change.
// The R2 state of a size S is every tile of a tree of size S (full and partial, entry bundles too) and the signed checkpoint of S, as the step writes them (R-SG7 rows 2, 3).
// Usage (repo root): node research/slice-257b-vectors/cases.mjs [--write]
//   writes the case dirs under worker/tests/cases/log/ (each dir is made again), and prints the Roc vector block.
//   --write also replaces the generated block of worker/tests/unit/LogStepTest.roc.
import { createHash, createPrivateKey, createPublicKey, sign, verify } from 'node:crypto';
import { mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = join(HERE, '..', '..');
const CASES = join(ROOT, 'worker', 'tests', 'cases', 'log');
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

// R-SG2: `<grp> <version> <hash> <time>\n`. History A is the leaf scheme of vectors.mjs (tlog index i = D1 idx i + 1). History B differs in the version (0.9.<i>):
// the case sg7-edge-from-r2 has B in D1 below the checkpoint and A in R2, so a step that reads the old leaves from D1 (not the tiles of R2) writes other bytes.
const GRP = 'github.com/acme/pkg/releases/download/{v}/';
const HASH = '6YbXkqTz7pUm2Ff8RcWvJ3s9Hd1LgAeNo4QxBiKt5uP';
const T0 = 1763500000000;
const leafText = (i, hist = 'A') => `${GRP} ${hist === 'A' ? '1.0.' : '0.9.'}${i} ${HASH} ${T0 + i * 1000}\n`;
const MAX = 600;
const entriesA = Array.from({ length: MAX }, (_, i) => Buffer.from(leafText(i), 'utf8'));
const hashesA = entriesA.map(leafHash);
const entriesB = Array.from({ length: MAX }, (_, i) => Buffer.from(leafText(i, 'B'), 'utf8'));
const hashesB = entriesB.map(leafHash);

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
function bundle(es) {
  return Buffer.concat(es.flatMap((e) => { const p = Buffer.alloc(2); p.writeUInt16BE(e.length); return [p, e]; }));
}
function tileBytes(t, entries = entriesA, hashes = hashesA) {
  if (t.level === 'E') return bundle(entries.slice(t.index * 256, t.index * 256 + t.width));
  const span = 256 ** t.level;
  const out = [];
  for (let k = t.index * 256; k < t.index * 256 + t.width; k++) out.push(mth(hashes.slice(k * span, (k + 1) * span)));
  return Buffer.concat(out);
}

// The keys. PKCS#8 of Ed25519 is a fixed 16-byte prefix and the 32-byte seed.
const PKCS8_PREFIX = Buffer.from('302e020100300506032b657004220420', 'hex');
function keyOfSeed(seed) {
  const priv = createPrivateKey({ key: Buffer.concat([PKCS8_PREFIX, seed]), format: 'der', type: 'pkcs8' });
  const jwk = priv.export({ format: 'jwk' });
  return { priv, pub: Buffer.from(jwk.x, 'base64url'), jwk };
}
const keyId = (name, pub) => sha(Buffer.from(name, 'utf8'), [0x0a, 0x01], pub).subarray(0, 4);
const signerText = (name, id, seed) => `PRIVATE+KEY+${name}+${hex(id)}+${b64(Buffer.concat([Buffer.from([1]), seed]))}`;
const ORIGIN = 'registry.roc-talon.org/log';
const seed = sha(Buffer.from('talon slice 257a throwaway test key, never used outside the tests'));
const key = keyOfSeed(seed);
const id = keyId(ORIGIN, key.pub);
const LOG_KEY = signerText(ORIGIN, id, seed);
// A second throwaway key: its id in the text of the first key is a wrong key id (R-WH14).
const seed2 = sha(Buffer.from('talon slice 257b second throwaway test key, never used outside the tests'));
const key2 = keyOfSeed(seed2);
const id2 = keyId(ORIGIN, key2.pub);
const LOG_KEY_WRONG_ID = signerText(ORIGIN, id2, seed);
if (hex(id) === hex(id2)) throw new Error('the two test keys have one key id');
const checkpointOf = (size, root) => {
  const body = `${ORIGIN}\n${size}\n${b64(root)}\n`;
  const sig = sign(null, Buffer.from(body), key.priv);
  if (!verify(null, Buffer.from(body), createPublicKey(key.priv), sig)) throw new Error('signature');
  return `${body}\n— ${ORIGIN} ${b64(Buffer.concat([id, sig]))}\n`;
};
const ckA = (size) => checkpointOf(size, mth(hashesA.slice(0, size)));

// Objects: { key, bytes, ct }. R-AP23 (proposal P-b1): a tile is application/octet-stream, the checkpoint text/plain; charset=utf-8.
const CT_TILE = 'application/octet-stream';
const CT_CK = 'text/plain; charset=utf-8';
const tileObj = (t, e, h) => ({ key: pathOf(t), bytes: tileBytes(t, e, h), ct: CT_TILE });
const ckObj = (text, k = 'checkpoint') => ({ key: k, bytes: Buffer.from(text, 'utf8'), ct: CT_CK, text });
const stateOf = (S) => (S === 0 ? [] : [...tilesOf(S).map((t) => tileObj(t)), ckObj(ckA(S))]);
const merge = (...lists) => { const m = new Map(); for (const l of lists) for (const o of l) m.set(o.key, o); return [...m.values()]; };
const seedLine = (o) => JSON.stringify(o.text !== undefined ? { key: o.key, text: o.text, content_type: o.ct } : { key: o.key, base64: b64(o.bytes), content_type: o.ct });
const expectLine = (o) => JSON.stringify({ key: o.key, sha256: hex(sha(o.bytes)), size: o.bytes.length, content_type: o.ct, ...(o.text !== undefined ? { text: o.text } : {}) });

// D1: the leaves idx 1 to n of history A (and B for idx 1 to bUpTo), with one recursive statement each.
const seedSql = (n, bUpTo = 0) => {
  const one = (from, to, ver) => `INSERT INTO log (idx, grp, version, hash, time) WITH RECURSIVE c(i) AS (SELECT ${from} UNION ALL SELECT i + 1 FROM c WHERE i < ${to}) SELECT i, '${GRP}', '${ver}' || (i - 1), '${HASH}', ${T0} + (i - 1) * 1000 FROM c;`;
  const out = ['-- Generated by research/slice-257b-vectors/cases.mjs. The leaves idx 1 to ' + n + ' (R-SG2: the tlog leaf at index idx - 1).'];
  if (bUpTo > 0) out.push(one(1, bUpTo, '0.9.'));
  if (n > bUpTo) out.push(one(bUpTo + 1, n, '1.0.'));
  return n === 0 ? out[0] + '\n' : out.join('\n') + '\n';
};

const NOW = 1767225600000;
const CRON = { cron: '2-59/5 * * * *', time: NOW, now: NOW };
const OK = { status: 200, json: { outcome: 'ok' } };
// Q257-17 (answered 2026-11-19, (a)): a failed step fails the cron run (Miniflare status 500).
const FAILED = { status: 500 };
const ERR_LOG = { level: 'error', msg: 'log step failed' };
const wrote = (from, size, tiles) => ({ level: 'info', msg: 'log wrote', from, size, tiles });
const tilePaths = (S, N) => growth(S, N).map(pathOf);

const cases = [];
const add = (c) => cases.push(c);
const base = { settings: { LOG_KEY } };

add({ name: 'sg7-first-step', rules: ['R-SG4', 'R-SG7', 'R-PU35', 'R-SG2'], notes: '3 leaves in D1, no object in R2 (no checkpoint: S = 0, R2.absent). One cron run writes the 2 partial tiles of size 3, then the checkpoint.',
  ...base, n: 3, lines: [[CRON, { ...OK, r2_puts: [tilePaths(0, 3), ['checkpoint?absent']] }, 1]], logs: [wrote(0, 3, 2)], final: stateOf(3) });
add({ name: 'sg7-empty-log', rules: ['R-SG7', 'R-SG4'], notes: 'No leaf and no checkpoint (Design Q636 (16): no checkpoint before the first leaf). The run writes nothing.',
  ...base, n: 0, lines: [[CRON, { ...OK, r2_puts: [] }, 1]], final: [] });
add({ name: 'sg7-growth-in-tile', rules: ['R-SG7', 'R-SG4'], notes: 'R2 has the state of size 3, D1 has 7 leaves. The step reads the etag (put ?etag) and writes the partial tiles of 7. The partial tiles of 3 stay (R-SG4: write-once, kept).',
  ...base, n: 7, r2: stateOf(3), lines: [[CRON, { ...OK, r2_puts: [tilePaths(3, 7), ['checkpoint?etag']] }, 1]], logs: [wrote(3, 7, 2)], final: merge(stateOf(3), stateOf(7)) });
add({ name: 'sg7-growth-256', rules: ['R-SG7', 'R-SG4'], notes: 'R2 has the state of size 255, D1 has 257 leaves: the full tiles tile/0/000 and tile/entries/000, the partial tiles .p/1 of level 0 and of the bundles, and the first level 1 tile.',
  ...base, n: 257, r2: stateOf(255), lines: [[CRON, { ...OK, r2_puts: [tilePaths(255, 257), ['checkpoint?etag']] }, 1]], logs: [wrote(255, 257, growth(255, 257).length)], final: merge(stateOf(255), stateOf(257)) });
add({ name: 'sg7-big-jump', rules: ['R-SG7', 'R-SG4'], notes: 'R2 has the state of size 7, D1 has 600 leaves: one step (fewer than the cap) writes 2 full tiles of each kind, the partial tiles of 600 and level 1.',
  ...base, n: 600, r2: stateOf(7), lines: [[CRON, { ...OK, r2_puts: [tilePaths(7, 600), ['checkpoint?etag']] }, 1]], logs: [wrote(7, 600, growth(7, 600).length)], final: merge(stateOf(7), stateOf(600)) });
{
  // The edge of 255 from R2 (history A); D1 has history B for idx 1 to 255 and A for 256, 257.
  const edgeA = stateOf(255);
  const grownA = growth(255, 257).map((t) => tileObj(t));
  add({ name: 'sg7-edge-from-r2', rules: ['R-SG7'], notes: 'R-SG7 row 1: the old hashes come from the partial tiles of size S in R2, the leaves only from idx S + 1. D1 has OTHER leaf texts for idx 1 to 255 (history B) than the tiles of R2 (history A). So a step that reads the leaves from idx 1 (or the bundle from D1) writes other bytes than these.',
    ...base, n: 257, bUpTo: 255, r2: edgeA, lines: [[CRON, { ...OK, r2_puts: [tilePaths(255, 257), ['checkpoint?etag']] }, 1]], logs: [wrote(255, 257, growth(255, 257).length)], final: merge(edgeA, grownA, [ckObj(ckA(257))]) });
}
add({ name: 'sg7-idempotent', rules: ['R-SG7', 'R-PU36'], notes: 'Two cron runs. The second finds no leaf above the checkpoint size: no put (R-SG7: one idempotent step), one D1 call.',
  ...base, n: 3, lines: [[CRON, { ...OK, r2_puts: [tilePaths(0, 3), ['checkpoint?absent']] }, 1], [CRON, { ...OK, r2_puts: [] }, 1]], logs: [wrote(0, 3, 2)], final: stateOf(3) });
add({ name: 'pu36-two-runs', rules: ['R-PU36', 'R-SG7'], notes: 'Two runs at the same time (copies 2) on 300 leaves and no checkpoint: one checkpoint of 300, no lost tile, both runs ok (R-SG7 row 4: the run that loses the compare and swap reads the checkpoint again and stops).',
  ...base, n: 300, lines: [[{ ...CRON, copies: 2 }, OK, '-']], logs: [wrote(0, 300, tilesOf(300).length)], final: stateOf(300) });
{
  const race = ckObj(ckA(9), 'race/checkpoint');
  add({ name: 'sg7-race-etag', rules: ['R-SG7', 'R-PU36'], notes: 'R-SG7 row 4 and its revert: R2 has the state of 3; another run writes the checkpoint of 9 between the read and the put (TEST_LOG_RACE). The put with the old etag does not write; the step reads the checkpoint again (9 >= 7) and stops. A plain put would leave the smaller size 7.',
    settings: { LOG_KEY, TEST_LOG_RACE: 'race/checkpoint' }, n: 7, r2: [...stateOf(3), race], lines: [[CRON, { ...OK, r2_puts: [tilePaths(3, 7), ['checkpoint?etag']] }, 1]],
    logs: [{ level: 'warn', msg: 'log checkpoint changed', size: 7, theirs: 9 }], final: merge(stateOf(3), growth(3, 7).map((t) => tileObj(t)), [race], [ckObj(ckA(9))]) });
}
{
  const race = ckObj(ckA(5), 'race/checkpoint');
  add({ name: 'sg7-race-absent', rules: ['R-SG7', 'R-PU36'], notes: 'No checkpoint at the read (R2.absent); another run writes the checkpoint of 5 before the put. The put does not write; the step reads it again (5 >= 3) and stops.',
    settings: { LOG_KEY, TEST_LOG_RACE: 'race/checkpoint' }, n: 3, r2: [race], lines: [[CRON, { ...OK, r2_puts: [tilePaths(0, 3), ['checkpoint?absent']] }, 1]],
    logs: [{ level: 'warn', msg: 'log checkpoint changed', size: 3, theirs: 5 }], final: merge(growth(0, 3).map((t) => tileObj(t)), [race], [ckObj(ckA(5))]) });
}
{
  // Q257-18 (Design Q636, answered 2026-11-19): after a lost compare and swap where the new checkpoint is SMALLER than the step wanted, the step goes once more, then stops.
  const race5 = ckObj(ckA(5), 'race/a');
  const tiles5 = growth(3, 5).map((t) => tileObj(t));
  add({ name: 'sg7-race-smaller-retry', rules: ['R-SG7', 'R-PU36'], notes: 'Q257-18: R2 has the state of 3; another run writes the checkpoint of 5 (and its tiles) before the put of 7. 5 < 7: the step goes once more from 5 (the edge of 5, the leaves 6 and 7, the checkpoint put with the etag of 5) and writes 7.',
    settings: { LOG_KEY, TEST_LOG_RACE: 'race/a' }, n: 7, r2: [...stateOf(3), ...tiles5, race5],
    lines: [[CRON, { ...OK, r2_puts: [tilePaths(3, 7), ['checkpoint?etag'], tilePaths(5, 7), ['checkpoint?etag']] }, 2]],
    logs: [wrote(5, 7, growth(5, 7).length)], final: merge(stateOf(3), tiles5, growth(3, 7).map((t) => tileObj(t)), [race5], [ckObj(ckA(7))]) });
  const race6 = ckObj(ckA(6), 'race/b');
  add({ name: 'sg7-race-smaller-stop', rules: ['R-SG7', 'R-PU36'], notes: 'Q257-18: the one more step also loses, to a checkpoint of 6 (TEST_LOG_RACE with 2 keys). The step stops (Lost, size 7, theirs 6), the run is ok, the checkpoint of 6 stays. A third try would need the tiles of 6, which R2 does not have (a fault).',
    settings: { LOG_KEY, TEST_LOG_RACE: JSON.stringify(['race/a', 'race/b']) }, n: 7, r2: [...stateOf(3), ...tiles5, race5, race6],
    lines: [[CRON, { ...OK, r2_puts: [tilePaths(3, 7), ['checkpoint?etag'], tilePaths(5, 7), ['checkpoint?etag']] }, 2]],
    logs: [{ level: 'warn', msg: 'log checkpoint changed', size: 7, theirs: 6 }], final: merge(stateOf(3), tiles5, growth(3, 7).map((t) => tileObj(t)), [race5, race6], [ckObj(ckA(6))]) });
}
add({ name: 'sg7-put-fault-tile', rules: ['R-SG7', 'R-PU35'], notes: 'R-SG7 rows 2 and 5: the put of one tile fails, so the step writes no checkpoint (Q257-17: the run fails). The next run writes the tiles again and the checkpoint.',
  settings: { LOG_KEY, TEST_LOG_FAIL_PUTS: JSON.stringify(['tile/entries/000.p/3']) }, n: 3,
  lines: [[CRON, { ...FAILED, r2: { checkpoint: null, 'tile/entries/000.p/3': null } }, '-'], [CRON, { ...OK, r2_puts: [tilePaths(0, 3), ['checkpoint?absent']] }, 1]],
  logs: [ERR_LOG, wrote(0, 3, 2)], final: stateOf(3) });
{
  const tiles = growth(0, 3).map((t) => tileObj(t));
  add({ name: 'sg7-put-fault-checkpoint', rules: ['R-SG7', 'R-PU35'], notes: 'R-SG7 tests: a step that stops after the tiles and before the checkpoint (the checkpoint put fails) is repaired by the next catch-up run.',
    settings: { LOG_KEY, TEST_LOG_FAIL_PUTS: JSON.stringify(['checkpoint']) }, n: 3,
    lines: [[CRON, { ...FAILED, r2_puts: [tilePaths(0, 3), ['checkpoint?absent']], r2: Object.fromEntries([['checkpoint', null], ...tiles.map((o) => [o.key, { sha256: hex(sha(o.bytes)) }])]) }, '-'],
      [CRON, { ...OK, r2_puts: [tilePaths(0, 3), ['checkpoint?absent']] }, 1]], logs: [ERR_LOG, wrote(0, 3, 2)], final: stateOf(3) });
}
add({ name: 'wh14-log-key-missing', rules: ['R-WH14', 'R-SG7'], notes: 'No LOG_KEY: 500 internal and no write (R-WH14; Q257-17: the run fails, one log line).',
  settings: {}, n: 3, lines: [[CRON, { ...FAILED, r2_puts: [] }, '-']], logs: [ERR_LOG], final: [] });
add({ name: 'wh14-log-key-bad-text', rules: ['R-WH14', 'R-SG7'], notes: 'A LOG_KEY that is not a signer key text (the key id is not hex): no write.',
  settings: { LOG_KEY: `PRIVATE+KEY+${ORIGIN}+zzzzzzzz+${b64(Buffer.concat([Buffer.from([1]), seed]))}` }, n: 3, lines: [[CRON, { ...FAILED, r2_puts: [] }, '-']], logs: [ERR_LOG], final: [] });
add({ name: 'wh14-log-key-wrong-id', rules: ['R-WH14', 'R-SG7'], notes: 'R-WH14: a LOG_KEY whose key id is not the key id of its key (the id of the second test key, the seed of the first): no write. Tlog does not check it (257a P2), the Worker does.',
  settings: { LOG_KEY: LOG_KEY_WRONG_ID }, n: 3, lines: [[CRON, { ...FAILED, r2_puts: [] }, '-']], logs: [ERR_LOG], final: [] });
{
  const s7 = stateOf(7).filter((o) => o.key !== 'tile/0/000.p/7');
  add({ name: 'sg7-bad-edge', rules: ['R-SG7'], notes: 'The partial tile tile/0/000.p/7 of the checkpoint size 7 is missing (slice file 3.2 row 3: a broken log): no write.',
    ...base, n: 9, r2: s7, lines: [[CRON, { ...FAILED, r2_puts: [] }, '-']], logs: [ERR_LOG], final: s7 });
}
{
  const s7 = [...stateOf(7).filter((o) => o.key !== 'checkpoint'), ckObj(checkpointOf(7, mth(hashesB.slice(0, 7))))];
  add({ name: 'sg7-root-mismatch', rules: ['R-SG7'], notes: 'The checkpoint of 7 is signed, but its root is not the root of the tiles of 7 (slice file 3.2 row 4: the root from the tiles of S must be the root of the checkpoint): no write.',
    ...base, n: 9, r2: s7, lines: [[CRON, { ...FAILED, r2_puts: [] }, '-']], logs: [ERR_LOG], final: s7 });
}
{
  const bad = [ckObj('not a checkpoint\n')];
  add({ name: 'sg7-bad-checkpoint', rules: ['R-SG7'], notes: 'A checkpoint that does not parse (slice file 3.2 row 1): no write.',
    ...base, n: 3, r2: bad, lines: [[CRON, { ...FAILED, r2_puts: [] }, '-']], logs: [ERR_LOG], final: bad });
}

rmSync(CASES, { recursive: true, force: true });
for (const c of cases) {
  const d = join(CASES, c.name);
  mkdirSync(join(d, 'expect'), { recursive: true });
  writeFileSync(join(d, 'rules'), c.rules.join('\n') + '\n');
  writeFileSync(join(d, 'notes.txt'), c.notes + '\nGenerated by research/slice-257b-vectors/cases.mjs (node:crypto, not the code under test). Do not edit: change the generator.\n');
  writeFileSync(join(d, 'settings.json'), JSON.stringify(c.settings) + '\n');
  writeFileSync(join(d, 'seed.sql'), seedSql(c.n, c.bUpTo ?? 0));
  if (c.r2?.length) writeFileSync(join(d, 'r2.jsonl'), c.r2.map(seedLine).join('\n') + '\n');
  writeFileSync(join(d, 'requests.jsonl'), c.lines.map(([r]) => JSON.stringify(r)).join('\n') + '\n');
  writeFileSync(join(d, 'expect', 'responses.jsonl'), c.lines.map(([, e]) => JSON.stringify(e)).join('\n') + '\n');
  writeFileSync(join(d, 'expect', 'd1-calls'), c.lines.map(([, , n]) => String(n)).join('\n') + '\n');
  writeFileSync(join(d, 'expect', 'r2.jsonl'), c.final.map(expectLine).join('\n') + (c.final.length ? '\n' : ''));
  if (c.logs?.length) writeFileSync(join(d, 'expect', 'logs.jsonl'), c.logs.map((l) => JSON.stringify(l)).join('\n') + '\n');
}
console.log(`wrote ${cases.length} cases under ${CASES}`);

// The W0 vectors of LogStepTest.roc.
const roc = [];
const L = (s) => roc.push(s);
L('# The throwaway test key of research/slice-257a-vectors/vectors.mjs: the signer key text, the public key, the key id, and the JWK text of the private key');
L('# as an export gives it (node:crypto; WebCrypto gives the same members). The second key: only its public key and its key id (for a wrong key id).');
L('vec_key : { signer : Str, public : Str, key_id : Str, jwk : Str, other_public : Str, other_key_id : Str }');
L(`vec_key = { signer: ${JSON.stringify(LOG_KEY)}, public: "${hex(key.pub)}", key_id: "${hex(id)}", jwk: ${JSON.stringify(JSON.stringify({ crv: key.jwk.crv, d: key.jwk.d, ext: true, key_ops: ['sign'], kty: key.jwk.kty, x: key.jwk.x }))}, other_public: "${hex(key2.pub)}", other_key_id: "${hex(id2)}" }`);
const text = roc.join('\n');
console.log(text);
if (process.argv.includes('--write')) {
  const f = join(ROOT, 'worker/tests/unit/LogStepTest.roc');
  const src = readFileSync(f, 'utf8');
  const a = '# --- vectors: generated by research/slice-257b-vectors/cases.mjs, do not edit ---\n';
  const b = '# --- end of vectors ---\n';
  const i = src.indexOf(a), j = src.indexOf(b);
  if (i < 0 || j < i) { console.log('LogStepTest.roc has no vector block'); process.exit(1); }
  writeFileSync(f, src.slice(0, i + a.length) + '\n' + text + '\n\n' + src.slice(j));
  console.log(`wrote the vector block of ${f}`);
}
