// Probe (slice 112b): does the Miniflare `ratelimits` binding count locally? 65 calls of limit() with one key, then one with another key,
// in one Miniflare, with the same options form as worker/tests/run.mjs (convertV4MiniflareOptions). Run: node research/slice-112b/ratelimit.mjs
import { createRequire } from 'node:module';
import { dirname, join } from 'node:path';
const mfDir = process.env.MINIFLARE ?? join(dirname(dirname(process.execPath)), 'lib/node_modules/wrangler/node_modules/miniflare');
const { Miniflare, convertV4MiniflareOptions } = createRequire(import.meta.url)(mfDir);
const mf = new Miniflare(convertV4MiniflareOptions({
  modules: true, compatibilityDate: '2026-10-01',
  ratelimits: { RL_INGEST: { namespace_id: '1001', simple: { limit: 60, period: 60 } } },
  script: `export default { async fetch(req, env) {
    const key = new URL(req.url).searchParams.get('k');
    const r = await env.RL_INGEST.limit({ key });
    return Response.json(r);
  } }`,
}));
const out = [];
for (let i = 1; i <= 65; i++) out.push((await (await mf.dispatchFetch('http://x/?k=1.2.3.4')).json()).success);
const other = (await (await mf.dispatchFetch('http://x/?k=5.6.7.8')).json()).success;
console.log(JSON.stringify({ firstFalse: out.indexOf(false) + 1, trues: out.filter(Boolean).length, otherKey: other }));
// A second Miniflare: a new count (each W2 case has its own Miniflare)
const mf2 = new Miniflare(convertV4MiniflareOptions({ modules: true, compatibilityDate: '2026-10-01', ratelimits: { RL_INGEST: { namespace_id: '1001', simple: { limit: 60, period: 60 } } }, script: `export default { async fetch(req, env) { return Response.json(await env.RL_INGEST.limit({ key: '1.2.3.4' })); } }` }));
console.log(JSON.stringify({ secondInstance: (await (await mf2.dispatchFetch('http://x/')).json()).success }));
await mf.dispose(); await mf2.dispose();
