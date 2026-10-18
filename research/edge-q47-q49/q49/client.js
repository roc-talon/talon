// Q49: the client Worker. A Durable Object made with a locationHint (wnam, weur, apac, ...) calls the target Workers on
// workers.dev and times each call. A fetch from a Durable Object enters Cloudflare at the colo of the Durable Object.
//   GET /run?hint=wnam&workers=default,smart&routes=closure,chain3&n=5
//     n rounds; in each round, each route of each Worker once (interleaved, so a slow minute hits all cases).
//     At most 45 fetches for each call (the Free plan allows 50 subrequests for each invocation).
//   GET /where?hint=wnam      the colo of the Durable Object (a fetch of /cdn-cgi/trace)
// Each sample: worker, route, client ms (the clock of the Durable Object moves at I/O), the cf-placement header, the
// ingress colo that the target saw, the D1 time inside the target, and where D1 served the call.
const TARGET = (w) => `https://rocplat-test-q49-${w}.bellup.workers.dev`;

export class Client {
  constructor(state) { this.state = state; }
  async fetch(req) {
    const url = new URL(req.url);
    const trace = await (await fetch('https://www.cloudflare.com/cdn-cgi/trace')).text();
    const doColo = /colo=(\w+)/.exec(trace)?.[1] ?? null;
    if (url.pathname === '/where') return Response.json({ do_colo: doColo });
    const workers = (url.searchParams.get('workers') ?? 'default,smart').split(',');
    const routes = (url.searchParams.get('routes') ?? 'closure').split(',');
    const n = Number(url.searchParams.get('n') ?? 1);
    if (n * workers.length * routes.length > 45) return Response.json({ error: 'over 45 fetches' }, { status: 400 });
    const samples = [];
    for (let i = 0; i < n; i++) {
      for (const w of workers) {
        for (const r of routes) {
          const t0 = Date.now();
          let res, body;
          try {
            res = await fetch(`${TARGET(w)}/${r}`, { headers: { 'cache-control': 'no-store' } });
            body = await res.json();
          } catch (e) {
            samples.push({ worker: w, route: r, error: String(e?.message ?? e) });
            continue;
          }
          samples.push({ worker: w, route: r, ms: Date.now() - t0, status: res.status, placement: res.headers.get('cf-placement'),
            ingress: body.colo, d1_ms: body.d1_ms, rows: body.rows, served: body.served, error: body.error });
        }
      }
    }
    return Response.json({ do_colo: doColo, samples });
  }
}

export default {
  async fetch(req, env) {
    const url = new URL(req.url);
    const hint = url.searchParams.get('hint');
    if (!hint) return new Response('hint is needed', { status: 400 });
    // One object for each hint. The hint applies only when the object is made the first time.
    const stub = env.CLIENT.get(env.CLIENT.idFromName(`client-${hint}`), { locationHint: hint });
    return stub.fetch(req);
  },
};
