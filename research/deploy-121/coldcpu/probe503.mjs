// Count 503 answers of prod on a light read route, with a pause so that some requests start new isolates.
// Usage: node research/deploy-121/coldcpu/probe503.mjs [n] [gap_ms]
const n = Number(process.argv[2] ?? 200), gap = Number(process.argv[3] ?? 300);
const c = {}; const st = { served1: 0, ms1: [], msN: [] };
for (let i = 0; i < n; i++) {
  const t = Date.now();
  const r = await fetch('https://registry.roc-talon.org/v1/toolchains?after=0').catch((e) => ({ status: 0 }));
  const ms = Date.now() - t;
  c[r.status] = (c[r.status] ?? 0) + 1;
  const s = r.headers?.get?.('x-roc-stats');
  if (s) { const served = Number((s.match(/served=(\d+)/) ?? [])[1]); (served === 1 ? st.ms1 : st.msN).push(ms); }
  await new Promise((z) => setTimeout(z, gap));
}
console.log('status counts', c, 'with x-roc-stats: first', st.ms1.length, 'later', st.msN.length);
