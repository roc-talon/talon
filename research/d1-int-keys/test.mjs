// Tests the integer keys of Registry 5.1 (R-IK1 to R-IK7) on local D1 and on plain SQLite.
// Run: node test.mjs                  (both backends)
//      node test.mjs sqlite           (plain SQLite only)
//      MUTATE=notarget node test.mjs  (ON CONFLICT DO NOTHING with no conflict target: K5 must fail, exit code 1)
//      MUTATE=nostrict node test.mjs  (the tables of K12 with no STRICT: K12 must fail)
// Local D1 comes from the global wrangler install (getPlatformProxy), or from $WRANGLER (a path to the wrangler package).
import { readFileSync, mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { execSync } from "node:child_process";
import { createRequire } from "node:module";
import { DatabaseSync } from "node:sqlite";
import { nameId, nightlyId, talonVersionId } from "./ids.mjs";

const MUTATE = process.env.MUTATE ?? "";
const schema = readFileSync(new URL("schema.sql", import.meta.url), "utf8")
  .split(/^;;$/m).map((s) => s.replace(/^--.*$/gm, "").trim()).filter(Boolean)
  .map((s) => (MUTATE === "nostrict" ? s.replace(/\) STRICT, WITHOUT ROWID$/, ") WITHOUT ROWID").replace(/\) STRICT$/, ")") : s));

function sqliteBackend() {
  const db = new DatabaseSync(":memory:");
  for (const s of schema) db.exec(s);
  return {
    name: "sqlite",
    async batch(stmts) {
      db.exec("BEGIN");
      try {
        const out = stmts.map(([sql, p]) => /^\s*SELECT|RETURNING/i.test(sql)
          ? { rows: db.prepare(sql).all(...p) } : (db.prepare(sql).run(...p), { rows: [] }));
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
  const persist = mkdtempSync(join(tmpdir(), "d1-int-keys-"));
  const proxy = await getPlatformProxy({ configPath: new URL("wrangler.toml", import.meta.url).pathname, persist: { path: persist } });
  const db = proxy.env.DB;
  for (const s of schema) await db.prepare(s).run();
  return {
    name: "d1",
    async batch(stmts) {
      const res = await db.batch(stmts.map(([sql, p]) => db.prepare(sql).bind(...p)));
      return res.map((r) => ({ rows: r.results ?? [] }));
    },
    async all(sql, p = []) { return (await db.prepare(sql).bind(...p).all()).results; },
    async close() { await proxy.dispose(); rmSync(persist, { recursive: true, force: true }); },
  };
}

const err = async (f) => { try { await f(); return null; } catch (e) { return String(e.message ?? e); } };

// R-IK3: insert a name. Only a (kind, value) that is there already is skipped. An id of another name stops the batch.
const putName = (id, kind, value) => [`INSERT INTO names (id, kind, value) VALUES (?, ?, ?)
  ON CONFLICT ${MUTATE === "notarget" ? "" : "(kind, value) "}DO NOTHING`, [id, kind, value]];
const putRelease = (log, form, [ma, mi, pa], artifact) => [
  "INSERT INTO releases (log_index, form, major, minor, patch, artifact) VALUES (?, ?, ?, ?, ?, ?)",
  [log, form, ma, mi, pa, artifact]];

async function run(b) {
  const out = [];
  const check = (id, what, ok, got) => out.push({ id, what, ok, got });
  const MAX = 2 ** 53 - 1;

  // K1: a 53-bit id goes in as a Number and comes back exact, also through a JSON parameter.
  await b.batch([["INSERT INTO ids (id) VALUES (?)", [MAX]],
    ["INSERT INTO ids (id) SELECT value FROM json_each(?)", [JSON.stringify([MAX - 1])]]]);
  const k1 = (await b.all("SELECT id FROM ids WHERE id >= ? ORDER BY id", [MAX - 1])).map((r) => r.id);
  check("K1", "2^53-1 and 2^53-2 round trip", k1.length === 2 && k1[0] === MAX - 1 && k1[1] === MAX, k1.join(","));

  // K2: D1 takes no BigInt parameter.
  const k2 = await err(() => b.batch([["INSERT INTO ids (id) VALUES (?)", [2n ** 60n]]]));
  check("K2", "BigInt parameter", b.name === "d1" ? k2 !== null : true, k2 ?? "accepted");

  // K3: a 64-bit id goes in as text (INTEGER affinity stores an integer), but comes back rounded.
  // The rounded value names another row with no error. Only CAST(id AS TEXT) gives the exact value.
  await b.batch([["INSERT INTO ids (id) VALUES (?)", ["9007199254740993"]], ["INSERT INTO ids (id) VALUES (?)", ["9007199254740992"]]]);
  // node:sqlite throws on the plain read (RangeError). D1 gives a rounded Number with no error.
  let plain = null;
  const thrown = await err(async () => { plain = (await b.all("SELECT id FROM ids WHERE id = ?", ["9007199254740993"]))[0]; });
  const t = (await b.all("SELECT typeof(id) t FROM ids WHERE id = ?", ["9007199254740993"]))[0].t;
  const exact = (await b.all("SELECT CAST(id AS TEXT) s FROM ids WHERE id = ?", ["9007199254740993"]))[0].s;
  const other = plain && (await b.all("SELECT CAST(id AS TEXT) s FROM ids WHERE id = ?", [plain.id]))[0]?.s;
  check("K3", "2^53+1 read as a Number", t === "integer" && exact === "9007199254740993"
    && (b.name === "sqlite" ? /too large/.test(thrown ?? "") : thrown === null && other === "9007199254740992"),
    `typeof ${t}, read ${plain?.id ?? thrown}, cast ${exact}, lookup of the read value ${other}`);

  // K4: the same name twice is one row and no error.
  const A = nameId("artifact", Buffer.alloc(32, 7)), F = nameId("form", "github.com/roc-lang/unicode/releases/download/{v}/");
  await b.batch([putName(A, 1, Buffer.alloc(32, 7)), putName(F, 2, "github.com/roc-lang/unicode/releases/download/{v}/")]);
  const k4 = await err(() => b.batch([putName(F, 2, "github.com/roc-lang/unicode/releases/download/{v}/"),
    putRelease(1, F, [4, 2, 0], A)]));
  const n4 = (await b.all("SELECT COUNT(*) n FROM names"))[0].n;
  check("K4", "same name again, then a release", k4 === null && n4 === 2, k4 ?? `names ${n4}`);

  // K5: another name with the id of F stops the batch, and the release of that batch is not written.
  const k5 = await err(() => b.batch([putName(F, 2, "github.com/attacker/x/releases/download/{v}/"),
    putRelease(2, F, [1, 0, 0], A)]));
  const r5 = (await b.all("SELECT COUNT(*) n FROM releases WHERE log_index = 2"))[0].n;
  check("K5", "id collision stops the batch", k5 !== null && /UNIQUE/.test(k5) && r5 === 0, k5 ?? `written, releases ${r5}`);

  // K6: version parts are u32 as in roc (url.zig parseInt(u32)). 01.2.3 and 1.2.3 are one label.
  const U = 4294967295;
  const k6a = await err(() => b.batch([putRelease(3, F, [U, U, U], A)]));
  const k6b = await err(() => b.batch([putRelease(4, F, [U + 1, 0, 0], A)]));
  const k6c = await err(() => b.batch([putRelease(5, F, [-1, 0, 0], A)]));
  const k6d = await err(() => b.batch([putRelease(6, F, [Number("01"), 2, 3], A), putRelease(7, F, [1, 2, 3], A)]));
  const top = (await b.all("SELECT major, minor, patch FROM releases WHERE form = ? ORDER BY major DESC, minor DESC, patch DESC LIMIT 1", [F]))[0];
  check("K6", "u32 parts, CHECK, one label", k6a === null && /CHECK/.test(k6b ?? "") && /CHECK/.test(k6c ?? "")
    && /UNIQUE/.test(k6d ?? "") && top.major === U && top.patch === U, `${k6a}|${k6b}|${k6c}|${k6d}`);

  // K9: a WITHOUT ROWID table works on D1, and the first write of a key wins (R-RE13 row 1).
  const N7 = nightlyId("nightly-2026-10-09-258ab27");
  const put = (r) => ["INSERT INTO compat VALUES (?, ?, 0, 0, ?) ON CONFLICT DO NOTHING", [A, N7, r]];
  const k9 = await err(() => b.batch([put(0), put(1)]));
  const r9 = await b.all("SELECT result FROM compat WHERE artifact = ? AND nightly = ? AND target = 0 AND source = 0", [A, N7]);
  check("K9", "WITHOUT ROWID, first write wins", k9 === null && r9.length === 1 && r9[0].result === 0, k9 ?? JSON.stringify(r9));

  // K10: 64-bit ids bound as text (the string trick). Where does the text become an integer, and where not?
  const BIG = "9223372036854775807", NEG = "-9223372036854775807";
  await b.batch([["INSERT INTO ids (id) VALUES (?)", [BIG]], ["INSERT INTO ids (id) VALUES (?)", [NEG]]]);
  const q = async (sql, p) => (await b.all(sql, p)).map((r) => Object.values(r).join("/")).join(",");
  const k10 = {
    where: await q("SELECT CAST(id AS TEXT) s FROM ids WHERE id = ?", [BIG]),
    in_json: await q("SELECT CAST(id AS TEXT) s FROM ids WHERE id IN (SELECT value FROM json_each(?)) ORDER BY id", [`[${BIG},${NEG}]`]),
    cte_join: await q("WITH p(x) AS (VALUES (?)) SELECT CAST(id AS TEXT) s FROM ids JOIN p ON ids.id = p.x", [BIG]),
    param_eq: await q("SELECT ? = (SELECT id FROM ids WHERE id = ?) AS e", [BIG, BIG]),
    two_params: await q("SELECT ? = ? + 0 AS e", [BIG, BIG]),
    column_plus0: await q("SELECT COUNT(*) n FROM ids WHERE id = ? + 0", [BIG]),
    cast_param: await q("SELECT COUNT(*) n FROM ids WHERE id = CAST(? AS INTEGER)", [BIG]),
    returning: await b.batch([["INSERT INTO ids (id) VALUES (?) RETURNING id", ["9223372036854775806"]]])
      .then((r) => r[0].rows[0].id, (e) => "throws"),
    plain_read: (await b.all("SELECT id FROM ids WHERE id = ?", [NEG]).catch((e) => [{ id: "throws" }]))[0].id,
  };
  const ok10 = k10.where === BIG && k10.in_json === `${NEG},${BIG}` && k10.cte_join === BIG && k10.param_eq === "1"
    && k10.two_params === "0" && k10.column_plus0 === "1" && k10.cast_param === "1";
  check("K10", "64-bit text ids: where, json_each, CTE join, compare", ok10, JSON.stringify(k10));

  // K11: the guard of R-IK3. With CAST an id comes back as text. Without it, D1 gives a Number, so a decoder
  // that reads the id column only as text fails. node:sqlite throws on the plain read.
  const cast = (await b.all("SELECT CAST(id AS TEXT) id FROM ids WHERE id = ?", [BIG]))[0].id;
  const bare = await b.all("SELECT id FROM ids WHERE id = ?", [BIG]).then((r) => typeof r[0].id, () => "throws");
  check("K11", "CAST gives text, a bare read does not", typeof cast === "string" && cast === BIG
    && (b.name === "d1" ? bare === "number" : bare === "throws"), `cast ${typeof cast}, bare ${bare}`);

  // K12: STRICT. A 64-bit id as text goes in as an integer. Text that is not an integer, or an integer out of the
  // i64 range, is SQLITE_CONSTRAINT_DATATYPE. A table that is not STRICT stores them as TEXT and REAL with no error.
  const kind = async (t, v) => {
    const e = await err(() => b.batch([[`INSERT INTO ${t} (a, b) VALUES (?, 1)`, [v]]]));
    if (e) return /DATATYPE|cannot store/.test(e) ? "datatype" : e;
    return (await b.all(`SELECT typeof(a) t FROM ${t} WHERE b = 1 AND a = ?`, [v]))[0]?.t ?? "?";
  };
  const k12 = {
    strict_big: await kind("strict_refs", BIG),
    strict_word: await kind("strict_refs", "abc"),
    strict_over: await kind("strict_refs", "9223372036854775808"),
    loose_word: await kind("loose_refs", "abc"),
    loose_over: await kind("loose_refs", "9223372036854775808"),
    names_text_for_hash: await err(() => b.batch([["INSERT INTO strict_ids (id, kind, value) VALUES (?, 1, ?)", [BIG, "not-bytes"]]]))
      .then((e) => (e && /CHECK/.test(e) ? "check" : e ?? "accepted")),
    names_ok: await err(() => b.batch([["INSERT INTO strict_ids (id, kind, value) VALUES (?, 1, ?), (?, 2, ?)",
      [BIG, Buffer.alloc(32, 1), NEG, "github.com/x/y/releases/download/{v}/"]]])).then((e) => e ?? "ok"),
  };
  check("K12", "STRICT: text id ok, bad text and out of range are errors; loose tables store them",
    k12.strict_big === "integer" && k12.strict_word === "datatype" && k12.strict_over === "datatype"
    && k12.loose_word === "text" && k12.loose_over === "real" && k12.names_text_for_hash === "check" && k12.names_ok === "ok",
    JSON.stringify(k12));
  return out;
}

// K7, K8: the id functions, with no database.
function pure() {
  const out = [];
  const check = (id, what, ok, got) => out.push({ id, what, ok, got });
  const a = nightlyId("nightly-2026-10-09-258ab27"), b = nightlyId("nightly-2026-October-09-258ab27");
  const c = nightlyId("nightly-2026-10-12-0000000"), d = nightlyId("nightly-2026-02-30-258ab27");
  check("K7", "nightly id: both tag forms, order, < 2^47, bad date",
    a === b && a < c && c < 2 ** 47 && d === null && nightlyId("0.1.0") === null, `${a} ${c} ${d}`);
  const form = "github.com/roc-lang/unicode/releases/download/{v}/";
  const hex = execSync("sha256sum", { input: Buffer.concat([Buffer.from([2]), Buffer.from(form)]) }).toString().slice(0, 16);
  const id = nameId("form", form);
  check("K8", "name id = first 8 bytes of sha256sum as i64, kinds differ", id === BigInt.asIntN(64, BigInt("0x" + hex)).toString()
    && nameId("repo", form) !== id && talonVersionId("0.4.1") === 262145
    && talonVersionId("0.4.1-rc1") === -1, `form id ${id}, sha256 ${hex}`);
  return out;
}

const only = process.argv[2];
const backends = only === "sqlite" ? [sqliteBackend()] : [sqliteBackend(), await d1Backend()];
let failed = 0;
for (const b of backends) {
  const res = await run(await b);
  await (await b).close();
  for (const r of res) {
    if (!r.ok) failed++;
    console.log(`${(await b).name}\t${r.ok ? "ok  " : "FAIL"}\t${r.id}\t${r.what}\t${r.got}`);
  }
}
for (const r of pure()) {
  if (!r.ok) failed++;
  console.log(`-\t${r.ok ? "ok  " : "FAIL"}\t${r.id}\t${r.what}\t${r.got}`);
}
process.exit(failed ? 1 : 0);
