// BLAKE3 (hash mode, 32 bytes) and base58 (Bitcoin alphabet) in plain JS, for the test bundles of slice 111 (Design 2: the roc hash is
// base58 of BLAKE3-256 of the .tar.zst file). Node has no BLAKE3. Checked against the names of real bundles (mk-bundle.mjs check).
const IV = [0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19];
const PERM = [2, 6, 3, 10, 7, 0, 4, 13, 1, 11, 12, 5, 9, 14, 15, 8];
const CHUNK_START = 1, CHUNK_END = 2, PARENT = 4, ROOT = 8;
const rotr = (x, n) => ((x >>> n) | (x << (32 - n))) >>> 0;

function g(s, a, b, c, d, x, y) {
  s[a] = (s[a] + s[b] + x) >>> 0; s[d] = rotr(s[d] ^ s[a], 16);
  s[c] = (s[c] + s[d]) >>> 0; s[b] = rotr(s[b] ^ s[c], 12);
  s[a] = (s[a] + s[b] + y) >>> 0; s[d] = rotr(s[d] ^ s[a], 8);
  s[c] = (s[c] + s[d]) >>> 0; s[b] = rotr(s[b] ^ s[c], 7);
}

// The compression function: 16 words of state.
function compress(cv, m, counter, len, flags) {
  const s = [...cv, IV[0], IV[1], IV[2], IV[3], counter >>> 0, Math.floor(counter / 0x100000000) >>> 0, len, flags];
  let w = m.slice();
  for (let r = 0; r < 7; r++) {
    g(s, 0, 4, 8, 12, w[0], w[1]); g(s, 1, 5, 9, 13, w[2], w[3]); g(s, 2, 6, 10, 14, w[4], w[5]); g(s, 3, 7, 11, 15, w[6], w[7]);
    g(s, 0, 5, 10, 15, w[8], w[9]); g(s, 1, 6, 11, 12, w[10], w[11]); g(s, 2, 7, 8, 13, w[12], w[13]); g(s, 3, 4, 9, 14, w[14], w[15]);
    w = PERM.map((i) => w[i]);
  }
  for (let i = 0; i < 8; i++) { s[i] = (s[i] ^ s[i + 8]) >>> 0; s[i + 8] = (s[i + 8] ^ cv[i]) >>> 0; }
  return s;
}

const words = (buf, off, len) => {
  const w = new Array(16).fill(0);
  for (let i = 0; i < len; i++) w[i >> 2] |= buf[off + i] << (8 * (i & 3));
  return w.map((x) => x >>> 0);
};

// The output of one chunk (up to 1024 bytes) as {cv, block, counter, len, flags} of its last block, so the caller can add ROOT.
function chunkOutput(buf, off, len, counter) {
  let cv = IV.slice();
  const blocks = Math.max(1, Math.ceil(len / 64));
  for (let b = 0; b < blocks; b++) {
    const blen = Math.min(64, len - b * 64);
    const flags = (b === 0 ? CHUNK_START : 0) | (b === blocks - 1 ? CHUNK_END : 0);
    const m = words(buf, off + b * 64, Math.max(0, blen));
    if (b === blocks - 1) return { cv, m, counter, len: Math.max(0, blen), flags };
    cv = compress(cv, m, counter, 64, flags).slice(0, 8);
  }
}
const cvOf = (o) => compress(o.cv, o.m, o.counter, o.len, o.flags).slice(0, 8);
const parentOutput = (l, r) => ({ cv: IV.slice(), m: [...l, ...r], counter: 0, len: 64, flags: PARENT });

export function blake3(buf) {
  const n = Math.max(1, Math.ceil(buf.length / 1024));
  const stack = [];
  let out;
  for (let i = 0; i < n; i++) {
    const o = chunkOutput(buf, i * 1024, Math.min(1024, buf.length - i * 1024), i);
    if (i === n - 1) { out = o; break; }
    let cv = cvOf(o);
    let total = i + 1;
    while ((total & 1) === 0) { cv = cvOf(parentOutput(stack.pop(), cv)); total >>= 1; }
    stack.push(cv);
  }
  while (stack.length) out = parentOutput(stack.pop(), cvOf(out));
  const s = compress(out.cv, out.m, out.counter, out.len, out.flags | ROOT);
  const d = new Uint8Array(32);
  for (let i = 0; i < 8; i++) for (let j = 0; j < 4; j++) d[i * 4 + j] = (s[i] >>> (8 * j)) & 255;
  return d;
}

const ALPHA = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
export function base58(bytes) {
  let n = 0n;
  for (const b of bytes) n = n * 256n + BigInt(b);
  let s = '';
  while (n > 0n) { s = ALPHA[Number(n % 58n)] + s; n /= 58n; }
  for (const b of bytes) { if (b !== 0) break; s = '1' + s; }
  return s;
}

export const rocHash = (buf) => base58(blake3(buf));
