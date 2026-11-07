// Decode 12-byte RocStr records (ptr, len, cap) at the given data addresses of a wasm32 Roc app.
import { readFileSync } from 'node:fs';
const b = readFileSync(process.argv[2]);
let p = 8; const u = () => { let r = 0, s = 0, x; do { x = b[p++]; r += (x & 0x7f) * 2 ** s; s += 7; } while (x & 0x80); return r; };
const s32 = () => { let r = 0, s = 0, x; do { x = b[p++]; r |= (x & 0x7f) << s; s += 7; } while (x & 0x80); if (s < 32 && (x & 0x40)) r |= (-1 << s); return r; };
const data = [];
while (p < b.length) { const id = b[p++], size = u(), end = p + size;
  if (id === 11) { const n = u(); for (let i = 0; i < n; i++) { const fl = u(); let off = 0; if (fl === 0 || fl === 2) { if (fl === 2) u(); p++; off = s32(); p++; } const len = u(); data.push({ off, start: p, len }); p += len; } }
  p = end; }
const at = (a) => { for (const d of data) if (a >= d.off && a < d.off + d.len) return d.start + a - d.off; return -1; };
for (const a of process.argv.slice(3).map(Number)) { const o = at(a); const ptr = b.readUInt32LE(o), len = b.readUInt32LE(o + 4), cap = b.readInt32LE(o + 8);
  const so = at(ptr); console.log(a, 'ptr', ptr, 'len', len, 'cap', cap, so >= 0 ? JSON.stringify(b.subarray(so, so + Math.min(len, 100)).toString('latin1')) : '?'); }
