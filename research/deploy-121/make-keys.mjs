// Slice 121: make the Worker secrets CONTRIBUTOR_KEY and TOKEN_KEY once (R-CT3, R-WH14 deploy note). Writes them to <dir> with mode 600 and prints nothing secret.
//   node make-keys.mjs ~/.config/talon-registry
import { mkdirSync, writeFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { randomBytes, webcrypto } from 'node:crypto';
const dir = process.argv[2];
mkdirSync(dir, { recursive: true, mode: 0o700 });
const put = (name, text) => {
  const p = join(dir, name);
  if (existsSync(p)) { console.log(`${name}: kept (exists)`); return; }
  writeFileSync(p, text, { mode: 0o600 });
  console.log(`${name}: written`);
};
put('CONTRIBUTOR_KEY', randomBytes(32).toString('hex'));
const kp = await webcrypto.subtle.generateKey({ name: 'Ed25519' }, true, ['sign', 'verify']);
const jwk = await webcrypto.subtle.exportKey('jwk', kp.privateKey);
const kid = 'k' + new Date().toISOString().slice(0, 10).replaceAll('-', '');
put('TOKEN_KEY', JSON.stringify({ kty: jwk.kty, crv: jwk.crv, x: jwk.x, d: jwk.d, kid }));
