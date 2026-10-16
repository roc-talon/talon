// Tests the user hint write (Registry 6.1, R-CT4), the fold (R-CT5) and the delete (R-CT7) on local D1 and on plain SQLite.
// Run: node test.mjs                  (both backends)
//      node test.mjs sqlite           (plain SQLite only)
//      MUTATE=notrigger node test.mjs (count every row with a plain statement: the once-per-contributor cases must fail, exit code 1)
//      MUTATE=orignore node test.mjs  (INSERT OR IGNORE in place of ON CONFLICT DO NOTHING: W7 must fail)
//      MUTATE=changes node test.mjs   (written from meta.changes in place of RETURNING: fails on D1)
// Local D1 comes from the global wrangler install (getPlatformProxy), or from $WRANGLER (a path to the wrangler package).
import { readFileSync, mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { execSync } from "node:child_process";
import { createRequire } from "node:module";
import { DatabaseSync } from "node:sqlite";

const MUTATE = process.env.MUTATE ?? "";
const schema = readFileSync(new URL("schema.sql", import.meta.url), "utf8")
  .split(/^;;$/m).map((s) => s.replace(/^--.*$/gm, "").trim()).filter(Boolean)
  .filter((s) => MUTATE !== "notrigger" || !/TRIGGER contributions_count/.test(s));

// One backend = { batch(list of [sql, params]) -> [{rows, changes}], throws on failure; all(sql, params) -> rows }.
function sqliteBackend() {
  const db = new DatabaseSync(":memory:");
  for (const s of schema) db.exec(s);
  return {
    name: "sqlite",
    async batch(stmts) {
      db.exec("BEGIN");
      try {
        const out = stmts.map(([sql, p]) => /^\s*SELECT|RETURNING/i.test(sql)
          ? { rows: db.prepare(sql).all(...p), changes: 0 }
          : { rows: [], changes: Number(db.prepare(sql).run(...p).changes) });
        db.exec("COMMIT");
        return out;
      } catch (e) { db.exec("ROLLBACK"); throw e; }
    },
    async all(sql, p = []) { return db.prepare(sql).all(...p); },
    async close() { db.close(); },
  };
}

async function d1Backend() {
  const dir = process.env.WRANGLER ?? `${execSync("npm root -g").toString().trim()}/wrangler`;
  const { getPlatformProxy } = createRequire(import.meta.url)(dir);
  const persist = mkdtempSync(join(tmpdir(), "d1-contrib-"));
  const proxy = await getPlatformProxy({ configPath: new URL("wrangler.toml", import.meta.url).pathname, persist: { path: persist } });
  const db = proxy.env.DB;
  for (const s of schema) await db.prepare(s).run();
  return {
    name: "d1",
    async batch(stmts) {
      const res = await db.batch(stmts.map(([sql, p]) => db.prepare(sql).bind(...p)));
      return res.map((r) => ({ rows: r.results ?? [], changes: r.meta?.changes ?? 0 }));
    },
    async all(sql, p = []) { return (await db.prepare(sql).bind(...p).all()).results; },
    async close() { await proxy.dispose(); rmSync(persist, { recursive: true, force: true }); },
  };
}

// The pairs of a request that no compat row and no compat_hints row has yet (R-CT4 "first").
const FIRST = `SELECT COUNT(*) FROM (SELECT DISTINCT json_extract(value, '$.hash') AS h, json_extract(value, '$.nightly') AS n,
    json_extract(value, '$.target') AS t FROM json_each(?)) p
  WHERE NOT EXISTS (SELECT 1 FROM compat c WHERE c.hash = p.h AND c.nightly = p.n AND c.target = p.t)
    AND NOT EXISTS (SELECT 1 FROM compat_hints x WHERE x.hash = p.h AND x.nightly = p.n AND x.target = p.t)`;

// The statements of one user hint request (R-CT4). The Worker sends them as one batch.
function hint(contributor, version, rows, now) {
  const json = JSON.stringify(rows);
  const stmts = [
    [`SELECT (${FIRST}) AS first`, [json]],
    [`INSERT INTO contributors (contributor, counted, first, agreed, disagreed, unconfirmed, first_time, last_time)
      VALUES (?, 0, (${FIRST}), 0, 0, 0, ?, ?)
      ON CONFLICT (contributor) DO UPDATE SET first = first + excluded.first, last_time = excluded.last_time`, [contributor, json, now, now]],
    // DO NOTHING skips only a duplicate key. INSERT OR IGNORE would also skip a row that fails CHECK (MUTATE=orignore).
    // RETURNING gives the inserted rows: D1 meta.changes also counts the rows of the trigger (MUTATE=changes).
    [`INSERT ${MUTATE === "orignore" ? "OR IGNORE " : ""}INTO contributions (contributor, hash, nightly, target, result, talon_version, time)
      SELECT ?, json_extract(value, '$.hash'), json_extract(value, '$.nightly'), json_extract(value, '$.target'),
        json_extract(value, '$.result'), ?, ? FROM json_each(?) WHERE true
      ${MUTATE === "orignore" ? "" : "ON CONFLICT (contributor, hash, nightly, target) DO NOTHING"}
      ${MUTATE === "changes" ? "" : "RETURNING hash"}`, [contributor, version, now, json]],
  ];
  if (MUTATE === "notrigger") stmts.push(
    [`INSERT INTO compat_hints (hash, nightly, target, talon_version, pass_count, fail_count, crash_count, first_time, last_time)
      SELECT json_extract(value, '$.hash'), json_extract(value, '$.nightly'), json_extract(value, '$.target'), ?,
        json_extract(value, '$.result') = 'pass', json_extract(value, '$.result') = 'fail', json_extract(value, '$.result') = 'crash', ?, ?
      FROM json_each(?) WHERE true
      ON CONFLICT (hash, nightly, target, talon_version) DO UPDATE SET pass_count = pass_count + excluded.pass_count,
        fail_count = fail_count + excluded.fail_count, crash_count = crash_count + excluded.crash_count, last_time = excluded.last_time`,
      [version, now, now, json]],
    ["UPDATE contributors SET counted = counted + json_array_length(?) WHERE contributor = ?", [json, contributor]]);
  return stmts;
}

// The daily fold (R-CT5): compare each pending row with the bot row of its pair, then delete it. One batch.
const BOT = (cmp) => `SELECT 1 FROM compat c WHERE c.hash = p.hash AND c.nightly = p.nightly AND c.target = p.target
  AND c.source = 'bot'${cmp}`;
const fold = (cutoff) => [
  [`UPDATE contributors SET
     agreed = agreed + (SELECT COUNT(*) FROM contributions p WHERE p.contributor = contributors.contributor
       AND EXISTS (${BOT(" AND c.result = p.result")})),
     disagreed = disagreed + (SELECT COUNT(*) FROM contributions p WHERE p.contributor = contributors.contributor
       AND EXISTS (${BOT(" AND c.result <> p.result")})),
     unconfirmed = unconfirmed + (SELECT COUNT(*) FROM contributions p WHERE p.contributor = contributors.contributor
       AND p.time < ? AND NOT EXISTS (${BOT("")}))
   WHERE contributor IN (SELECT contributor FROM contributions)`, [cutoff]],
  [`DELETE FROM contributions AS p WHERE p.time < ? OR EXISTS (${BOT("")})`, [cutoff]],
];

// R-CT7: the delete of one contributor, and of an account with its linked contributors.
const forget = (c) => [
  ["DELETE FROM contributions WHERE contributor = ?", [c]],
  ["DELETE FROM contributors WHERE contributor = ?", [c]],
];
const forgetAccount = (id) => [
  ["DELETE FROM contributions WHERE contributor IN (SELECT contributor FROM contributors WHERE account = ?)", [id]],
  ["DELETE FROM contributors WHERE account = ?", [id]],
  ["DELETE FROM accounts WHERE github_id = ?", [id]],
];

const r = (hash, result, nightly = "N1", target = "any") => ({ hash, nightly, target, result });
const bot = (hash, result) => ["INSERT INTO compat (hash, nightly, target, source, result) VALUES (?, 'N1', 'any', 'bot', ?)", [hash, result]];
async function send(b, c, v, rows, now) {
  try { const res = await b.batch(hint(c, v, rows, now));
    return { written: MUTATE === "changes" ? res[2].changes : res[2].rows.length, first: res[0].rows[0].first }; }
  catch (e) { return { error: /CHECK/.test(String(e.message ?? e)) ? "check" : String(e.message ?? e) }; }
}
// Counts of each hash on N1/any, added up over all Talon versions (the reader of Resolution 3, R-EF3).
async function hints(b) {
  const out = {};
  for (const x of await b.all(`SELECT hash, SUM(pass_count) p, SUM(fail_count) f, SUM(crash_count) c, COUNT(*) buckets
      FROM compat_hints GROUP BY hash ORDER BY hash`)) out[x.hash] = [x.p, x.f, x.c, x.buckets];
  return out;
}
async function who(b, c) {
  return (await b.all("SELECT counted, first, agreed, disagreed, unconfirmed FROM contributors WHERE contributor = ?", [c]))[0] ?? null;
}
const pending = async (b) => (await b.all("SELECT contributor || ':' || hash AS k FROM contributions ORDER BY k")).map((x) => x.k);
const reset = (b) => b.batch(["compat", "compat_hints", "contributors", "contributions", "accounts"].map((t) => [`DELETE FROM ${t}`, []]));

async function run(b) {
  const out = [];
  const check = (id, what, got, want) => out.push({ id, what, got: JSON.stringify(got), want: JSON.stringify(want), pass: JSON.stringify(got) === JSON.stringify(want) });

  // Write (R-CT4). hints: [pass, fail, crash, buckets]. who: counted, first, agreed, disagreed, unconfirmed.
  check("W1", "A sends 3 new pairs: all written and first. changes() does not count the trigger rows.",
    [await send(b, "A", "0.4.1", [r("HA", "pass"), r("HB", "fail"), r("HC", "crash")], 100), await hints(b), await who(b, "A")],
    [{ written: 3, first: 3 }, { HA: [1, 0, 0, 1], HB: [0, 1, 0, 1], HC: [0, 0, 1, 1] }, { counted: 3, first: 3, agreed: 0, disagreed: 0, unconfirmed: 0 }]);
  check("W2", "A sends the same rows again (no answer the first time): nothing counts twice",
    [await send(b, "A", "0.4.1", [r("HA", "pass"), r("HB", "fail"), r("HC", "crash")], 110), await hints(b), await who(b, "A")],
    [{ written: 0, first: 0 }, { HA: [1, 0, 0, 1], HB: [0, 1, 0, 1], HC: [0, 0, 1, 1] }, { counted: 3, first: 3, agreed: 0, disagreed: 0, unconfirmed: 0 }]);
  check("W3", "B sends 2 known pairs: counted for B, not first",
    [await send(b, "B", "0.4.1", [r("HA", "pass"), r("HB", "pass")], 120), (await hints(b)).HB, await who(b, "B")],
    [{ written: 2, first: 0 }, [1, 1, 0, 1], { counted: 2, first: 0, agreed: 0, disagreed: 0, unconfirmed: 0 }]);
  check("W4", "one request names a pair 3 times: one row, first once",
    [await send(b, "B", "0.4.1", [r("HD", "pass"), r("HD", "pass"), r("HD", "fail")], 130), (await hints(b)).HD],
    [{ written: 1, first: 1 }, [1, 0, 0, 1]]);
  check("W5", "another Talon version is another bucket. The reader adds them up.",
    [await send(b, "C", "0.5.0", [r("HA", "pass")], 140), (await hints(b)).HA],
    [{ written: 1, first: 0 }, [3, 0, 0, 2]]);
  await b.batch([bot("HE", "pass")]);
  check("W6", "a pair with a bot row: counted, not first",
    [await send(b, "A", "0.4.1", [r("HE", "pass")], 150), await who(b, "A")],
    [{ written: 1, first: 0 }, { counted: 4, first: 3, agreed: 0, disagreed: 0, unconfirmed: 0 }]);
  check("W7", "one bad row (result 'hang'): error, and the batch writes nothing, also not the first count",
    [await send(b, "A", "0.4.1", [r("HF", "pass"), r("HG", "hang")], 160), await who(b, "A"), (await hints(b)).HF ?? null],
    [{ error: "check" }, { counted: 4, first: 3, agreed: 0, disagreed: 0, unconfirmed: 0 }, null]);
  const both = await Promise.all([send(b, "D", "0.4.1", [r("HH", "pass")], 170), send(b, "E", "0.4.1", [r("HH", "pass")], 170)]);
  check("W8", "two requests at once on one new pair: both count, first only once",
    [both.map((x) => x.written), both[0].first + both[1].first, (await hints(b)).HH], [[1, 1], 1, [2, 0, 0, 1]]);

  // Fold (R-CT5). A sends 4 rows at t=100 and 1 at t=200. Bot rows: HA pass, HB pass, HC crash. Cutoff 150.
  await reset(b);
  await send(b, "A", "0.4.1", [r("HA", "pass"), r("HB", "fail"), r("HC", "crash"), r("HD", "pass")], 100);
  await send(b, "A", "0.4.1", [r("HE", "pass")], 200);
  await b.batch([bot("HA", "pass"), bot("HB", "pass"), bot("HC", "crash")]);
  const before = await hints(b);
  await b.batch(fold(150));
  check("F1", "agree HA and HC, disagree HB, HD too old with no bot row, HE stays pending",
    [await who(b, "A"), await pending(b)], [{ counted: 5, first: 5, agreed: 2, disagreed: 1, unconfirmed: 1 }, ["A:HE"]]);
  check("F2", "the fold changes no hint count", [await hints(b)], [before]);
  await b.batch(fold(150));
  check("F3", "a second fold changes nothing", [await who(b, "A"), await pending(b)],
    [{ counted: 5, first: 5, agreed: 2, disagreed: 1, unconfirmed: 1 }, ["A:HE"]]);
  check("F4", "after the fold, a resend of HA counts again (tln does not send a pair with a bot row, CLI R-SH3 filter 5)",
    [await send(b, "A", "0.4.1", [r("HA", "pass")], 300), (await hints(b)).HA], [{ written: 1, first: 0 }, [2, 0, 0, 1]]);

  // Delete (R-CT7). A and B are linked to the account X. C has no account.
  await reset(b);
  for (const c of ["A", "B", "C"]) await send(b, c, "0.4.1", [r("HA", "pass")], 100);
  await b.batch([["INSERT INTO accounts (github_id, login) VALUES ('X', 'someone')", []],
    ["UPDATE contributors SET account = 'X' WHERE contributor IN ('A', 'B')", []]]);
  await b.batch(forget("C"));
  check("D1", "forget C: its rows go, the counts stay", [await who(b, "C"), await pending(b), (await hints(b)).HA], [null, ["A:HA", "B:HA"], [3, 0, 0, 1]]);
  await b.batch(forgetAccount("X"));
  check("D2", "forget the account: A, B and the account go, the counts stay",
    [await who(b, "A"), await who(b, "B"), await pending(b), (await b.all("SELECT COUNT(*) n FROM accounts"))[0].n, (await hints(b)).HA],
    [null, null, [], 0, [3, 0, 0, 1]]);
  check("D3", "a second delete is no error", [await b.batch(forgetAccount("X")).then(() => "ok", (e) => String(e))], ["ok"]);
  return out;
}

const backends = process.argv[2] === "sqlite" ? [sqliteBackend] : [d1Backend, sqliteBackend];
let failed = 0;
for (const make of backends) {
  const b = await make();
  try {
    console.log(`\n## ${b.name}\n\n| case | what | got | want | pass |\n| --- | --- | --- | --- | --- |`);
    for (const x of await run(b)) {
      if (!x.pass) failed++;
      console.log(`| ${x.id} | ${x.what} | ${x.got.replaceAll("|", "\\|")} | ${x.want} | ${x.pass ? "yes" : "NO"} |`);
    }
  } finally { await b.close(); }
}
process.exit(failed ? 1 : 0);
