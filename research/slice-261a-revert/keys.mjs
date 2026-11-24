// Slice 261a: the vectors of Ed25519.is_valid_public_key (Go rules: y mod p, a y with no x rejected, small-order and non-canonical accepted).
// Usage: node research/slice-261a-revert/keys.mjs   prints the off-curve y values and checks each vector with the BigInt reference ref.mjs.
const { decodes } = await import("./ref.mjs");
const le = (n) => { const b = Buffer.alloc(32); for (let i = 0; i < 32; i++) { b[i] = Number(n & 255n); n >>= 8n; } return b; };
const p = (1n << 255n) - 19n;
const bad = [];
for (let y = 0n; bad.length < 6; y++) if (!decodes(le(y))) bad.push(y);
const big = p - 2n; // a large y; checked below
console.log("off-curve y (no x):", bad.join(", "), "| p - 2 decodes:", decodes(le(big)));
let big2 = p - 1n; while (decodes(le(big2))) big2--;
console.log("largest y below p with no x:", (p - big2).toString(), "below p:", le(big2).toString("hex"));
const signed = (y) => { const b = le(y); b[31] |= 0x80; return b; };
console.log("bad y with the sign bit:", bad.map((y) => decodes(signed(y))).join(","));
