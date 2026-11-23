// Repro for the w1 sqlite failure: an INSERT with an id outside the safe JS integer range.
// Node 26.7 (local) passes; CI Node 26.13.1 throws "Value is too large to be represented as a JavaScript number".
import { DatabaseSync } from 'node:sqlite';
const db = new DatabaseSync(':memory:');
db.exec('CREATE TABLE t (id INTEGER PRIMARY KEY, v TEXT)');
for (const [label, stmt] of [
  ['run() as is', () => db.prepare('INSERT INTO t (id, v) VALUES (?, ?)').run(-5806314255104343322n, 'a')],
  ['run() readBigInts', () => { const s = db.prepare('INSERT INTO t (id, v) VALUES (?, ?)'); s.setReadBigInts(true); return s.run(4611686018427387905n, 'b'); }],
]) {
  try { console.log(process.version, label, 'ok', stmt()); } catch (e) { console.log(process.version, label, 'ERR', e.code, e.message); }
}
