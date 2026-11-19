import { createRequire } from 'node:module';
import { dirname, join } from 'node:path';
import { createHash } from 'node:crypto';
const mfDir = process.env.MINIFLARE ?? join(dirname(dirname(process.execPath)), 'lib/node_modules/wrangler/node_modules/miniflare');
const { Miniflare, convertV4MiniflareOptions } = createRequire(import.meta.url)(mfDir);
const script = `export default { async fetch(req, env) {
  const b = env.LOG;
  await b.put('k', new Uint8Array([1,2,3,4]), { httpMetadata: { contentType: 'application/octet-stream' } });
  const h = await b.head('k');
  return Response.json({ etag: h.etag, http: h.httpEtag });
} }`;
const v4 = { modules: true, script, r2Buckets: ['LOG'], compatibilityDate: '2026-10-01' };
const mf = new Miniflare(convertV4MiniflareOptions ? convertV4MiniflareOptions(v4) : v4);
console.log(JSON.stringify(await (await mf.dispatchFetch('http://localhost/')).json()));
await mf.dispose();
console.log(createHash('md5').update(Buffer.from([1,2,3,4])).digest('hex'));
