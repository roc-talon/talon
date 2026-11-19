// Callers (paths up the stack) of a function name in a .cpuprofile, with self time. Usage: node prof-callers.mjs <file> <fnName> [depth]
import { readFileSync } from 'node:fs';
const p = JSON.parse(readFileSync(process.argv[2], 'utf8')); const name = process.argv[3]; const depth = Number(process.argv[4] ?? 6);
const byId = new Map(p.nodes.map((n) => [n.id, n])); const parent = new Map();
for (const n of p.nodes) for (const c of n.children ?? []) parent.set(c, n.id);
const self = new Map(); p.samples.forEach((id, i) => self.set(id, (self.get(id) ?? 0) + p.timeDeltas[i] / 1000));
const agg = new Map();
for (const [id, t] of self) { const f = byId.get(id).callFrame; if (f.functionName !== name) continue;
  const path = []; let cur = parent.get(id); for (let d = 0; cur !== undefined && d < depth; d++, cur = parent.get(cur)) { const g = byId.get(cur).callFrame; path.push(`${g.functionName || '(anon)'}@${g.url.split('/').slice(-2).join('/')}:${g.lineNumber}`); }
  const k = path.join(' < '); agg.set(k, (agg.get(k) ?? 0) + t); }
for (const [k, t] of [...agg].sort((a, b) => b[1] - a[1]).slice(0, 12)) console.log(t.toFixed(0).padStart(7), k);
