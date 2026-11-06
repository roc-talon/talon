// Probe for slice 118 (docs/slices/118-webhook.md): what Miniflare gives for a queue producer, a queue consumer, a delay, and a patch of crypto.subtle.timingSafeEqual.
// Run: node research/slice-118/probe-queue.mjs   (Miniflare of the global wrangler, as worker/tests/run.mjs)
import { createRequire } from 'node:module';
import { dirname, join } from 'node:path';
const mfDir = process.env.MINIFLARE ?? join(dirname(dirname(process.execPath)), 'lib/node_modules/wrangler/node_modules/miniflare');
const { Miniflare, convertV4MiniflareOptions } = createRequire(import.meta.url)(mfDir);

const script = `
let timing = 0;
const orig = crypto.subtle.timingSafeEqual;
let patched = 'no';
try { crypto.subtle.timingSafeEqual = function (a, b) { timing++; return orig.call(crypto.subtle, a, b); }; patched = crypto.subtle.timingSafeEqual !== orig ? 'yes' : 'assign-ignored'; } catch (e) { patched = 'throws: ' + e.message; }
const sent = [];
const wrap = (q) => new Proxy(q, { get(t, k) { const v = t[k]; if (k === 'send') return (...a) => { sent.push(JSON.stringify(a)); return v.apply(t, a); }; return typeof v === 'function' ? v.bind(t) : v; } });
export default {
  async fetch(req, env) {
    const u = new URL(req.url);
    if (u.pathname === '/send') { await wrap(env.INDEX).send({ event: 'release', n: 1 }, { contentType: 'json', delaySeconds: Number(u.searchParams.get('d') ?? 0) }); return new Response(JSON.stringify(sent)); }
    if (u.pathname === '/timing') { const r = crypto.subtle.timingSafeEqual(new Uint8Array([1, 2]), new Uint8Array([1, 2])); return new Response(JSON.stringify({ r, timing, patched })); }
    return new Response('no', { status: 404 });
  },
  async queue(batch, env) {
    for (const m of batch.messages) {
      if (batch.queue === 'talon-index') { if (m.body.n === 1) m.retry({ delaySeconds: 60 }); else m.ack(); }
    }
  },
};`;

const run = async (label, opts) => {
  const mf = new Miniflare(convertV4MiniflareOptions({ modules: true, script, compatibilityDate: '2026-10-01', queueProducers: { INDEX: 'talon-index' }, ...opts }));
  try {
    const t = await (await mf.dispatchFetch('http://x/timing')).json();
    const s = await (await mf.dispatchFetch('http://x/send?d=0')).json();
    const w = await mf.getWorker();
    const r = await w.queue('talon-index', [
      { id: 'a', timestamp: new Date(1_700_000_000_000), body: { n: 1 }, attempts: 1 },
      { id: 'b', timestamp: new Date(1_700_000_000_000), body: { n: 2 }, attempts: 5 },
    ]);
    console.log(label, JSON.stringify({ timing: t, sent: s, queueResult: r }));
  } finally { await mf.dispose(); }
};
// 1: a producer and no consumer. A message stays in the queue, and w.queue() calls the handler directly.
await run('no-consumer', {});
// 2: a consumer with a dead letter queue (the broker would deliver a sent message by itself).
await run('with-dlq', { queueConsumers: { 'talon-index': { maxBatchSize: 10, maxBatchTimeout: 0.1, maxRetries: 4, deadLetterQueue: 'talon-index-dlq' }, 'talon-index-dlq': { maxBatchSize: 10, maxBatchTimeout: 0.1 } } });
