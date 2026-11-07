// Usage: node count.mjs app.wasm TEXT
// Prints the code section size, the largest function, and each function that has `i32.const <address of TEXT>`
// (one per copy of the code that uses TEXT), with its size. Function index counts the imports.
import { readFileSync } from 'node:fs';
const [f, text] = process.argv.slice(2), b = readFileSync(f);
let p = 8;
const u = () => { let r = 0, s = 0, x; do { x = b[p++]; r += (x & 0x7f) * 2 ** s; s += 7; } while (x & 0x80); return r; };
const s32 = () => { let r = 0, s = 0, x; do { x = b[p++]; r |= (x & 0x7f) << s; s += 7; } while (x & 0x80); if (s < 32 && (x & 0x40)) r |= (-1 << s); return r; };
const sleb = (v) => { const o = []; for (;;) { const x = v & 0x7f; v >>= 7; if ((v === 0 && !(x & 0x40)) || (v === -1 && (x & 0x40))) { o.push(x); return o; } o.push(x | 0x80); } };
let imports = 0, bodies = [], addr = -1, code = 0;
while (p < b.length) {
  const id = b[p++], size = u(), end = p + size;
  if (id === 2) { const n = u(); for (let i = 0; i < n; i++) { { const l = u(); p += l; } { const l = u(); p += l; } const k = b[p++];
      if (k === 0) { u(); imports++; } else if (k === 1) { p++; const fl = u(); u(); if (fl & 1) u(); } else if (k === 2) { const fl = u(); u(); if (fl & 1) u(); } else { p += 2; } } }
  if (id === 10) { code = size; const n = u(); for (let i = 0; i < n; i++) { const s = u(); bodies.push([imports + i, p, p + s]); p += s; } }
  if (id === 11) { const n = u(); for (let i = 0; i < n; i++) { const fl = u(); let off = 0; if (fl === 0 || fl === 2) { if (fl === 2) u(); p++; off = s32(); p++; } const len = u();
      const k = b.subarray(p, p + len).indexOf(text); if (k >= 0 && addr < 0) addr = off + k; p += len; } }
  p = end;
}
const big = bodies.reduce((a, c) => (c[2] - c[1] > a[2] - a[1] ? c : a));
console.log(`code ${code} | largest func ${big[0]} ${big[2] - big[1]}`);
if (addr < 0) { console.log('text not in data'); process.exit(0); }
// the literal can start some bytes before TEXT: take the nearest start address that some code uses
// a linked object (wasm-ld) keeps the 5-byte padded LEB of a relocation: match both forms
const padded = (v) => [0, 1, 2, 3].map((i) => ((v >> (7 * i)) & 0x7f) | 0x80).concat([(v >> 28) & 0x0f]);
const count = (a) => { const pats = [Buffer.from([0x41, ...sleb(a)]), Buffer.from([0x41, ...padded(a)])]; const r = [];
  for (const [fi, s, e] of bodies) { let n = 0; for (const pat of pats) { let q = s; for (;;) { q = b.indexOf(pat, q); if (q < 0 || q >= e) break; n++; q++; } } if (n) r.push([fi, e - s, n]); }
  return r; };
for (let k = 0; k <= 64; k++) { const r = count(addr - k); if (!r.length) continue;
  for (const [fi, sz, n] of r) console.log(`  func ${fi} ${sz} bytes: ${n} copies of "${text}"${k ? ` (literal starts ${k} bytes before)` : ''}`);
  break; }
