// What JS type does local D1 give for a BLOB in a STRICT table column of type ANY (names.value)?
import { createRequire } from 'node:module';
import { dirname, join } from 'node:path';
const mf = process.env.MINIFLARE ?? join(dirname(dirname(process.execPath)), 'lib/node_modules/wrangler/node_modules/miniflare');
const { Miniflare, convertV4MiniflareOptions } = createRequire(import.meta.url)(mf);
const m = new Miniflare(convertV4MiniflareOptions({ modules: [{ type: "ESModule", path: "w.js", contents: "export default { fetch() { return new Response(1) } }" }], compatibilityDate: "2026-10-01", d1Databases: ["DB"] }));
const db = await m.getD1Database('DB');
await db.prepare('CREATE TABLE n (id INTEGER PRIMARY KEY, kind INTEGER, value ANY NOT NULL) STRICT').run();
await db.prepare("INSERT INTO n VALUES (1, 1, X'0102ff'), (2, 2, 'text')").run();
for (const sql of ["SELECT value FROM n WHERE id = 1", "SELECT x'0102ff' AS value"]) {
  const r = await db.prepare(sql).all();
  const v = r.results[0].value;
  console.log(sql, '->', Object.prototype.toString.call(v), JSON.stringify(v));
}
await m.dispose();
