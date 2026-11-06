// The hooks module of the W2 runner (slice 123e): what startApp does not give by itself (docs/slices/123e-startapp-runner.md section 3).
// It replaces the old test entry worker-test.js. The D1 count, the sessions, the clock, the queue sends with body and delay (`delaySeconds`, since platform 0.0.6) and the rate limits come from startApp
// (`res.calls`, `res.sessions`, `app.setNow`, the option `ratelimits`). This module has only:
//   1. The count of `crypto.subtle.timingSafeEqual` calls of a request: the response header `x-timing-safe-calls` (the check "timing_safe" of expect/responses.jsonl).
//   2. The paths `/__test/...`, answered here with no Roc code, so the checks of the runner do not depend on the Worker (worker/tests/selftest/, worker/tests/cases/runner/).
//      `/__test/now` is answered by the runner (the clock is in the test entry, not here).
//   3. The setting TEST_INDEX_FAIL_SENDS: the first N sends to INDEX of the case fail (the send is rejected before the count of startApp, so it is no call).
//      `/__test/arm` makes the counter read the setting again: the runner calls it when a case starts in an app that an earlier case used (reset() does not reset a module global).
let timing = 0;
const timingOrig = crypto.subtle.timingSafeEqual;
crypto.subtle.timingSafeEqual = function (a, b) { timing++; return timingOrig.call(crypto.subtle, a, b); };

let failSends = -1; // -1: not read yet
const wrapQueue = (q) => new Proxy(q, {
  get(t, k) {
    const v = t[k];
    if ((k === 'send' || k === 'sendBatch') && failSends > 0) return () => { failSends--; return Promise.reject(new Error('test: the queue send is refused (TEST_INDEX_FAIL_SENDS)')); };
    return typeof v === 'function' ? v.bind(t) : v;
  },
});

// Runs after the count of startApp, so the wrapped INDEX is the counted one.
export function wrapEnv(env) {
  if (!env || !env.INDEX) return env;
  if (failSends < 0) failSends = Number(env.TEST_INDEX_FAIL_SENDS ?? 0);
  return { ...env, INDEX: wrapQueue(env.INDEX) };
}

const json = (status, body, headers = {}) => new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json', ...headers } });

// `/__test/json`: a fixed JSON answer. `/__test/problem`: a fixed problem answer. `/__test/d1?n=K&write=1`: K reads (and one write) on the counted DB.
// `/__test/headers`: the headers `cache-control` and `pragma` of the request. `/__test/count`: the rows of `example`. `/__test/session?id=X`: a read in `withSession(X)`.
// `/__test/rows`: a list of 3 rows (slice 109, the checks json_len, json_at, json_range). `/__test/github`: one outbound fetch. `/__test/send?d=N`: one send to INDEX with the delay N.
async function selfTest(url, req, env) {
  const p = url.pathname;
  if (p === '/__test/json') return json(200, { a: 1, b: { c: [1, 2, 3] }, s: 'x' }, { 'x-test': 'yes' });
  if (p === '/__test/problem') return json(404, { type: '/errors/not-found', title: 'Not found', status: 404, detail: 'fixed' }, { 'content-type': 'application/problem+json' });
  if (p === '/__test/rows') return json(200, { rows: [{ n: 1 }, { n: 2 }, { n: 3 }], more: false });
  if (p === '/__test/arm') { failSends = -1; return json(200, { ok: true }); }
  if (p === '/__test/d1') {
    for (let i = 0; i < Number(url.searchParams.get('n') ?? 0); i++) await env.DB.prepare('SELECT 1 AS one').all();
    if (url.searchParams.get('write')) await env.DB.prepare("INSERT INTO example (v) VALUES ('written')").run();
    return json(200, { ok: true });
  }
  if (p === '/__test/headers') return json(200, { 'cache-control': req.headers.get('cache-control'), pragma: req.headers.get('pragma') });
  if (p === '/__test/count') {
    const row = await env.DB.prepare('SELECT count(*) AS n FROM example').first();
    return json(200, { count: row.n });
  }
  if (p === '/__test/session') {
    const s = env.DB.withSession(url.searchParams.get('id') ?? 'first-unconstrained');
    await s.prepare('SELECT 1 AS one').all();
    return json(200, { ok: true });
  }
  if (p === '/__test/send') {
    await env.INDEX.send({ n: 1 }, { contentType: 'json', delaySeconds: Number(url.searchParams.get('d') ?? 0) });
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

async function handle(request, env, next) {
  const url = new URL(request.url);
  timing = 0;
  const res = url.pathname.startsWith('/__test/') ? await selfTest(url, request, env) : await next(request);
  const out = new Response(res.body, res);
  out.headers.set('x-timing-safe-calls', String(timing));
  return out;
}

export { handle as fetch }; // the global `fetch` is used by /__test/github, so the export has another local name
