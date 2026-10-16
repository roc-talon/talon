// Cost of the sweep guard (R-MX4) on local D1: N hashes, each with one bot row on N1, then one sweep write.
// Run: node bench.mjs [N ...]     Default: 1000 5000 20000.
import { readFileSync, mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { execSync } from "node:child_process";
import { createRequire } from "node:module";

const schema = readFileSync(new URL("schema.sql", import.meta.url), "utf8")
  .split(/^;;$/m).map((s) => s.replace(/^--.*$/gm, "").trim()).filter(Boolean);
const dir = process.env.WRANGLER ?? `${execSync("npm root -g").toString().trim()}/wrangler`;
const { getPlatformProxy } = createRequire(import.meta.url)(dir);
const sweep = "INSERT INTO sweeps (nightly, target, upto_log_index) VALUES (?, 'any', ?) ON CONFLICT (nightly, target) DO UPDATE SET upto_log_index = excluded.upto_log_index WHERE excluded.upto_log_index > sweeps.upto_log_index";

console.log("| hashes | sweep batch, median of 5 (ms) | D1 `meta.duration` (ms) |\n| --- | --- | --- |");
for (const n of (process.argv.slice(2).length ? process.argv.slice(2) : ["1000", "5000", "20000"]).map(Number)) {
  const persist = mkdtempSync(join(tmpdir(), "d1-bench-"));
  const proxy = await getPlatformProxy({ configPath: new URL("wrangler.toml", import.meta.url).pathname, persist: { path: persist } });
  const db = proxy.env.DB;
  for (const s of schema) await db.prepare(s).run();
  // Fill with a recursive CTE: n releases (log index 1..n, the trigger writes the leaves) and n bot rows.
  await db.prepare(`WITH RECURSIVE i(x) AS (SELECT 1 UNION ALL SELECT x + 1 FROM i WHERE x < ?)
    INSERT INTO releases (grp, version, hash, log_index) SELECT 'g' || x, '1.0.0', 'H' || x, x FROM i`).bind(n).run();
  await db.prepare(`INSERT INTO compat (hash, nightly, target, source, result) SELECT hash, 'N1', 'any', 'bot', 'pass' FROM releases`).run();
  // N2..N6 have no rows, so these writes are incomplete and fail. N1 below has a row for each hash.
  const wall = [], dur = [];
  for (let k = 0; k < 5; k++) {
    const t = performance.now();
    const [r] = await db.batch([db.prepare(sweep).bind(`N${k + 2}`, n)]).catch(() => [{ meta: {} }]);
    wall.push(performance.now() - t); dur.push(r.meta?.duration);
  }
  const wallOk = [], durOk = [];
  for (let k = 0; k < 5; k++) {
    const t = performance.now();
    const [r] = await db.batch([db.prepare(sweep).bind("N1", n - 4 + k)]);
    wallOk.push(performance.now() - t); durOk.push(r.meta.duration);
  }
  const med = (a) => a.slice().sort((x, y) => x - y)[2].toFixed(2);
  console.log(`| ${n} | complete: ${med(wallOk)}. Incomplete (fails early): ${med(wall)} | complete: ${med(durOk)} |`);
  await proxy.dispose(); rmSync(persist, { recursive: true, force: true });
}
