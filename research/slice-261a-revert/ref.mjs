// A BigInt reference of Go crypto/ed25519 Verify (filippo decode: y mod p, x = 0 with the sign bit accepted). A test tool only.
import { createHash } from "node:crypto";
const p = (1n << 255n) - 19n, L = (1n << 252n) + 27742317777372353535851937790883648493n;
const mod = (a, m = p) => ((a % m) + m) % m;
const pow = (b, e) => { let r = 1n; b = mod(b); while (e > 0n) { if (e & 1n) r = mod(r * b); b = mod(b * b); e >>= 1n; } return r; };
const inv = (a) => pow(a, p - 2n);
const d = mod(-121665n * inv(121666n)), I = pow(2n, (p - 1n) / 4n);
const fromLe = (b) => [...b].reduceRight((a, x) => (a << 8n) + BigInt(x), 0n);
const le = (n) => { const b = Buffer.alloc(32); for (let i = 0; i < 32; i++) { b[i] = Number(n & 255n); n >>= 8n; } return b; };
function decode(b) {
  const sign = b[31] >> 7; const yb = Buffer.from(b); yb[31] &= 0x7f; const y = mod(fromLe(yb));
  const u = mod(y * y - 1n), v = mod(d * y * y + 1n);
  let x = mod(u * pow(v, 3n) * pow(u * pow(v, 7n), (p - 5n) / 8n));
  if (mod(v * x * x) !== u) { if (mod(v * x * x) === mod(-u)) x = mod(x * I); else return null; }
  if (Number(x & 1n) !== sign) x = mod(-x);
  return [x, y];
}
const add = ([x1, y1], [x2, y2]) => { const t = mod(d * x1 * x2 * y1 * y2); return [mod((x1 * y2 + x2 * y1) * inv(1n + t)), mod((y1 * y2 + x1 * x2) * inv(1n - t))]; };
const mul = (k, P) => { let R = [0n, 1n], Q = P; while (k > 0n) { if (k & 1n) R = add(R, Q); Q = add(Q, Q); k >>= 1n; } return R; };
const enc = ([x, y]) => { const b = le(y); b[31] |= Number(x & 1n) << 7; return b; };
const B = decode(le(mod(4n * inv(5n))));
export function verifyRaw(pk, msg, sig) {
  if (pk.length !== 32 || sig.length !== 64 || (sig[63] & 0xe0)) return null;
  const A = decode(pk); if (!A) return null;
  const S = fromLe(sig.subarray(32)); if (S >= L) return null;
  const k = mod(fromLe(createHash("sha512").update(Buffer.concat([sig.subarray(0, 32), pk, msg])).digest()), L);
  return enc(add(mul(S, B), mul(k, [mod(-A[0]), A[1]])));
}
export const verify = (pk, msg, sig) => { const e = verifyRaw(pk, msg, sig); return e !== null && e.equals(sig.subarray(0, 32)); };
export const decodes = (b) => b.length === 32 && decode(b) !== null;
