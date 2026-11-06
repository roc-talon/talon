// The W2 runner (docs/registry/PLAN.md B, docs/slices/101-worker-skeleton.md): the built Worker (app.wasm) in Miniflare with a local D1,
// a fake GitHub as the outbound service, a D1 call count and a fixed clock.
// Slice 123e: the runner uses the platform test helper (`startApp` of .roc-cfw/test.mjs, platform 0.0.5). It keeps a pool of started apps, one for each set of settings
// (bindings, ratelimits.json, app = archive or not) and each job; `app.reset()` between two cases of one set. The part in the isolate that the helper does not give is
// worker/tests/hooks.js (the timingSafeEqual count, the /__test/ paths, TEST_INDEX_FAIL_SENDS); the config is worker/tests/wrangler-test.toml (no queue consumer).
//   node worker/tests/run.mjs [filter ...]     run the cases whose name has a filter text (the self-test cases too)
// Env: W2_DIR (the dir with app.wasm and .roc-cfw/ with test.mjs, default: worker/), MINIFLARE (the dir of the miniflare package, default: the one of the
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
//                         Miniflare counts each binding locally, for each app; `app.reset()` starts new counters (the counters follow the real wall clock, not the case clock).
//                         A request with no `cf-connecting-ip` header gets 127.0.0.1 from Miniflare.
//                         Slice 117: every case also gets RL_HINTS and RL_LOGIN with a limit that no case reaches (1000 in 60 s), unless ratelimits.json gives RL_LOGIN.
//   settings.json         Slice 117: a value {"$edkey": "t1", "kid": "key-1"} becomes the text of the private JWK of the throwaway Ed25519 key t1 (worker/tests/oidc.mjs): the secret TOKEN_KEY.
//   settings.json         optional. More Worker settings (the `vars` of the Wrangler config), in addition to worker/tests/settings.json.
//   expect/responses.jsonl  one line for each request: {"status":N, "headers":{"name":"exact value" | null}, "d1_session":"arg" | null, "json":{subset}, "body":"exact text",
//                         `d1_session` (slice 123e, was the header x-d1-session): the argument of the last `withSession` of the request (`res.sessions`); null: the request made no `withSession`.
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
//   Slice 118 (queue). Each case has the queue producers INDEX (queue `talon-index`) and INDEX_DLQ (queue `talon-index-dlq`), and no consumer: a message that the Worker sends stays in the queue. startApp records each send (`res.calls`).
//   expect/responses.jsonl "queue_sent":[{"body":{..},"delay_s":N}, ...]: the sends of the request to INDEX, in order (the body compared with the order of the members ignored; `delay_s` 0 is no delay). `[]` checks that there is none.
//   expect/responses.jsonl "timing_safe":N: the count of `crypto.subtle.timingSafeEqual` calls of the request (a constant-time compare of a secret is a call).
//   A line {"queue":"talon-index","now":ms,"messages":[{"id":"m1","attempts":1,"body":{..}}, ...]} (slice 118) is a request: the runner sets the clock, then calls the `queue` handler of the Worker with this batch
//                         (Miniflare `worker.queue()`; no broker, no wait). Its line in expect/responses.jsonl is {"outcome":"ok","acked":["m1"],"retried":[{"id":"m2","delay_s":60}]}: the ids that the handler acked
//                         (`acked`, any order), and the messages that it retried with the delay in whole seconds (`delay_s` null for a retry with no delay). A message in neither list was not answered. Its line in expect/d1-calls is `-`.
//   expect/logs.jsonl     optional (slice 118). One JSON object in each line. Each must be a subset of a different Worker log line (the JSON of the line, with `level`), in any order. The run waits up to 3 s for the lines.
//   Slice 123e: a queue line for a queue whose name starts with `__test` is answered by the runner (ack, or retry with `retry_s`, `{"retry":true}`): the platform has no hook for the `queue` handler. Other queues: the Worker.
//   Slice 119b (the reconcile cron): a cron line can have "copies":N: the runner starts N scheduled runs of the line at the same time (R-PU36) and checks the expected line against each answer.
//                         After the run(s) of a cron line, the runner reads the D1 calls and the queue sends of the run(s) (`app.calls`): expect/d1-calls and "queue_sent" of the line check them
//                         (for "copies", the calls are the sum, and "queue_sent" is compared as a list of any order).
//   github/<file>.meta.json  Slice 119b: a status 304 (or 204) answer has no body. In "require", the value null means that the request must NOT have the header (for example `if-none-match`).
//   settings.json         Slice 119b: TEST_INDEX_FAIL_SENDS ("N") makes the first N sends to the INDEX queue of the case fail (hooks.js rejects them, so startApp records no send).
//   timeout               optional. The seconds for this case, in place of CASE_TIMEOUT (default 30). For a case with a large seed that is slow when many builds run at the same time. A window_s line still adds its P s.
//   expect-fail           self-test cases only (worker/tests/selftest/<name>/). One text in each line. The case must fail, and the failure must have each text.
// The output is one line for each case: `PASS <case>` or `FAIL <case>` and the reasons. Exit 1 on a failure.
import { createRequire } from 'node:module';
import { readFileSync, readdirSync, existsSync, mkdirSync, rmSync, statSync } from 'node:fs';
import { cpus, tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
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
process.env.TMPDIR = runDir; // the temp dirs of Miniflare and of startApp go here too
const live = new Set(); // the started apps (pool entries)
const cleanup = () => rmSync(runDir, { recursive: true, force: true });
process.on('exit', cleanup);
for (const [sig, code] of [['SIGTERM', 143], ['SIGINT', 130]]) {
  process.once(sig, async () => {
    await Promise.all([...live].map((e) => e.app.close().catch(() => {})));
    process.exit(code);
  });
}

const mfDir = process.env.MINIFLARE ?? join(dirname(dirname(process.execPath)), 'lib/node_modules/wrangler/node_modules/miniflare');
try {
  createRequire(import.meta.url)(mfDir);
} catch (e) {
  console.log(`FAIL w2: Miniflare is not at ${mfDir} (install wrangler 4 globally with node 26, or set MINIFLARE): ${e.message.split('\n')[0]}`);
  process.exit(1);
}
const shimDir = join(w2Dir, '.roc-cfw');
for (const f of ['app.wasm', '.roc-cfw/index.js', '.roc-cfw/test.mjs', '.roc-cfw/test-entry.js']) {
  if (!existsSync(join(w2Dir, f))) {
    console.log(`FAIL w2: ${join(w2Dir, f)} is missing: build the Worker first (scripts/test.sh w2 does it; by hand: tln run build in worker/). The test helper needs the platform 0.0.4 or later (0.0.5 for the queue delay)`);
    process.exit(1);
  }
}
const { startApp } = await import(pathToFileURL(join(shimDir, 'test.mjs')).href);
const { manifestOf } = await import(pathToFileURL(join(shimDir, 'runner.js')).href);
const { manifestEvent } = await import(pathToFileURL(join(shimDir, 'events.js')).href);
const { checkManifest } = await import(pathToFileURL(join(shimDir, 'manifest.js')).href);

const read = (p) => (existsSync(p) ? readFileSync(p, 'utf8') : '');
const lines = (p) => read(p).split('\n').filter((l) => l.trim() !== '');
const subdirs = (d) => (existsSync(d) ? readdirSync(d, { withFileTypes: true }).filter((e) => e.isDirectory()).map((e) => e.name).sort() : []);
const DEFAULT_NOW = 1767225600000;

const cases = [];
for (const area of subdirs(join(here, 'cases'))) for (const id of subdirs(join(here, 'cases', area))) cases.push({ name: `${area}/${id}`, dir: join(here, 'cases', area, id), mustFail: false });
for (const id of subdirs(join(here, 'selftest'))) cases.push({ name: `selftest/${id}`, dir: join(here, 'selftest', id), mustFail: true });
const chosen = cases.filter((c) => filters.length === 0 || filters.some((f) => c.name.includes(f)));

const archiveWasm = process.env.W2_ARCHIVE_WASM || join(w2Dir, 'archive-test.wasm');
// The migrations are one `db.batch` of the runner after the start and after each reset(), not the `d1` seeds of startApp (they run one statement at a time: a reset took 120 ms in place of 50 ms, research/slice-123e/reset-probe.mjs).
const migrations = migrationFiles(join(root, 'sql')).flatMap((f) => splitSql(readFileSync(f, 'utf8')).map((s) => s.sql));
const migrate = async (h) => { const db = await h.d1('DB'); await db.batch(migrations.map((s) => db.prepare(s))); };
const baseSettings = JSON.parse(read(join(here, 'settings.json')) || '{}');
// The rate limit bindings of a case (slice 116b): ratelimits.json, else RL_HINTS with a limit that a case does not reach.
const ratelimitsOf = (c) => JSON.parse(read(join(c.dir, 'ratelimits.json')) || '{"RL_HINTS":{"limit":1000,"period":60}}');

// The settings of a case, and the key of the pool (slice 123e): the cases with one key share an app. The key is everything that startApp takes at the start:
// the app (the Worker or the archive test app), the settings (bindings) and the rate limits. Slice 112b and 117: every case also gets RL_INGEST 60 a minute, RL_HINTS and RL_LOGIN with 1000 a minute, unless ratelimits.json gives them.
const configOf = (c) => {
  const archive = read(join(c.dir, 'app')).trim() === 'archive';
  // Slice 119a: the settings of the App, the clock of the current request, the token and auth logs and the count of default tokens (worker/tests/githubapp.mjs).
  const settings = dropNulls({ ...appSettings(), ...baseSettings, ...fillSettings(JSON.parse(read(join(c.dir, 'settings.json')) || '{}')) });
  const ratelimits = Object.fromEntries(Object.entries({ RL_INGEST: { limit: 60, period: 60 }, RL_HINTS: { limit: 1000, period: 60 }, RL_LOGIN: { limit: 1000, period: 60 }, ...ratelimitsOf(c) }).map(([n, r]) => [n, { limit: r.limit, period: r.period ?? 60 }]));
  const windowed = lines(join(c.dir, 'requests.jsonl')).some((l) => { try { return JSON.parse(l).window_s !== undefined; } catch { return false; } });
  return { archive, settings, ratelimits, windowed, key: JSON.stringify([archive, settings, ratelimits]) };
};
for (const c of chosen) c.cfg = configOf(c);

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
    const got = res.sent;
    if (canon(got) !== canon(exp.queue_sent)) put(`queue_sent: expected ${canon(exp.queue_sent)}, got ${canon(got)}`);
  }
  if (exp.d1_session !== undefined && exp.d1_session !== res.session) put(`d1_session: expected ${jstr(exp.d1_session)}, got ${jstr(res.session)}`);
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

// Slice 118: the queue line `__test...` (slice 123e: answered here, the platform has no hook for the queue handler): `{"retry_s":N}` retries with a delay, `{"retry":true}` retries, any other body is acked.
const testQueue = (spec) => {
  const acked = [], retried = [];
  for (const m of spec.messages) {
    if (m.body?.retry_s !== undefined) retried.push({ id: m.id, delay_s: m.body.retry_s });
    else if (m.body?.retry) retried.push({ id: m.id, delay_s: null });
    else acked.push(m.id);
  }
  return { outcome: 'ok', acked, retried };
};

// Slice 118/123e: set the clock, then call the queue handler of the Worker with the batch (no broker).
async function queueCall(h, spec, st) {
  const now = spec.now ?? DEFAULT_NOW;
  st.nowMs = now;
  if (spec.queue.startsWith('__test')) { await setClock(h, now); return testQueue(spec); }
  await h.idle();
  const r = await h.queue(spec.queue, spec.messages.map((m) => ({ id: m.id, timestamp: new Date(now), body: m.body, attempts: m.attempts ?? 1 })), { now });
  clocks.set(h, now);
  return { outcome: r.outcome, acked: r.explicitAcks ?? [], retried: (r.retryMessages ?? []).map((x) => ({ id: x.msgId, delay_s: x.delaySeconds ?? null })) };
}

// The clock that Node set. `h.now` of startApp 0.0.5 is a value, not a getter (Object.assign copies it at the start), so the runner keeps the clock itself (docs/slices/123e-startapp-runner.md section 9).
const clocks = new WeakMap();
const setClock = async (h, ms) => { if ((clocks.get(h) ?? DEFAULT_NOW) !== ms) { await h.setNow(ms); clocks.set(h, ms); } };

// Slice 118: each expected log object is a subset of a different Worker log line. workerd writes a line a little after the answer, so the run waits up to 3 s.
async function checkLogs(wanted, getRecords, errs) {
  const parsed = () => getRecords().map((r) => { try { return { ...JSON.parse(r.message), level: r.level }; } catch { return { msg: r.message, level: r.level }; } });
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
function fakeGithub(c, log, errs, dbRef, app) { // `app` is the state of the case (settings, clock, logs); `h` is the app of startApp
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

// The queue sends of a `calls` group (slice 123e, platform 0.0.5): `send` has the body (`value`, the decoded JSON); `sendBatch` has `bodies`. The delay of each message comes from hooks.js (`delays`, the same order):
// `res.calls` of 0.0.5 has no `delaySeconds` (docs/slices/123e-startapp-runner.md section 9).
const sentOf = (g, delays) => (g?.list ?? []).flatMap((it) => (it.op === 'send' ? [it.body?.value] : it.op === 'sendBatch' ? (it.bodies ?? []).map((b) => b.value) : [])).map((body, k) => ({ body, delay_s: delays[k] ?? 'no delay record' }));
const d1Of = (g) => ({ calls: g?.DB?.n ?? 0, ops: (g?.DB?.ops ?? []).join(',') });

// One request or cron line. Gives { status, headers, body, calls, ops, sent, session } or, for a cron line, { cron: [...] } with the same fields.
async function request(h, spec, c, st) {
  const now = spec.now ?? DEFAULT_NOW;
  st.nowMs = now;
  if (spec.cron !== undefined) {
    // The D1 calls and the queue sends of the run(s): the calls since the line (work after an earlier response must be done first).
    await h.idle();
    await h.calls({ reset: true });
    await (await h.fetch('/__test/delays')).text();
    await setClock(h, now); // Slice 120: the scheduled event does not pass the fetch of the test entry, so set the clock first.
    const time = spec.time ?? DEFAULT_NOW;
    let all;
    if (spec.copies) {
      // Slice 119b: "copies" runs at the same time. They go through `worker.scheduled()` of Miniflare (the outcome with no body, as a queue line): 2 dispatchFetch calls at once can share one body (a runner fault seen under load).
      const w = await h.mf.getWorker();
      const outs = await Promise.all(Array.from({ length: spec.copies }, () => w.scheduled({ cron: spec.cron, scheduledTime: new Date(time) })));
      all = outs.map((o) => ({ status: o.outcome === 'ok' ? 200 : 500, headers: {}, body: JSON.stringify({ outcome: o.outcome, noRetry: o.noRetry }) }));
    } else {
      const q = new URLSearchParams({ cron: spec.cron, time: String(time), format: 'json' });
      const r = await h.mf.dispatchFetch(`http://localhost/cdn-cgi/local/scheduled?${q}`);
      const headers = {};
      r.headers.forEach((v, k) => { headers[k] = v; });
      all = [{ status: r.status, headers, body: await r.text() }];
    }
    await h.idle();
    const g = await h.calls({ reset: true });
    const delays = (await (await h.fetch('/__test/delays')).json()).delays;
    for (const one of all) Object.assign(one, d1Of(g), { sent: sentOf(g.INDEX, delays) });
    return { cron: all };
  }
  if (spec.path.split('?')[0] === '/__test/now') {
    // The clock of the Worker (slice 123e): read from the isolate by the control path of the test entry, as `app.now` is only the value that Node set.
    await setClock(h, now);
    const r = await h.mf.dispatchFetch(`http://localhost/__cfw_test/${h.token}/now`);
    return { status: 200, headers: { 'content-type': 'application/json' }, body: JSON.stringify({ now: (await r.json()).now }), calls: 0, ops: '', sent: [], session: null };
  }
  const headers = { ...(spec.headers ?? {}) };
  if (spec.token !== undefined) headers.authorization = `Bearer ${await token(c.dir, spec.token)}`;
  // The body is bytes, so fetch adds no Content-Type of its own (a text body would get text/plain).
  let body = spec.body === undefined ? undefined : Buffer.from(spec.body);
  // Slice 118: {"body_pad":{"prefix":"..","fill":"a","suffix":"..","total":N}} is a body of exactly N bytes (prefix, the fill repeated, suffix), so a case needs no file of 1 MiB.
  if (spec.body_pad !== undefined) { const b = spec.body_pad; body = Buffer.from(b.prefix + (b.fill ?? 'a').repeat(b.total - b.prefix.length - (b.suffix ?? '').length) + (b.suffix ?? '')); }
  if (spec.json !== undefined) {
    body = Buffer.from(JSON.stringify(spec.json));
    if (!Object.keys(headers).some((h) => h.toLowerCase() === 'content-type')) headers['content-type'] = 'application/json';
  }
  await setClock(h, now);
  // startApp: cache 'force-cache' (Node fetch adds no-cache and Pragma to a request with If-None-Match, and a Worker that follows the cache rule then skips its cache) and redirect 'manual' are its defaults.
  const res = await h.fetch(spec.path, { method: spec.method ?? 'GET', headers, body });
  const out = {};
  res.headers.forEach((v, k) => { out[k] = v; });
  return { status: res.status, headers: out, body: await res.text(), ...d1Of(res.calls), sent: sentOf(res.calls.INDEX, JSON.parse(out['x-queue-delays'] ?? '[]')), session: res.sessions?.DB?.at(-1) ?? null };
}

// Start the app of a pool key. The ratelimits that the app does not declare are dropped (the archive test app has none).
async function startEntry(cfg) {
  const wasm = cfg.archive ? archiveWasm : join(w2Dir, 'app.wasm');
  const declared = new Set(checkManifest(manifestOf(new WebAssembly.Module(readFileSync(wasm)), manifestEvent())).bindings.map((b) => b.name));
  const ref = { fn: async (req) => new Response(`no case runs: ${req.url}`, { status: 599 }) };
  const app = await startApp({
    dir: here,
    shim: shimDir,
    wasm,
    config: join(here, 'wrangler-test.toml'),
    hooks: 'hooks.js',
    now: DEFAULT_NOW,
    count: ['DB', 'INDEX'],
    bindings: cfg.settings,
    ratelimits: Object.fromEntries(Object.entries(cfg.ratelimits).filter(([n]) => declared.has(n))),
    outbound: (req) => ref.fn(req),
    miniflare: mfDir,
  });
  const entry = { key: cfg.key, app, ref, used: false, broken: false, hasDb: declared.has('DB') };
  live.add(entry);
  try {
    if (entry.hasDb) await migrate(app);
  } catch (e) {
    await closeEntry(entry);
    throw e;
  }
  return entry;
}
async function closeEntry(entry) {
  live.delete(entry);
  await entry.app.close().catch(() => {});
}

// Run one case on an app of its key. Gives the list of failure texts and the Worker log lines.
async function runCase(c, entry) {
  const errs = [];
  const github = [];
  const h = entry.app;
  const specs = lines(join(c.dir, 'requests.jsonl')).map((l) => JSON.parse(l));
  const expected = lines(join(c.dir, 'expect', 'responses.jsonl')).map((l) => JSON.parse(l));
  if (specs.length === 0) return { errs: ['requests.jsonl has no request'], logs: [] };
  const nreq0 = specs.filter((s) => s.sql === undefined && s.wait_ms === undefined && s.window_s === undefined).length;
  if (expected.length !== nreq0) return { errs: [`expect/responses.jsonl has ${expected.length} lines for ${nreq0} requests`], logs: [] };
  const logLines = () => h.logs.map((l) => l.message ?? JSON.stringify(l));
  const records = () => h.logs.map((l) => ({ message: l.message ?? '', level: l.level }));
  const dbRef = { db: await h.d1('DB').catch(() => undefined) };
  // The state of the case: the settings, the clock of the current request, the token and auth logs and the count of default tokens.
  const st = { settings: c.cfg.settings, nowMs: DEFAULT_NOW, tokenLog: [], authLog: [], issued: 0 };
  entry.ref.fn = fakeGithub(c, github, errs, dbRef, st);
  try {
    const db = dbRef.db;
    for (const s of splitSql(read(join(c.dir, 'seed.sql')))) await db.prepare(s.sql).run();
    const counts = [];
    let i = 0;
    const nreq = nreq0;
    for (const spec of specs) {
      if (spec.sql !== undefined) { for (const stmt of spec.sql) await db.prepare(stmt).run(); continue; }
      if (spec.wait_ms !== undefined) { await new Promise((r) => setTimeout(r, spec.wait_ms)); continue; }
      if (spec.window_s !== undefined) { const w = spec.window_s * 1000, left = w - (Date.now() % w); if (left < spec.need_ms) await new Promise((r) => setTimeout(r, left + 50)); continue; }
      if (spec.queue !== undefined) {
        counts.push({ calls: NaN, ops: '' });
        checkQueue(i + 1, expected[i], await queueCall(h, spec, st), errs);
        i++;
        continue;
      }
      const res = await request(h, spec, c, st);
      if (res.cron !== undefined) {
        // Slice 119b: each run of a cron line has the expected answer; the D1 calls and the sends are those of all the runs of the line.
        const first = res.cron[0];
        counts.push({ calls: first.calls, ops: first.ops });
        const exp = res.cron.length > 1 && expected[i].queue_sent !== undefined ? { ...expected[i], queue_sent: undefined } : expected[i];
        for (const one of res.cron) checkResponse(i + 1, exp, one, errs);
        if (exp !== expected[i]) {
          const sorted = (a) => a.map(canon).sort();
          if (JSON.stringify(sorted(first.sent)) !== JSON.stringify(sorted(expected[i].queue_sent))) errs.push(`request ${i + 1}: queue_sent (any order): expected ${canon(expected[i].queue_sent)}, got ${canon(first.sent)}`);
        }
        i++;
        continue;
      }
      counts.push({ calls: res.calls, ops: res.ops });
      checkResponse(i + 1, expected[i], res, errs);
      i++;
    }
    const want = lines(join(c.dir, 'expect', 'd1-calls'));
    if (want.length) {
      if (want.length !== nreq) errs.push(`expect/d1-calls has ${want.length} lines for ${nreq} requests`);
      want.forEach((w, k) => {
        if (w.trim() !== '-' && counts[k] && Number(w) !== counts[k].calls) errs.push(`d1-calls: request ${k + 1}: expected ${w.trim()}, got ${counts[k].calls} (${counts[k].ops || 'no call'})`);
      });
    }
    for (const blk of parseExpected(read(join(c.dir, 'expect', 'db.tsv')))) {
      const got = tsvOf(await db.prepare(blk.sql).raw());
      if (got.join('\n') !== blk.rows.join('\n')) errs.push(`db: @ ${blk.sql}: rows differ:\n      expected: ${JSON.stringify(blk.rows)}\n      got:      ${JSON.stringify(got)}`);
    }
    for (const [name, got] of [['tokens.log', st.tokenLog], ['auth.log', st.authLog]]) {
      if (!existsSync(join(c.dir, 'expect', name))) continue;
      const wantLog = lines(join(c.dir, 'expect', name));
      if (JSON.stringify(wantLog) !== JSON.stringify(got)) errs.push(`${name} differs:\n      expected: ${JSON.stringify(wantLog)}\n      got:      ${JSON.stringify(got)}`);
    }
    if (existsSync(join(c.dir, 'expect', 'logs.jsonl'))) await checkLogs(lines(join(c.dir, 'expect', 'logs.jsonl')).map((l) => JSON.parse(l)), records, errs);
    const wantGh = lines(join(c.dir, 'expect', 'github.log'));
    if (JSON.stringify(wantGh) !== JSON.stringify(github)) errs.push(`github.log differs:\n      expected: ${JSON.stringify(wantGh)}\n      got:      ${JSON.stringify(github)}`);
  } catch (e) {
    errs.push(`runner fault: ${String(e.stack ?? e).split('\n').slice(0, 4).join(' | ')}`);
    entry.broken = true;
  }
  return { errs, logs: logLines() };
}

// Make the app of the pool ready for a case: a new case on a used app starts with reset() (D1 with the migrations, the clock, the pins, the counters of the rate limits, the logs).
async function prepare(entry, c) {
  const h = entry.app;
  if (entry.used) {
    await h.reset();
    if (entry.hasDb) await migrate(h);
    if ('TEST_INDEX_FAIL_SENDS' in c.cfg.settings) await (await h.fetch('/__test/arm')).text(); // a module global of hooks.js: reset() does not clear it
  }
  entry.used = true;
  clocks.set(h, DEFAULT_NOW); // start and reset() give the clock of the option `now`
  h.logs.length = 0;
}

const caseLimitMs = (c) => { const t = Number(read(join(c.dir, 'timeout')).trim()); return (t > 0 ? t : Number(process.env.CASE_TIMEOUT ?? 30)) * 1000; };
async function runOne(c, entry) {
  const t0 = performance.now();
  let timer;
  const limitMs = caseLimitMs(c) + Math.max(0, ...lines(join(c.dir, 'requests.jsonl')).map((l) => { try { return (JSON.parse(l).window_s ?? 0) * 1000; } catch { return 0; } }));
  const r = await Promise.race([
    runCase(c, entry),
    new Promise((res) => { timer = setTimeout(() => { entry.broken = true; res({ errs: [`timed out after ${limitMs / 1000} s`], logs: [] }); }, limitMs); }),
  ]);
  clearTimeout(timer);
  return finish(c, r, t0);
}
function finish(c, r, t0) {
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

// The cases run at the same time, at most JOBS; each job keeps one started app and runs the cases of its key one after the other. The report is in the order of the cases.
// The queue: the cases with a wait for a rate limit window first (they are the longest), then the cases by key. A job takes the next case of its own key when there is one.
const jobs = Math.max(1, Number(process.env.JOBS ?? Math.min(cpus().length, 6)));
const results = new Array(chosen.length);
const byKey = new Map();
for (const c of chosen) { if (!byKey.has(c.cfg.key)) byKey.set(c.cfg.key, []); byKey.get(c.cfg.key).push(c); }
const pending = [...chosen.filter((c) => c.cfg.windowed), ...[...byKey.values()].flat().filter((c) => !c.cfg.windowed)];
const stats = { starts: 0, resets: 0, startMs: 0, resetMs: 0, runMs: 0 };
const timed = async (field, f) => { const t = performance.now(); try { return await f(); } finally { stats[field] += performance.now() - t; } };
const holding = new Map(); // key -> the jobs that hold an app of the key
// The next case of a job: one of its own key; else the first case with a wait for a window; else a case of the key that the fewest jobs hold (the most cases left on a tie), so two jobs do not start the same key while another key waits.
const nextCase = (entry) => {
  const own = entry ? pending.findIndex((c) => c.cfg.key === entry.key) : -1;
  if (own !== -1) return pending.splice(own, 1)[0];
  const w = pending.findIndex((c) => c.cfg.windowed);
  if (w !== -1) return pending.splice(w, 1)[0];
  const left = new Map();
  for (const c of pending) left.set(c.cfg.key, (left.get(c.cfg.key) ?? 0) + 1);
  const best = [...left.keys()].sort((a, b) => (holding.get(a) ?? 0) - (holding.get(b) ?? 0) || left.get(b) - left.get(a))[0];
  return pending.splice(pending.findIndex((c) => c.cfg.key === best), 1)[0];
};
await Promise.all(Array.from({ length: Math.min(jobs, chosen.length) }, async () => {
  let entry = null;
  while (pending.length) {
    const c = nextCase(entry);
    const i = chosen.indexOf(c);
    const t0 = performance.now();
    try {
      if (c.cfg.archive && !existsSync(archiveWasm)) {
        results[i] = finish(c, { errs: [`the test app ${archiveWasm} is missing: the build of worker/archive-test.roc failed or did not run (scripts/test.sh w2 builds it; its log is $WORK/logs/worker-archive-build.*.log)`], logs: [] }, t0);
        continue;
      }
      if (entry && entry.key !== c.cfg.key) { holding.set(entry.key, holding.get(entry.key) - 1); await closeEntry(entry); entry = null; }
      if (!entry) { holding.set(c.cfg.key, (holding.get(c.cfg.key) ?? 0) + 1); entry = await timed('startMs', () => startEntry(c.cfg)); stats.starts++; }
      if (entry.used) stats.resets++;
      try {
        await timed('resetMs', () => prepare(entry, c));
      } catch (e) {
        // reset() failed (tasks still run, 409): the app is not clean. Start a new one.
        await closeEntry(entry);
        entry = await startEntry(c.cfg);
        stats.starts++;
        await prepare(entry, c);
      }
      results[i] = await timed('runMs', () => runOne(c, entry));
      if (entry.broken || !results[i].ok) { holding.set(entry.key, holding.get(entry.key) - 1); await closeEntry(entry); entry = null; } // after a timeout, a fault or a failed case, the next case gets a new app
    } catch (e) {
      results[i] = finish(c, { errs: [`runner fault: ${String(e.stack ?? e).split('\n').slice(0, 4).join(' | ')}`], logs: [] }, t0);
      if (entry) { holding.set(entry.key, holding.get(entry.key) - 1); await closeEntry(entry); entry = null; }
    }
  }
  if (entry) await closeEntry(entry);
}));
for (const r of results) console.log(r.text);
const failed = results.filter((r) => !r.ok).length;
console.log(`w2 pool: ${stats.starts} apps started, ${stats.resets} resets, ${results.length} cases; time of the jobs added: start ${(stats.startMs / 1000).toFixed(0)} s, reset ${(stats.resetMs / 1000).toFixed(0)} s, cases ${(stats.runMs / 1000).toFixed(0)} s`);
console.log(`w2: ${results.length - failed} passed, ${failed} failed`);
process.exit(failed ? 1 : 0);
