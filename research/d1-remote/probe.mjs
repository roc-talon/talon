// Remote D1 run: the error texts, the result meta and the round trip time, on local D1 and on remote D1.
// Run: node probe.mjs          (local D1, in a temp dir)
//      node probe.mjs remote   (rocplat-test-d1-remote; run.sh create first)
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { execSync } from "node:child_process";
import { createRequire } from "node:module";
import { REMOTE, configPath, wipe } from "./remote.mjs";

const dir = process.env.WRANGLER ?? `${execSync("npm root -g").toString().trim()}/wrangler`;
const { getPlatformProxy } = createRequire(import.meta.url)(dir);
const tmp = mkdtempSync(join(tmpdir(), "d1-probe-"));
const local = join(tmp, "wrangler.toml");
writeFileSync(local, 'name = "probe"\ncompatibility_date = "2026-10-01"\n[[d1_databases]]\nbinding = "DB"\ndatabase_name = "probe"\ndatabase_id = "00000000-0000-0000-0000-000000000000"\n');
const proxy = await getPlatformProxy({ configPath: configPath(local), persist: { path: tmp } });
const db = proxy.env.DB;
const err = async (f) => { try { await f(); return "ok"; } catch (e) { return { message: e.message, cause: e.cause?.message ?? null }; } };
const out = {};
try {
  await wipe(db);
  await db.batch([
    "CREATE TABLE t (k INTEGER PRIMARY KEY, r TEXT CHECK (r IN ('pass', 'fail')))",
    "CREATE TABLE side (k INTEGER)",
    "CREATE TRIGGER t_side AFTER INSERT ON t BEGIN INSERT INTO side VALUES (NEW.k); INSERT INTO side VALUES (NEW.k); END",
    "CREATE TRIGGER t_quota BEFORE INSERT ON t WHEN NEW.k > 100 BEGIN SELECT RAISE(ABORT, 'hint-quota'); END",
  ].map((s) => db.prepare(s)));
  const ins = (k, r = "pass") => db.prepare("INSERT INTO t VALUES (?, ?) ON CONFLICT DO NOTHING RETURNING k").bind(k, r);
  const res = await db.batch([ins(1), ins(2), ins(1)]);
  out.meta = res.map((x) => ({ results: x.results, changes: x.meta.changes, rows_written: x.meta.rows_written, last_row_id: x.meta.last_row_id,
    served_by_region: x.meta.served_by_region ?? null, served_by_colo: x.meta.served_by_colo ?? null, served_by_primary: x.meta.served_by_primary ?? null }));
  out.raise = await err(() => db.batch([ins(3), ins(101)]));
  out.check = await err(() => db.batch([ins(4), ins(5, "hang")]));
  out.afterFailed = (await db.prepare("SELECT (SELECT COUNT(*) FROM t) AS t, (SELECT COUNT(*) FROM side) AS side").all()).results[0];
  out.raiseInRun = await err(() => ins(102).run());
  const times = [];
  for (let i = 0; i < 10; i++) { const t0 = performance.now(); await db.batch([ins(10 + i), db.prepare("SELECT COUNT(*) FROM t")]); times.push(performance.now() - t0); }
  times.sort((a, b) => a - b);
  out.batchMs = { min: Math.round(times[0]), median: Math.round(times[5]), max: Math.round(times[9]) };
  console.log(JSON.stringify({ backend: REMOTE ? "d1-remote" : "d1-local", ...out }, null, 1));
} finally { await proxy.dispose(); rmSync(tmp, { recursive: true, force: true }); }
