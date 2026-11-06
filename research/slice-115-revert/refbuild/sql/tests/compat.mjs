// The SQL of the compat routes (Registry R-AP10, R-AP39, R-AP40, R-MX8, R-MX11; slices 115a and 115b) for the W1 cases of sql/tests/cases/compat/.
// The Worker embeds the same files (worker/sql/compat/*.sql). A statement `<name>` of the bot set is the text of `prefix.sql`, a newline, and the text of `<name>.sql`.
// The statements of the bot set take 3 parameters: ?1 the nightly id, ?2 the target code, ?3 the bound (a log index) or NULL for the log size now.
//   missing.sql  (115a)  the hash (BLOB `names.value`) of each member of the bot set at the bound that has no `bot` row on (?1, ?2), in byte order.
//   members.sql  (115b)  one row `members`: the count of the members.
// audit.sql (115b) is a statement of its own with ?1 the most pairs. The columns are in docs/slices/115b-compat-reads.md section 4.
// Env: COMPAT_SQL_DIR (another dir of the same files, for the private reference and its mutations).
// This file also has the random state and the independent JS reference of the bot set (R-MX11, R-MX16) that the cases m1 and m2 use.
import { readFileSync, existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..');

export function compatDir() { return process.env.COMPAT_SQL_DIR ?? join(root, 'worker', 'sql', 'compat'); }

function read(name) {
  const p = join(compatDir(), `${name}.sql`);
  if (!existsSync(p)) throw new Error(`the compat SQL is missing: ${p}`);
  return readFileSync(p, 'utf8');
}

// { missing, members, audit }: each is a function that reads its files when it is called, so a slice that has no `members.sql` yet fails only the cases that need it.
export const compatSql = {
  missing: () => `${read('prefix')}\n${read('missing')}`,
  members: () => `${read('prefix')}\n${read('members')}`,
  audit: () => read('audit'),
};

// A BLOB cell (a hash) as upper-case hex, so that node:sqlite (Uint8Array) and local D1 (an array of bytes) give one text.
export function hexOf(v) {
  if (v instanceof ArrayBuffer) v = new Uint8Array(v);
  return [...v].map((x) => x.toString(16).toUpperCase().padStart(2, '0')).join('');
}

export function makeRng(seed) {
  let s = seed;
  return (n) => {
    s = (s + 0x6d2b79f5) | 0; let t = Math.imul(s ^ (s >>> 15), 1 | s);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) % n;
  };
}

const DAY = 86400000;
const WINDOW = 47347200000; // R-MX11 row 3: 548 days in ms
const storedVersion = (M, m, p) => BigInt.asIntN(64, ((BigInt(M) << 48n) | (BigInt(m) << 32n) | (BigInt(p) << 16n) | 0xFFFFn) ^ (1n << 63n));
const hash32 = (k) => Array.from({ length: 32 }, (_, i) => (i === 0 ? k : (k * 7 + i) % 256));

// A random registry state: forms (groups), artifacts (kind app 0, package 1, platform 2), nightlies with 1 or 2 toolchains rows, releases.
// Every `log` leaf is there (R-SG8): the compiler leaves first, then one leaf for each release, in log order.
export function randomState(rnd) {
  const nf = 2 + rnd(4);
  const na = 4 + rnd(8);
  const artifacts = Array.from({ length: na }, (_, i) => ({ id: 1000 + i, hash: hash32(i + 1), kind: [0, 1, 1, 2][rnd(4)] }));
  const nights = [];
  const nn = 1 + rnd(3);
  for (let i = 0; i < nn; i++) {
    const day = 900 + rnd(700);
    nights.push({ id: 100 + i, tag: `t${i}`, published_at: day * DAY, targets: rnd(2) ? ['linux_x86_64'] : ['linux_x86_64', 'macos_arm64'] });
  }
  const releases = [];
  for (let f = 1; f <= nf; f++) {
    const count = 1 + rnd(4);
    const seen = new Set();
    for (let k = 0; k < count; k++) {
      const M = rnd(3), m = rnd(3), p = rnd(3);
      const key = `${M}.${m}.${p}`;
      if (seen.has(key)) continue;
      seen.add(key);
      releases.push({
        form: f, M, m, p, version: storedVersion(M, m, p), artifact: artifacts[rnd(na)].id,
        published_at: (700 + rnd(900)) * DAY + rnd(DAY), yanked: rnd(8) === 0 ? 1 : 0, withdrawn: rnd(10) === 0 ? 'deleted' : null,
      });
    }
  }
  // R-MX11 row 3: a release at the edge of the window of the first nightly (the edge is in, 1 ms before it is out, 1 ms after it is in).
  for (const r of releases) if (rnd(5) === 0) r.published_at = nights[0].published_at - WINDOW + [0, -1, 1][rnd(3)];
  let idx = 0;
  const leaves = [];
  for (const n of nights) for (const t of n.targets) leaves.push({ idx: ++idx, grp: `roc-lang/nightlies:${t}`, version: n.tag, hash: `sha256:${n.id}${t}` });
  for (const r of releases) { r.log_index = ++idx; leaves.push({ idx: r.log_index, grp: `g${r.form}`, version: `${r.M}.${r.m}.${r.p}`, hash: `H${r.log_index}` }); }
  return { nf, artifacts, nights, releases, leaves, log_size: idx };
}

// Writes the state with the triggers on: names, artifacts, log, toolchains, releases. The tables must be empty (`clearState`).
export async function insertState(b, st) {
  const list = [];
  const add = (sql, params = []) => list.push({ sql, params });
  for (let f = 1; f <= st.nf; f++) add('INSERT INTO names (id, kind, value) VALUES (?, 2, ?)', [f, `g${f}`]);
  for (const a of st.artifacts) {
    add(`INSERT INTO names (id, kind, value) VALUES (${a.id}, 1, X'${a.hash.map((x) => x.toString(16).padStart(2, '0')).join('')}')`);
    add(`INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (${a.id}, ${a.kind}, '[]', NULL, NULL, 1)`);
  }
  for (const l of st.leaves) add('INSERT INTO log (idx, grp, version, hash, time) VALUES (?, ?, ?, ?, ?)', [l.idx, l.grp, l.version, l.hash, 1790000000000]);
  let i = 0;
  for (const n of st.nights) for (const t of n.targets) {
    add('INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, published_at, log_index) VALUES (?, ?, ?, ?, ?, ?, ?)', [n.id, t, n.tag, 'a', `${n.id}${t}`, n.published_at, ++i]);
  }
  for (const r of st.releases) {
    add(`INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (${r.log_index}, ${r.form}, ${r.version.toString()}, '', ${r.artifact}, NULL, 'u', NULL, NULL, ${r.published_at}, ${r.yanked}, ${r.withdrawn === null ? 'NULL' : `'${r.withdrawn}'`}, NULL)`);
  }
  await b.batch(list);
}

export async function clearState(b) {
  await b.batch(['sweeps', 'transitions', 'compat', 'releases', 'toolchains', 'log', 'artifacts', 'names'].map((t) => ({ sql: `DELETE FROM ${t}`, params: [] })));
}

// The bot set of R-MX11 at a bound for a nightly id, from the rows, with no SQL: a Set of artifact ids.
// The series is (M) for M above 0 and (0, m) for M = 0 (Design 4.1, R-ID1), from the generated parts, not from the bits of the stored key.
export function refMembers(st, nightly, bound) {
  const live = st.releases.filter((r) => r.log_index <= bound && r.yanked === 0 && r.withdrawn === null);
  const kind = new Map(st.artifacts.map((a) => [a.id, a.kind]));
  const series = (r) => (r.M > 0 ? `${r.M}` : `0.${r.m}`);
  const night = st.nights.find((n) => n.id === nightly);
  const members = new Set();
  for (const r of live) {
    if (![1, 2].includes(kind.get(r.artifact))) continue;
    if (live.some((o) => o.form === r.form && series(o) === series(r) && o.version > r.version)) continue;
    const inWindow = night !== undefined && r.published_at >= night.published_at - WINDOW;
    const newestOfForm = !live.some((o) => o.form === r.form && o.version > r.version);
    if (inWindow || newestOfForm) members.add(r.artifact);
  }
  return members;
}

export const hexOfArtifact = (st, id) => hexOf(new Uint8Array(st.artifacts.find((a) => a.id === id).hash));
