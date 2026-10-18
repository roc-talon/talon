// Size and time of the closure answer: all rows (the old R-AP17) against runs in a window. Plain SQLite, and local D1
// with `d1`. Run: node bench.mjs [years] [d1]
// The matrix: 300 compilers a year. 25 packages (target `any`) and 1 platform (target `any` and 6 build targets) in the
// closure, and 300 other hashes. The bot checks each hash on each compiler while it is a member (18 months). About 1
// compiler in 20 breaks code: each hash then changes its result with a chance of 30%. Each compiler is swept.
import { DatabaseSync } from "node:sqlite";
import { execSync } from "node:child_process";
import { createRequire } from "node:module";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { schema, epochsSql, runsSql, nearestSql, hintsSql, allRowsSql } from "./schema.mjs";

const YEARS = Number(process.argv.find((a) => /^\d+$/.test(a)) ?? 3);
const N = 300 * YEARS, MEMBER = 450;
let seed = 5;
const rnd = (n) => { seed = (seed + 0x6d2b79f5) | 0; let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
  t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) % n; };
const D = Array.from({ length: N }, (_, i) => `nightly-${String(i).padStart(4, "0")}-abcdef0`);
const hashOf = (i) => `${String(i).padStart(4, "0")}`.padEnd(44, "x"); // a base58 hash is 44 characters
const closure = Array.from({ length: 26 }, (_, i) => hashOf(i));
const breaks = new Set(D.map((_, i) => i).filter(() => rnd(20) === 0));
const compat = [], bot = new Map();
for (let h = 0; h < 326; h++) {
  const start = rnd(Math.max(1, N - 30)), targets = h === 25 ? ["any", "linux_x86_64", "linux_arm64", "macos_arm64", "macos_x86_64", "windows_x86_64", "windows_arm64"] : ["any"];
  for (const t of targets) {
    let res = "pass";
    for (let i = start; i < Math.min(N, start + MEMBER); i++) {
      if (breaks.has(i) && rnd(10) < 3) res = res === "pass" ? "fail" : "pass";
      compat.push([hashOf(h), D[i], t, "bot", res, res === "fail" ? "d1" : null]);
      bot.set(`${h}|${i}|${t}`, res);
    }
  }
}
const transitions = [];
for (const t of ["any", "linux_x86_64", "linux_arm64", "macos_arm64", "macos_x86_64", "windows_x86_64", "windows_arm64"]) for (let i = 1; i < N; i++) {
  let compared = 0, changed = 0;
  for (let h = 0; h < 326; h++) { const a = bot.get(`${h}|${i - 1}|${t}`), b = bot.get(`${h}|${i}|${t}`); if (a && b) { compared++; if (a !== b) changed++; } }
  transitions.push([D[i], t, D[i - 1], compared, changed]);
}

async function backend(d1) {
  if (!d1) {
    const db = new DatabaseSync(":memory:");
    for (const s of schema) db.exec(s);
    const ins = (t, rows) => { const st = db.prepare(`INSERT INTO ${t} VALUES (${rows[0].map(() => "?").join(", ")})`); db.exec("BEGIN"); for (const r of rows) st.run(...r); db.exec("COMMIT"); };
    return { name: "sqlite", ins, all: async (sql, p) => db.prepare(sql).all(...p), close: async () => db.close() };
  }
  const dir = process.env.WRANGLER ?? `${execSync("npm root -g").toString().trim()}/wrangler`;
  const { getPlatformProxy } = createRequire(import.meta.url)(dir);
  const persist = mkdtempSync(join(tmpdir(), "closure-runs-"));
  const proxy = await getPlatformProxy({ configPath: new URL("wrangler.toml", import.meta.url).pathname, persist: { path: persist } });
  const db = proxy.env.DB;
  for (const s of schema) await db.prepare(s).run();
  const ins = async (t, rows) => { for (let i = 0; i < rows.length; i += 500) await db.batch(rows.slice(i, i + 500).map((r) => db.prepare(`INSERT INTO ${t} VALUES (${r.map(() => "?").join(", ")})`).bind(...r))); };
  return { name: "d1 (local)", ins, d1: db, all: async (sql, p) => (await db.prepare(sql).bind(...p).all()).results,
    close: async () => { await proxy.dispose(); rmSync(persist, { recursive: true, force: true }); } };
}

const db = await backend(process.argv.includes("d1"));
await db.ins("toolchains", D.map((d, i) => [d, 1000 + i]));
await db.ins("compat", compat);
await db.ins("transitions", transitions);
const H = JSON.stringify(closure);
async function time(f) { const t = performance.now(); const r = await f(); return [r, performance.now() - t]; }
console.log(`${db.name}, ${YEARS} years: ${N} compilers, ${compat.length} compat rows in all\n`);
console.log("| Answer | Rows | JSON bytes | Query ms |\n| --- | --- | --- | --- |");
const [all, ta] = await time(() => db.all(allRowsSql, [H]));
console.log(`| All rows of the closure (old) | ${all.length} | ${JSON.stringify(all).length} | ${ta.toFixed(0)} |`);
for (const [name, lo, hi] of [["One compiler (held nightly)", D[N - 10], D[N - 10]], ["Last 30 compilers", D[N - 30], null], ["All compilers (free nightly)", null, null]]) {
  let rows = 0, bytes = 0, ms = 0;
  const each = [];
  for (const sql of [epochsSql, runsSql, nearestSql, hintsSql]) { const [r, t] = await time(() => db.all(sql, [H, lo, hi])); rows += r.length; bytes += JSON.stringify(r).length; ms += t; each.push(t.toFixed(0)); }
  if (process.env.EACH) console.log(each.join(" "));
  console.log(`| ${name} | ${rows} | ${bytes} | ${ms.toFixed(0)} |`);
}
await db.close();
