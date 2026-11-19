// Top self-time functions and top-level categories of a .cpuprofile. Usage: node prof-top.mjs <file> [n]
import { readFileSync } from 'node:fs';
const p = JSON.parse(readFileSync(process.argv[2], 'utf8'));
const self = new Map(); const byId = new Map(p.nodes.map((n) => [n.id, n]));
const dt = p.timeDeltas; let total = 0;
p.samples.forEach((id, i) => { const d = dt[i] / 1000; total += d; self.set(id, (self.get(id) ?? 0) + d); });
const agg = new Map();
for (const [id, t] of self) { const f = byId.get(id).callFrame; const k = `${f.functionName || '(anon)'} ${f.url.split('/').slice(-3).join('/')}:${f.lineNumber}`; agg.set(k, (agg.get(k) ?? 0) + t); }
console.log('total ms', total.toFixed(0));
for (const [k, t] of [...agg].sort((a, b) => b[1] - a[1]).slice(0, Number(process.argv[3] ?? 25))) console.log(t.toFixed(0).padStart(7), k);
