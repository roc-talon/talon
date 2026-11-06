// The W2 runner (docs/registry/PLAN.md B, docs/slices/101-worker-skeleton.md): the built Worker (app.wasm) in Miniflare with a local D1,
// a fake GitHub as the outbound service, a D1 call count and a fixed clock.
//   node worker/tests/run.mjs [filter ...]     run the cases whose name has a filter text (the self-test cases too)
// Env: W2_DIR (the dir with app.wasm and .roc-cfw/, default: worker/), MINIFLARE (the dir of the miniflare package, default: the one of the
//      global wrangler of this node), JOBS (cases at the same time, default: min(CPU count, 6)), W2_TMP (the dir for temp files, default: the temp dir),
//      CASE_TIMEOUT (seconds for one case, default 30), VERBOSE=1 (print the Worker log lines of a passed case too).
// A case is a dir `worker/tests/cases/<area>/<id>-<name>/`:
//   requests.jsonl        one request in each line: {"method","path","headers":{..},"body":"text" | "json":{..},"now":ms}, or a cron run {"cron":"..","time":ms}.
//                         The clock of the Worker is `now` (default 1767225600000, 2026-01-01T00:00:00Z): a case never reads the real clock.
//                         A line {"sql":["statement", ...]} is not a request: the statements run on the DB between the requests. It has no line in expect/responses.jsonl and expect/d1-calls.
//   seed.sql              optional. Statements that run after the migrations (`sql/0001_init.sql`, ... when they exist). The statements may be DDL.
//   github/               optional. The fake GitHub: one file for each URL: `github/<host>/<path>` (and `%3F<query>` at the end), with the names encoded as TESTING.md 3.1.
//                         The body of the file is the answer (status 200, `application/json`; `application/octet-stream` for a name that ends in .zst or .tar).
//                         `<file>.meta.json` is optional: {"status":404,"headers":{..}}. A URL with no file gets status 599 and fails the case.
//                         `<file>.<n>` (n = 2, 3, ...) is optional: the answer to the n-th request of that URL in the case (with its own `.meta.json`).
//                         A JSON body can name test keys: {"$key": "k1", ...} (worker/tests/oidc.mjs).
//   tokens.json           optional. Signed test tokens by name (worker/tests/oidc.mjs). A request line with "token": "<name>" gets `authorization: Bearer <token>`.
//   ratelimits.json       optional (slice 116b). The rate limit bindings of the case: {"RL_HINTS":{"limit":3,"period":60}} (period 10 or 60). A case without it gets RL_HINTS with a limit that no case reaches
//                         (1000 in 60 s), because the Worker declares the binding and the shim refuses a start without it.
//                         Slice 112b: each case also gets RL_INGEST with 60 a minute (Registry R-WH14, R-PU34 row 1), unless ratelimits.json gives RL_INGEST.
//                         Miniflare counts each binding locally, for each Miniflare (research/slice-112b/ratelimit.mjs).
//                         A request with no `cf-connecting-ip` header gets 127.0.0.1 from Miniflare.
//                         Slice 117: every case also gets RL_HINTS and RL_LOGIN with a limit that no case reaches (1000 in 60 s), unless ratelimits.json gives RL_LOGIN.
//   settings.json         Slice 117: a value {"$edkey": "t1", "kid": "key-1"} becomes the text of the private JWK of the throwaway Ed25519 key t1 (worker/tests/oidc.mjs): the secret TOKEN_KEY.
//   settings.json         optional. More Worker settings (the `vars` of the Wrangler config), in addition to worker/tests/settings.json.
//   expect/responses.jsonl  one line for each request: {"status":N, "headers":{"name":"exact value" | null}, "json":{subset}, "body":"exact text",
//                         "problem":{subset}}. `problem` is `json` plus: the content type is exactly `application/problem+json` and `status` of the body is the HTTP status.
//                         Slice 109 adds 3 checks for a long list: "json_len":{"a.b":N} (the length of the array at a dotted path), "json_at":{"a.0.b":value}
//                         (the value at a dotted path, a number is an array index), "json_range":{"path":"a","field":"f","from":1,"to":1000} (the field `f` of the
//                         items of the array at `path` is the integers from..to in this order, each once).
//   expect/responses.jsonl  "jwt":{"at":"token","key":"t1","header":{subset},"claims":{subset}} (slice 117): the text at the member `at` of the JSON body is a JWT with a good Ed25519 signature of the key `key`,
//                         canonical base64url parts, and a header and claims that have the subset. A number compares as a number (`1767225600.000` is `1767225600`).
//   github/<file>.meta.json  Slice 117: `"require":{"authorization":"Bearer ghu_one"}`: the request must have these headers (names in lower case, exact values), else the case fails.
//   expect/d1-calls       optional. One line for each request: the count of D1 calls (a number), or `-` for a request that is not checked (the D1 call budget of Registry 4.2).
//   expect/db.tsv         optional. Blocks: a line `@ SELECT ...` and then the rows that it must give after the last request (cells tab separated, NULL as \N).
//   expect/github.log     the outbound requests in order, one line `METHOD url`. A missing file means that the Worker makes no outbound request.
//                         Slice 119a: the token request (`POST https://api.github.com/app/installations/<id>/access_tokens`) is not in github.log; it is in tokens.log.
//   Slice 119a (worker/tests/githubapp.mjs, docs/slices/119a-read-token.md section 4): each case gets the settings GITHUB_APP_ID (123456), GITHUB_APP_INSTALLATION_ID (654321) and
//                         GITHUB_APP_KEY (the PKCS#8 PEM of a throwaway test key made at the start of the run), before settings.json. A value null in settings.json removes the setting.
//                         The fake GitHub serves the token request: it checks the App JWT (RS256, header, iat now-60, exp now+540, iss the id as a number, the signature with the test key;
//                         `now` is the clock of the request) and gives the n-th token `ghs_test<n>`, valid for 1 h from that clock (status 201). A file `github/api.github.com/app/installations/<id>/access_tokens`
//                         (and `.meta.json`, `.<n>`) in the case gives the answer in its place, after the JWT check (a 401, a 403, a body that is not a token).
//   expect/tokens.log     optional (slice 119a). One line for each token request: `POST <url> now=<s> ua=<user-agent> accept=<accept>` (`s` = the clock of the request in whole seconds, `none` for a missing header).
//   expect/auth.log       optional (slice 119a). One line for each other request to api.github.com: `METHOD <url> token=<none|n|bad> ua=<user-agent> accept=<accept>`. `token=n` is exactly
//                         `authorization: Bearer ghs_test<n>` (the n-th default token of the case), `none` is no authorization header, `bad` is any other value. Other hosts are not in this log.
//   app                   optional (slice 111). The text `archive`: the case runs the test app worker/archive-test.roc (W2_ARCHIVE_WASM, default W2_DIR/archive-test.wasm)
//                         in place of app.wasm. When that wasm is missing, only these cases fail, with a message; the other cases run.
//   github/<dir>/%2F      optional (slice 112). The answer to a URL whose path is also a dir of github/ (`repos/o/r` beside `repos/o/r/releases/...`). `%2F.meta.json`, `%2F.<n>` as above.
//   github/<file>.sql     optional (slice 112). SQL statements (split as seed.sql) that run on the DB just before the fake answers with <file> (also `<file>.<n>.sql`):
//                         a write of "another request" between two D1 calls of one request (Registry R-AP41 row 3).
//   Slice 120: a cron line {"cron":"0 3 * * *","time":ms,"now":ms} sets the clock to `now` first. The answer is the JSON of Miniflare: expect {"status":200,"json":{"outcome":"ok"}} (a failed run is status 500).
//   A line {"wait_ms": N} (slice 112b) is not a request: the runner waits N ms (the work after a response, `Response.after`, ends before the next request).
//   A line {"window_s": P, "need_ms": N} (slice 112b) is not a request: the runner waits until the wall-clock window of P s has N ms or more left. The rate limit
//                         of Miniflare counts in windows aligned to the wall clock (Date.now / period), so a case that must stay in one window starts with this line.
//                         The case timeout gets P s more.
//   expect/responses.jsonl "headers_set":["name", ...] (slice 112): each header is in the response, with any value (a D1 bookmark is not a fixed text).
//   github/<file>.gen.json  optional (slice 111). The body of <file> is made while the Worker reads it (`generate` of tools/mk-bundle.mjs): an answer too large to track.
//   Slice 118: a request line can have "body_pad":{"prefix":"{\"zen\":\"","fill":"a","suffix":"\"}","total":1048576}: the body is exactly `total` bytes (ASCII), made by the runner. The signature of a webhook case is made by the generator over the same bytes.
//   Slice 118 (queue). Each case has the queue producers INDEX (queue `talon-index`) and INDEX_DLQ (queue `talon-index-dlq`), and no consumer: a message that the Worker sends stays in the queue. The test entry records each send.
//   expect/responses.jsonl "queue_sent":[{"body":{..},"delay_s":N}, ...]: the sends of the request to INDEX, in order (the body compared with the order of the members ignored; `delay_s` 0 is no delay). `[]` checks that there is none.
//   expect/responses.jsonl "timing_safe":N: the count of `crypto.subtle.timingSafeEqual` calls of the request (a constant-time compare of a secret is a call).
//   A line {"queue":"talon-index","now":ms,"messages":[{"id":"m1","attempts":1,"body":{..}}, ...]} (slice 118) is a request: the runner sets the clock, then calls the `queue` handler of the Worker with this batch
//                         (Miniflare `worker.queue()`; no broker, no wait). Its line in expect/responses.jsonl is {"outcome":"ok","acked":["m1"],"retried":[{"id":"m2","delay_s":60}]}: the ids that the handler acked
//                         (`acked`, any order), and the messages that it retried with the delay in whole seconds (`delay_s` null for a retry with no delay). A message in neither list was not answered. Its line in expect/d1-calls is `-`.
//   expect/logs.jsonl     optional (slice 118). One JSON object in each line. Each must be a subset of a different Worker log line (the JSON of the line, with `level`), in any order. The run waits up to 3 s for the lines.
//   timeout               optional. The seconds for this case, in place of CASE_TIMEOUT (default 30). For a case with a large seed that is slow when many builds run at the same time. A window_s line still adds its P s.
//   expect-fail           self-test cases only (worker/tests/selftest/<name>/). One text in each line. The case must fail, and the failure must have each text.
// The output is one line for each case: `PASS <case>` or `FAIL <case>` and the reasons. Exit 1 on a failure.
import { createRequire } from 'node:module';
import { readFileSync, readdirSync, existsSync, mkdirSync, rmSync, statSync } from 'node:fs';
import { cpus, tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { splitSql, migrationFiles, parseExpected, tsvOf } from '../../sql/tests/split.mjs';
import { fillKeys, token, fillSettings, verifyJwt } from './oidc.mjs';
import { generate } from './tools/mk-bundle.mjs';
import { appSettings, dropNulls, checkJwt, tokenAnswer, readAuth } from './githubapp.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, '..', '..');
const w2Dir = process.env.W2_DIR ?? join(root, 'worker');
const filters = process.argv.slice(2);
const runDir = join(process.env.W2_TMP ?? tmpdir(), `talon-w2-${process.pid}`);
mkdirSync(runDir, { recursive: true });
process.env.TMPDIR = runDir; // the temp dirs of Miniflare go here too
const live = new Set();
const cleanup = () => rmSync(runDir, { recursive: true, force: true });
process.on('exit', cleanup);
for (const [sig, code] of [['SIGTERM', 143], ['SIGINT', 130]]) {
  process.once(sig, async () => {
    await Promise.all([...live].map((m) => m.dispose().catch(() => {})));
    process.exit(code);
  });
}

const mfDir = process.env.MINIFLARE ?? join(dirname(dirname(process.execPath)), 'lib/node_modules/wrangler/node_modules/miniflare');
let Miniflare, convertV4MiniflareOptions;
try {
  ({ Miniflare, convertV4MiniflareOptions } = createRequire(import.meta.url)(mfDir));
} catch (e) {
  console.log(`FAIL w2: Miniflare is not at ${mfDir} (install wrangler 4 globally with node 26, or set MINIFLARE): ${e.message.split('\n')[0]}`);
  process.exit(1);
}
for (const f of ['app.wasm', '.roc-cfw/index.js']) {
  if (!existsSync(join(w2Dir, f))) {
    console.log(`FAIL w2: ${join(w2Dir, f)} is missing: build the Worker first (scripts/test.sh w2 does it; by hand: tln run build in worker/)`);
    process.exit(1);
  }
}

const read = (p) => (existsSync(p) ? readFileSync(p, 'utf8') : '');
const lines = (p) => read(p).split('\n').filter((l) => l.trim() !== '');
const subdirs = (d) => (existsSync(d) ? readdirSync(d, { withFileTypes: true }).filter((e) => e.isDirectory()).map((e) => e.name).sort() : []);
const DEFAULT_NOW = 1767225600000;

const cases = [];
for (const area of subdirs(join(here, 'cases'))) for (const id of subdirs(join(here, 'cases', area))) cases.push({ name: `${area}/${id}`, dir: join(here, 'cases', area, id), mustFail: false });
for (const id of subdirs(join(here, 'selftest'))) cases.push({ name: `selftest/${id}`, dir: join(here, 'selftest', id), mustFail: true });
const chosen = cases.filter((c) => filters.length === 0 || filters.some((f) => c.name.includes(f)));

// The modules of the Worker: the test entry, the shim (.roc-cfw/*.js) and app.wasm, by the names that worker-test.js imports.
const modulesFor = (wasm) => [
  { type: 'ESModule', path: join(w2Dir, 'worker-test.js'), contents: readFileSync(join(here, 'worker-test.js'), 'utf8') },
  { type: 'ESModule', path: join(w2Dir, 'clock.js'), contents: readFileSync(join(here, 'clock.js'), 'utf8') },
  ...readdirSync(join(w2Dir, '.roc-cfw')).filter((f) => f.endsWith('.js')).map((f) => ({ type: 'ESModule', path: join(w2Dir, '.roc-cfw', f), contents: readFileSync(join(w2Dir, '.roc-cfw', f), 'utf8') })),
  { type: 'CompiledWasm', path: join(w2Dir, 'app.wasm'), contents: readFileSync(wasm) },
];
const modules = modulesFor(join(w2Dir, 'app.wasm'));
let archiveModules; // the test app of slice 111, read when a case needs it
const archiveWasm = process.env.W2_ARCHIVE_WASM || join(w2Dir, 'archive-test.wasm');
// The modules of a case, or the text of why they are missing (the case fails with it; the other cases run).
const modulesOf = (c) => {
  if (read(join(c.dir, 'app')).trim() !== 'archive') return { modules };
  if (!existsSync(archiveWasm)) return { missing: `the test app ${archiveWasm} is missing: the build of worker/archive-test.roc failed or did not run (scripts/test.sh w2 builds it; its log is $WORK/logs/worker-archive-build.*.log)` };
  archiveModules ??= modulesFor(archiveWasm);
  return { modules: archiveModules };
};
const migrations = migrationFiles(join(root, 'sql')).map((f) => readFileSync(f, 'utf8'));
const baseSettings = JSON.parse(read(join(here, 'settings.json')) || '{}');
// The rate limit bindings of a case (slice 116b): ratelimits.json, else RL_HINTS with a limit that a case does not reach.
const ratelimitsOf = (c) => JSON.parse(read(join(c.dir, 'ratelimits.json')) || '{"RL_HINTS":{"limit":1000,"period":60}}');

// The file name of a URL part (TESTING.md 3.1, TW29): `%` `?` `:` `\` `*` `<` `>` `|` `"` are written as %XX with upper case hex digits.
const encodeName = (s) => s.replace(/[%?:\\*<>|"]/g, (c) => `%${c.charCodeAt(0).toString(16).toUpperCase().padStart(2, '0')}`);

const jstr = (v) => (v === undefined ? 'missing' : JSON.stringify(v));
// Check that `actual` has everything in `expected`: an object is a subset, an array has the same length and each item is a subset, other values are equal.
function subset(expected, actual, path, errs) {
  if (expected !== null && typeof expected === 'object' && !Array.isArray(expected)) {
    if (actual === null || typeof actual !== 'object' || Array.isArray(actual)) { errs.push(`${path}: expected an object, got ${jstr(actual)}`); return; }
    for (const [k, v] of Object.entries(expected)) subset(v, actual[k], `${path}.${k}`, errs);
  } else if (Array.isArray(expected)) {
    if (!Array.isArray(actual) || actual.length !== expected.length) { errs.push(`${path}: expected an array of ${expected.length} items, got ${jstr(actual)}`); return; }
    expected.forEach((v, i) => subset(v, actual[i], `${path}[${i}]`, errs));
  } else if (expected !== actual) errs.push(`${path}: expected ${jstr(expected)}, got ${jstr(actual)}`);
}

// Check one response against its expected line. `n` is the number of the request (from 1).
function checkResponse(n, exp, res, errs) {
  const at = `request ${n}`;
  const put = (e) => errs.push(`${at}: ${e}`);
  if (exp.status !== res.status) put(`status: expected ${exp.status}, got ${res.status}`);
  for (const name of exp.headers_set ?? []) if (res.headers[name.toLowerCase()] === undefined) put(`header ${name}: expected a value, got none`);
  for (const [name, want] of Object.entries(exp.headers ?? {})) {
    const got = res.headers[name.toLowerCase()] ?? null;
    if (got !== want) put(`header ${name}: expected ${jstr(want)}, got ${jstr(got)}`);
  }
  let parsed;
  const needJson = exp.json !== undefined || exp.problem !== undefined || exp.json_len !== undefined || exp.json_at !== undefined || exp.json_range !== undefined;
  if (needJson) {
    try { parsed = JSON.parse(res.body); } catch { put(`body is not JSON: ${res.body.slice(0, 120)}`); }
  }
  if (exp.json !== undefined && parsed !== undefined) { const e = []; subset(exp.json, parsed, 'json', e); e.forEach(put); }
  if (parsed !== undefined && (exp.json_len || exp.json_at || exp.json_range)) {
    const at = (path) => path.split('.').reduce((v, k) => (v === undefined || v === null ? undefined : v[k]), parsed);
    for (const [path, n] of Object.entries(exp.json_len ?? {})) { const v = at(path); if (!Array.isArray(v) || v.length !== n) put(`json_len ${path}: expected an array of ${n} items, got ${Array.isArray(v) ? `${v.length} items` : jstr(v)}`); }
    for (const [path, want] of Object.entries(exp.json_at ?? {})) { const v = at(path); if (JSON.stringify(v) !== JSON.stringify(want)) put(`json_at ${path}: expected ${jstr(want)}, got ${jstr(v)}`); }
    if (exp.json_range) {
      const { path, field, from, to } = exp.json_range;
      const v = at(path);
      const got = Array.isArray(v) ? v.map((x) => x?.[field]) : undefined;
      const bad = got === undefined ? 'not an array' : got.length !== to - from + 1 ? `${got.length} items` : got.findIndex((x, i) => x !== from + i);
      if (bad !== -1) put(`json_range ${path}.${field}: expected ${from}..${to} in order, ${typeof bad === 'number' ? `first difference at item ${bad} (${jstr(got[bad])})` : bad}`);
    }
  }
  if (exp.problem !== undefined) {
    if (res.headers['content-type'] !== 'application/problem+json') put(`problem: content-type: expected "application/problem+json", got ${jstr(res.headers['content-type'] ?? null)}`);
    if (parsed !== undefined) {
      const e = [];
      subset(exp.problem, parsed, 'problem', e);
      if (parsed.status !== res.status) e.push(`problem.status: expected ${res.status} (the HTTP status), got ${jstr(parsed.status)}`);
      e.forEach(put);
    }
  }
  if (exp.jwt !== undefined && parsed === undefined) {
    try { parsed = JSON.parse(res.body); } catch { put(`jwt: body is not JSON: ${res.body.slice(0, 120)}`); }
  }
  if (exp.jwt !== undefined && parsed !== undefined) {
    const text = parsed[exp.jwt.at];
    const v = verifyJwt(text, exp.jwt.key ?? 't1');
    if (!v.ok) put(`jwt ${exp.jwt.at}: not a good Ed25519 token of key ${exp.jwt.key ?? 't1'}: ${v.why ?? 'bad signature'} (${jstr(text)})`);
    else {
      if (!v.canonical) put(`jwt ${exp.jwt.at}: a part is not canonical base64url`);
      const e = [];
      subset(exp.jwt.header ?? {}, v.header, 'jwt.header', e);
      subset(exp.jwt.claims ?? {}, v.claims, 'jwt.claims', e);
      e.forEach(put);
    }
  }
  if (exp.queue_sent !== undefined) {
    let got;
    try { got = JSON.parse(res.headers['x-queue-sent'] ?? '[]'); } catch { got = 'not JSON'; }
    if (canon(got) !== canon(exp.queue_sent)) put(`queue_sent: expected ${canon(exp.queue_sent)}, got ${canon(got)}`);
  }
  if (exp.timing_safe !== undefined && Number(res.headers['x-timing-safe-calls']) !== exp.timing_safe) put(`timing_safe: expected ${exp.timing_safe} calls of timingSafeEqual, got ${res.headers['x-timing-safe-calls'] ?? 'none'}`);
  if (exp.body !== undefined && exp.body !== res.body) put(`body: expected ${jstr(exp.body)}, got ${jstr(res.body.slice(0, 200))}`);
}

// JSON text with the members sorted at each level: two values with the same members have the same text (slice 118).
const canon = (v) => JSON.stringify(v, (_, x) => (x !== null && typeof x === 'object' && !Array.isArray(x) ? Object.fromEntries(Object.keys(x).sort().map((k) => [k, x[k]])) : x));

// Slice 118: the result of a queue line against its expected line.
function checkQueue(n, exp, res, errs) {
  const put = (e) => errs.push(`request ${n}: ${e}`);
  if (exp.outcome !== undefined && exp.outcome !== res.outcome) put(`queue outcome: expected ${exp.outcome}, got ${res.outcome}`);
  if (exp.acked !== undefined && canon([...exp.acked].sort()) !== canon([...res.acked].sort())) put(`queue acked: expected ${canon(exp.acked)}, got ${canon(res.acked)}`);
  if (exp.retried !== undefined) {
    const by = (a) => [...a].sort((x, y) => (x.id < y.id ? -1 : 1));
    if (canon(by(exp.retried)) !== canon(by(res.retried))) put(`queue retried: expected ${canon(exp.retried)}, got ${canon(res.retried)}`);
  }
}

// Slice 118: set the clock, then call the queue handler of the Worker with the batch (no broker).
async function queueCall(mf, spec, app) {
  const now = String(spec.now ?? DEFAULT_NOW);
  app.nowMs = Number(now);
  await mf.dispatchFetch('http://localhost/__test/now', { headers: { 'x-test-now': now } });
  const messages = spec.messages.map((m) => ({ id: m.id, timestamp: new Date(Number(now)), body: m.body, attempts: m.attempts ?? 1 }));
  const r = await (await mf.getWorker()).queue(spec.queue, messages);
  return { outcome: r.outcome, acked: r.explicitAcks ?? [], retried: (r.retryMessages ?? []).map((x) => ({ id: x.msgId, delay_s: x.delaySeconds ?? null })) };
}

// Slice 118: each expected log object is a subset of a different Worker log line. workerd writes a line a little after the answer, so the run waits up to 3 s.
async function checkLogs(wanted, records, errs) {
  const parsed = () => records.map((r) => { try { return { ...JSON.parse(r.message), level: r.level }; } catch { return { msg: r.message, level: r.level }; } });
  const missing = () => {
    const used = new Set();
    return wanted.filter((w) => {
      const i = parsed().findIndex((p, k) => { if (used.has(k)) return false; const e = []; subset(w, p, 'log', e); return e.length === 0; });
      if (i === -1) return true;
      used.add(i);
      return false;
    });
  };
  for (let t = 0; t < 120 && missing().length; t++) await new Promise((r) => setTimeout(r, 25));
  for (const w of missing()) errs.push(`logs: no Worker log line has ${JSON.stringify(w)}; the lines are ${JSON.stringify(parsed()).slice(0, 600)}`);
}

// The fake GitHub: serves `github/` of the case, logs each request.
function fakeGithub(c, log, errs, dbRef, app) {
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
    let first = join(c.dir, 'github', ...parts);
    if (existsSync(first) && statSync(first).isDirectory()) first = join(first, '%2F');
    const file = n > 1 && existsSync(`${first}.${n}`) ? `${first}.${n}` : first;
    if (isToken && !existsSync(file)) return new Response(tokenAnswer(++app.issued, nowS), { status: 201, headers: { 'content-type': 'application/json' } });
    if (!existsSync(file)) {
      errs.push(`github: no fake route for ${req.method} ${req.url} (expected the file ${file.slice(c.dir.length + 1)})`);
      return new Response(`no fake route for ${req.url}`, { status: 599 });
    }
    if (existsSync(`${file}.sql`)) for (const s of splitSql(read(`${file}.sql`))) await dbRef.db.prepare(s.sql).run();
    const meta = JSON.parse(read(`${file}.meta.json`) || '{}');
    for (const [h, want] of Object.entries(meta.require ?? {})) {
      if (req.headers.get(h) !== want) { errs.push(`github: ${req.method} ${req.url}: the header ${h} is ${jstr(req.headers.get(h) ?? undefined)}, expected ${jstr(want)}`); return new Response('wrong header', { status: 599 }); }
    }
    const type = /\.(zst|tar)$/.test(file) ? 'application/octet-stream' : 'application/json';
    if (existsSync(`${file}.gen.json`)) {
      const g = generate(JSON.parse(read(`${file}.gen.json`)));
      return new Response(g.body, { status: meta.status ?? 200, headers: { 'content-type': type, ...g.headers } });
    }
    const body = type === 'application/json' ? await fillKeys(readFileSync(file, 'utf8')) : readFileSync(file);
    return new Response(body, { status: meta.status ?? 200, headers: { 'content-type': type, ...(meta.headers ?? {}) } });
  };
}

async function request(mf, spec, c, app) {
  const now = String(spec.now ?? DEFAULT_NOW);
  app.nowMs = Number(now);
  let res;
  if (spec.cron !== undefined) {
    const q = new URLSearchParams({ cron: spec.cron, time: String(spec.time ?? DEFAULT_NOW), format: 'json' });
    // Slice 120: the scheduled event does not pass the entry `fetch`, so the header x-test-now sets no clock: set it by the self-test path first (as queueCall).
    await mf.dispatchFetch('http://localhost/__test/now', { headers: { 'x-test-now': now } });
    res = await mf.dispatchFetch(`http://localhost/cdn-cgi/local/scheduled?${q}`, { headers: { 'x-test-now': now } });
  } else {
    const headers = { 'x-test-now': now, ...(spec.headers ?? {}) };
    if (spec.token !== undefined) headers.authorization = `Bearer ${await token(c.dir, spec.token)}`;
    // The body is bytes, so fetch adds no Content-Type of its own (a text body would get text/plain).
    let body = spec.body === undefined ? undefined : Buffer.from(spec.body);
    // Slice 118: {"body_pad":{"prefix":"..","fill":"a","suffix":"..","total":N}} is a body of exactly N bytes (prefix, the fill repeated, suffix), so a case needs no file of 1 MiB.
    if (spec.body_pad !== undefined) { const b = spec.body_pad; body = Buffer.from(b.prefix + (b.fill ?? 'a').repeat(b.total - b.prefix.length - (b.suffix ?? '').length) + (b.suffix ?? '')); }
    if (spec.json !== undefined) {
      body = Buffer.from(JSON.stringify(spec.json));
      if (!Object.keys(headers).some((h) => h.toLowerCase() === 'content-type')) headers['content-type'] = 'application/json';
    }
    res = await mf.dispatchFetch(`http://localhost${spec.path}`, { method: spec.method ?? 'GET', headers, body, redirect: 'manual', cache: 'force-cache' }); // force-cache: Node fetch adds no-cache and Pragma to a request with If-None-Match, and a Worker that follows the cache rule then skips its cache
  }
  const headers = {};
  res.headers.forEach((v, k) => { headers[k] = v; });
  return { status: res.status, headers, body: await res.text() };
}

// Run one case. Gives the list of failure texts and the Worker log lines.
async function runCase(c) {
  const errs = [];
  const logs = [];
  const records = [];
  const github = [];
  const specs = lines(join(c.dir, 'requests.jsonl')).map((l) => JSON.parse(l));
  const expected = lines(join(c.dir, 'expect', 'responses.jsonl')).map((l) => JSON.parse(l));
  if (specs.length === 0) return { errs: ['requests.jsonl has no request'], logs };
  const nreq = specs.filter((s) => s.sql === undefined && s.wait_ms === undefined && s.window_s === undefined).length;
  if (expected.length !== nreq) return { errs: [`expect/responses.jsonl has ${expected.length} lines for ${nreq} requests`], logs };
  const mods = modulesOf(c);
  if (mods.missing) return { errs: [mods.missing], logs };
  const persist = join(runDir, c.name.replace(/\W/g, '_'));
  const dbRef = {};
  // Slice 119a: the settings of the App, the clock of the current request, the token and auth logs and the count of default tokens (worker/tests/githubapp.mjs).
  const app = { settings: dropNulls({ ...appSettings(), ...baseSettings, ...fillSettings(JSON.parse(read(join(c.dir, 'settings.json')) || '{}')) }), nowMs: DEFAULT_NOW, tokenLog: [], authLog: [], issued: 0 };
  const mf = new Miniflare(convertV4MiniflareOptions({
    modules: mods.modules,
    modulesRoot: w2Dir,
    compatibilityDate: '2026-10-01',
    compatibilityFlags: ['enable_request_signal', 'global_fetch_strictly_public'],
    d1Databases: ['DB'],
    queueProducers: { INDEX: 'talon-index', INDEX_DLQ: 'talon-index-dlq' }, // slice 118: no consumer, so a sent message stays in the queue
    d1Persist: join(persist, 'd1'),
    ratelimits: Object.fromEntries(Object.entries({ RL_INGEST: { limit: 60, period: 60 }, RL_HINTS: { limit: 1000, period: 60 }, RL_LOGIN: { limit: 1000, period: 60 }, ...ratelimitsOf(c) }).map(([name, r], i) => [name, { namespace_id: String(1000 + i), simple: { limit: r.limit, period: r.period ?? 60 } }])),
    bindings: app.settings,
    outboundService: fakeGithub(c, github, errs, dbRef, app),
    unsafeTriggerHandlers: true,
    handleStructuredLogs: (l) => { logs.push(l.message ?? JSON.stringify(l)); records.push({ message: l.message ?? '', level: l.level }); },
  }));
  live.add(mf);
  try {
    const db = await mf.getD1Database('DB');
    dbRef.db = db;
    for (const sql of migrations) for (const s of splitSql(sql)) await db.prepare(s.sql).run();
    for (const s of splitSql(read(join(c.dir, 'seed.sql')))) await db.prepare(s.sql).run();
    const counts = [];
    let i = 0;
    for (const spec of specs) {
      if (spec.sql !== undefined) { for (const st of spec.sql) await db.prepare(st).run(); continue; }
      if (spec.wait_ms !== undefined) { await new Promise((r) => setTimeout(r, spec.wait_ms)); continue; }
      if (spec.window_s !== undefined) { const w = spec.window_s * 1000, left = w - (Date.now() % w); if (left < spec.need_ms) await new Promise((r) => setTimeout(r, left + 50)); continue; }
      if (spec.queue !== undefined) {
        counts.push({ calls: NaN, ops: '' });
        checkQueue(i + 1, expected[i], await queueCall(mf, spec, app), errs);
        i++;
        continue;
      }
      const res = await request(mf, spec, c, app);
      counts.push({ calls: Number(res.headers['x-d1-calls'] ?? NaN), ops: res.headers['x-d1-ops'] ?? '' });
      checkResponse(i + 1, expected[i], res, errs);
      i++;
    }
    const want = lines(join(c.dir, 'expect', 'd1-calls'));
    if (want.length) {
      if (want.length !== nreq) errs.push(`expect/d1-calls has ${want.length} lines for ${nreq} requests`);
      want.forEach((w, i) => {
        if (w.trim() !== '-' && counts[i] && Number(w) !== counts[i].calls) errs.push(`d1-calls: request ${i + 1}: expected ${w.trim()}, got ${counts[i].calls} (${counts[i].ops || 'no call'})`);
      });
    }
    for (const blk of parseExpected(read(join(c.dir, 'expect', 'db.tsv')))) {
      const got = tsvOf(await db.prepare(blk.sql).raw());
      if (got.join('\n') !== blk.rows.join('\n')) errs.push(`db: @ ${blk.sql}: rows differ:\n      expected: ${JSON.stringify(blk.rows)}\n      got:      ${JSON.stringify(got)}`);
    }
    for (const [name, got] of [['tokens.log', app.tokenLog], ['auth.log', app.authLog]]) {
      if (!existsSync(join(c.dir, 'expect', name))) continue;
      const want = lines(join(c.dir, 'expect', name));
      if (JSON.stringify(want) !== JSON.stringify(got)) errs.push(`${name} differs:\n      expected: ${JSON.stringify(want)}\n      got:      ${JSON.stringify(got)}`);
    }
    if (existsSync(join(c.dir, 'expect', 'logs.jsonl'))) await checkLogs(lines(join(c.dir, 'expect', 'logs.jsonl')).map((l) => JSON.parse(l)), records, errs);
    const wantGh = lines(join(c.dir, 'expect', 'github.log'));
    if (JSON.stringify(wantGh) !== JSON.stringify(github)) errs.push(`github.log differs:\n      expected: ${JSON.stringify(wantGh)}\n      got:      ${JSON.stringify(github)}`);
  } catch (e) {
    errs.push(`runner fault: ${String(e.stack ?? e).split('\n').slice(0, 4).join(' | ')}`);
  } finally {
    live.delete(mf);
    await mf.dispose().catch(() => {});
    rmSync(persist, { recursive: true, force: true });
  }
  return { errs, logs };
}

const caseLimitMs = (c) => { const t = Number(read(join(c.dir, 'timeout')).trim()); return (t > 0 ? t : Number(process.env.CASE_TIMEOUT ?? 30)) * 1000; };
async function runOne(c) {
  const t0 = performance.now();
  let timer;
  const limitMs = caseLimitMs(c) + Math.max(0, ...lines(join(c.dir, 'requests.jsonl')).map((l) => { try { return (JSON.parse(l).window_s ?? 0) * 1000; } catch { return 0; } }));
  const r = await Promise.race([
    runCase(c),
    new Promise((res) => { timer = setTimeout(() => res({ errs: [`timed out after ${limitMs / 1000} s`], logs: [] }), limitMs); }),
  ]);
  clearTimeout(timer);
  let ok = r.errs.length === 0, why = r.errs;
  if (c.mustFail) {
    const want = lines(join(c.dir, 'expect-fail'));
    const text = r.errs.join('\n');
    const missing = want.filter((w) => !text.includes(w));
    ok = r.errs.length > 0 && missing.length === 0;
    why = r.errs.length === 0 ? ['the case passed, but it must fail'] : missing.map((w) => `the failure has no text "${w}"; it is:\n    ${r.errs.join('\n    ')}`);
  }
  const out = [`${ok ? 'PASS' : 'FAIL'} ${c.name} (${(performance.now() - t0).toFixed(0)} ms)`];
  if (!ok) out.push(...why.map((w) => `    ${w}`), ...r.logs.slice(-5).map((l) => `    worker log: ${l}`));
  else if (process.env.VERBOSE === '1') out.push(...r.logs.map((l) => `    worker log: ${l}`));
  return { ok, text: out.join('\n') };
}

// The cases run at the same time, at most JOBS. The report is in the order of the cases.
const jobs = Math.max(1, Number(process.env.JOBS ?? Math.min(cpus().length, 6)));
const results = new Array(chosen.length);
let next = 0;
await Promise.all(Array.from({ length: Math.min(jobs, chosen.length) }, async () => {
  while (next < chosen.length) {
    const i = next++;
    results[i] = await runOne(chosen[i]);
  }
}));
for (const r of results) console.log(r.text);
const failed = results.filter((r) => !r.ok).length;
console.log(`w2: ${results.length - failed} passed, ${failed} failed`);
process.exit(failed ? 1 : 0);
