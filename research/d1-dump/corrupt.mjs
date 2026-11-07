// Test helper for check.sh: writes every integer literal with abs value above 2^53 as a JSON float
// (the bug of `wrangler d1 export`: -7163292474072844001 becomes -7163292474072844000). Usage: node corrupt.mjs in.sql out.sql
import { readFileSync, writeFileSync } from 'node:fs'
const [inp, outp] = process.argv.slice(2)
const lim = 2n ** 53n
let changed = 0
const text = readFileSync(inp, 'utf8').replace(/(?<![\w.'"])-?\d{16,19}(?![\w.])/g, (m) => {
  const n = BigInt(m)
  if (n <= lim && n >= -lim) return m
  const f = Number(n)
  // A value that rounds out of the int64 range makes the import fail at once. Leave it, so the silent case is tested.
  if (BigInt(f) >= 2n ** 63n || BigInt(f) <= -(2n ** 63n)) return m
  const [mant, exp] = f.toExponential().split('e')
  const neg = mant.startsWith('-')
  const digits = mant.replace('-', '').replace('.', '')
  const e = Number(exp)
  const s = digits.padEnd(e + 1, '0')
  changed++
  return (neg ? '-' : '') + s
})
writeFileSync(outp, text)
console.error(`corrupt.mjs: ${changed} integer literals changed`)
