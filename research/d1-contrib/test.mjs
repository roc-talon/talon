// Tests the user hint write (Registry 6.1, R-CT4), the login (R-CT8), the tracker (R-CT10), the daily limit (R-CT13) and
// the delete (R-CT7) on local D1 and on plain SQLite.
// Run: node test.mjs                  (both backends)
//      node test.mjs sqlite           (plain SQLite only)
// Mutations (each must fail the cases named, exit code 1):
//      MUTATE=notrigger  count every row with a plain statement: W2 to W6, Q1, Q2 fail
//      MUTATE=orignore   INSERT OR IGNORE in place of ON CONFLICT DO NOTHING: W7 fails
//      MUTATE=changes    written from meta.changes in place of RETURNING: W1 and others fail on D1
//      MUTATE=nolink     the write does not follow the link of a machine: L2 to L4, T1 fail
//      MUTATE=nomove     a login does not move the rows of the machine: L1 to L4, T1, D1, D2 fail
//      MUTATE=nobotskip  a pair with a bot row is counted: W6, W7 fail
//      MUTATE=nototals   the trim deletes rows and keeps no totals: X1, X3 fail
//      MUTATE=noage      the write takes a row of an old nightly: X2 fails
// Local D1 comes from the global wrangler install (getPlatformProxy), or from $WRANGLER (a path to the wrangler package).
import { readFileSync, mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { execSync } from "node:child_process";
import { createRequire } from "node:module";
import { DatabaseSync } from "node:sqlite";
import { REMOTE, configPath, wipe } from "../d1-remote/remote.mjs"; // `node test.mjs remote`: real D1

const MUTATE = process.env.MUTATE ?? "";
const CAP = 50; // the daily limit of R-CT13 in this test (200,000 in the design)
const DAY = 86400;
const schema = readFileSync(new URL("schema.sql", import.meta.url), "utf8")
  .split(/^;;$/m).map((s) => s.replace(/^--.*$/gm, "").trim()).filter(Boolean)
  .filter((s) => MUTATE !== "notrigger" || !/TRIGGER contributions_count/.test(s))
  .map((s) => s.replace(":CAP", String(CAP)));

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
  const proxy = await getPlatformProxy({ configPath: configPath(new URL("wrangler.toml", import.meta.url).pathname), persist: { path: persist } });
  const db = proxy.env.DB;
  await wipe(db);
  for (const s of schema) await db.prepare(s).run();
  return {
    name: REMOTE ? "d1-remote" : "d1",
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
    AND NOT EXISTS (SELECT 1 FROM compat_hints x WHERE x.hash = p.h AND x.nightly = p.n AND x.target = p.t)
    AND NOT EXISTS (SELECT 1 FROM toolchains t WHERE t.nightly = p.n AND t.published_at < ?)`; // not a skipped row (R-CT14)
// A row whose pair has a bot row is skipped (R-CT14 `bot-row`).
const BOTROW = (h, n, t) => `EXISTS (SELECT 1 FROM compat c WHERE c.hash = ${h} AND c.nightly = ${n} AND c.target = ${t} AND c.source = 'bot')`;
const J = (f) => `json_extract(value, '$.${f}')`;

// The statements of one user hint request (R-CT4). `machine` is the negative HMAC id of the header (R-CT3).
// The contributor is the account of the machine when it logged in (links), else the machine.
function hint(machine, version, rows, now, cutoff = -1) {
  const json = JSON.stringify(rows);
  const who = MUTATE === "nolink" ? "?" : "COALESCE((SELECT contributor FROM links WHERE machine = ?1), ?1)";
  const stmts = [
    [`SELECT (${FIRST}) AS first`, [json, cutoff]],
    [`SELECT CAST(key AS INTEGER) AS row FROM json_each(?) WHERE ${BOTROW(J("hash"), J("nightly"), J("target"))}
      OR EXISTS (SELECT 1 FROM toolchains t WHERE t.nightly = ${J("nightly")} AND t.published_at < ?)`, [json, cutoff]],
    // DO NOTHING skips only a duplicate key. INSERT OR IGNORE would also skip a row that fails CHECK (MUTATE=orignore).
    // RETURNING gives the inserted rows: D1 meta.changes also counts the rows of the trigger (MUTATE=changes).
    [`INSERT ${MUTATE === "orignore" ? "OR IGNORE " : ""}INTO contributions (contributor, hash, nightly, target, result, talon_version, time)
      SELECT ${who.replaceAll("?1", "?")}, ${J("hash")}, ${J("nightly")}, ${J("target")}, ${J("result")}, ?, ? FROM json_each(?)
      WHERE ${MUTATE === "nobotskip" ? "true" : `NOT ${BOTROW(J("hash"), J("nightly"), J("target"))}`}
        ${MUTATE === "noage" ? "" : `AND NOT EXISTS (SELECT 1 FROM toolchains t WHERE t.nightly = ${J("nightly")} AND t.published_at < ${cutoff})`}
      ${MUTATE === "orignore" ? "" : "ON CONFLICT (contributor, hash, nightly, target) DO NOTHING"}
      ${MUTATE === "changes" ? "" : "RETURNING hash"}`, [...(MUTATE === "nolink" ? [machine] : [machine, machine]), version, now, json]],
  ];
  if (MUTATE === "notrigger") stmts.push(
    [`INSERT INTO compat_hints (hash, nightly, target, talon_version, pass_count, fail_count, crash_count, first_time, last_time)
      SELECT ${J("hash")}, ${J("nightly")}, ${J("target")}, ?, ${J("result")} = 'pass', ${J("result")} = 'fail', ${J("result")} = 'crash', ?, ?
      FROM json_each(?) WHERE true
      ON CONFLICT (hash, nightly, target, talon_version) DO UPDATE SET pass_count = pass_count + excluded.pass_count,
        fail_count = fail_count + excluded.fail_count, crash_count = crash_count + excluded.crash_count, last_time = excluded.last_time`,
      [version, now, now, json]]);
  return stmts;
}

// R-CT8 row 3: a login. The account row, the link of the machine (a later login moves it), then the rows of the machine
// move to the account. A pair that the account has already stays once: UPDATE OR IGNORE skips it, and DELETE removes it.
const login = (machine, account, name, now) => [
  [`INSERT INTO contributors (contributor, login, tokens_after, first_time, last_time) VALUES (?, ?, 0, ?, ?)
    ON CONFLICT (contributor) DO UPDATE SET login = excluded.login, last_time = excluded.last_time`, [account, name, now, now]],
  [`INSERT INTO links (machine, contributor, time) VALUES (?, ?, ?)
    ON CONFLICT (machine) DO UPDATE SET contributor = excluded.contributor, time = excluded.time`, [machine, account, now]],
  ...(MUTATE === "nomove" ? [] : [
    ["UPDATE OR IGNORE contributions SET contributor = ? WHERE contributor = ?", [account, machine]],
    ["DELETE FROM contributions WHERE contributor = ?", [machine]]]),
  [`INSERT INTO contributor_totals SELECT ?, counted, first, agreed, disagreed, unconfirmed FROM contributor_totals WHERE contributor = ?
    ON CONFLICT (contributor) DO UPDATE SET counted = counted + excluded.counted, first = first + excluded.first,
      agreed = agreed + excluded.agreed, disagreed = disagreed + excluded.disagreed, unconfirmed = unconfirmed + excluded.unconfirmed`, [account, machine]],
  ["DELETE FROM contributor_totals WHERE contributor = ?", [machine]],
];

// R-CT10: the tracker, computed from the rows when it is read. `first`: no compat row of the pair before the row, and no
// row of another contributor before it (the smaller id first on the same time).
const PAIR = (a) => `${a}.hash = p.hash AND ${a}.nightly = p.nightly AND ${a}.target = p.target`;
const TRACKER = `SELECT COUNT(*) AS counted,
    COALESCE(SUM(NOT EXISTS (SELECT 1 FROM compat c WHERE ${PAIR("c")} AND c.time < p.time)
      AND NOT EXISTS (SELECT 1 FROM contributions o WHERE ${PAIR("o")} AND o.contributor <> p.contributor
        AND (o.time < p.time OR (o.time = p.time AND o.contributor < p.contributor)))), 0) AS first,
    COALESCE(SUM(EXISTS (SELECT 1 FROM compat c WHERE ${PAIR("c")} AND c.source = 'bot' AND c.result = p.result)), 0) AS agreed,
    COALESCE(SUM(EXISTS (SELECT 1 FROM compat c WHERE ${PAIR("c")} AND c.source = 'bot' AND c.result <> p.result)), 0) AS disagreed,
    COALESCE(SUM(NOT EXISTS (SELECT 1 FROM compat c WHERE ${PAIR("c")} AND c.source = 'bot')), 0) AS unconfirmed
  FROM contributions p WHERE p.contributor = ?`;
const CLASSES = TRACKER.slice(TRACKER.indexOf("SELECT ") + 7, TRACKER.indexOf("FROM contributions p WHERE")).trim();
const WITH_TOTALS = `SELECT l.counted + COALESCE(t.counted, 0) AS counted, l.first + COALESCE(t.first, 0) AS first,
    l.agreed + COALESCE(t.agreed, 0) AS agreed, l.disagreed + COALESCE(t.disagreed, 0) AS disagreed,
    l.unconfirmed + COALESCE(t.unconfirmed, 0) AS unconfirmed
  FROM (${TRACKER.replace("p.contributor = ?", "p.contributor = ?1")}) l LEFT JOIN contributor_totals t ON t.contributor = ?1`;

// R-CT15: the trim of one nightly that is older than the age. One batch: the totals of its rows (the classes of R-CT10,
// computed before the delete, while the other rows of each pair are still there), then the delete of its rows and hints.
const trim = (nightly) => [
  ...(MUTATE === "nototals" ? [] : [[`INSERT INTO contributor_totals (contributor, counted, first, agreed, disagreed, unconfirmed)
    SELECT p.contributor, ${CLASSES} FROM contributions p WHERE p.nightly = ? GROUP BY p.contributor
    ON CONFLICT (contributor) DO UPDATE SET counted = counted + excluded.counted, first = first + excluded.first,
      agreed = agreed + excluded.agreed, disagreed = disagreed + excluded.disagreed, unconfirmed = unconfirmed + excluded.unconfirmed`, [nightly]]]),
  ["DELETE FROM contributions WHERE nightly = ?", [nightly]],
  ["DELETE FROM compat_hints WHERE nightly = ?", [nightly]],
];

// R-CT7: the delete with the header only (one machine), and with the JWT (the account).
const forgetMachine = (m) => [["DELETE FROM contributions WHERE contributor = ?", [m]], ["DELETE FROM links WHERE machine = ?", [m]],
  ["DELETE FROM contributor_totals WHERE contributor = ?", [m]]];
const forgetAccount = (a) => [["DELETE FROM contributions WHERE contributor = ?", [a]], ["DELETE FROM links WHERE contributor = ?", [a]],
  ["DELETE FROM contributors WHERE contributor = ?", [a]], ["DELETE FROM contributor_totals WHERE contributor = ?", [a]]];

const r = (hash, result, nightly = "N1", target = "any") => ({ hash, nightly, target, result });
const bot = (hash, result, time = 0) => ["INSERT INTO compat (hash, nightly, target, source, result, time) VALUES (?, 'N1', 'any', 'bot', ?, ?)", [hash, result, time]];
async function send(b, m, v, rows, now, cutoff) {
  try { const res = await b.batch(hint(m, v, rows, now, cutoff));
    return { written: MUTATE === "changes" ? res[2].changes : res[2].rows.length, first: res[0].rows[0].first, skipped: res[1].rows.map((x) => x.row) }; }
  catch (e) { const t = String(e.message ?? e); return { error: /CHECK/.test(t) ? "check" : /hint-quota/.test(t) ? "hint-quota" : t }; }
}
// Counts of each hash on N1/any, added up over all Talon versions (the reader of Resolution 3, R-EF3).
async function hints(b) {
  const out = {};
  for (const x of await b.all(`SELECT hash, SUM(pass_count) p, SUM(fail_count) f, SUM(crash_count) c, COUNT(*) buckets
      FROM compat_hints GROUP BY hash ORDER BY hash`)) out[x.hash] = [x.p, x.f, x.c, x.buckets];
  return out;
}
const who = async (b, c) => (await b.all(WITH_TOTALS, [c]))[0];
const rowsOf = async (b) => (await b.all("SELECT contributor || ':' || hash AS k FROM contributions ORDER BY contributor, hash")).map((x) => x.k);
const reset = (b) => b.batch(["compat", "compat_hints", "contributors", "contributions", "links", "hint_days", "toolchains", "contributor_totals"].map((t) => [`DELETE FROM ${t}`, []]));
const T = (counted, first, agreed, disagreed, unconfirmed) => ({ counted, first, agreed, disagreed, unconfirmed });
const A = -101, B = -102, C = -103, D = -104, E = -105; // machines: negative HMAC ids

async function run(b) {
  const out = [];
  const check = (id, what, got, want) => out.push({ id, what, got: JSON.stringify(got), want: JSON.stringify(want), pass: JSON.stringify(got) === JSON.stringify(want) });

  // Write (R-CT4). hints: [pass, fail, crash, buckets]. who: the tracker of R-CT10.
  check("W1", "A sends 3 new pairs: all written and first. changes() does not count the trigger rows.",
    [await send(b, A, "0.4.1", [r("HA", "pass"), r("HB", "fail"), r("HC", "crash")], 100), await hints(b), await who(b, A)],
    [{ written: 3, first: 3, skipped: [] }, { HA: [1, 0, 0, 1], HB: [0, 1, 0, 1], HC: [0, 0, 1, 1] }, T(3, 3, 0, 0, 3)]);
  check("W2", "A sends the same rows again (no answer the first time): nothing counts twice",
    [await send(b, A, "0.4.1", [r("HA", "pass"), r("HB", "fail"), r("HC", "crash")], 110), await hints(b), await who(b, A)],
    [{ written: 0, first: 0, skipped: [] }, { HA: [1, 0, 0, 1], HB: [0, 1, 0, 1], HC: [0, 0, 1, 1] }, T(3, 3, 0, 0, 3)]);
  check("W3", "B sends 2 known pairs: counted for B, not first",
    [await send(b, B, "0.4.1", [r("HA", "pass"), r("HB", "pass")], 120), (await hints(b)).HB, await who(b, B)],
    [{ written: 2, first: 0, skipped: [] }, [1, 1, 0, 1], T(2, 0, 0, 0, 2)]);
  check("W4", "one request names a pair 3 times: one row, first once",
    [await send(b, B, "0.4.1", [r("HD", "pass"), r("HD", "pass"), r("HD", "fail")], 130), (await hints(b)).HD],
    [{ written: 1, first: 1, skipped: [] }, [1, 0, 0, 1]]);
  check("W5", "another Talon version is another bucket. The reader adds them up.",
    [await send(b, C, "0.5.0", [r("HA", "pass")], 140), (await hints(b)).HA], [{ written: 1, first: 0, skipped: [] }, [3, 0, 0, 2]]);
  await b.batch([bot("HE", "pass", 145)]);
  check("W6", "a pair with a bot row is skipped (R-CT14): not written, not counted, listed as row 0",
    [await send(b, A, "0.4.1", [r("HE", "pass"), r("HF", "fail")], 150), (await hints(b)).HE ?? null],
    [{ written: 1, first: 1, skipped: [0] }, null]);
  check("W7", "one bad row (result 'hang'): error, and the batch writes nothing",
    [await send(b, A, "0.4.1", [r("HG", "pass"), r("HH", "hang")], 160), await who(b, A), (await hints(b)).HG ?? null],
    [{ error: "check" }, T(4, 4, 0, 0, 4), null]);
  const both = await Promise.all([send(b, D, "0.4.1", [r("HI", "pass")], 170), send(b, E, "0.4.1", [r("HI", "pass")], 170)]);
  check("W8", "two requests at once on one new pair: both count; the tracker gives first to one of them",
    [both.map((x) => x.written), (await hints(b)).HI, (await who(b, D)).first + (await who(b, E)).first], [[1, 1], [2, 0, 0, 1], 1]);

  // Login (R-CT8). A sent HA, HB at t=100. Then it logs in as the account 42.
  await reset(b);
  await send(b, A, "0.4.1", [r("HA", "pass"), r("HB", "fail")], 100);
  await b.batch(login(A, 42, "someone", 200));
  check("L1", "the rows of A move to the account 42; the counts do not change",
    [await rowsOf(b), await who(b, 42), (await hints(b)).HA], [["42:HA", "42:HB"], T(2, 2, 0, 0, 2), [1, 0, 0, 1]]);
  await send(b, A, "0.4.1", [r("HC", "pass")], 210);
  check("L2", "after the login, a hint with the header of A counts for 42", [await rowsOf(b)], [["42:HA", "42:HB", "42:HC"]]);
  // B (a second machine) sent HA and HD before its login as 42. HA is a pair that 42 has: it stays once.
  await send(b, B, "0.4.1", [r("HA", "pass"), r("HD", "pass")], 220);
  await b.batch(login(B, 42, "someone", 230));
  check("L3", "a second machine of 42: its new pair moves, its copy of HA goes",
    [await rowsOf(b), (await who(b, 42)).counted], [["42:HA", "42:HB", "42:HC", "42:HD"], 4]);
  await b.batch(login(A, 43, "other", 240));
  await send(b, A, "0.4.1", [r("HE", "pass")], 250);
  check("L4", "A logs in as 43: its new rows go to 43, its old rows stay with 42",
    [await rowsOf(b)], [["42:HA", "42:HB", "42:HC", "42:HD", "43:HE"]]);

  // Tracker (R-CT10): computed when read. Bot rows come later; no row is deleted.
  await b.batch([bot("HA", "pass", 300), bot("HB", "pass", 300), bot("HC", "crash", 300)]);
  check("T1", "42: agreed HA, disagreed HB and HC, unconfirmed HD; first for HA to HD (B's HA at 220 was after A's at 100)",
    [await who(b, 42), (await rowsOf(b)).length], [T(4, 4, 1, 2, 1), 5]);

  // Daily limit (R-CT13): CAP rows a day for all users. Day 10 is empty.
  await reset(b);
  const many = (n, p) => Array.from({ length: n }, (_, i) => r(`${p}${i}`, "pass"));
  check("Q1", `${CAP + 1} new rows in one day: hint-quota, nothing written`,
    [await send(b, A, "0.4.1", many(CAP + 1, "X"), 10 * DAY), await rowsOf(b)], [{ error: "hint-quota" }, []]);
  check("Q2", `${CAP} rows: written. One more on the same day: hint-quota. The next day: written.`,
    [(await send(b, A, "0.4.1", many(CAP, "Y"), 10 * DAY)).written, (await send(b, B, "0.4.1", [r("Z", "pass")], 10 * DAY + 5)).error,
      (await send(b, B, "0.4.1", [r("Z", "pass")], 11 * DAY)).written], [CAP, "hint-quota", 1]);

  // Trim (R-CT15). N1 is a year old, N2 is new. A and B send on both; bot rows on N1 for HA (pass) and HB (pass).
  await reset(b);
  await b.batch([["INSERT INTO toolchains VALUES ('N1', 0), ('N2', 400)", []]]);
  await send(b, A, "0.4.1", [r("HA", "pass"), r("HB", "fail"), r("HC", "pass"), r("HA", "pass", "N2")], 100);
  await send(b, B, "0.4.1", [r("HA", "pass"), r("HD", "crash")], 110);
  await b.batch([bot("HA", "pass", 300), bot("HB", "pass", 300)]);
  const before = [await who(b, A), await who(b, B)];
  await b.batch(trim("N1"));
  check("X1", "the trim of N1: the tracker of A and B does not change; only the N2 row and its hint stay",
    [await who(b, A), await who(b, B), await rowsOf(b), Object.keys(await hints(b))], [...before, [`${A}:HA`], ["HA"]]);
  check("X2", "a new hint for the old N1 is skipped (cutoff 200): not written, not counted",
    [await send(b, C, "0.4.1", [r("HE", "pass"), r("HE", "pass", "N2")], 500, 200), await rowsOf(b)],
    [{ written: 1, first: 1, skipped: [0] }, [`${C}:HE`, `${A}:HA`]]);
  await b.batch(login(A, 42, "someone", 600));
  check("X3", "a login after the trim: the old totals of A move to 42 with its rows", [await who(b, 42), await who(b, A)],
    [T(before[0].counted, before[0].first, before[0].agreed, before[0].disagreed, before[0].unconfirmed), T(0, 0, 0, 0, 0)]);
  await b.batch(forgetAccount(42));
  check("X4", "forget the account: its old totals go too", [await who(b, 42)], [T(0, 0, 0, 0, 0)]);

  // Delete (R-CT7). A and B are machines of 42 (their rows moved). C has no account.
  await reset(b);
  for (const m of [A, B, C]) await send(b, m, "0.4.1", [r(`H${-m}`, "pass")], 100);
  await b.batch([...login(A, 42, "someone", 200), ...login(B, 42, "someone", 210)]);
  await b.batch(forgetMachine(C));
  check("D1", "forget C (header only): its rows go, the counts stay", [await rowsOf(b), Object.keys(await hints(b)).length], [["42:H101", "42:H102"], 3]);
  await b.batch(forgetAccount(42));
  check("D2", "forget the account: its rows, its links and its row go, the counts stay",
    [await rowsOf(b), (await b.all("SELECT COUNT(*) n FROM links"))[0].n, (await b.all("SELECT COUNT(*) n FROM contributors"))[0].n, Object.keys(await hints(b)).length],
    [[], 0, 0, 3]);
  check("D3", "a second delete is no error", [await b.batch(forgetAccount(42)).then(() => "ok", (e) => String(e))], ["ok"]);
  return out;
}

const backends = process.argv[2] === "sqlite" ? [sqliteBackend] : REMOTE ? [d1Backend] : [d1Backend, sqliteBackend];
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
