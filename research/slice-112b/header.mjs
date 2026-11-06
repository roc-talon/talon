// Probe (slice 112b): does a cf-connecting-ip header of dispatchFetch reach the Worker as sent? And with no header, what value?
import { createRequire } from 'node:module';
import { dirname, join } from 'node:path';
const mfDir = process.env.MINIFLARE ?? join(dirname(dirname(process.execPath)), 'lib/node_modules/wrangler/node_modules/miniflare');
const { Miniflare, convertV4MiniflareOptions } = createRequire(import.meta.url)(mfDir);
const mf = new Miniflare(convertV4MiniflareOptions({ modules: true, compatibilityDate: '2026-10-01',
  script: `export default { async fetch(req) { return new Response(String(req.headers.get('cf-connecting-ip'))); } }` }));
console.log('sent 203.0.113.7:', await (await mf.dispatchFetch('http://x/', { headers: { 'cf-connecting-ip': '203.0.113.7' } })).text());
console.log('sent nothing:', await (await mf.dispatchFetch('http://x/')).text());
await mf.dispose();
