// Slice 121: read or set the webhook config of the GitHub App (GET or PATCH /app/hook/config) with an App JWT (RS256).
//   node app-hook.mjs <app id> <private key pem file>            read
//   node app-hook.mjs <app id> <private key pem file> <url>      set the url (content_type json; the secret is not changed)
// Prints the config without the secret.
import { readFileSync } from 'node:fs';
import { createSign } from 'node:crypto';
const [id, keyFile, url] = process.argv.slice(2);
const b64 = (x) => Buffer.from(typeof x === 'string' ? x : JSON.stringify(x)).toString('base64url');
const now = Math.floor(Date.now() / 1000);
const head = b64({ alg: 'RS256', typ: 'JWT' }) + '.' + b64({ iat: now - 60, exp: now + 540, iss: id });
const sig = createSign('RSA-SHA256').update(head).sign(readFileSync(keyFile), 'base64url');
const res = await fetch('https://api.github.com/app/hook/config', {
  method: url ? 'PATCH' : 'GET',
  headers: { authorization: `Bearer ${head}.${sig}`, accept: 'application/vnd.github+json', 'user-agent': 'talon-deploy', 'content-type': 'application/json' },
  body: url ? JSON.stringify({ url, content_type: 'json', insecure_ssl: '0' }) : undefined,
});
const body = await res.json();
delete body.secret;
console.log(res.status, JSON.stringify(body));
