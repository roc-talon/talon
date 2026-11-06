// Makes worker/tests/unit/LoginTest.roc from LoginTest.tmpl.roc and vectors.json (node vectors.mjs > vectors.json).
import { readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
const v = JSON.parse(readFileSync(join(import.meta.dirname, 'vectors.json'), 'utf8'));
let t = readFileSync(join(import.meta.dirname, 'LoginTest.tmpl.roc'), 'utf8');
const esc = (s) => s.replace(/\\/g, '\\\\').replace(/"/g, '\\"');
t = t.replace('@@sig@@', `[${v.sig.join(', ')}]`);
t = t.replace(/@@([a-z0-9_.]+)@@/g, (_, name) => {
  const val = name.split('.').reduce((o, k) => o[k], v);
  if (typeof val !== 'string') throw new Error(`no vector ${name}`);
  return esc(val);
});
writeFileSync(join(import.meta.dirname, '..', '..', '..', 'worker', 'tests', 'unit', 'LoginTest.roc'), t);
