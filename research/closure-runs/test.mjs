// Do runs in a window give the client the same facts as all rows (Registry R-AP16, R-AP17, Resolution 4, R-EP2 to R-EP6)?
// Each case makes a random matrix, asks the SQL of schema.mjs for a random window, and compares the facts that the client
// gets in the window (real, inferred or unknown) with a reference that reads all rows. Local D1 and plain SQLite.
// Run: node test.mjs [sqlite] [cases]
// Mutations (each must fail): MUTATE=noexpand, nogap, nomerge, fault (schema.mjs).
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { execSync } from "node:child_process";
import { createRequire } from "node:module";
import { DatabaseSync } from "node:sqlite";
import { schema, epochsSql, runsSql, nearestSql, hintsSql } from "./schema.mjs";

const CASES = Number(process.argv.find((a) => /^\d+$/.test(a)) ?? 400);

function sqliteBackend() {
  const db = new DatabaseSync(":memory:");
  for (const s of schema) db.exec(s);
  return {
    name: "sqlite",
    async run(sql, p = []) { db.prepare(sql).run(...p); },
    async insert(table, rows) {
      if (!rows.length) return;
      const st = db.prepare(`INSERT INTO ${table} VALUES (${rows[0].map(() => "?").join(", ")})`);
      db.exec("BEGIN"); for (const r of rows) st.run(...r); db.exec("COMMIT");
    },
    async all(sql, p = []) { return db.prepare(sql).all(...p); },
    async close() { db.close(); },
  };
}
async function d1Backend() {
  const dir = process.env.WRANGLER ?? `${execSync("npm root -g").toString().trim()}/wrangler`;
  const { getPlatformProxy } = createRequire(import.meta.url)(dir);
  const persist = mkdtempSync(join(tmpdir(), "closure-runs-"));
  const proxy = await getPlatformProxy({ configPath: new URL("wrangler.toml", import.meta.url).pathname, persist: { path: persist } });
  const db = proxy.env.DB;
  for (const s of schema) await db.prepare(s).run();
  return {
    name: "d1",
    async run(sql, p = []) { await db.prepare(sql).bind(...p).run(); },
    async insert(table, rows) {
      for (let i = 0; i < rows.length; i += 200) {
        const part = rows.slice(i, i + 200);
        await db.batch(part.map((r) => db.prepare(`INSERT INTO ${table} VALUES (${r.map(() => "?").join(", ")})`).bind(...r)));
      }
    },
    async all(sql, p = []) { return (await db.prepare(sql).bind(...p).all()).results; },
    async close() { await proxy.dispose(); rmSync(persist, { recursive: true, force: true }); },
  };
}

let seed = 11;
const rnd = (n) => { seed = (seed + 0x6d2b79f5) | 0; let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
  t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) % n; };

const TARGETS = ["any", "t1", "t2"];
const code = (x) => x === "pass" || x === "fail";
const tag = (i) => `nightly-${String(i).padStart(3, "0")}`;

// A random matrix. Results come in segments, so runs and epochs exist, with gaps, faults and both sources.
function randomState() {
  const n = 8 + rnd(40), hashes = 3 + rnd(6);
  const D = Array.from({ length: n }, (_, i) => tag(i));
  const compat = [];
  for (let h = 0; h < hashes; h++) for (const t of TARGETS) {
    if (t !== "any" && rnd(2)) continue;
    for (const source of ["bot", "author"]) {
      let i = rnd(n), cur;
      const sparse = source === "author" ? 3 : 0;
      while (i < n) {
        const len = 1 + rnd(8), k = rnd(10);
        cur = k < 4 ? ["pass", null] : k < 6 ? ["fail", `d${rnd(2)}`] : k < 7 ? ["crash", null] : k < 8 ? ["hang", null] : null;
        for (let j = i; j < Math.min(n, i + len); j++) if (cur && (!sparse || rnd(sparse) === 0)) compat.push([`h${h}`, D[j], t, source, ...cur]);
        i += len;
      }
    }
  }
  // Swept compilers for each target, and the transitions of R-MX12 from all `bot` rows.
  const swept = Object.fromEntries(TARGETS.map((t) => [t, D.map(() => rnd(5) !== 0)]));
  const bot = new Map(compat.filter((c) => c[3] === "bot").map((c) => [`${c[0]}|${c[1]}|${c[2]}`, c[4]]));
  const transitions = [];
  for (const t of TARGETS) for (let i = 1; i < n; i++) {
    if (!swept[t][i] || !swept[t][i - 1]) continue;
    let compared = 0, changed = 0;
    for (let h = 0; h < hashes; h++) {
      const a = bot.get(`h${h}|${D[i - 1]}|${t}`), b = bot.get(`h${h}|${D[i]}|${t}`);
      if (code(a) && code(b)) { compared++; if (a !== b) changed++; }
    }
    transitions.push([D[i], t, D[i - 1], compared, changed]);
  }
  const hints = [];
  for (let k = 0; k < rnd(20); k++) hints.push([`h${rnd(hashes)}`, D[rnd(n)], TARGETS[rnd(3)], `v0.${rnd(3)}.0`, rnd(4), rnd(4), rnd(2)]);
  const uniq = new Map(hints.map((x) => [x.slice(0, 4).join("|"), x]));
  const closure = Array.from({ length: hashes }, (_, h) => `h${h}`).filter(() => rnd(4) !== 0);
  if (!closure.length) closure.push("h0");
  const lo = rnd(n), w = rnd(3) === 0 ? [lo, lo] : rnd(3) === 0 ? [lo, null] : [lo, Math.min(n - 1, lo + rnd(10))];
  return { D, compat, transitions, hints: [...uniq.values()], closure, window: w };
}

// Merged facts: key `hash|target` -> Map(ord -> {result, digest}). A `bot` row wins over an `author` row (R-EF3).
function merge(rows, ordOf) {
  const out = new Map();
  for (const r of [...rows].sort((a, b) => (a.source === "bot") - (b.source === "bot"))) {
    const k = `${r.hash}|${r.target}`;
    if (!out.has(k)) out.set(k, new Map());
    out.get(k).set(ordOf(r), { result: r.result, digest: r.digest });
  }
  return out;
}

// The client part of R-EP3 to R-EP6, the same for both inputs. `cutA(t, i)`: the transition into compiler i of target t is
// not covered, or is a boundary of the registry. `known(t, i)`: the client has all of its closure facts on i.
function infer(facts, n, cutA, known, window) {
  const out = {};
  const targets = new Set([...facts.keys()].map((k) => k.split("|")[1]));
  for (const t of targets) {
    const keys = [...facts.keys()].filter((k) => k.endsWith(`|${t}`));
    const epoch = [];
    let e = 0;
    for (let i = 0; i < n; i++) {
      let cut = i === 0 || cutA(t, i);
      if (!cut && known(t, i) && known(t, i - 1)) {
        let ch = 0;
        for (const k of keys) { const a = facts.get(k).get(i - 1), b = facts.get(k).get(i);
          if (a && b && code(a.result) && code(b.result) && a.result !== b.result) ch++; }
        if (ch >= 2) cut = true;
      }
      if (cut) e++;
      epoch.push(e);
    }
    const [lo, hi] = window;
    for (const k of keys) for (let r = lo; r <= hi; r++) {
      const f = facts.get(k);
      const real = f.get(r);
      if (real) { out[`${k}|${r}`] = `real ${real.result} ${real.digest ?? ""}`; continue; }
      const got = new Set();
      for (const [i, x] of f) if (epoch[i] === epoch[r] && code(x.result)) got.add(x.result);
      let b = null, a = null;
      for (const [i, x] of f) if (code(x.result)) {
        if (i < r && (b === null || i > b[0])) b = [i, x.result];
        if (i > r && (a === null || i < a[0])) a = [i, x.result];
      }
      if (b && a && b[1] === a[1]) got.add(b[1]);
      const v = got.size === 1 ? `inferred ${[...got][0]}` : "unknown";
      if (v !== "unknown") out[`${k}|${r}`] = v;
    }
  }
  return out;
}

function reference(st) {
  const ord = new Map(st.D.map((d, i) => [d, i]));
  const rows = st.compat.filter((c) => st.closure.includes(c[0]))
    .map(([hash, nightly, target, source, result, digest]) => ({ hash, nightly, target, source, result, digest }));
  const facts = merge(rows, (r) => ord.get(r.nightly));
  const tr = new Map(st.transitions.map((x) => [`${x[0]}|${x[1]}`, x]));
  const cutA = (t, i) => { const x = tr.get(`${st.D[i]}|${t}`); return !x || x[4] >= 1; };
  const [lo, hi] = [st.window[0], st.window[1] ?? st.D.length - 1];
  return infer(facts, st.D.length, cutA, () => true, [lo, hi]);
}

async function fromAnswer(db, st) {
  const ord = new Map(st.D.map((d, i) => [d, i]));
  const p = [JSON.stringify(st.closure), st.D[st.window[0]], st.window[1] === null ? null : st.D[st.window[1]]];
  const epochs = await db.all(epochsSql, p), runs = await db.all(runsSql, p), nearest = await db.all(nearestSql, p);
  // E for each target is the span of the window and of the epochs that it touches. The client has every fact in E.
  const [lo, hi] = [st.window[0], st.window[1] ?? st.D.length - 1];
  const E = {};
  for (const t of TARGETS) {
    let a = lo, b = hi;
    for (const e of epochs) if (e.target === t) { const f = ord.get(e.from), to = ord.get(e.to);
      if (f <= hi && to >= lo) { a = Math.min(a, f); b = Math.max(b, to); } }
    E[t] = [a, b];
  }
  const rows = [];
  for (const r of runs) for (let i = ord.get(r.from); i <= ord.get(r.to); i++) rows.push({ ...r, ord: i });
  for (const x of nearest) rows.push({ ...x, ord: ord.get(x.nightly) });
  const facts = merge(rows, (r) => r.ord);
  const same = (t, i) => epochs.some((e) => e.target === t && ord.get(e.from) <= i - 1 && i <= ord.get(e.to));
  const known = (t, i) => i >= E[t][0] && i <= E[t][1];
  return infer(facts, st.D.length, (t, i) => !same(t, i), known, [lo, hi]);
}

async function hintsCheck(db, st) {
  const ord = new Map(st.D.map((d, i) => [d, i]));
  const [lo, hi] = [st.window[0], st.window[1] ?? st.D.length - 1];
  const want = {};
  for (const [h, n, t, , p, f, c] of st.hints) if (st.closure.includes(h) && ord.get(n) >= lo && ord.get(n) <= hi) {
    const k = `${h}|${n}|${t}`; want[k] = (want[k] ?? [0, 0, 0]).map((v, i) => v + [p, f, c][i]); }
  const got = {};
  for (const r of await db.all(hintsSql, [JSON.stringify(st.closure), st.D[st.window[0]], st.window[1] === null ? null : st.D[st.window[1]]]))
    got[`${r.hash}|${r.nightly}|${r.target}`] = [r.pass_count, r.fail_count, r.crash_count];
  return JSON.stringify(Object.entries(want).sort()) === JSON.stringify(Object.entries(got).sort());
}

const diff = (a, b) => [...new Set([...Object.keys(a), ...Object.keys(b)])].filter((k) => a[k] !== b[k]).map((k) => `${k}: want ${a[k] ?? "unknown"}, got ${b[k] ?? "unknown"}`);

async function main() {
  const backends = process.argv.includes("sqlite") ? [sqliteBackend] : [d1Backend, sqliteBackend];
  let failed = 0;
  for (const make of backends) {
    const db = await make();
    seed = 11; // the same cases on each backend
    let bad = 0, badHints = 0, inferredSeen = 0, held = 0;
    for (let c = 0; c < CASES; c++) {
      for (const t of ["toolchains", "compat", "transitions", "compat_hints"]) await db.run(`DELETE FROM ${t}`);
      const st = randomState();
      await db.insert("toolchains", st.D.map((d, i) => [d, 1000 + i]));
      await db.insert("compat", st.compat);
      await db.insert("transitions", st.transitions);
      await db.insert("compat_hints", st.hints);
      const want = reference(st), got = await fromAnswer(db, st);
      inferredSeen += Object.values(want).filter((v) => v.startsWith("inferred")).length;
      if (st.window[0] === st.window[1]) held++;
      const d = diff(want, got);
      if (d.length) { if (bad++ < 3) console.log(`  case ${c} window ${st.window}: ${d.slice(0, 3).join("; ")}`); }
      if (!(await hintsCheck(db, st))) badHints++;
    }
    console.log(`${db.name}: ${CASES - bad} of ${CASES} cases equal (${held} with one compiler, ${inferredSeen} inferred facts), hints ${CASES - badHints} of ${CASES}`);
    failed += bad + badHints;
    await db.close();
  }
  process.exit(failed ? 1 : 0);
}
await main();
