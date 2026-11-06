// Values for the W0 tests of slice 116, with node only (crypto): no expected value comes from the Roc code. Run: node vectors.mjs
import { createHmac } from 'node:crypto';
const idOf = (key, machine) => {
  const mac = createHmac('sha256', key).update(machine, 'utf8').digest();
  return BigInt.asIntN(64, mac.readBigUInt64BE(0) | (1n << 63n));
};
const KEY = 'test-contributor-key';
for (const m of ['0123456789abcdef0123456789abcdef', 'fedcba9876543210fedcba9876543210', '00000000000000000000000000000000']) console.log('contributor', KEY, m, idOf(KEY, m));
console.log('contributor other key', idOf('other-key', '0123456789abcdef0123456789abcdef'));
// R-IK5 keys of tln versions (no flip, Q116-8): major<<48 | minor<<32 | patch<<16 | code
const r = (c) => (c === undefined ? 0 : c === '-' ? 1 : c >= '0' && c <= '9' ? 2 + (+c) : c >= 'A' && c <= 'Z' ? 12 + c.charCodeAt(0) - 65 : 38 + c.charCodeAt(0) - 97);
const alnum = (s) => 0x1000 + 65 * r(s[0]) + r(s[1]);
const key = (M, m, p, code = 0xffff) => BigInt.asIntN(64, (BigInt(M) << 48n) | (BigInt(m) << 32n) | (BigInt(p) << 16n) | BigInt(code));
console.log('0.4.1', key(0, 4, 1), '1.2.3', key(1, 2, 3), '0.5.0-rc.1', key(0, 5, 0, alnum('rc')), '0.5.0-beta1', key(0, 5, 0, alnum('be')), '0.10.0', key(0, 10, 0));
// The HMAC outputs (32 bytes) as Roc lists, for the W0 test of contributor_id.
const macs = (key, machine) => '[' + [...createHmac('sha256', key).update(machine, 'utf8').digest()].map((b) => '0x' + b.toString(16).padStart(2, '0').toUpperCase()).join(', ') + ']';
for (const m of ['0123456789abcdef0123456789abcdef', 'fedcba9876543210fedcba9876543210']) console.log('mac', m, macs(KEY, m));
console.log('mac other', macs('other-key', '0123456789abcdef0123456789abcdef'));
