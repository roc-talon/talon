// Vectors of the W0 tests of slice 117 (worker/tests/unit/LoginTest.roc), made with node (crypto only): no expected value comes from the Roc code.
// The key is the test key of RFC 8037 A.1 (public in the RFC): it signs the one full token. Usage: node vectors.mjs
import { createPrivateKey, sign } from 'node:crypto';
const D = 'nWGxne_9WmC6hEr0kuwsxERJxWl7MmkZcDusAxyuf2A', X = '11qYAYKxCrfVS_7TyWQHOg7hcvPapiMlrwIaaPcHURo';
const key = createPrivateKey({ key: { kty: 'OKP', crv: 'Ed25519', x: X, d: D }, format: 'jwk' });
const b64u = (b) => Buffer.from(b).toString('base64url');
const enc = (o) => b64u(Buffer.from(typeof o === 'string' ? o : JSON.stringify(o)));
const AUD = 'https://registry.example';
const ZERO = 'A'.repeat(86); // 64 zero bytes
const tok = (header, claims, sig = ZERO) => `${enc(header)}.${enc(claims)}.${sig}`;
const H = { alg: 'EdDSA', kid: 'key-1', typ: 'JWT' };
const C = { iss: AUD, aud: AUD, sub: '4242', iat: 1767225600, exp: 1769817600 };
const out = {};
// the exact signing input of Login.signing_input and its signed token (now 1767225601234, sub 4242)
const header = '{"alg":"EdDSA","kid":"key-1","typ":"JWT"}';
const payload = `{"aud":"${AUD}","exp":1769817601.234,"iat":1767225601.234,"iss":"${AUD}","sub":"4242"}`;
const input = `${enc(header)}.${enc(payload)}`;
const sig = sign(null, Buffer.from(input), key);
out.input = input; out.token = `${input}.${b64u(sig)}`; out.sig = [...sig];
// a second input: a whole second, another kid and sub, an audience and kid that need JSON escapes
const header2 = '{"alg":"EdDSA","kid":"k\\"1","typ":"JWT"}';
const payload2 = `{"aud":"https://r.example/a\\\\b","exp":2592000.000,"iat":0.000,"iss":"https://r.example/a\\\\b","sub":"9007199254740993"}`;
out.input2 = `${enc(header2)}.${enc(payload2)}`;
// decode refusals
out.dec = {
  none: tok({ alg: 'none', kid: 'key-1' }, C), hs256: tok({ alg: 'HS256', kid: 'key-1' }, C, 'A'.repeat(43)), rs256: tok({ alg: 'RS256', kid: 'kid-1' }, C, 'A'.repeat(342)),
  nokid: tok({ alg: 'EdDSA' }, C), otherkid: tok({ ...H, kid: 'key-2' }, C), noalg: tok({ kid: 'key-1' }, C), compact: 'a.b', empty: `${enc(H)}.${enc(C)}.`, short: tok(H, C, 'AAAA'),
  good: tok(H, C),
};
// check: [name, claims]; now_ms = 1767225601000, leeway 60 s (Q301): exp = now - 60 s is refused, now - 59.999 s is good; iat = now + 60 s is good, now + 60.001 s is refused
const c = (o) => { const r = { ...C, ...o }; for (const k of Object.keys(r)) if (r[k] === null) delete r[k]; return r; };
out.chk = {
  good: tok(H, C), frac: tok(H, c({ iat: 1767225600.5 })), exp_eq: tok(H, c({ exp: 1767225541 })), exp_ok: tok(H, c({ exp: 1767225541.001 })), iat_future: tok(H, c({ iat: 1767225661.001 })), iat_eq: tok(H, c({ iat: 1767225661 })),
  iss: tok(H, c({ iss: 'https://other.example' })), aud: tok(H, c({ aud: 'https://other.example' })), aud_list: tok(H, c({ aud: ['https://other.example', AUD] })), aud_miss: tok(H, c({ aud: null })),
  iat_miss: tok(H, c({ iat: null })), exp_miss: tok(H, c({ exp: null })), sub_miss: tok(H, c({ sub: null })), iss_miss: tok(H, c({ iss: null })),
  sub_abc: tok(H, c({ sub: 'abc' })), sub_0: tok(H, c({ sub: '0' })), sub_neg: tok(H, c({ sub: '-5' })), sub_frac: tok(H, c({ sub: '12.5' })), sub_plus: tok(H, c({ sub: '+7' })), sub_empty: tok(H, c({ sub: '' })),
  sub_num: tok(H, c({ sub: 4242 })), sub_big: tok(H, c({ sub: '18446744073709551616' })), sub_max: tok(H, c({ sub: '9007199254740993' })),
};
console.log(JSON.stringify(out, null, 1));
