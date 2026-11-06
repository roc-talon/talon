// R-AP17, R-AP42, R-AP58, R-AP60, R-MX16, R-RE13, R-AP18: the random reference of research/closure-runs/test.mjs, ported to the real schema (slice 110).
// R-AP17: epochs, runs, nearest and hints of a random matrix in a random window W must give the client the same facts in W (real, inferred or
// unknown, Resolution 4 R-EP2 to R-EP6) as all rows. R-MX16: the order of compilers is over the distinct nightlies of `toolchains` (1 to 3 rows
// each, one published_at): the date (id >> 28), then t, then the id. The generator makes nightlies of one date with t out of id order, and t out of
// date order, so an order by the id only or by t only gives other facts. A compat row on a nightly with no toolchains row has no place in the
// order (R-MX16), and the reference ignores it. R-RE13 row 4: the sources are sent as runs; only `nearest` merges them (bot over author, R-EF3).
// R-AP41 row 2: the hashes go as one JSON parameter with 64-bit ids. R-AP18: the 12 statements run as one batch.
// The lists must be in the order of the slice file section 4 (R-AP24: one state gives one answer).
// Cases: 60 on sqlite and 8 on local D1 by default (the w1 budget of TW26: local D1 takes about 0.14 s a case), SLOW=1 gives 400 on each, CLOSURE_CASES=<n> sets the count.
import { runBatch, params } from '../../../closure.mjs';

const casesOf = (backend) => Number(process.env.CLOSURE_CASES ?? (process.env.SLOW === '1' ? 400 : backend === 'd1' ? 8 : 60));

let seed = 11;
const rnd = (n) => {
  seed = (seed + 0x6d2b79f5) | 0; let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
  t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) % n;
};
const TARGETS = [[0, 'any'], [7, 'x64musl'], [24, 'arm64linux']];
const HOSTS = ['linux_x86_64', 'macos_apple_silicon', 'windows_x86_64'];
const code = (x) => x === 0 || x === 1;
const hex2 = (n) => n.toString(16).toUpperCase().padStart(2, '0');
const two28 = 2 ** 28;

function randomState() {
  const n = 8 + rnd(40), nh = 3 + rnd(6);
  // Nightlies. The date moves on by 0, 1 or 2 days. t is near the date, but can be a day before it, and can be equal to the t of the one before.
  const nights = [], ids = new Set();
  let day = 20454, lastT = 0;
  for (let i = 0; i < n; i++) {
    if (i > 0 && rnd(3) !== 0) day += 1 + rnd(2);
    let sha, id;
    do { sha = rnd(two28); id = day * two28 + sha; } while (ids.has(id));
    ids.add(id);
    const t = i > 0 && rnd(4) === 0 ? lastT : day * 86400000 + (rnd(4) === 0 ? -rnd(86400000) : rnd(86400000));
    lastT = t;
    const date = new Date(day * 86400000).toISOString().slice(0, 10);
    nights.push({ id, day, t, tag: `nightly-${date}-${sha.toString(16).padStart(7, '0')}`, hosts: HOSTS.filter((_, k) => k === 0 || rnd(2) === 0) });
  }
  // The reference order of R-MX16.
  const D = [...nights].sort((a, b) => a.day - b.day || a.t - b.t || a.id - b.id);
  // A nightly with no toolchains row: compat rows on it are not facts.
  const phantom = rnd(3) === 0 ? { id: (day + 1) * two28 + 5 } : null;
  const hashes = Array.from({ length: nh }, (_, h) => {
    const bytes = Array.from({ length: 32 }, (_, k) => (k === 0 ? 16 * h + rnd(16) : rnd(256)));
    const big = 4611686018427387904n + BigInt(rnd(1000000000)) * 1024n + BigInt(h); // 2^62 + ..., above 2^53 (R-IK2)
    return { hx: bytes.map(hex2).join(''), id: (rnd(2) ? big : -big).toString() };
  });
  const compat = [];
  for (let h = 0; h < nh; h++) for (const [tc] of TARGETS) {
    if (tc !== 0 && rnd(2)) continue;
    for (const source of [0, 1]) {
      let i = rnd(n);
      const sparse = source === 1 ? 3 : 0;
      while (i < n) {
        const len = 1 + rnd(8), k = rnd(10);
        const cur = k < 4 ? [0, null] : k < 6 ? [1, `d${rnd(2)}`] : k < 7 ? [3, null] : k < 8 ? [2, null] : null;
        for (let j = i; j < Math.min(n, i + len); j++) if (cur && (!sparse || rnd(sparse) === 0)) compat.push({ h, ord: j, nightly: D[j].id, target: tc, source, result: cur[0], digest: cur[1] });
        i += len;
      }
    }
    if (phantom) compat.push({ h, ord: -1, nightly: phantom.id, target: tc, source: 0, result: rnd(2), digest: null });
  }
  const swept = Object.fromEntries(TARGETS.map(([t]) => [t, D.map(() => rnd(5) !== 0)]));
  const bot = new Map(compat.filter((c) => c.source === 0 && c.ord >= 0).map((c) => [`${c.h}|${c.ord}|${c.target}`, c.result]));
  const transitions = [];
  for (const [t] of TARGETS) for (let i = 1; i < n; i++) {
    if (!swept[t][i] || !swept[t][i - 1]) continue;
    let compared = 0, changed = 0;
    for (let h = 0; h < nh; h++) {
      const a = bot.get(`${h}|${i - 1}|${t}`), b = bot.get(`${h}|${i}|${t}`);
      if (code(a) && code(b)) { compared++; if (a !== b) changed++; }
    }
    transitions.push([D[i].id, t, D[i - 1].id, compared, changed]);
  }
  const hints = new Map();
  for (let k = 0; k < rnd(20); k++) {
    const x = { h: rnd(nh), ord: rnd(n), target: TARGETS[rnd(3)][0], tv: rnd(3), p: rnd(4), f: rnd(4), c: rnd(2) };
    hints.set(`${x.h}|${x.ord}|${x.target}|${x.tv}`, x);
  }
  if (phantom) hints.set('phantom', { h: 0, ord: -1, nightly: phantom.id, target: 0, tv: 9, p: 5, f: 0, c: 0 });
  const closure = Array.from({ length: nh }, (_, h) => h).filter(() => rnd(4) !== 0);
  if (!closure.length) closure.push(0);
  const lo = rnd(n);
  const w = rnd(3) === 0 ? [lo, lo] : rnd(3) === 0 ? [lo, null] : [lo, Math.min(n - 1, lo + rnd(10))];
  // An end that is no nightly of toolchains is the end of the domain on its side (R-AP60).
  const strange = rnd(10) === 0 ? (rnd(2) ? 'from' : 'to') : null;
  return { D, hashes, compat, transitions, hints: [...hints.values()], closure, window: w, strange, phantom };
}

async function load(b, st) {
  for (const t of ['toolchains', 'compat', 'transitions', 'compat_hints', 'names', 'artifacts']) await b.run(`DELETE FROM ${t}`, []);
  const insert = async (table, rows, cols = '') => {
    for (let i = 0; i < rows.length; i += 200) await b.run(`INSERT INTO ${table}${cols} VALUES ${rows.slice(i, i + 200).map((r) => `(${r.join(', ')})`).join(', ')}`, []);
  };
  const q = (s) => (s === null ? 'NULL' : `'${s}'`);
  let li = 0;
  await insert('toolchains', st.D.flatMap((d) => d.hosts.map((host) => [d.id, q(host), q(d.tag), q(`roc_nightly-${host}.tar.gz`), q('ab'.repeat(32)), 1000, d.t, ++li])), ' (nightly, target, tag, asset_name, sha256, size, published_at, log_index)');
  await insert('names', st.hashes.map((x) => [x.id, 1, `x'${x.hx}'`]));
  await insert('artifacts', st.hashes.map((x) => [x.id, 1, q('[]'), 'NULL', 'NULL', 1]));
  await insert('compat', st.compat.map((c) => [st.hashes[c.h].id, c.nightly, c.target, c.source, c.result, q(c.digest), 1, c.source === 1 ? 3 : 'NULL']));
  await insert('transitions', st.transitions);
  await insert('compat_hints', st.hints.map((x) => [st.hashes[x.h].id, x.nightly ?? st.D[x.ord].id, x.target, x.tv, x.p, x.f, x.c, 1, 2]));
}

const tname = Object.fromEntries(TARGETS);

// Merged facts: `hx|target` -> Map(ord -> {result, digest}). A bot row wins over an author row (R-EF3).
function merge(rows) {
  const out = new Map();
  for (const r of [...rows].sort((a, b) => (b.source === 0) - (a.source === 0) || 0).reverse()) {
    const k = `${r.hash}|${r.target}`;
    if (!out.has(k)) out.set(k, new Map());
    out.get(k).set(r.ord, { result: r.result, digest: r.digest });
  }
  return out;
}

// Resolution 4, R-EP3 to R-EP6, the client side (as research/closure-runs/test.mjs).
function infer(facts, n, cutA, known, window) {
  const out = {};
  const targets = new Set([...facts.keys()].map((k) => k.split('|')[1]));
  for (const t of targets) {
    const keys = [...facts.keys()].filter((k) => k.endsWith(`|${t}`));
    const epoch = [];
    let e = 0;
    for (let i = 0; i < n; i++) {
      let cut = i === 0 || cutA(t, i);
      if (!cut && known(t, i) && known(t, i - 1)) {
        let ch = 0;
        for (const k of keys) {
          const a = facts.get(k).get(i - 1), b = facts.get(k).get(i);
          if (a && b && code(a.result) && code(b.result) && a.result !== b.result) ch++;
        }
        if (ch >= 2) cut = true;
      }
      if (cut) e++;
      epoch.push(e);
    }
    const [lo, hi] = window;
    for (const k of keys) for (let r = lo; r <= hi; r++) {
      const f = facts.get(k);
      const real = f.get(r);
      if (real) { out[`${k}|${r}`] = `real ${real.result} ${real.digest ?? ''}`; continue; }
      const got = new Set();
      for (const [i, x] of f) if (epoch[i] === epoch[r] && code(x.result)) got.add(x.result);
      let bb = null, aa = null;
      for (const [i, x] of f) if (code(x.result)) {
        if (i < r && (bb === null || i > bb[0])) bb = [i, x.result];
        if (i > r && (aa === null || i < aa[0])) aa = [i, x.result];
      }
      if (bb && aa && bb[1] === aa[1]) got.add(bb[1]);
      if (got.size === 1) out[`${k}|${r}`] = `inferred ${[...got][0]}`;
    }
  }
  return out;
}

function windowOf(st) {
  const n = st.D.length;
  return [st.strange === 'from' ? 0 : st.window[0], st.strange === 'to' || st.window[1] === null ? n - 1 : st.window[1]];
}

function reference(st) {
  const rows = st.compat.filter((c) => c.ord >= 0 && st.closure.includes(c.h))
    .map((c) => ({ hash: st.hashes[c.h].hx, target: tname[c.target], source: c.source, result: c.result, digest: c.digest, ord: c.ord }));
  const tr = new Map(st.transitions.map((x) => [`${x[0]}|${tname[x[1]]}`, x]));
  const cutA = (t, i) => { const x = tr.get(`${st.D[i].id}|${t}`); return !x || x[4] >= 1; };
  return infer(merge(rows), st.D.length, cutA, () => true, windowOf(st));
}

const cmp = (a, b) => (a < b ? -1 : a > b ? 1 : 0);
function sorted(list, key) {
  for (let i = 1; i < list.length; i++) {
    const a = key(list[i - 1]), b = key(list[i]);
    for (let k = 0; k < a.length; k++) { const c = cmp(a[k], b[k]); if (c < 0) break; if (c > 0) return false; }
  }
  return true;
}

async function fromAnswer(b, st) {
  const ord = new Map(st.D.map((d, i) => [d.tag, i]));
  const ids = st.closure.map((h) => st.hashes[h].id);
  const from = st.strange === 'from' ? 12345 : st.D[st.window[0]].id;
  const to = st.strange === 'to' ? 12345 : st.window[1] === null ? null : st.D[st.window[1]].id;
  const ans = await runBatch(b, params('[]', `[${ids.join(',')}]`, from, to));
  const problems = [];
  if (!sorted(ans.epochs, (e) => [e.target, ord.get(e.from)])) problems.push('epochs are not in the order (target, from)');
  if (!sorted(ans.runs, (r) => [r.hash, r.target, r.source, ord.get(r.from)])) problems.push('runs are not in the order (hash, target, source, from)');
  if (!sorted(ans.nearest, (x) => [x.hash, x.target, x.side === 'after' ? 1 : 0])) problems.push('nearest is not in the order (hash, target, before first)');
  if (!sorted(ans.hints, (x) => [x.hash, ord.get(x.nightly), x.target])) problems.push('hints are not in the order (hash, nightly, target)');
  const [lo, hi] = windowOf(st);
  const E = {};
  for (const [, t] of TARGETS) {
    let a = lo, z = hi;
    for (const e of ans.epochs) if (e.target === t) {
      const f = ord.get(e.from), to2 = ord.get(e.to);
      if (f <= hi && to2 >= lo) { a = Math.min(a, f); z = Math.max(z, to2); }
    }
    E[t] = [a, z];
  }
  const rows = [];
  for (const r of ans.runs) for (let i = ord.get(r.from); i <= ord.get(r.to); i++) rows.push({ hash: r.hash, target: r.target, source: r.source, result: r.result, digest: r.error_digest, ord: i });
  for (const x of ans.nearest) rows.push({ hash: x.hash, target: x.target, source: x.source, result: x.result, digest: x.error_digest, ord: ord.get(x.nightly) });
  const same = (t, i) => ans.epochs.some((e) => e.target === t && ord.get(e.from) <= i - 1 && i <= ord.get(e.to));
  const known = (t, i) => i >= E[t][0] && i <= E[t][1];
  const facts = infer(merge(rows), st.D.length, (t, i) => !same(t, i), known, [lo, hi]);
  // The hints of W, summed over the Talon versions. A hint on a nightly with no toolchains row is not in W.
  const want = {};
  for (const x of st.hints) if (x.ord >= lo && x.ord <= hi && st.closure.includes(x.h)) {
    const k = `${st.hashes[x.h].hx}|${st.D[x.ord].tag}|${tname[x.target]}`;
    want[k] = (want[k] ?? [0, 0, 0]).map((v, i) => v + [x.p, x.f, x.c][i]);
  }
  const got = {};
  for (const r of ans.hints) got[`${r.hash}|${r.nightly}|${r.target}`] = [r.pass_count, r.fail_count, r.crash_count];
  if (JSON.stringify(Object.entries(want).sort()) !== JSON.stringify(Object.entries(got).sort())) problems.push(`hints differ: want ${JSON.stringify(want)}, got ${JSON.stringify(got)}`);
  return { facts, problems };
}

const diff = (a, b) => [...new Set([...Object.keys(a), ...Object.keys(b)])].filter((k) => a[k] !== b[k]).map((k) => `${k}: want ${a[k] ?? 'unknown'}, got ${b[k] ?? 'unknown'}`);

export default async function (b) {
  const CASES = casesOf(b.name);
  seed = 11; // the same cases on each backend
  const fails = [];
  let bad = 0, inferred = 0, held = 0;
  for (let c = 0; c < CASES; c++) {
    const st = randomState();
    await load(b, st);
    const want = reference(st);
    let got;
    try { got = await fromAnswer(b, st); } catch (e) { fails.push(`case ${c}: ${String(e.message ?? e).slice(0, 300)}`); break; }
    inferred += Object.values(want).filter((v) => v.startsWith('inferred')).length;
    if (st.window[0] === st.window[1]) held++;
    const d = diff(want, got.facts).concat(got.problems);
    if (d.length && bad++ < 3) fails.push(`case ${c} window ${st.window} ${st.strange ?? ''}: ${d.slice(0, 3).join('; ')}`);
  }
  if (process.env.VERBOSE === '1') console.log(`    ${b.name}: ${CASES - bad} of ${CASES} cases equal (${held} with one compiler, ${inferred} inferred facts)`);
  if (bad) fails.push(`${bad} of ${CASES} cases differ (${held} with one compiler, ${inferred} inferred facts in the reference)`);
  return fails;
}
