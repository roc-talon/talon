// The OIDC part of the W2 runner (docs/slices/108-oidc.md section 4.2, docs/registry/PLAN.md B.1): test RSA keys, the fake JWKS and signed test tokens.
// Node WebCrypto only, no npm package. The keys are made once for each run of the runner (RSASSA-PKCS1-v1_5, 2048 bits, e = 65537, SHA-256), so no
// private key is in the repository. A key has a name (`k1`, `k2`, ...): the same name gives the same key in all cases of one run.
//
// 1. The fake JWKS: a JSON file of the fake GitHub can hold objects {"$key": "<name>", ...more members}. The runner replaces each with the public
//    JWK of that key ({kty, n, e}) plus the other members of the object (for example "kid", "alg", "use").
//    worker/tests/oidc/jwks.json is the JWKS {kid-1: k1} that most cases copy.
// 2. Tokens: the file `tokens.json` of a case maps a name to a spec. A request line {"token": "<name>"} gets the header `authorization: Bearer <token>`.
//    A spec: {
//      "base": "bot" | "publish"   the claims of worker/tests/oidc/claims-<base>.json (default: no claims)
//      "claims": {..}              members to add or replace; null removes a member
//      "kid": "kid-1"              the header kid (default "kid-1"); null: no kid
//      "alg": "RS256"              the header alg (default "RS256"); null: no alg. The token is signed with RS256 for each alg.
//      "key": "k1"                 the key that signs (default "k1")
//      "tamper": "signature" | "payload"   after the sign: change the first byte of the signature, or put a payload with "x":1 added
//      "raw": "text"               the token text as written, with no sign
//    }
import { webcrypto } from 'node:crypto';
import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

const { subtle } = webcrypto;
const keys = new Map();
const ALG = { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' };

function key(name) {
  if (!keys.has(name)) {
    keys.set(name, (async () => {
      const pair = await subtle.generateKey({ ...ALG, modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]) }, true, ['sign', 'verify']);
      const { kty, n, e } = await subtle.exportKey('jwk', pair.publicKey);
      return { privateKey: pair.privateKey, publicJwk: { kty, n, e } };
    })());
  }
  return keys.get(name);
}

const b64u = (bytes) => Buffer.from(bytes).toString('base64url');
const enc = (obj) => b64u(Buffer.from(JSON.stringify(obj)));

// Replace each {"$key": name, ...} in a JSON text with the public JWK of that key and the other members. A text with no "$key" is not changed.
export async function fillKeys(text) {
  if (!text.includes('"$key"')) return text;
  const walk = async (v) => {
    if (Array.isArray(v)) return Promise.all(v.map(walk));
    if (v !== null && typeof v === 'object') {
      if (typeof v.$key === 'string') {
        const { $key, ...rest } = v;
        return { ...(await key($key)).publicJwk, ...rest };
      }
      const out = {};
      for (const [k, x] of Object.entries(v)) out[k] = await walk(x);
      return out;
    }
    return v;
  };
  return JSON.stringify(await walk(JSON.parse(text)));
}

// The token text of the spec `name` in tokens.json of the case dir.
export async function token(caseDir, name) {
  const file = join(caseDir, 'tokens.json');
  const specs = existsSync(file) ? JSON.parse(readFileSync(file, 'utf8')) : {};
  const spec = specs[name];
  if (spec === undefined) throw new Error(`tokens.json has no token "${name}"`);
  if (spec.raw !== undefined) return spec.raw;
  const base = spec.base === undefined ? {} : JSON.parse(readFileSync(join(import.meta.dirname, 'oidc', `claims-${spec.base}.json`), 'utf8'));
  const claims = { ...base };
  for (const [k, v] of Object.entries(spec.claims ?? {})) {
    if (v === null) delete claims[k];
    else claims[k] = v;
  }
  const header = { typ: 'JWT' };
  const alg = spec.alg === undefined ? 'RS256' : spec.alg;
  const kid = spec.kid === undefined ? 'kid-1' : spec.kid;
  if (alg !== null) header.alg = alg;
  if (kid !== null) header.kid = kid;
  const signed = `${enc(header)}.${enc(claims)}`;
  const sig = Buffer.from(await subtle.sign(ALG, (await key(spec.key ?? 'k1')).privateKey, Buffer.from(signed)));
  if (spec.tamper === 'signature') sig[0] ^= 1;
  const payload = spec.tamper === 'payload' ? enc({ ...claims, x: 1 }) : enc(claims);
  return `${enc(header)}.${payload}.${b64u(sig)}`;
}
