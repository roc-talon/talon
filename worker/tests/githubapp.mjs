// The GitHub App part of the W2 runner (docs/slices/119a-read-token.md section 4): a throwaway test RSA key for the App, the settings of the App for each case,
// the check of the JWT of the Worker, and the answer of the fake GitHub to the token request. Node crypto only, no npm package.
// The key is made once for each run of the runner (RSA 2048, e = 65537), so no private key is in the repository and the real key of the App (~/.config/talon-indexer/) is never read.
//
// Settings of a case (the `vars` of the Wrangler config; a case settings.json can change one, and the value null removes it, so a case can test a missing setting):
//   GITHUB_APP_ID               123456
//   GITHUB_APP_INSTALLATION_ID  654321        Q1 of the slice file (proposal: a setting)
//   GITHUB_APP_KEY              the PKCS#8 PEM of the test key   Q2 of the slice file (proposal: PKCS#8 PEM). The form is one constant here: KEY_FORM.
//
// The fake GitHub (run.mjs, `fakeGithub`) uses `tokenRequest` for `POST https://api.github.com/app/installations/<id>/access_tokens`, and `readAuth` for each other request to api.github.com.
import { generateKeyPairSync, createVerify } from 'node:crypto';

export const KEY_FORM = 'pkcs8-pem';
export const APP_ID = '123456';
export const INSTALLATION_ID = '654321';
export const USER_AGENT = 'talon-registry';
export const ACCEPT = 'application/vnd.github+json';

let pair;
const keys = () => {
  pair ??= generateKeyPairSync('rsa', { modulusLength: 2048, publicExponent: 65537 });
  return pair;
};

// The settings that every case gets (before settings.json of the test and of the case).
export function appSettings() {
  const pem = keys().privateKey.export({ type: 'pkcs8', format: 'pem' });
  return { GITHUB_APP_ID: APP_ID, GITHUB_APP_INSTALLATION_ID: INSTALLATION_ID, GITHUB_APP_KEY: pem };
}

// Remove the settings that a case sets to null.
export function dropNulls(settings) {
  return Object.fromEntries(Object.entries(settings).filter(([, v]) => v !== null));
}

const b64uText = (s) => Buffer.from(s, 'base64url').toString('utf8');
const sameKeys = (o, names) => JSON.stringify(Object.keys(o).sort()) === JSON.stringify([...names].sort());

// Check the JWT of the App in the header `authorization` of the token request. `nowS` is the clock of the Worker (whole seconds). Gives a list of texts (empty: the JWT is right).
// R-PU25: RS256, header {alg, typ}, payload {iat now-60, exp now+540, iss the app id as a number}, a signature that the public key of the test key verifies.
export function checkJwt(auth, appId, nowS) {
  const m = /^Bearer ([A-Za-z0-9_-]+)\.([A-Za-z0-9_-]+)\.([A-Za-z0-9_-]+)$/.exec(auth ?? '');
  if (!m) return [`the token request has no "Bearer <jwt>" authorization (got ${auth === null || auth === undefined ? 'none' : JSON.stringify(String(auth).slice(0, 20))})`];
  const errs = [];
  let header, payload;
  try { header = JSON.parse(b64uText(m[1])); payload = JSON.parse(b64uText(m[2])); } catch { return ['the JWT header or payload is not JSON']; }
  if (!sameKeys(header, ['alg', 'typ']) || header.alg !== 'RS256' || header.typ !== 'JWT') errs.push(`JWT header is ${JSON.stringify(header)}, not {"alg":"RS256","typ":"JWT"}`);
  if (!sameKeys(payload, ['iat', 'exp', 'iss'])) errs.push(`JWT payload members are ${JSON.stringify(Object.keys(payload))}, not iat, exp, iss`);
  if (payload.iss !== Number(appId)) errs.push(`JWT iss is ${JSON.stringify(payload.iss)}, not the number ${appId}`);
  if (payload.iat !== nowS - 60) errs.push(`JWT iat is ${JSON.stringify(payload.iat)}, not now - 60 = ${nowS - 60}`);
  if (payload.exp !== nowS + 540) errs.push(`JWT exp is ${JSON.stringify(payload.exp)}, not now + 540 = ${nowS + 540}`);
  const v = createVerify('RSA-SHA256');
  v.update(`${m[1]}.${m[2]}`);
  if (!v.verify(keys().publicKey, Buffer.from(m[3], 'base64url'))) errs.push('JWT signature does not verify with the public key of the test App key');
  return errs;
}

const iso = (s) => new Date(s * 1000).toISOString().replace(/\.\d{3}Z$/, 'Z');

// The default answer of the fake to a good token request: the n-th token of the case (n from 1), valid for 1 h from the clock of the Worker.
export function tokenAnswer(n, nowS) {
  return JSON.stringify({ token: `ghs_test${n}`, expires_at: iso(nowS + 3600), permissions: { contents: 'read', metadata: 'read' }, repository_selection: 'selected' });
}

// The text of the credential kind of a read: `none` (no authorization header), `<n>` (exactly `Bearer ghs_test<n>`), `bad` (anything else).
export function readAuth(auth) {
  if (auth === null || auth === undefined) return 'none';
  const m = /^Bearer ghs_test(\d+)$/.exec(auth);
  return m ? m[1] : 'bad';
}
