// Property tests of the semver order key (key.mjs). Run: node test.mjs [runs]
// Mutations: MUTATE=nosat node test.mjs (S1, S4, S5 must fail), MUTATE=prenum node test.mjs (S1, S4 must fail)
import { DatabaseSync } from "node:sqlite";
import { parse, compare, toKey, fromKey, stored, caretBounds, caretMatches } from "./key.mjs";

const RUNS = Number(process.argv[2] ?? 200000);
let seed = 1;
// mulberry32: 32-bit integer steps (Math.imul), so no step goes above 2^53 and loses its low bits.
const rnd = (n) => { seed = (seed + 0x6d2b79f5) | 0; let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
  t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) % n; };
// Parts from a domain with the edges: small numbers, 0xFFFE, 0xFFFF, 0x10000, u32 max.
const EDGE = [0n, 1n, 2n, 9n, 10n, 0xfffen, 0xffffn, 0x10000n, 4294967295n];
const part = () => (rnd(3) === 0 ? EDGE[rnd(EDGE.length)] : BigInt(rnd(12)));
const IDS = ["alpha", "alpha4", "alpha10", "beta", "rc", "rc1", "a", "b", "A", "-", "0", "1", "4094", "4095", "99999", "x-y", "al"];
const ver = () => {
  const pre = rnd(2) ? [] : Array.from({ length: 1 + rnd(3) }, () => IDS[rnd(IDS.length)]);
  return { major: part(), minor: part(), patch: part(), pre, build: rnd(5) ? [] : ["b" + rnd(9)] };
};
// A version near v: one part or the pre-release changed. So pairs share large parts, and ranges get matches.
const near = (v) => {
  const w = { ...v, pre: [...v.pre], build: [] };
  const f = ["major", "minor", "patch", "pre"][rnd(4)];
  if (f === "pre") w.pre = rnd(2) ? [] : [IDS[rnd(IDS.length)]];
  else w[f] = rnd(2) ? part() : v[f] + BigInt(rnd(3));
  return w;
};
const show = (v) => `${v.major}.${v.minor}.${v.patch}${v.pre.length ? "-" + v.pre.join(".") : ""}${v.build.length ? "+" + v.build.join(".") : ""}`;

const out = [];
const check = (id, what, fail) => out.push({ id, what, fail });

// S1: monotone. a before b in semver precedence -> key(a) <= key(b). A key never says the wrong order.
let s1 = null, ties = 0, lt = 0;
for (let i = 0; i < RUNS && !s1; i++) {
  const a = ver(), b = i % 2 ? ver() : near(a), c = compare(a, b), ka = toKey(a).key, kb = toKey(b).key;
  if (c < 0 && ka > kb) s1 = `${show(a)} < ${show(b)} but key ${ka.toString(16)} > ${kb.toString(16)}`;
  if (c < 0) { lt++; if (ka === kb) ties++; }
}
check("S1", `monotone over ${RUNS} pairs (${lt} ordered, ${ties} key ties)`, s1);

// S2: exact keys. When exact is true, the key gives the version back, and two exact versions with one key are equal.
let s2 = null;
for (let i = 0; i < RUNS && !s2; i++) {
  const v = ver(), k = toKey(v);
  if (k.exact) { const back = fromKey(k.key); if (!back || compare(back, v) !== 0) s2 = `${show(v)} -> ${back && show(back)}`; }
  else if (!v.pre.length && !v.build.length && [v.major, v.minor, v.patch].every((p) => p < 0xffffn)) s2 = `${show(v)} not exact`;
}
check("S2", "exact keys round trip; a release with parts below 0xFFFF is exact", s2);

// S3: the examples of the question and of semver 11.4.
const chain = ["1.0.0-alpha", "1.0.0-alpha.1", "1.0.0-alpha.beta", "1.0.0-beta", "1.0.0-beta.2", "1.0.0-beta.11", "1.0.0-rc.1", "1.0.0"].map(parse);
let s3 = null;
for (let i = 1; i < chain.length; i++) if (toKey(chain[i - 1]).key > toKey(chain[i]).key) s3 = show(chain[i]);
const a4 = toKey(parse("1.2.3-alpha4")), b1 = toKey(parse("1.2.3-beta1")), r = toKey(parse("1.2.3"));
if (!(a4.key < b1.key && b1.key < r.key && !a4.exact && r.exact)) s3 = "alpha4 < beta1 < release";
check("S3", `semver 11.4 chain, 1.2.3-alpha4 < 1.2.3-beta1 < 1.2.3 (keys ${a4.key.toString(16)} ${b1.key.toString(16)} ${r.key.toString(16)})`, s3);

// S4: the stored value (top bit flipped) keeps the order in SQLite, which compares signed integers.
const db = new DatabaseSync(":memory:");
db.exec("CREATE TABLE v (k INTEGER NOT NULL, t TEXT NOT NULL) STRICT");
const ins = db.prepare("INSERT INTO v VALUES (?, ?)");
const sample = Array.from({ length: 3000 }, ver);
for (const v of sample) ins.run(stored(toKey(v).key), show(v));
const sorted = db.prepare("SELECT t FROM v ORDER BY k").all().map((x) => parse(x.t));
let s4 = null;
for (let i = 1; i < sorted.length; i++) if (compare(sorted[i - 1], sorted[i]) > 0 && toKey(sorted[i - 1]).key !== toKey(sorted[i]).key) s4 = `${show(sorted[i - 1])} before ${show(sorted[i])}`;
const ext = db.prepare("SELECT CAST(MIN(k) AS TEXT) lo, CAST(MAX(k) AS TEXT) hi FROM v").get();
check("S4", `ORDER BY the stored key agrees with precedence (min ${ext.lo}, max ${ext.hi})`, s4);

// S5: caret bounds are a superset: each version that matches ^req has its key in [lo, hi].
let s5 = null, inside = 0, matched = 0;
for (let i = 0; i < RUNS && !s5; i++) {
  const req = { ...ver(), pre: [], build: [] }, v = near(req), { lo, hi } = caretBounds(req), k = toKey(v).key;
  const m = caretMatches(req, v);
  if (m) matched++;
  if (k >= lo && k <= hi) inside++;
  if (m && (k < lo || k > hi)) s5 = `^${show(req)} matches ${show(v)} but key outside`;
}
check("S5", `caret key bounds are a superset (${matched} matches, ${inside} keys inside)`, s5);

let failed = 0;
for (const r of out) { if (r.fail) failed++; console.log(`${r.fail ? "FAIL" : "ok  "}\t${r.id}\t${r.what}${r.fail ? "\t" + r.fail : ""}`); }
process.exit(failed ? 1 : 0);
