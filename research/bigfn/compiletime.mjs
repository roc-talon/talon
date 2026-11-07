// Time of the eager compile of a whole wasm module (median of 5; each run adds a different custom section so that no code cache is used).
//   node --liftoff --no-wasm-tier-up --no-wasm-lazy-compilation compiletime.mjs a.wasm
import { readFileSync } from 'node:fs';
const base = readFileSync(process.argv[2]); const t = [];
for (let i = 0; i < 5; i++) {
  const tag = Buffer.from([0, 6, 1, 0x78, ...Buffer.from(String(1000 + i))]); // custom section "x" + 4 bytes
  const bytes = Buffer.concat([base, tag]);
  const s = performance.now(); new WebAssembly.Module(bytes); t.push(performance.now() - s);
}
t.sort((a, b) => a - b); console.log(process.argv[2], 'median ms', t[2].toFixed(1));
