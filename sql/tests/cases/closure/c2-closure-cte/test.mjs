// The fixed rows of the closure batch (slice 110). requests.json: [{note, params: [groups, hashes, from, to], expect: {statement: rows}}].
// The setup and the expected rows are made by research/slice-110-revert/gen/mk_w1.py from the design, not from the SQL.
// c2-closure-cte: R-AP59 (unknown), R-AP64 (checked: all releases of the form), R-AP17 (artifacts, releases, unknown, checked, log_size), R-RE19 (the closure follows deps.dep, to the end, with a cycle),
// R-AP28 (unknown), R-AP29 (checked), R-AP32 (repos), R-AP41 row 1 (a recursive CTE) and row 2 (one JSON parameter, a 64-bit id), R-IK2, R-IK5, R-AP18 (one batch).
// c3-order-window: R-AP17 (epochs, runs, nearest, hints), R-MX16 (the order of nightlies), R-MX12 (a transitions row counts only with the adjacent previous),
// R-RE13 row 4 (bot over author only in nearest), R-AP16 (the window), R-AP18.
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { runBatch, sameRows } from '../../../closure.mjs';

export default async function (b, { dir }) {
  const fails = [];
  for (const r of JSON.parse(readFileSync(join(dir, 'requests.json'), 'utf8'))) {
    let got;
    try { got = await runBatch(b, r.params); } catch (e) { fails.push(`${r.note}: ${String(e.message ?? e).slice(0, 300)}`); continue; }
    for (const [name, rows] of Object.entries(r.expect)) fails.push(...sameRows(`${r.note}: ${name}`, rows, got[name]));
  }
  return fails;
}
