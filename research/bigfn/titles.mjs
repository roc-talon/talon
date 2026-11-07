// Per function: the number of i32.const values that point at the text "Unauthenticated" (one per copy of Problem.title). Prints the top functions.
import { readFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
const f = process.argv[2], b = readFileSync(f);
// address of the text in linear memory: find the data segment that holds it
let p = 8; const u = () => { let r = 0, s = 0, x; do { x = b[p++]; r += (x & 0x7f) * 2 ** s; s += 7; } while (x & 0x80); return r; };
const s32 = () => { let r = 0, s = 0, x; do { x = b[p++]; r |= (x & 0x7f) << s; s += 7; } while (x & 0x80); if (s < 32 && (x & 0x40)) r |= (-1 << s); return r; };
let addr = -1;
while (p < b.length) { const id = b[p++], size = u(), end = p + size;
  if (id === 11) { const n = u(); for (let i = 0; i < n; i++) { const fl = u(); let off = 0; if (fl === 0 || fl === 2) { if (fl === 2) u(); p++; off = s32(); p++; } const len = u();
      const k = b.subarray(p, p + len).indexOf('Unauthenticated'); if (k >= 0 && addr < 0) addr = off + k; p += len; } }
  p = end; }
if (addr < 0) { console.log('no text Unauthenticated (folded)'); process.exit(0); }
const out = execFileSync('node', [new URL('./wasmscan.mjs', import.meta.url).pathname, f, 'big', 'pos', String(addr)]).toString().split('\n');
console.log('title-table copies in biggest function:', out[1].trim() ? out[1].trim().split(' ').length : 0, '(' + out[0].split(' target ')[1] + ')');
