// Tests the all-or-nothing sweep write (R-MX4) and the publish batch (Q27) on local D1 (Miniflare) and on plain SQLite.
// Run: node test.mjs            (both backends)
//      node test.mjs sqlite     (plain SQLite only)
//      MUTATE=noguard node test.mjs   (no guard triggers: the guard cases must fail, exit code 1)
// Local D1 comes from the global wrangler install (getPlatformProxy), or from $WRANGLER (a path to the wrangler package).
import { readFileSync, mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { execSync } from "node:child_process";
import { createRequire } from "node:module";
import { DatabaseSync } from "node:sqlite";

const schema = readFileSync(new URL("schema.sql", import.meta.url), "utf8")
  .split(/^;;$/m).map((s) => s.replace(/^--.*$/gm, "").trim()).filter(Boolean)
  // MUTATE=noguard drops the 3 guard triggers, to show that the cases catch a schema with no guard.
  .filter((s) => process.env.MUTATE !== "noguard" || !/TRIGGER (sweeps_guard_insert|sweeps_guard_update|releases_label_conflict)/.test(s));

// One backend = { batch(list of [sql, params]) -> throws on failure, all(sql, params) -> rows }.
function sqliteBackend() {
  const db = new DatabaseSync(":memory:");
  for (const s of schema) db.exec(s);
  return {
    name: "sqlite",
    async batch(stmts) {
      db.exec("BEGIN");
      try { for (const [sql, p] of stmts) db.prepare(sql).run(...p); db.exec("COMMIT"); }
      catch (e) { db.exec("ROLLBACK"); throw e; }
    },
    async all(sql, p = []) { return db.prepare(sql).all(...p); },
    async close() { db.close(); },
  };
}

async function d1Backend() {
  // Local D1 (workerd, SQLite in a Durable Object) through wrangler. $WRANGLER overrides the path of the package.
  const dir = process.env.WRANGLER ?? `${execSync("npm root -g").toString().trim()}/wrangler`;
  const { getPlatformProxy } = createRequire(import.meta.url)(dir);
  const persist = mkdtempSync(join(tmpdir(), "d1-sweep-"));
  const proxy = await getPlatformProxy({ configPath: new URL("wrangler.toml", import.meta.url).pathname, persist: { path: persist } });
  const db = proxy.env.DB;
  const mf = { dispose: async () => { await proxy.dispose(); rmSync(persist, { recursive: true, force: true }); } };
  for (const s of schema) await db.prepare(s).run();
  return {
    name: "d1",
    async batch(stmts) { await db.batch(stmts.map(([sql, p]) => db.prepare(sql).bind(...p))); },
    async all(sql, p = []) { return (await db.prepare(sql).bind(...p).all()).results; },
    async close() { await mf.dispose(); },
  };
}

// The statements that one request makes. The Worker builds them, then sends them as one batch.
const row = (hash, n, t, src = "bot") =>
  ["INSERT OR IGNORE INTO compat (hash, nightly, target, source, result) VALUES (?, ?, ?, ?, 'pass')", [hash, n, t, src]];
const sweep = (n, t, upto) => [
  `INSERT INTO sweeps (nightly, target, upto_log_index) VALUES (?, ?, ?)
   ON CONFLICT (nightly, target) DO UPDATE SET upto_log_index = excluded.upto_log_index
   WHERE excluded.upto_log_index > sweeps.upto_log_index`, [n, t, upto]];
const publish = (grp, version, hash) => [
  ["INSERT OR IGNORE INTO artifacts (hash, kind) VALUES (?, 'package')", [hash]],
  [`INSERT OR IGNORE INTO releases (grp, version, hash, log_index)
    VALUES (?, ?, ?, (SELECT COALESCE(MAX(idx), 0) + 1 FROM log))`, [grp, version, hash]],
];

async function count(b, table) { return (await b.all(`SELECT COUNT(*) AS n FROM ${table}`))[0].n; }
async function upto(b) { return (await b.all("SELECT upto_log_index AS u FROM sweeps WHERE nightly = 'N1'"))[0]?.u ?? null; }
async function tryBatch(b, stmts) { try { await b.batch(stmts); return "ok"; } catch (e) { return String(e.message ?? e); } }
const errKind = (msg) => (msg.match(/sweep-incomplete|sweep-bound|sweep-smaller|label-conflict/) ?? ["ok"])[0];

async function run(b) {
  const out = [];
  const check = (id, what, got, want) => out.push({ id, what, got: JSON.stringify(got), want: JSON.stringify(want), pass: JSON.stringify(got) === JSON.stringify(want) });

  // Q27 cases.
  await b.batch([...publish("g/a/{v}/", "1.0.0", "HA"), ...publish("g/b/{v}/", "1.0.0", "HB"), ...publish("g/c/{v}/", "1.0.0", "HC")]);
  check("P1", "3 new labels: 3 releases, leaves 1 to 3", [await count(b, "releases"), (await b.all("SELECT idx FROM log ORDER BY idx")).map((r) => r.idx)], [3, [1, 2, 3]]);
  check("P2", "same label, same hash: no error, no new leaf", [await tryBatch(b, publish("g/a/{v}/", "1.0.0", "HA")), await count(b, "log")], ["ok", 3]);
  const p3 = await tryBatch(b, [...publish("g/z/{v}/", "1.0.0", "HZ"), ...publish("g/a/{v}/", "1.0.0", "HX")]);
  check("P3", "same label, other hash: error, and the batch writes nothing (no HZ, no HX)",
    [errKind(p3), await count(b, "log"), await count(b, "artifacts")], ["label-conflict", 3, 3]);
  out.push({ id: "P3m", what: "error message that the Worker sees", got: JSON.stringify(p3), want: "", pass: true });

  // Sweep cases. Hashes HA, HB, HC have log index 1, 2, 3.
  const s2 = await tryBatch(b, [row("HA", "N1", "any"), row("HB", "N1", "any"), sweep("N1", "any", 3)]);
  check("S2", "incomplete (no HC row): error, and no row of the request is written", [errKind(s2), await count(b, "compat"), await upto(b)], ["sweep-incomplete", 0, null]);
  out.push({ id: "S2m", what: "error message that the Worker sees", got: JSON.stringify(s2), want: "", pass: true });

  await b.batch([row("HA", "N1", "any"), row("HB", "N1", "any")]);
  const s4 = await tryBatch(b, [row("HC", "N1", "any", "author"), sweep("N1", "any", 3)]);
  check("S4", "an author row does not count", [errKind(s4), await upto(b)], ["sweep-incomplete", null]);

  const s5 = await tryBatch(b, [row("HC", "N1", "any"), sweep("N1", "any", 9)]);
  check("S5", "bound larger than the log size: error", [errKind(s5), await upto(b)], ["sweep-bound", null]);

  // S7: a publish of a new hash after the bot read the log size (3), before its write.
  await b.batch(publish("g/d/{v}/", "1.0.0", "HD"));
  const s3 = await tryBatch(b, [row("HC", "N1", "any"), sweep("N1", "any", 3)]);
  check("S3", "rows of an earlier request count: complete at bound 3", [errKind(s3), await upto(b)], ["ok", 3]);
  check("S7", "the new hash HD (log index 4) is above the bound, so it does not block", [await count(b, "log")], [4]);

  // S8: a new label of an old hash gets log index 5, but HA keeps the log index 1.
  await b.batch(publish("g/a2/{v}/", "1.0.0", "HA"));
  const s8 = await tryBatch(b, [sweep("N1", "any", 5)]);
  check("S8", "bound 5: HD has no row, so incomplete. HA is not asked twice.", [errKind(s8), await upto(b)], ["sweep-incomplete", 3]);

  const s6 = await tryBatch(b, [sweep("N1", "any", 2)]);
  check("S6", "a smaller bound is a no-op, not an error", [errKind(s6), await upto(b)], ["ok", 3]);

  // S9: two bot requests at once, bounds 4 and 5, both complete after the HD row.
  await b.batch([row("HD", "N1", "any")]);
  const both = await Promise.all([tryBatch(b, [sweep("N1", "any", 4)]), tryBatch(b, [sweep("N1", "any", 5)])]);
  check("S9", "two sweeps at once: both ok, the larger bound stays", [both.map(errKind), await upto(b)], [["ok", "ok"], 5]);

  const s10 = await tryBatch(b, [["UPDATE sweeps SET upto_log_index = 1 WHERE nightly = 'N1'", []]]);
  check("S10", "a direct UPDATE to a smaller bound: error", [errKind(s10), await upto(b)], ["sweep-smaller", 5]);
  return out;
}

const only = process.argv[2];
const backends = only === "sqlite" ? [sqliteBackend] : [d1Backend, sqliteBackend];
let failed = 0;
for (const make of backends) {
  const b = await make();
  try {
    console.log(`\n## ${b.name}\n\n| case | what | got | want | pass |\n| --- | --- | --- | --- | --- |`);
    for (const r of await run(b)) {
      if (!r.pass) failed++;
      console.log(`| ${r.id} | ${r.what} | ${r.got.replaceAll("|", "\\|")} | ${r.want} | ${r.pass ? "yes" : "NO"} |`);
    }
  } finally { await b.close(); }
}
process.exit(failed ? 1 : 0);
