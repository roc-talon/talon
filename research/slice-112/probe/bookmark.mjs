// Probe (slice 112): does local D1 (Miniflare) give a bookmark for a session after a batch?
import { createRequire } from 'node:module';
import { dirname, join } from 'node:path';
const mfDir = process.env.MINIFLARE ?? join(dirname(dirname(process.execPath)), 'lib/node_modules/wrangler/node_modules/miniflare');
const { Miniflare, convertV4MiniflareOptions } = createRequire(import.meta.url)(mfDir);
const mf = new Miniflare(convertV4MiniflareOptions({ modules: true, compatibilityDate: "2026-10-01", d1Databases: ['DB'], script: `export default { async fetch(req, env) {
  await env.DB.prepare('CREATE TABLE IF NOT EXISTS t (k INTEGER PRIMARY KEY)').run();
  const s = env.DB.withSession('first-primary');
  const b0 = s.getBookmark();
  await s.prepare('SELECT 1').all();
  const b1 = s.getBookmark();
  await s.batch([s.prepare('INSERT INTO t (k) VALUES (?)').bind(Date.now())]);
  const b2 = s.getBookmark();
  return Response.json({ b0, b1, b2 });
} }` }));
for (let i = 0; i < 2; i++) console.log(await (await mf.dispatchFetch('http://x/')).text());
await mf.dispose();
