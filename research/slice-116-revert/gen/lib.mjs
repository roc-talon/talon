// Ids, texts and the seed of the slice 116 W2 cases (copied from research/slice-115-revert/gen/lib.mjs and changed), with node only (crypto): no expected id comes from the Roc code.
// name_id (R-IK2), nightly id (R-IK4), base58, version keys (R-IK5), the ETag of R-AP54.
import { createHash } from 'node:crypto';
import { mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { join } from 'node:path';

export const ROOT = join(import.meta.dirname, '..', '..', '..');
export const CASES = join(ROOT, 'worker', 'tests', 'cases', 'hints');

const A = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
export function b58(bytes) {
  let n = 0n;
  for (const b of bytes) n = (n << 8n) | BigInt(b);
  let s = '';
  while (n > 0n) { s = A[Number(n % 58n)] + s; n /= 58n; }
  let lead = 0;
  while (lead < bytes.length && bytes[lead] === 0) lead++;
  return '1'.repeat(lead) + s;
}
export const nameId = (kind, bytes) => BigInt.asIntN(64, BigInt('0x' + createHash('sha256').update(Buffer.from([kind, ...bytes])).digest('hex').slice(0, 16)));
export function nightlyId(tag) {
  const [, y, m, d, sha] = tag.split('-');
  const days = Math.round((Date.UTC(+y, +m - 1, +d) - Date.UTC(1970, 0, 1)) / 86400000);
  return days * 2 ** 28 + parseInt(sha, 16);
}
export const storedVersion = (M, m, p) => BigInt.asIntN(64, ((BigInt(M) << 48n) | (BigInt(m) << 32n) | (BigInt(p) << 16n) | 0xFFFFn) ^ (1n << 63n));
export const etagOf = (body) => `"${createHash('sha256').update(Buffer.from(body)).digest('hex').slice(0, 32)}"`;
export const hex = (bytes) => Buffer.from(bytes).toString('hex');
export const rep = (b) => Array(32).fill(b);

// The nightlies, the hashes and the groups of the dataset. Releases (log index): 4 PA g a 1.0.0, 5 PC g a 1.1.0 (PA is no member while PC is live),
// 6 PB g b 0.2.0, 7 PP g p 1.0.0 (a platform, targets x64glibc 8 and wasm32 34), 8 PX g x 1.0.0 (an app). The members at 8: PC, PB, PP.
export const N = {
  n1: { tag: 'nightly-2026-10-29-aaaaaaa', day: '2026-10-29', published_at: Date.UTC(2026, 9, 29, 12) },
  n2: { tag: 'nightly-2026-10-30-bbbbbbb', day: '2026-10-30', published_at: Date.UTC(2026, 9, 30, 12) },
  n3: { tag: 'nightly-2026-10-31-ccccccc', day: '2026-10-31', published_at: Date.UTC(2026, 9, 31, 12) },
};
for (const n of Object.values(N)) n.id = nightlyId(n.tag);
export const H = {};
for (const [k, byte] of Object.entries({ PA: 0x11, PB: 0x22, PP: 0x33, PX: 0x44, PY: 0x55, PC: 0x66 })) H[k] = { byte, bytes: rep(byte), b58: b58(rep(byte)), id: nameId(1, rep(byte)) };
export const G = {
  a: 'github.com/o/a/releases/download/{v}/', b: 'github.com/o/b/releases/download/{v}/',
  p: 'github.com/o/p/releases/download/{v}/', x: 'github.com/o/x/releases/download/{v}/',
};
const gid = (g) => nameId(2, Buffer.from(g, 'utf8'));
const sha = (n) => n.tag.replace(/\D/g, '').padEnd(64, 'e').slice(0, 64);

// The seed statements of the dataset. `extra` statements go after.
export function dataset() {
  const s = [];
  for (const g of Object.values(G)) s.push(`INSERT INTO names (id, kind, value) VALUES (${gid(g)}, 2, '${g}');`);
  for (const h of ['PA', 'PB', 'PP', 'PX', 'PC']) s.push(`INSERT INTO names (id, kind, value) VALUES (${H[h].id}, 1, X'${hex(H[h].bytes)}');`);
  const kinds = { PA: 1, PB: 1, PC: 1, PP: 2, PX: 0 };
  for (const h of ['PA', 'PB', 'PP', 'PX', 'PC']) s.push(`INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (${H[h].id}, ${kinds[h]}, '[]', NULL, NULL, 1);`);
  s.push(`INSERT INTO artifact_targets (artifact, target) VALUES (${H.PP.id}, 8), (${H.PP.id}, 34);`);
  let idx = 0;
  for (const n of Object.values(N)) {
    idx++;
    n.log_index = idx;
    s.push(`INSERT INTO log (idx, grp, version, hash, time) VALUES (${idx}, 'roc-lang/nightlies:linux_x86_64', '${n.tag}', 'sha256:${sha(n)}', 1790000000000);`);
    s.push(`INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, published_at, log_index) VALUES (${n.id}, 'linux_x86_64', '${n.tag}', 'roc_nightly-linux_x86_64.tar.gz', '${sha(n)}', ${n.published_at}, ${idx});`);
  }
  const rel = [
    ['PA', G.a, [1, 0, 0]], ['PC', G.a, [1, 1, 0]], ['PB', G.b, [0, 2, 0]], ['PP', G.p, [1, 0, 0]], ['PX', G.x, [1, 0, 0]],
  ];
  for (const [h, g, [M, m, p]] of rel) {
    idx++;
    const v = `${M}.${m}.${p}`;
    s.push(`INSERT INTO log (idx, grp, version, hash, time) VALUES (${idx}, '${g}', '${v}', '${H[h].b58}', 1790000000000);`);
    s.push(`INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (${idx}, ${gid(g)}, ${storedVersion(M, m, p)}, '', ${H[h].id}, NULL, 'https://${g.replace('{v}', v)}${H[h].b58}.tar.zst', '${v}', NULL, ${Date.UTC(2026, 9, 25)}, 0, NULL, NULL);`);
  }
  return s;
}
export const LOG_SIZE = 8;

export const SETTINGS = { AUDIENCE: 'https://registry.example', BOT_REPOSITORY_ID: '900001', BOT_WORKFLOW_REF: 'roc-talon/talon/.github/workflows/compat-bot.yml@refs/heads/main' };
export const JWKS = '{"keys":[{"$key":"k1","kid":"kid-1","alg":"RS256","use":"sig","x5t":"test"}]}\n';
export const TOKENS = {
  bot: { base: 'bot' },
  pub: { base: 'publish' },
  bad: { base: 'bot', tamper: 'signature' },
  garbage: { raw: 'not-a-jwt' },
};

// A request body: rows [{h, n, t, r, d}] with h a key of H, n a key of N, d the digest (undefined is null).
export const row = (h, n, t, r, d) => ({ hash: H[h].b58, nightly: N[n].tag, target: t, result: r, error_digest: d === undefined ? null : d });
export const sweepOf = (n, upto) => ({ nightly: N[n].tag, target: 'any', upto_log_index: upto });
export const post = (rows, sweep, extra = {}) => ({ ...extra, rows, ...(sweep === undefined ? {} : { sweep }) });

export const JSON_CT = { 'content-type': 'application/json' };
// A request line. `body` is an object (written as JSON text) or a text.
export const req = (body, o = {}) => ({
  method: 'POST', path: '/v1/compat', headers: { ...JSON_CT, ...(o.headers ?? {}) },
  body: typeof body === 'string' ? body : JSON.stringify(body),
  ...(o.token === undefined ? {} : { token: o.token }), ...(o.now === undefined ? {} : { now: o.now }),
});

export const ok = (status, written) => ({ status, headers: { 'content-type': 'application/json', 'cache-control': 'no-store' }, body: JSON.stringify({ written }) });
export const prob = (status, type, more = {}) => ({ status, problem: { type, ...more } });

// Writes a case dir. `c` has: name, rules (array), seed (array of statements), requests (array of request lines or {sql}), responses (array), d1 (array of numbers or '-'),
// db (text of db.tsv), github (array of lines), tokens (bool), files (extra {path: text}).
export function writeCase(c) {
  const dir = join(CASES, c.name);
  rmSync(dir, { recursive: true, force: true });
  mkdirSync(join(dir, 'expect'), { recursive: true });
  const w = (p, t) => { mkdirSync(join(dir, p, '..'), { recursive: true }); writeFileSync(join(dir, p), t); };
  w('rules', c.rules.join('\n') + '\n');
  if (c.seed) w('seed.sql', c.seed.join('\n') + '\n');
  w('requests.jsonl', c.requests.map((r) => JSON.stringify(r)).join('\n') + '\n');
  w('expect/responses.jsonl', c.responses.map((r) => JSON.stringify(r)).join('\n') + '\n');
  if (c.d1) w('expect/d1-calls', c.d1.join('\n') + '\n');
  if (c.db) w('expect/db.tsv', c.db);
  if (c.github && c.github.length) w('expect/github.log', c.github.join('\n') + '\n');
  w('settings.json', JSON.stringify(c.settings ?? {}) + '\n');
  if (c.tokenSpecs) w('tokens.json', JSON.stringify(c.tokenSpecs, null, 1) + '\n');
  if (c.ratelimits) w('ratelimits.json', JSON.stringify(c.ratelimits) + '\n');
  for (const [p, t] of Object.entries(c.files ?? {})) w(p, t);
}
export const JWKS_LOG = 'GET https://token.actions.githubusercontent.com/.well-known/jwks';

// db.tsv blocks: [[sql, rows]], rows are arrays of cells (null is \N).
export function tsv(blocks) {
  return blocks.map(([sql, rows]) => `@ ${sql}\n${rows.map((r) => r.map((v) => (v === null ? '\\N' : String(v))).join('\t')).join('\n')}${rows.length ? '\n' : ''}`).join('');
}
export const COMPAT_Q = 'SELECT hex(substr(n.value, 1, 1)) AS h, c.nightly, c.target, c.source, c.result, c.error_digest, c.time, c.log_index FROM compat c JOIN names n ON n.id = c.artifact ORDER BY n.value, c.nightly, c.target, c.source';
export const SWEEPS_Q = 'SELECT nightly, target, upto_log_index, time FROM sweeps ORDER BY nightly, target';
export const TRANS_Q = 'SELECT nightly, target, previous, compared, changed FROM transitions ORDER BY nightly, target';
// A compat row for db.tsv: [hash key, night key, target code, source, result code, digest, time, log_index]
export const crow = (h, n, t, src, res, d, time, li = null) => [hex([H[h].byte]).toUpperCase(), N[n].id, t, src, res, d, time, li];
export const sortRows = (rows) => rows; // the callers give the rows in the order of the query

// The detail of the 422 (the proposal of the slice file section 6).
export function incompleteDetail(tag, upto, missing) {
  const k = missing.length;
  const shown = missing.slice(0, 100).join(', ');
  return `the sweep of ${tag} up to the log index ${upto} is incomplete: ${k} members of the bot set have no bot row: ${shown}${k > 100 ? `, and ${k - 100} more` : ''}`;
}
