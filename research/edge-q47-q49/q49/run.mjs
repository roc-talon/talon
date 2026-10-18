// Q49: one measure round. Calls the client Worker for each region, and also calls the targets from this machine (TBS).
//   PHASE=base ROUTES=closure,chain3,publish N=7 node q49/run.mjs >> results/q49.jsonl
// Each line: {phase, region, do_colo, worker, route, ms, placement, ingress, d1_ms, served, error}.
const phase = process.env.PHASE ?? 'base';
const routes = process.env.ROUTES ?? 'closure,chain3,publish';
const n = Number(process.env.N ?? 7);
const workers = process.env.WORKERS ?? 'default,smart';
const regions = (process.env.REGIONS ?? 'wnam,weur,apac,local').split(',');
const at = new Date().toISOString();
for (const region of regions) {
  if (region === 'local') {
    for (let i = 0; i < n; i++) for (const w of workers.split(',')) for (const r of routes.split(',')) {
      const t0 = performance.now();
      const res = await fetch(`https://rocplat-test-q49-${w}.bellup.workers.dev/${r}`);
      const b = await res.json();
      console.log(JSON.stringify({ phase, at, region, do_colo: 'TBS (this machine)', round: i, worker: w, route: r, ms: Math.round(performance.now() - t0),
        placement: res.headers.get('cf-placement'), ingress: b.colo, d1_ms: b.d1_ms, rows: b.rows, served: b.served, error: b.error }));
    }
    continue;
  }
  const res = await fetch(`https://rocplat-test-q49-client.bellup.workers.dev/run?hint=${region}&workers=${workers}&routes=${routes}&n=${n}`);
  const text = await res.text();
  let b;
  try { b = JSON.parse(text); } catch { console.log(JSON.stringify({ phase, at, region, error: text.slice(0, 300) })); continue; }
  const per = workers.split(',').length * routes.split(',').length;
  b.samples.forEach((s, k) => console.log(JSON.stringify({ phase, at, region, do_colo: b.do_colo, round: Math.floor(k / per), ...s })));
}
