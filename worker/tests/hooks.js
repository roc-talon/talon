// The hooks module of the W2 runner (slice 123e): what startApp does not give by itself (docs/slices/123e-startapp-runner.md section 3).
// It replaces the old test entry worker-test.js. The D1 count, the sessions, the clock, the queue sends with body and delay (`delaySeconds`, since platform 0.0.6) and the rate limits come from startApp
// (`res.calls`, `res.sessions`, `app.setNow`, the option `ratelimits`). This module has only:
//   1. The count of `crypto.subtle.timingSafeEqual` calls of a request: the response header `x-timing-safe-calls` (the check "timing_safe" of expect/responses.jsonl).
//   2. The paths `/__test/...`, answered here with no Roc code, so the checks of the runner do not depend on the Worker (worker/tests/selftest/, worker/tests/cases/runner/).
//      `/__test/now` is answered by the runner (the clock is in the test entry, not here).
//   3. The setting TEST_INDEX_FAIL_SENDS: the first N sends to INDEX of the case fail (the send is rejected before the count of startApp, so it is no call).
//      `/__test/arm` makes the counter read the setting again: the runner calls it when a case starts in an app that an earlier case used (reset() does not reset a module global).
//   4. Slice 257b: the R2 binding LOG (the log tiles and the checkpoint, Registry R-SG4, R-SG7, R-WH14). Each call of the Worker on LOG goes in a list (`/__test/r2ops`: { op, key, cond });
//      `cond` of a put is '' (no condition), '?etag' (onlyIf.etagMatches), '?absent' (onlyIf.etagDoesNotMatch "*", R2.absent), '?headers' or '?other'.
//      The setting TEST_LOG_FAIL_PUTS (a JSON array of keys): the FIRST put of each key in the case fails (a rejected promise, as an R2 error), and the object is not written.
//      The setting TEST_LOG_RACE (a key): just before the first put of `checkpoint` in the case, the object of that key is copied to `checkpoint` (another run that wrote first, R-SG7 row 4).
//      Slice 257b verify (Q257-18): TEST_LOG_RACE can also be a JSON array of keys: the n-th put of `checkpoint` gets the n-th copy (one race for each put).
//      The copy and the seeds of `/__test/r2seed` use the binding with no wrapper, so they are not in the list and no fault hits them. `/__test/arm` arms both settings again.
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

// Slice 257b: the state of the R2 hooks. `failPuts` null and `race` null: not read yet (the first wrapEnv of the case reads the settings).
const RAW = Symbol('raw');
let r2ops = [];
let failPuts = null;
let failGets = null; // slice 257d: TEST_LOG_FAIL_GETS, a JSON array of keys: the first get or head of each key fails
let race = null;
const condOf = (o) => {
  const c = o?.onlyIf;
  if (c === undefined || c === null) return '';
  if (typeof Headers !== 'undefined' && c instanceof Headers) return '?headers';
  if (c.etagDoesNotMatch === '*') return '?absent';
  if (c.etagMatches !== undefined) return '?etag';
  return '?other';
};
const wrapR2 = (b) => new Proxy(b, {
  get(t, k) {
    if (k === RAW) return t;
    const v = t[k];
    if (k === 'put') {
      return async (key, body, opts) => {
        r2ops.push({ op: 'put', key, cond: condOf(opts) });
        if (failPuts?.has(key)) {
          failPuts.delete(key);
          throw new Error(`test: the put of ${key} is refused (TEST_LOG_FAIL_PUTS)`);
        }
        if (key === 'checkpoint' && race.length) {
          const src = race.shift();
          const o = await t.get(src);
          if (o) await t.put('checkpoint', await o.arrayBuffer(), { httpMetadata: o.httpMetadata });
        }
        return t.put(key, body, opts);
      };
    }
    if (k === 'get' || k === 'head' || k === 'delete' || k === 'list') {
      return (...a) => {
        r2ops.push({ op: k, key: typeof a[0] === 'string' ? a[0] : JSON.stringify(a[0] ?? null), cond: k === 'get' || k === 'head' ? condOf(a[1]) : '' });
        if ((k === 'get' || k === 'head') && typeof a[0] === 'string' && failGets?.has(a[0])) {
          failGets.delete(a[0]);
          return Promise.reject(new Error(`test: the read of ${a[0]} is refused (TEST_LOG_FAIL_GETS)`));
        }
        return v.apply(t, a);
      };
    }
    return typeof v === 'function' ? v.bind(t) : v;
  },
});
const rawR2 = (b) => b?.[RAW] ?? b;

// Runs after the count of startApp, so the wrapped INDEX is the counted one.
export function wrapEnv(env) {
  if (!env) return env;
  let out = env;
  if (env.INDEX) {
    if (failSends < 0) failSends = Number(env.TEST_INDEX_FAIL_SENDS ?? 0);
    out = { ...out, INDEX: wrapQueue(env.INDEX) };
  }
  if (env.LOG) {
    if (failPuts === null) failPuts = new Set(JSON.parse(env.TEST_LOG_FAIL_PUTS ?? '[]'));
    if (failGets === null) failGets = new Set(JSON.parse(env.TEST_LOG_FAIL_GETS ?? '[]'));
    if (race === null) { const r = env.TEST_LOG_RACE ?? ''; race = r.startsWith('[') ? JSON.parse(r) : r ? [r] : []; }
    out = { ...out, LOG: wrapR2(env.LOG) };
  }
  return out;
}

// Slice 257b: bytes as hex, and the UTF-8 text of bytes when they are valid UTF-8 (else undefined).
const hexOf = (buf) => [...new Uint8Array(buf)].map((x) => x.toString(16).padStart(2, '0')).join('');
const textOf = (buf) => {
  try {
    return new TextDecoder('utf-8', { fatal: true }).decode(buf);
  } catch {
    return undefined;
  }
};
const bytesOf = (o) => (o.base64 !== undefined ? Uint8Array.from(atob(o.base64), (c) => c.charCodeAt(0)) : new TextEncoder().encode(o.text ?? ''));
// The objects of a bucket: { key, size, sha256 (hex), content_type (or null), text (only for valid UTF-8 of 8 KiB or less) }, in key order.
async function dumpR2(b) {
  const out = [];
  let cursor;
  do {
    const page = await b.list({ cursor, include: ['httpMetadata'] });
    for (const m of page.objects) {
      const o = await b.get(m.key);
      const buf = await o.arrayBuffer();
      const item = { key: m.key, size: buf.byteLength, sha256: hexOf(await crypto.subtle.digest('SHA-256', buf)), content_type: o.httpMetadata?.contentType ?? null };
      const text = buf.byteLength <= 8192 ? textOf(buf) : undefined;
      if (text !== undefined) item.text = text;
      out.push(item);
    }
    cursor = page.truncated ? page.cursor : undefined;
  } while (cursor);
  return out.sort((a, b) => (a.key < b.key ? -1 : a.key > b.key ? 1 : 0));
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
  // Slice 256: `POST /__test/sql?mode=batch|seq`, the body is a JSON array of statements. The runner sends the migrations (batch: one transaction, as `db.batch`) and the seed and `sql` lines
  // (seq: one statement after the other, as `prepare(s).run()`) in one request. A `db.prepare()` of the Node side is a blocking call of Miniflare for each statement, and it stopped the main thread of the runner.
  if (p === '/__test/sql') {
    try {
      const stmts = JSON.parse(await req.text());
      if (url.searchParams.get('mode') === 'batch') await env.DB.batch(stmts.map((s) => env.DB.prepare(s)));
      else for (const s of stmts) await env.DB.prepare(s).run();
      return json(200, { ok: true, n: stmts.length });
    } catch (e) {
      return json(500, { ok: false, error: String(e?.stack ?? e) });
    }
  }
  if (p === '/__test/arm') { failSends = -1; failPuts = null; failGets = null; race = null; r2ops = []; return json(200, { ok: true }); }
  // Slice 257b. `POST /__test/r2seed?bucket=LOG`: the body is a JSON array of { key, text | base64, content_type? }, written with no wrapper (one request for the seed of a case).
  // `GET /__test/r2dump?bucket=LOG`: the objects of the bucket (dumpR2). `GET /__test/r2ops`: the calls on LOG since the last read, then the list is empty.
  // `POST /__test/r2write`: the body is a JSON array of { key, text, cond?: "absent" | "etag" }, written THROUGH the wrapper (the list, TEST_LOG_FAIL_PUTS, TEST_LOG_RACE): the runner self-tests.
  if (p === '/__test/r2seed' || p === '/__test/r2dump' || p === '/__test/r2write') {
    const name = url.searchParams.get('bucket') ?? 'LOG';
    const b = env[name];
    if (!b) return json(500, { error: `no binding ${name}` });
    try {
      if (p === '/__test/r2dump') return json(200, { objects: await dumpR2(rawR2(b)) });
      const items = JSON.parse(await req.text());
      if (p === '/__test/r2seed') {
        for (const o of items) await rawR2(b).put(o.key, bytesOf(o), o.content_type ? { httpMetadata: { contentType: o.content_type } } : {});
        return json(200, { ok: true, n: items.length });
      }
      const results = [];
      for (const o of items) {
        let onlyIf;
        if (o.cond === 'absent') onlyIf = { etagDoesNotMatch: '*' };
        if (o.cond === 'etag') onlyIf = { etagMatches: (await rawR2(b).head(o.key))?.etag ?? 'none' };
        try {
          const r = await b.put(o.key, bytesOf(o), onlyIf ? { onlyIf } : {});
          results.push({ key: o.key, written: r !== null });
        } catch (e) {
          results.push({ key: o.key, error: String(e?.message ?? e) });
        }
      }
      return json(200, { results });
    } catch (e) {
      return json(500, { error: String(e?.stack ?? e) });
    }
  }
  // Slice 257d. `GET /__test/r2read?key=K`: `get` of K THROUGH the wrapper (it is in the list as a read), the answer is the bytes of the object with its content type (404 when absent): the runner self-tests of "r2_reads".
  if (p === '/__test/r2read') {
    let o;
    try { o = await env.LOG.get(url.searchParams.get('key') ?? ''); } catch (e) { return new Response(`failed: ${e?.message ?? e}`, { status: 500 }); }
    if (!o) return new Response('absent', { status: 404 });
    return new Response(await o.arrayBuffer(), { headers: { 'content-type': o.httpMetadata?.contentType ?? 'application/octet-stream' } });
  }
  if (p === '/__test/r2ops') {
    const ops = r2ops;
    r2ops = [];
    return json(200, { ops });
  }
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
