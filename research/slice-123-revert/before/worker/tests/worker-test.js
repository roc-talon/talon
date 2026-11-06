// The test entry of the W2 runner (docs/registry/PLAN.md B.1). It replaces worker.js in the tests. Not for production.
//   1. It wraps env.DB, so each D1 call of a request is counted (the D1 call budget test of Registry 4.2). The count is in the header `x-d1-calls`,
//      and the kinds of the calls are in `x-d1-ops`. A subclass of the class that `makeHandler` gives reads `this.env`:
//      the shim does not document this (docs/slices/101-worker-skeleton.md "Platform issues").
//   2. It fixes the clock (the clock rule of Registry 8, TW2): clock.js sets `Date.now()` before the shim loads, and the request header `x-test-now` (ms since 1970)
//      sets the time of a request. `Time.now_ms!` of the platform calls `Date.now()`. The shim option `now` is not this clock (it drives
//      the task deadlines and the pins only), so the shim keeps the real clock through that option.
//   Slice 118: 4. The queue producer INDEX (if the case has it) records each send: the header `x-queue-sent` is the JSON list `[{"body":..,"delay_s":N}]`. `crypto.subtle.timingSafeEqual` counts its calls:
//      the header `x-timing-safe-calls`. The queue `__test...` is answered here (ack, or retry with `retry_s`), so the runner checks its queue lines without Roc code.
//   3. It answers the paths `/__test/...` itself, with no Roc code, so the checks of the runner do not depend on the Worker
//      (worker/tests/selftest/, worker/tests/cases/runner/).
import { realNow, setNow } from './clock.js'; // first: it fixes Date.now() before the shim loads
import app from './app.wasm';
import { makeHandler } from './.roc-cfw/index.js';

const inner = makeHandler(app, { now: realNow });
let ops = [];
let session = ''; // the argument of the last withSession of the request (x-d1-session)

const wrapStmt = (s) => new Proxy(s, {
  get(t, k) {
    const v = t[k];
    if (k === 'bind') return (...a) => wrapStmt(v.apply(t, a));
    if (['all', 'run', 'first', 'raw'].includes(k)) return (...a) => { ops.push(k); return v.apply(t, a); };
    return typeof v === 'function' ? v.bind(t) : v;
  },
});
const wrapDb = (db) => new Proxy(db, {
  get(t, k) {
    const v = t[k];
    if (k === 'prepare') return (...a) => wrapStmt(v.apply(t, a));
    if (k === 'batch' || k === 'exec') return (...a) => { ops.push(k); return v.apply(t, a); };
    if (k === 'withSession') return (...a) => { session = String(a[0]); return wrapDb(v.apply(t, a)); };
    return typeof v === 'function' ? v.bind(t) : v;
  },
});

// Slice 118: the sends to the queue producer and the calls of timingSafeEqual in the request (reset in fetch).
let sent = [];
let timing = 0;
let failSends = -1; // slice 119b: the sends to INDEX that still fail (the setting TEST_INDEX_FAIL_SENDS of the case; read once)
const timingOrig = crypto.subtle.timingSafeEqual;
crypto.subtle.timingSafeEqual = function (a, b) { timing++; return timingOrig.call(crypto.subtle, a, b); };
const wrapQueue = (q) => new Proxy(q, {
  get(t, k) {
    const v = t[k];
    if ((k === 'send' || k === 'sendBatch') && failSends > 0) return () => { failSends--; return Promise.reject(new Error('test: the queue send is refused (TEST_INDEX_FAIL_SENDS)')); };
    if (k === 'send') return (body, opts) => { sent.push({ body, delay_s: opts?.delaySeconds ?? 0 }); return v.call(t, body, opts); };
    if (k === 'sendBatch') return (items, opts) => { for (const m of items) sent.push({ body: m.body, delay_s: opts?.delaySeconds ?? 0 }); return v.call(t, items, opts); };
    return typeof v === 'function' ? v.bind(t) : v;
  },
});

const json = (status, body, headers = {}) => new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json', ...headers } });

export default class Test extends inner {
  constructor(ctx, env) {
    super(ctx, { ...env, DB: wrapDb(env.DB), ...(env.INDEX ? { INDEX: wrapQueue(env.INDEX) } : {}) });
    if (failSends < 0) failSends = Number(env.TEST_INDEX_FAIL_SENDS ?? 0);
  }

  // The paths of the runner. `/__test/json`: a fixed JSON answer. `/__test/problem`: a fixed problem answer. `/__test/d1?n=K&write=1`: K reads
  // (and one write) on the wrapped DB. `/__test/now`: the clock. `/__test/headers`: the headers `cache-control` and `pragma` of the request. `/__test/count`: the rows of `example`. `/__test/session?id=X`: a read in `withSession(X)`. `/__test/rows`: a list of 3 rows (slice 109, the checks json_len, json_at, json_range). `/__test/github`: one outbound fetch.
  async selfTest(url, req) {
    const p = url.pathname;
    if (p === '/__test/json') return json(200, { a: 1, b: { c: [1, 2, 3] }, s: 'x' }, { 'x-test': 'yes' });
    if (p === '/__test/problem') return json(404, { type: '/errors/not-found', title: 'Not found', status: 404, detail: 'fixed' }, { 'content-type': 'application/problem+json' });
    if (p === '/__test/now') return json(200, { now: Date.now() });
    if (p === '/__test/rows') return json(200, { rows: [{ n: 1 }, { n: 2 }, { n: 3 }], more: false });
    if (p === '/__test/d1') {
      const db = this.env.DB;
      for (let i = 0; i < Number(url.searchParams.get('n') ?? 0); i++) await db.prepare('SELECT 1 AS one').all();
      if (url.searchParams.get('write')) await db.prepare("INSERT INTO example (v) VALUES ('written')").run();
      return json(200, { ok: true });
    }
    if (p === '/__test/headers') return json(200, { 'cache-control': req.headers.get('cache-control'), pragma: req.headers.get('pragma') });
    if (p === '/__test/count') {
      const row = await this.env.DB.prepare('SELECT count(*) AS n FROM example').first();
      return json(200, { count: row.n });
    }
    if (p === '/__test/session') {
      const s = this.env.DB.withSession(url.searchParams.get('id') ?? 'first-unconstrained');
      await s.prepare('SELECT 1 AS one').all();
      return json(200, { ok: true });
    }
    if (p === '/__test/send') {
      await this.env.INDEX.send({ n: 1 }, { contentType: 'json', delaySeconds: Number(url.searchParams.get('d') ?? 0) });
      return json(200, { ok: true });
    }
    if (p === '/__test/timing') {
      const same = crypto.subtle.timingSafeEqual(new Uint8Array([1, 2]), new Uint8Array([1, 2]));
      return json(200, { same });
    }
    if (p === '/__test/len') return json(200, { len: (await req.arrayBuffer()).byteLength });
    if (p === '/__test/log') {
      console.warn(JSON.stringify({ level: 'warn', msg: 'test line', n: 1 }));
      return json(200, { ok: true });
    }
    if (p === '/__test/github') {
      const r = await fetch('https://api.github.com/repos/o/r');
      return json(200, { status: r.status, body: await r.text() });
    }
    return json(404, { error: 'no such test path' });
  }

  // A batch of a queue whose name starts with `__test` (slice 118): `{"retry_s":N}` retries with a delay, `{"retry":true}` retries, any other body is acked. Other queues: the Worker.
  async queue(batch, ...rest) {
    if (!String(batch.queue).startsWith('__test')) return super.queue(batch, ...rest);
    for (const m of batch.messages) {
      if (m.body?.retry_s !== undefined) m.retry({ delaySeconds: m.body.retry_s });
      else if (m.body?.retry) m.retry();
      else m.ack();
    }
  }

  async fetch(req) {
    // Slice 119b: the D1 calls and the queue sends since the last request (the cron runs of the runner do not pass this fetch, so their counts stay until here).
    if (new URL(req.url).pathname === '/__test/stats') return json(200, { ops, sent });
    ops = [];
    session = '';
    sent = [];
    timing = 0;
    const now = req.headers.get('x-test-now');
    if (now !== null) setNow(Number(now));
    const url = new URL(req.url);
    const res = url.pathname.startsWith('/__test/') ? await this.selfTest(url, req) : await super.fetch(req);
    const out = new Response(res.body, res);
    out.headers.set('x-d1-calls', String(ops.length));
    out.headers.set('x-d1-ops', ops.join(','));
    if (session !== '') out.headers.set('x-d1-session', session);
    out.headers.set('x-queue-sent', JSON.stringify(sent));
    out.headers.set('x-timing-safe-calls', String(timing));
    return out;
  }
}
