// Tests the bounded bot set (Registry R-MX11), its sweep guard (R-MX4, R-MX8) and the transitions table (R-RE23),
// on local D1 (wrangler getPlatformProxy) and on plain SQLite.
// Run: node test.mjs [sqlite] [states]
// Mutations (each must fail the cases named):
//   MUTATE=allhash   the old rule, every hash up to the bound: B0, B1, B3 to B6 fail
//   MUTATE=noseries  only the newest release of each group: B0, B1, B5 fail
//   MUTATE=nowindow  no age window: B0, B1, B3 to B6 fail
//   MUTATE=faults    hangs and crashes count in a transition: T1, T2 fail
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { execSync } from "node:child_process";
import { createRequire } from "node:module";
import { DatabaseSync } from "node:sqlite";
import { REMOTE, configPath, wipe } from "../d1-remote/remote.mjs"; // `node test.mjs remote`: real D1
import { schema, membersSql, missingSql, WINDOW_DAYS } from "./schema.mjs";

const DAY = 86400;
const STATES = Number(process.argv.find((a) => /^\d+$/.test(a)) ?? 300);

// One backend = { batch(list of [sql, params]) -> throws on failure, all(sql, params) -> rows }. Parameters are text or
// small numbers: a 64-bit value goes in as decimal text, as on D1 (R-IK2), and STRICT INTEGER columns convert it.
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
  const dir = process.env.WRANGLER ?? `${execSync("npm root -g").toString().trim()}/wrangler`;
  const { getPlatformProxy } = createRequire(import.meta.url)(dir);
  const persist = mkdtempSync(join(tmpdir(), "bot-set-"));
  const proxy = await getPlatformProxy({ configPath: configPath(new URL("wrangler.toml", import.meta.url).pathname), persist: { path: persist } });
  const db = proxy.env.DB;
  await wipe(db);
  for (const s of schema) await db.prepare(s).run();
  return {
    name: REMOTE ? "d1-remote" : "d1",
    async batch(stmts) { await db.batch(stmts.map(([sql, p]) => db.prepare(sql).bind(...p))); },
    async all(sql, p = []) { return (await db.prepare(sql).bind(...p).all()).results; },
    async close() { await proxy.dispose(); rmSync(persist, { recursive: true, force: true }); },
  };
}

// The stored order key of R-IK5 for a release version (no pre-release in the registry).
const stored = (ma, mi, pa) => BigInt.asIntN(64, ((BigInt(ma) << 48n) | (BigInt(mi) << 32n) | (BigInt(pa) << 16n) | 0xffffn) ^ (1n << 63n)).toString();
const key = (r) => (BigInt(r.major) << 32n) | (BigInt(r.minor) << 16n) | BigInt(r.patch);

// Reference of R-MX11, written from the rule text, not from the SQL.
function reference(st, L, nightlyTime) {
  // The newest release is chosen over the whole group. Then only a package or a platform is a member.
  const live = st.releases.filter((r) => r.log_index <= L && !r.yanked && !r.withdrawn);
  const series = (r) => (r.major === 0 ? `0.${r.minor}` : `${r.major}`);
  const out = new Set();
  for (const r of live) {
    const newestSeries = !live.some((o) => o.form === r.form && series(o) === series(r) && key(o) > key(r));
    const newestForm = !live.some((o) => o.form === r.form && key(o) > key(r));
    const recent = r.published_at >= nightlyTime - WINDOW_DAYS * DAY;
    if (newestSeries && (recent || newestForm) && st.kind[r.artifact] !== 2) out.add(r.artifact);
  }
  return [...out].sort((a, b) => a - b);
}

let seed = 7;
// mulberry32: 32-bit integer steps (Math.imul), so no step goes above 2^53 and loses its low bits.
const rnd = (n) => { seed = (seed + 0x6d2b79f5) | 0; let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
  t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) % n; };
function randomState() {
  const kind = {}, releases = [];
  for (let a = 1; a <= 12; a++) kind[a] = rnd(6) === 0 ? 2 : rnd(4) === 0 ? 1 : 0;
  const seen = new Set();
  for (let i = 1; i <= 2 + rnd(25); i++) {
    const r = { log_index: i, form: 1 + rnd(4), major: [0, 0, 1, 2][rnd(4)], minor: rnd(4), patch: rnd(3), artifact: 1 + rnd(12),
      published_at: rnd(1000) * DAY, yanked: rnd(10) === 0 ? 1 : 0, withdrawn: rnd(15) === 0 ? 1 : 0 };
    const label = `${r.form}/${r.major}.${r.minor}.${r.patch}`;
    if (seen.has(label)) continue;
    seen.add(label);
    releases.push(r);
  }
  return { kind, releases };
}
const insRelease = (r) => ["INSERT INTO releases VALUES (?, ?, ?, ?, ?, ?, ?)",
  [r.log_index, r.form, stored(r.major, r.minor, r.patch), r.artifact, r.published_at, r.yanked, r.withdrawn]];
const load = (st) => [
  ["DELETE FROM releases", []], ["DELETE FROM artifacts", []],
  ...Object.entries(st.kind).map(([a, k]) => ["INSERT INTO artifacts VALUES (?, ?)", [Number(a), k]]),
  ...st.releases.map(insRelease),
];
const bot = (a, n, result = 0, source = 0) => ["INSERT OR IGNORE INTO compat VALUES (?, ?, 0, ?, ?)", [a, n, source, result]];
const sweep = (n, upto) => [`INSERT INTO sweeps VALUES (?, 0, ?) ON CONFLICT (nightly, target)
  DO UPDATE SET upto_log_index = excluded.upto_log_index WHERE excluded.upto_log_index > sweeps.upto_log_index`, [n, upto]];
async function tryBatch(b, stmts) { try { await b.batch(stmts); return "ok"; } catch (e) { return (String(e.message ?? e).match(/sweep-incomplete|sweep-smaller/) ?? [String(e.message ?? e)])[0]; } }

async function run(b) {
  const out = [];
  const check = (id, what, got, want) => out.push({ id, what, got: JSON.stringify(got), want: JSON.stringify(want), pass: JSON.stringify(got) === JSON.stringify(want) });

  // B1: the SQL member set equals the reference, on random indexes. The nightly is at day 900.
  await b.batch([["INSERT INTO toolchains VALUES (1, ?)", [900 * DAY]]]);
  let b1 = null, sizes = 0;
  for (let i = 0; i < STATES && !b1; i++) {
    const st = randomState(), L = 1 + rnd(st.releases.length + 1);
    await b.batch(load(st));
    const got = (await b.all(membersSql, [1, L])).map((x) => x.artifact), want = reference(st, L, 900 * DAY);
    sizes += want.length;
    if (JSON.stringify(got) !== JSON.stringify(want)) b1 = { state: st.releases.map((r) => `${r.log_index}:${r.form}/${r.major}.${r.minor}.${r.patch}=${r.artifact}${r.yanked ? "y" : ""}`), L, got, want };
  }
  check("B1", `SQL members = reference over ${STATES} random indexes (${sizes} members)`, b1, null);

  // A fixed index. Nightlies 1 (day 900), 2 (day 901), 3 (day 902), 4 (day 903). Group 1: 0.1.0 (A1), 0.1.1 (A2),
  // 0.2.0 (A3). Group 2: 1.0.0 (A4, day 100, old series), 2.0.0 (A5). Group 3: 1.0.0 (A6, day 10, the only series).
  // Group 4: an app (A7). Then 0.2.1 (A8, log index 8) after the bound.
  await b.batch([["DELETE FROM releases", []], ["DELETE FROM artifacts", []], ["DELETE FROM toolchains", []],
    ...[[1, 900], [2, 901], [3, 902], [4, 903]].map(([n, d]) => ["INSERT INTO toolchains VALUES (?, ?)", [n, d * DAY]]),
    ...[1, 2, 3, 4, 5, 6, 8].map((a) => ["INSERT INTO artifacts VALUES (?, 0)", [a]]), ["INSERT INTO artifacts VALUES (7, 2)", []],
    ...[[1, 1, 0, 1, 0, 1, 800], [2, 1, 0, 1, 1, 2, 850], [3, 1, 0, 2, 0, 3, 870], [4, 2, 1, 0, 0, 4, 100],
      [5, 2, 2, 0, 0, 5, 880], [6, 3, 1, 0, 0, 6, 10], [7, 4, 1, 0, 0, 7, 890]]
      .map(([i, f, ma, mi, pa, a, d]) => insRelease({ log_index: i, form: f, major: ma, minor: mi, patch: pa, artifact: a, published_at: d * DAY, yanked: 0, withdrawn: 0 })),
  ]);
  check("B0", "members at bound 7: newest of each series in the window, and the newest series of each group",
    (await b.all(membersSql, [1, 7])).map((x) => x.artifact), [2, 3, 5, 6]);

  const s2 = await tryBatch(b, [bot(2, 1), bot(3, 1), bot(5, 1), sweep(1, 7)]);
  check("B2", "no row for A6 (a member): incomplete, and nothing of the batch is written",
    [s2, (await b.all("SELECT COUNT(*) AS n FROM compat"))[0].n], ["sweep-incomplete", 0]);
  const s3 = await tryBatch(b, [bot(2, 1), bot(3, 1), bot(5, 1), bot(6, 1), sweep(1, 7)]);
  check("B3", "rows for the 4 members only: complete. A1 (an older patch) and A4 (an old series) need no row.", s3, "ok");
  // B4: A4 is the newest of series 1 but out of the window. With no window, it is a member.
  check("B4", "A4 (series 1 of group 2, day 100) is outside the window; A6 (day 10) is the newest series of group 3",
    [(await b.all(missingSql, [1, 0])).map((x) => x.artifact)], [[]]);
  // B5: a yank of A2 (0.1.1) between the read of the bot and its write makes A1 (0.1.0) a member.
  await b.batch([bot(2, 2), bot(3, 2), bot(5, 2), bot(6, 2)]); // the rows of the bot run: true facts, written apart
  await b.batch([["UPDATE releases SET yanked = 1 WHERE log_index = 2", []]]);
  const s5 = await tryBatch(b, [sweep(2, 7)]);
  check("B5", "after the yank of 0.1.1, 0.1.0 (A1) is a member: incomplete, and the route lists A1",
    [s5, (await b.all(missingSql, [2, 0])).map((x) => x.artifact)], ["sweep-incomplete", [1]]);
  await b.batch([["UPDATE releases SET yanked = 0 WHERE log_index = 2", []]]);
  // B6: a release above the bound (A8, log index 8) is not needed by a sweep at bound 7, but the route lists it.
  await b.batch([insRelease({ log_index: 8, form: 1, major: 0, minor: 2, patch: 1, artifact: 8, published_at: 899 * DAY, yanked: 0, withdrawn: 0 })]);
  const s6 = await tryBatch(b, [bot(2, 2), bot(3, 2), bot(5, 2), bot(6, 2), sweep(2, 7)]);
  check("B6", "A8 above the bound: sweep at 7 complete; the route at the log size lists A8",
    [s6, (await b.all(missingSql, [2, 0])).map((x) => x.artifact)], ["ok", [8]]);
  const s7 = await tryBatch(b, [bot(8, 2, 0, 1), sweep(2, 8)]);
  check("B7", "an author row for A8 does not count", s7, "sweep-incomplete");

  // T1: nightlies 1 and 2 are adjacent and swept. Same results, so compared 4 and changed 0. Then nightly 3 with A2 and
  // A3 failing, A5 crashing: compared 3 (the crash is a fault), changed 2.
  const t = async (n) => (await b.all("SELECT previous, compared, changed FROM transitions WHERE nightly = ?", [n]))[0] ?? null;
  check("T0", "transition (1, 2): 4 code results on both, none changed", await t(2), { previous: 1, compared: 4, changed: 0 });
  await tryBatch(b, [bot(2, 3, 1), bot(3, 3, 1), bot(5, 3, 2), bot(6, 3), bot(8, 3), sweep(3, 8)]);
  check("T1", "transition (2, 3): the crash of A5 is not compared; A2 and A3 changed", await t(3), { previous: 2, compared: 3, changed: 2 });
  // T2: a sweep of nightly 4 comes. Then T3: nightly 3 sweeps to a larger bound, and both its rows are computed again.
  await tryBatch(b, [bot(2, 4, 1), bot(3, 4, 1), bot(5, 4), bot(6, 4), bot(8, 4), sweep(4, 8)]);
  check("T2", "transition (3, 4): the crash of A5 on 3 is not compared", await t(4), { previous: 3, compared: 4, changed: 0 });
  // T3: nightly 6 has no row, so (5, 6) is not covered; then a sweep of 5 alone writes no transition to 6.
  await b.batch([["INSERT INTO toolchains VALUES (5, ?)", [904 * DAY]], ["INSERT INTO toolchains VALUES (6, ?)", [905 * DAY]]]);
  await tryBatch(b, [bot(2, 6), bot(3, 6), bot(5, 6), bot(6, 6), bot(8, 6), sweep(6, 8)]);
  check("T3", "nightly 5 is not swept: no transition (5, 6), and none from 4 to 6", await t(6), null);
  await tryBatch(b, [bot(2, 5, 1), bot(3, 5, 1), bot(5, 5), bot(6, 5), bot(8, 5), sweep(5, 8)]);
  check("T4", "a later sweep of 5 writes (4, 5) and (5, 6)", [await t(5), await t(6)],
    [{ previous: 4, compared: 5, changed: 0 }, { previous: 5, compared: 5, changed: 2 }]);
  return out;
}

const only = process.argv[2];
const backends = only === "sqlite" ? [sqliteBackend] : REMOTE ? [d1Backend] : [d1Backend, sqliteBackend];
let failed = 0;
for (const make of backends) {
  const b = await make();
  try {
    console.log(`\n## ${b.name}${process.env.MUTATE ? ` (MUTATE=${process.env.MUTATE})` : ""}\n\n| case | what | got | want | pass |\n| --- | --- | --- | --- | --- |`);
    for (const r of await run(b)) {
      if (!r.pass) failed++;
      console.log(`| ${r.id} | ${r.what} | ${r.got.replaceAll("|", "\\|").slice(0, 300)} | ${r.want} | ${r.pass ? "yes" : "NO"} |`);
    }
  } finally { await b.close(); }
}
process.exit(failed ? 1 : 0);
