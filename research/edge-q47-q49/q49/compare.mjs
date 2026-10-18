// Q49: one table for each route kind: the client time (median, min to max) from each region, for each placement.
// Uses the measure phases (not the warm-up). Round 0 of each run is left out.
//   node q49/compare.mjs results/q49.jsonl
import { readFileSync } from 'node:fs';
const rows = readFileSync(process.argv[2], 'utf8').trim().split('\n').map((l) => JSON.parse(l))
  .filter((r) => r.ms != null && r.round > 0 && !r.error && ['base', 'repl1', 'p1', 'p2', 'p3'].includes(r.phase));
const med = (a) => { const s = [...a].sort((x, y) => x - y); const m = s.length >> 1; return s.length % 2 ? s[m] : Math.round((s[m - 1] + s[m]) / 2); };
const cell = (g) => g.length ? `${med(g.map((r) => r.ms))} (${Math.min(...g.map((r) => r.ms))}-${Math.max(...g.map((r) => r.ms))}) n=${g.length}` : '-';
const regions = [['wnam', 'DFW'], ['weur', 'LHR'], ['apac', 'KIX'], ['local', 'TBS']];
const cases = [['default', ''], ['smart', ''], ['hint', ''], ['default', '_s'], ['hint', '_s']];
for (const route of ['closure', 'chain3', 'publish']) {
  console.log(`\n${route}: client ms, median (min-max)\n`);
  console.log(`| Placement | ${regions.map(([r, c]) => `${r} (${c})`).join(' | ')} |`);
  console.log(`| --- | ${regions.map(() => '---').join(' | ')} |`);
  for (const [w, s] of cases) {
    if (route === 'publish' && s) continue;
    const name = `${w}${s ? ' + session' : ''}`;
    console.log(`| ${name} | ${regions.map(([r]) => cell(rows.filter((x) => x.region === r && x.worker === w && x.route === route + s))).join(' | ')} |`);
  }
}
