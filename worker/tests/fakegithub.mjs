// The fake GitHub of W2 (slice 224: moved here from run.mjs, so that run.mjs and serve.mjs share it; no change of behavior).
// fakeGithub(dir, log, errs, dbRef, app) gives the `outbound` function of startApp. It serves the files of `<dir>/github/` (the form is in the doc comment of run.mjs),
// adds `METHOD url` to `log` for each request that is not a token request, and adds a text to `errs` for each fault (no file, a wrong header, a bad token request).
// `dbRef.db` is the D1 handle for `<file>.sql`. `app` is the state of the case: { settings, nowMs, tokenLog, authLog, issued }.
import { readFileSync, existsSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { splitSql } from '../../sql/tests/split.mjs';
import { fillKeys } from './oidc.mjs';
import { generate } from './tools/mk-bundle.mjs';
import { checkJwt, tokenAnswer, readAuth } from './githubapp.mjs';

const read = (p) => (existsSync(p) ? readFileSync(p, 'utf8') : '');
const jstr = (v) => (v === undefined ? 'missing' : JSON.stringify(v));
// The file name of a URL part (TESTING.md 3.1, TW29): `%` `?` `:` `\` `*` `<` `>` `|` `"` are written as %XX with upper case hex digits.
export const encodeName = (s) => s.replace(/[%?:\\*<>|"]/g, (c) => `%${c.charCodeAt(0).toString(16).toUpperCase().padStart(2, '0')}`);

// The fake GitHub: serves `github/` of the case, logs each request.
export function fakeGithub(dir, log, errs, dbRef, app) { // `app` is the state of the case (settings, clock, logs); `h` is the app of startApp
  const seen = new Map();
  const tokenPath = /^\/app\/installations\/([^/]+)\/access_tokens$/;
  return async (req) => {
    const url = new URL(req.url);
    const nowS = Math.floor(app.nowMs / 1000);
    const hdr = (name) => req.headers.get(name) ?? 'none';
    const isToken = url.host === 'api.github.com' && req.method === 'POST' && tokenPath.test(url.pathname);
    if (isToken) {
      app.tokenLog.push(`POST ${req.url} now=${nowS} ua=${hdr('user-agent')} accept=${hdr('accept')}`);
      const id = tokenPath.exec(url.pathname)[1];
      if (id !== app.settings.GITHUB_APP_INSTALLATION_ID) {
        errs.push(`token request: the installation id is ${id}, not ${app.settings.GITHUB_APP_INSTALLATION_ID}`);
        return new Response('{"message":"Not Found"}', { status: 404, headers: { 'content-type': 'application/json' } });
      }
      const bad = checkJwt(req.headers.get('authorization'), app.settings.GITHUB_APP_ID, nowS);
      if (bad.length) {
        errs.push(...bad.map((b) => `token request: ${b}`));
        return new Response('{"message":"A JSON web token could not be decoded"}', { status: 401, headers: { 'content-type': 'application/json' } });
      }
    } else {
      log.push(`${req.method} ${req.url}`);
      if (url.host === 'api.github.com') app.authLog.push(`${req.method} ${req.url} token=${readAuth(req.headers.get('authorization'))} ua=${hdr('user-agent')} accept=${hdr('accept')}`);
    }
    const parts = [encodeName(url.host), ...url.pathname.split('/').filter(Boolean).map(encodeName)];
    if (url.search) parts[parts.length - 1] += `%3F${encodeName(url.search.slice(1))}`;
    const n = (seen.get(req.url) ?? 0) + 1;
    seen.set(req.url, n);
    let first = join(dir, 'github', ...parts);
    if (existsSync(first) && statSync(first).isDirectory()) first = join(first, '%2F');
    const file = n > 1 && existsSync(`${first}.${n}`) ? `${first}.${n}` : first;
    if (isToken && !existsSync(file)) return new Response(tokenAnswer(++app.issued, nowS), { status: 201, headers: { 'content-type': 'application/json' } });
    if (!existsSync(file)) {
      errs.push(`github: no fake route for ${req.method} ${req.url} (expected the file ${file.slice(dir.length + 1)})`);
      return new Response(`no fake route for ${req.url}`, { status: 599 });
    }
    if (existsSync(`${file}.sql`)) for (const s of splitSql(read(`${file}.sql`))) await dbRef.db.prepare(s.sql).run();
    const meta = JSON.parse(read(`${file}.meta.json`) || '{}');
    for (const [h, want] of Object.entries(meta.require ?? {})) {
      if (req.headers.get(h) !== want && !(want === null && !req.headers.has(h))) { errs.push(`github: ${req.method} ${req.url}: the header ${h} is ${jstr(req.headers.get(h) ?? undefined)}, expected ${jstr(want)}`); return new Response('wrong header', { status: 599 }); }
    }
    const type = /\.(zst|tar)$/.test(file) ? 'application/octet-stream' : 'application/json';
    if (existsSync(`${file}.gen.json`)) {
      const g = generate(JSON.parse(read(`${file}.gen.json`)));
      return new Response(g.body, { status: meta.status ?? 200, headers: { 'content-type': type, ...g.headers } });
    }
    if ([204, 304].includes(meta.status)) return new Response(null, { status: meta.status, headers: { ...(meta.headers ?? {}) } }); // slice 119b: a null-body status
    const body = type === 'application/json' ? await fillKeys(readFileSync(file, 'utf8')) : readFileSync(file);
    return new Response(body, { status: meta.status ?? 200, headers: { 'content-type': type, ...(meta.headers ?? {}) } });
  };
}

