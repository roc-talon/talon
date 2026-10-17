// Prototype of the semver order key (Registry R-IK5, proposed roc-semver feature). Parts are BigInt.
// Layout of the U64 key, high to low: major 16 bits, minor 16, patch 16, pre-release code 16.

const MAX = 0xffffn;

// A version: { major, minor, patch, pre: [identifier strings], build: [..] }. Parse is minimal (semver 2.0.0 text).
export function parse(text) {
  const m = /^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-([0-9A-Za-z.-]+))?(?:\+([0-9A-Za-z.-]+))?$/.exec(text);
  if (!m) return null;
  return { major: BigInt(m[1]), minor: BigInt(m[2]), patch: BigInt(m[3]), pre: m[4] ? m[4].split(".") : [], build: m[5] ? m[5].split(".") : [] };
}

// Semver 2.0.0 section 11 precedence: -1, 0, 1. Build metadata is ignored.
const isNum = (s) => /^\d+$/.test(s);
export function compare(a, b) {
  for (const k of ["major", "minor", "patch"]) if (a[k] !== b[k]) return a[k] < b[k] ? -1 : 1;
  if (!a.pre.length || !b.pre.length) return a.pre.length === b.pre.length ? 0 : a.pre.length ? -1 : 1;
  for (let i = 0; i < Math.max(a.pre.length, b.pre.length); i++) {
    const x = a.pre[i], y = b.pre[i];
    if (x === undefined) return -1;
    if (y === undefined) return 1;
    if (x === y) continue;
    if (isNum(x) && isNum(y)) return BigInt(x) < BigInt(y) ? -1 : 1;
    if (isNum(x) !== isNum(y)) return isNum(x) ? -1 : 1;
    return x < y ? -1 : 1;
  }
  return 0;
}

// Rank of a pre-release character in ASCII order, 0 for "no character": '-' 1, '0'-'9' 2-11, 'A'-'Z' 12-37, 'a'-'z' 38-63.
const rank = (c) => (c === undefined ? 0 : c === "-" ? 1 : c <= "9" ? 2 + (c.charCodeAt(0) - 48)
  : c <= "Z" ? 12 + (c.charCodeAt(0) - 65) : 38 + (c.charCodeAt(0) - 97));

// The pre-release code: 0xFFFF for no pre-release (a release comes after its pre-releases, semver 11.3).
// A numeric first identifier n: 0x0001 + min(n, 0x0FFE). An alphanumeric one: 0x1000 + 65 * rank(c1) + rank(c2).
// So numeric < alphanumeric (semver 11.4.3), and a code is never larger for a smaller first identifier.
export function preCode(pre) {
  if (!pre.length) return MAX;
  const id = pre[0];
  if (isNum(id)) return (MUTATE === "prenum" ? 0x3000n : 1n) + (BigInt(id) < 0xffen ? BigInt(id) : 0xffen);
  return 0x1000n + 65n * BigInt(rank(id[0])) + BigInt(rank(id[1]));
}

// MUTATE=nosat: a part above 0xFFFE only saturates itself, not the parts after it.
// MUTATE=prenum: a numeric first identifier gets a code above the alphanumeric codes (against semver 11.4.3).
const MUTATE = process.env.MUTATE ?? "";

// key: the U64. exact: the key alone gives the version back (each part below 0xFFFF, no pre-release, no build).
export function toKey(v) {
  const fields = [v.major, v.minor, v.patch, preCode(v.pre)];
  let sat = false;
  const out = fields.map((f, i) => {
    if (sat) return MAX;
    if (i < 3 && f >= MAX) { if (MUTATE !== "nosat") sat = true; return MAX; }
    return f;
  });
  const key = (out[0] << 48n) | (out[1] << 32n) | (out[2] << 16n) | out[3];
  return { key, exact: !sat && !v.pre.length && !v.build.length && fields.slice(0, 3).every((f) => f < MAX) };
}

export function fromKey(key) {
  const f = [key >> 48n, (key >> 32n) & MAX, (key >> 16n) & MAX, key & MAX];
  if (f[3] !== MAX || f.slice(0, 3).some((x) => x === MAX)) return null; // not exact
  return { major: f[0], minor: f[1], patch: f[2], pre: [], build: [] };
}

// Talon stores the U64 in a signed SQLite INTEGER with the top bit flipped, so the signed order is the key order.
export const stored = (key) => BigInt.asIntN(64, key ^ (1n << 63n));

// Key bounds of a caret range ^M.m.p (the range form that Talon uses most, Design 4.3): every version that matches has
// a key in [lo, hi]. The caller then checks each row with the real match (the key is only monotone, not exact).
export function caretBounds(v) {
  const upper = v.major > 0n ? { major: v.major + 1n, minor: 0n, patch: 0n }
    : v.minor > 0n ? { major: 0n, minor: v.minor + 1n, patch: 0n } : { major: 0n, minor: 0n, patch: v.patch + 1n };
  return { lo: toKey({ ...v, pre: [], build: [] }).key, hi: toKey({ ...upper, pre: [], build: [] }).key, upper };
}
export function caretMatches(req, v) {
  const { upper } = caretBounds(req);
  const lowOk = compare(v, { ...req, pre: [], build: [] }) >= 0;
  const highOk = compare(v, { ...upper, pre: [], build: [] }) < 0;
  return v.pre.length === 0 && lowOk && highOk; // no pre-release match (roc-semver Q6, Q12)
}
