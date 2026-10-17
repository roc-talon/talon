// Size and read time of the compat table (Registry R-RE3) with text keys and with integer keys (Registry 5.1).
// Run: node size.mjs [hashes] [nightlies]     (default 20000 x 50 = 1,000,000 rows, plain SQLite in memory)
import { DatabaseSync } from "node:sqlite";
import { createHash } from "node:crypto";
import { nameId, nightlyId } from "./ids.mjs";

const H = Number(process.argv[2] ?? 20000), N = Number(process.argv[3] ?? 50);
const B58 = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";
const base58 = (buf) => { let n = BigInt("0x" + buf.toString("hex")), s = ""; while (n > 0n) { s = B58[Number(n % 58n)] + s; n /= 58n; } return s; };
const hashes = Array.from({ length: H }, (_, i) => createHash("sha256").update(String(i)).digest());
const tags = Array.from({ length: N }, (_, i) => {
  const d = new Date(Date.UTC(2026, 0, 1) + i * 86400000).toISOString().slice(0, 10);
  return `nightly-${d}-${createHash("sha256").update(d).digest("hex").slice(0, 7)}`;
});
const digest = "error: undefined symbol: roc_alloc in host.o"; // about 5 % of the rows fail
// The 4 forms. text: the keys as the design has them now. int: integer keys. -wr: WITHOUT ROWID (the key is the table).
const forms = {
  text: `CREATE TABLE compat (hash TEXT NOT NULL, nightly TEXT NOT NULL, target TEXT NOT NULL, source TEXT NOT NULL,
    result TEXT NOT NULL, error_digest TEXT, time INTEGER NOT NULL, PRIMARY KEY (hash, nightly, target, source))`,
  "text-wr": `CREATE TABLE compat (hash TEXT NOT NULL, nightly TEXT NOT NULL, target TEXT NOT NULL, source TEXT NOT NULL,
    result TEXT NOT NULL, error_digest TEXT, time INTEGER NOT NULL, PRIMARY KEY (hash, nightly, target, source)) WITHOUT ROWID`,
  int: `CREATE TABLE compat (artifact INTEGER NOT NULL, nightly INTEGER NOT NULL, target INTEGER NOT NULL, source INTEGER NOT NULL,
    result INTEGER NOT NULL, error_digest TEXT, time INTEGER NOT NULL, PRIMARY KEY (artifact, nightly, target, source))`,
  "int-wr": `CREATE TABLE compat (artifact INTEGER NOT NULL, nightly INTEGER NOT NULL, target INTEGER NOT NULL, source INTEGER NOT NULL,
    result INTEGER NOT NULL, error_digest TEXT, time INTEGER NOT NULL, PRIMARY KEY (artifact, nightly, target, source)) WITHOUT ROWID`,
};
const keys = {
  text: { h: hashes.map(base58), n: tags, t: "any", s: "bot", r: (f) => (f ? "fail" : "pass") },
  int: { h: hashes.map((b) => nameId("artifact", b)), n: tags.map(nightlyId), t: 0, s: 0, r: (f) => (f ? 1 : 0) },
};

console.log(`rows ${H * N} (${H} hashes x ${N} nightlies, target any, source bot)`);
console.log("form\tMB\tbytes/row\t500-hash read ms\t10k point reads ms");
for (const [form, ddl] of Object.entries(forms)) {
  const k = keys[form.startsWith("int") ? "int" : "text"];
  const db = new DatabaseSync(":memory:");
  db.exec(ddl);
  const ins = db.prepare("INSERT INTO compat VALUES (?, ?, ?, ?, ?, ?, ?)");
  db.exec("BEGIN");
  for (let n = 0; n < N; n++) for (let h = 0; h < H; h++) {
    const fail = (h * 31 + n) % 20 === 0;
    ins.run(k.h[h], k.n[n], k.t, k.s, k.r(fail), fail ? digest : null, 1790000000 + n * 86400);
  }
  db.exec("COMMIT");
  db.exec("VACUUM");
  const bytes = db.prepare("PRAGMA page_count").get().page_count * db.prepare("PRAGMA page_size").get().page_size;
  // The closure answer reads the matrix rows of a set of hashes (R-AP17).
  const pick = Array.from({ length: 500 }, (_, i) => k.h[(i * 7919) % H]);
  const many = db.prepare("SELECT * FROM compat WHERE " + (form.startsWith("int") ? "artifact" : "hash") + " IN (SELECT value FROM json_each(?))");
  if (form.startsWith("int")) many.setReadBigInts(true); // node:sqlite throws on a 64-bit integer read as a Number
  // Integer ids go into the JSON as numbers: SQLite reads a 64-bit JSON integer exactly (K10).
  const json = form.startsWith("int") ? `[${pick.join(",")}]` : JSON.stringify(pick);
  let t0 = performance.now(), rows = 0;
  for (let i = 0; i < 5; i++) rows = many.all(json).length;
  const tMany = (performance.now() - t0) / 5;
  const one = db.prepare("SELECT result FROM compat WHERE " + (form.startsWith("int") ? "artifact" : "hash")
    + " = ? AND nightly = ? AND target = ? AND source = ?");
  t0 = performance.now();
  for (let i = 0; i < 10000; i++) one.get(k.h[(i * 104729) % H], k.n[i % N], k.t, k.s);
  const tOne = performance.now() - t0;
  console.log(`${form}\t${(bytes / 1e6).toFixed(1)}\t${(bytes / (H * N)).toFixed(1)}\t${tMany.toFixed(1)} (${rows} rows)\t${tOne.toFixed(1)}`);
  db.close();
}
