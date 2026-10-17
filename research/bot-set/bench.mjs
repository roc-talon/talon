// Time of the member query (R-MX11) and of one sweep write with the guard (R-MX8), plain SQLite in memory.
// Run: node bench.mjs [groups] [releases per group]     (default 2000 x 10 = 20,000 releases)
import { DatabaseSync } from "node:sqlite";
import { schema, membersSql } from "./schema.mjs";

const G = Number(process.argv[2] ?? 2000), R = Number(process.argv[3] ?? 10);
const DAY = 86400;
const stored = (ma, mi, pa) => BigInt.asIntN(64, ((BigInt(ma) << 48n) | (BigInt(mi) << 32n) | (BigInt(pa) << 16n) | 0xffffn) ^ (1n << 63n));
for (const index of [false, true]) {
  const db = new DatabaseSync(":memory:");
  for (const s of schema) db.exec(s);
  if (index) db.exec("CREATE INDEX releases_form ON releases (form, version)");
  db.exec("BEGIN");
  db.prepare("INSERT INTO toolchains VALUES (1, ?)").run(900 * DAY);
  const ins = db.prepare("INSERT INTO releases VALUES (?, ?, ?, ?, ?, 0, 0)"), art = db.prepare("INSERT INTO artifacts VALUES (?, 0)");
  let i = 0;
  // Each group: R releases over 3 series (0.1, 0.2, 1), one release every 30 days, the last one near day 900.
  for (let g = 1; g <= G; g++) for (let k = 0; k < R; k++) {
    i++;
    const [ma, mi] = k < R / 3 ? [0, 1] : k < (2 * R) / 3 ? [0, 2] : [1, 0];
    art.run(i);
    ins.run(i, g, stored(ma, mi, k), i, (900 - (R - k) * 30 + (g % 30)) * DAY);
  }
  db.exec("COMMIT");
  let t0 = performance.now();
  const members = db.prepare(membersSql).all(1, i).map((x) => x.artifact);
  const tMembers = performance.now() - t0;
  const bot = db.prepare("INSERT INTO compat VALUES (?, 1, 0, 0, 0)");
  db.exec("BEGIN"); for (const a of members) bot.run(a); db.exec("COMMIT");
  t0 = performance.now();
  db.prepare("INSERT INTO sweeps VALUES (1, 0, ?)").run(i);
  const tSweep = performance.now() - t0;
  console.log(`index on (form, version): ${index ? "yes" : "no "}  releases ${i}  members ${members.length}  member query ${tMembers.toFixed(1)} ms  sweep write ${tSweep.toFixed(1)} ms`);
  db.close();
}
