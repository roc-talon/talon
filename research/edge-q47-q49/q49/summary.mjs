// Q49: a table of the samples: median and min to max of the client time and of the D1 time in the Worker, for each
// phase, region, Worker and route. Round 0 of each run is left out (a cold isolate). Also the placement headers seen.
//   node q49/summary.mjs results/q49.jsonl [phase ...]
import { readFileSync } from 'node:fs';
const [file, ...phases] = process.argv.slice(2);
const rows = readFileSync(file, 'utf8').trim().split('\n').map((l) => JSON.parse(l))
  .filter((r) => r.ms != null && r.round > 0 && (!phases.length || phases.includes(r.phase)));
const groups = new Map();
for (const r of rows) {
  const k = [r.phase, r.region, r.do_colo, r.worker, r.route].join('|');
  if (!groups.has(k)) groups.set(k, []);
  groups.get(k).push(r);
}
const med = (a) => { const s = [...a].sort((x, y) => x - y); const m = s.length >> 1; return s.length % 2 ? s[m] : Math.round((s[m - 1] + s[m]) / 2); };
const span = (a) => `${med(a)} (${Math.min(...a)}-${Math.max(...a)})`;
console.log('| Phase | Region (colo) | Worker | Route | n | Client ms: median (min-max) | D1 ms in Worker | Placement | D1 served by |');
console.log('| --- | --- | --- | --- | --- | --- | --- | --- | --- |');
for (const [k, g] of groups) {
  const [phase, region, colo, worker, route] = k.split('|');
  const pl = [...new Set(g.map((r) => r.placement))].join(', ');
  const sv = [...new Set(g.flatMap((r) => (r.served ?? []).map((s) => `${s.region ?? '-'}${s.primary === true ? ' primary' : s.primary === false ? ' replica' : ''}`)))].join(', ');
  const errs = g.filter((r) => r.error).length;
  console.log(`| ${phase} | ${region} (${colo}) | ${worker} | ${route} | ${g.length}${errs ? ` (${errs} errors)` : ''} | ${span(g.map((r) => r.ms))} | ${span(g.map((r) => r.d1_ms))} | ${pl} | ${sv} |`);
}
