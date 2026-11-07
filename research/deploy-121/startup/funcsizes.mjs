// Prints the code section size and the largest function bodies of a wasm file (index is the function index, imports included).
import { readFileSync } from 'node:fs';
const b = readFileSync(process.argv[2]);
let p = 8;
const leb = () => { let r = 0, s = 0, x; do { x = b[p++]; r += (x & 0x7f) * 2 ** s; s += 7; } while (x & 0x80); return r; };
let imports = 0, out = [];
while (p < b.length) {
  const id = b[p++], size = leb(), end = p + size;
  if (id === 2) { const n = leb(); for (let i = 0; i < n; i++) { p += leb(); p += leb(); const k = b[p++];
      if (k === 0) { leb(); imports++; } else if (k === 1) { p++; const f = leb(); leb(); if (f & 1) leb(); } else if (k === 2) { const f = leb(); leb(); if (f & 1) leb(); } else { p += 2; } } }
  if (id === 10) { console.log('code section bytes', size); const n = leb(); for (let i = 0; i < n; i++) { const s = leb(); out.push([imports + i, s]); p += s; } }
  p = end;
}
out.sort((a, c) => c[1] - a[1]);
console.log('functions', out.length);
for (const [i, s] of out.slice(0, 5)) console.log('func', i, s);
