// Makes the W2 cases of slice 117 (login, the JWT, the tracker, delete) in worker/tests/cases/account/. Run: node gen_117.mjs
// No Roc code and no id from the Worker: node crypto only. The expected rows and answers come from the independent model below (R-CT7 to R-CT10, R-RE16 to R-RE18, R-RE25).
// The Ed25519 test keys are made by the runner at the start of each run (worker/tests/oidc.mjs): no private key is in the repository.
import { createHmac } from 'node:crypto';
import { N, H, dataset, writeCase, tsv, JSON_CT } from './lib.mjs';

const KEY = 'test-contributor-key';
const AUD = 'https://registry.example';
const D = 1767225600000; // 2026-01-01T00:00:00Z, the default clock of the runner
const TTL = 2592000; // 30 days in seconds
const SETTINGS = { AUDIENCE: AUD, TOKEN_KEY: { $edkey: 't1', kid: 'key-1' }, CONTRIBUTOR_KEY: KEY };
const M = { m1: '0123456789abcdef0123456789abcdef', m2: 'fedcba9876543210fedcba9876543210', m3: '00000000000000000000000000000000', m4: 'ffffffffffffffffffffffffffffffff', m5: '11112222333344445555666677778888' };
const cid = (m) => BigInt.asIntN(64, createHmac('sha256', KEY).update(m, 'utf8').digest().readBigUInt64BE(0) | (1n << 63n));
const TV = 17180000255n; // talon_version 0.4.1 (R-IK5)
const R = { pass: 0, fail: 1, hang: 2, crash: 3 };
const ANY = 0;
const X64 = 8;
const WASM = 34;
const NOSTORE = { 'cache-control': 'no-store' };
const JSON_ANS = { 'content-type': 'application/json', 'cache-control': 'no-store' };

// ---- requests and answers ----
const post = (body, o = {}) => ({ method: 'POST', path: '/v1/tokens', headers: { ...JSON_CT, ...(o.machine ? { 'talon-contributor': o.machine } : {}), ...(o.headers ?? {}) }, body: typeof body === 'string' ? body : JSON.stringify(body), now: o.now ?? D });
const login = (token, o = {}) => post({ github_token: token }, o);
const get = (path, o = {}) => ({ method: 'GET', path, headers: o.headers ?? {}, ...(o.token === undefined ? {} : { token: o.token }), now: o.now ?? D });
const del = (path, o = {}) => ({ method: 'DELETE', path, headers: { ...(o.machine ? { 'talon-contributor': o.machine } : {}), ...(o.headers ?? {}) }, ...(o.token === undefined ? {} : { token: o.token }), now: o.now ?? D });
const me = '/v1/contributors/me';
const prob = (status, type, detail, more = {}) => ({ status, problem: { type, ...(detail === undefined ? {} : { detail }), ...more } });
const unauth = (detail) => prob(401, '/errors/unauthenticated', detail);
const ok201 = (id, login_, now) => ({
  status: 201, headers: JSON_ANS, json: { account: { id, login: login_ }, expires_at: now + TTL * 1000 },
  jwt: { at: 'token', key: 't1', header: { alg: 'EdDSA', kid: 'key-1', typ: 'JWT' }, claims: { iss: AUD, aud: AUD, sub: String(id), iat: now / 1000, exp: now / 1000 + TTL } },
});
const no204 = { status: 204, headers: NOSTORE, body: '' };
// The fake GitHub: GET https://api.github.com/user. `files` gets the route file and its meta.
const USER_FILE = 'github/api.github.com/user';
const userFile = (n, id, login_, status = 200, requireToken) => {
  const suffix = n === 1 ? '' : `.${n}`;
  const f = {};
  f[`${USER_FILE}${suffix}`] = JSON.stringify(status === 200 && id !== undefined ? { id, login: login_, node_id: 'x', type: 'User' } : { message: 'x' }) + '\n';
  if (status !== 200 || requireToken) f[`${USER_FILE}${suffix}.meta.json`] = JSON.stringify({ ...(status !== 200 ? { status } : {}), ...(requireToken ? { require: { authorization: `Bearer ${requireToken}`, accept: 'application/vnd.github+json', 'user-agent': 'talon-registry' } } : {}) }) + '\n';
  return f;
};
const GH = 'GET https://api.github.com/user';
// The specs of tokens.json: an account token of the Worker (R-CT9). `iat` in seconds (a fraction is allowed).
const spec = (sub, iat, o = {}) => ({ base: 'account', alg: 'EdDSA', claims: { sub: String(sub), iat, exp: o.exp ?? iat + TTL, ...(o.claims ?? {}) }, ...(o.top ?? {}) });

// ---- the dataset ----
const seedBase = () => dataset();
const pairs = {
  a: { h: 'PA', n: 'n1', t: ANY }, b: { h: 'PB', n: 'n1', t: ANY }, c: { h: 'PC', n: 'n1', t: ANY }, p: { h: 'PP', n: 'n1', t: X64 }, x: { h: 'PX', n: 'n2', t: ANY }, a2: { h: 'PA', n: 'n2', t: ANY }, b2: { h: 'PB', n: 'n2', t: WASM },
};
const pk = (p) => `${H[p.h].id}|${N[p.n].id}|${p.t}`;
const hashHex = (p) => H[p.h].byte.toString(16).padStart(2, '0').toUpperCase();
const contribSql = (who, p, result, time) => `INSERT INTO contributions (contributor, artifact, nightly, target, result, talon_version, time) VALUES (${who}, ${H[p.h].id}, ${N[p.n].id}, ${p.t}, ${R[result]}, ${TV}, ${time});`;
const compatSql = (p, source, result, time) => `INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index) VALUES (${H[p.h].id}, ${N[p.n].id}, ${p.t}, ${source}, ${R[result]}, NULL, ${time}, ${source === 1 ? 5 : 'NULL'});`;
const totalsSql = (who, t) => `INSERT INTO contributor_totals (contributor, counted, first, agreed, disagreed, unconfirmed, first_time, last_time) VALUES (${who}, ${t.join(', ')});`;
const contributorSql = (id, login_, after, first, last) => `INSERT INTO contributors (contributor, login, tokens_after, first_time, last_time) VALUES (${id}, '${login_}', ${after}, ${first}, ${last});`;
const linkSql = (machine, account, time) => `INSERT INTO links (machine, contributor, time) VALUES (${machine}, ${account}, ${time});`;

// The queries of db.tsv. 64-bit ids are read as text (the runner reads numbers as JS numbers).
const Q_CONTRIB = 'SELECT hex(substr(n.value, 1, 1)) AS h, CAST(c.contributor AS TEXT) AS contributor, c.nightly, c.target, c.result, c.time FROM contributions c JOIN names n ON n.id = c.artifact ORDER BY n.value, c.nightly, c.target, c.contributor';
const Q_TOTALS = 'SELECT CAST(contributor AS TEXT), counted, first, agreed, disagreed, unconfirmed, first_time, last_time FROM contributor_totals ORDER BY contributor';
const Q_ACCOUNTS = 'SELECT contributor, login, tokens_after, first_time, last_time FROM contributors ORDER BY contributor';
const Q_LINKS = 'SELECT CAST(machine AS TEXT), contributor, time FROM links ORDER BY machine';
const Q_HINTS = 'SELECT hex(substr(n.value, 1, 1)) AS h, x.nightly, x.target, CAST(x.talon_version AS TEXT), x.pass_count, x.fail_count, x.crash_count, x.first_time, x.last_time FROM compat_hints x JOIN names n ON n.id = x.artifact ORDER BY n.value, x.nightly, x.target, x.talon_version';

// The model of the rows (a list of contributions) and of the hints that the seed triggers write.
const byPair = (a, b) => (a.h < b.h ? -1 : a.h > b.h ? 1 : a.n - b.n || a.t - b.t || (a.who < b.who ? -1 : a.who > b.who ? 1 : 0));
const contribRows = (list) => [...list].sort(byPair).map((c) => [c.h, c.who.toString(), c.n, c.t, c.result, c.time]);
const rowOf = (who, p, result, time) => ({ who: BigInt(who), h: hashHex(p), n: N[p.n].id, t: p.t, result: R[result], time, pk: pk(p) });
function hintRows(list) {
  const m = new Map();
  for (const c of list) {
    const k = `${c.h}|${c.n}|${c.t}`;
    const v = m.get(k) ?? { h: c.h, n: c.n, t: c.t, pass: 0, fail: 0, crash: 0, first: c.time, last: c.time };
    if (c.result === 0) v.pass++; else if (c.result === 1) v.fail++; else v.crash++;
    v.first = Math.min(v.first, c.time); v.last = Math.max(v.last, c.time);
    m.set(k, v);
  }
  return [...m.values()].sort((a, b) => (a.h < b.h ? -1 : a.h > b.h ? 1 : a.n - b.n || a.t - b.t)).map((v) => [v.h, v.n, v.t, TV.toString(), v.pass, v.fail, v.crash, v.first, v.last]);
}

const RULES = (...xs) => xs;

// =====================================================================================================================================================================
// A. account/ct8-login: POST /v1/tokens. The GitHub read, the upsert, the link, the move of the rows of a machine, the totals. 4 logins.
{
  const B = 1767225000000;
  const c1 = [rowOf(cid(M.m1), pairs.a, 'pass', B + 100), rowOf(cid(M.m1), pairs.b, 'fail', B + 110), rowOf(cid(M.m1), pairs.c, 'pass', B + 120)];
  const c2 = [rowOf(cid(M.m2), pairs.a, 'fail', B + 105), rowOf(cid(M.m2), pairs.x, 'pass', B + 130)];
  const seed = [...seedBase(), ...[...c1, ...c2].map((c) => contribSql(c.who, { h: Object.keys(H).find((k) => hashHex({ h: k }) === c.h), n: Object.keys(N).find((k) => N[k].id === c.n), t: c.t }, Object.keys(R).find((k) => R[k] === c.result), c.time)),
    // the account 4242 has totals of its own (a trim). m1 merges first, then m2. last_time: account 300, m1 500 (the larger comes in), m2 400 (the smaller comes in, 500 stays), so the result 500 differs from "keep", "incoming" and "smaller". first_time: account 090, m1 070, m2 050
    totalsSql(4242, [1, 0, 0, 0, 1, 1767224000090, 1767224000300]),
    totalsSql(cid(M.m1), [3, 1, 0, 0, 3, 1767224000070, 1767224000500]), totalsSql(cid(M.m2), [5, 2, 1, 1, 3, 1767224000050, 1767224000400])];
  const T = (i) => D + i * 1000;
  // after: the rows of m1 are the account's; the row (PA, n1, any) of m2 is a pair that the account has (m1's stays); PX moves
  const after = [...c1.map((c) => ({ ...c, who: 4242n })), { ...c2[1], who: 4242n }];
  const hints = hintRows([...c1, ...c2]);
  writeCase({
    name: 'ct8-login', rules: RULES('R-AP37', 'R-AP41', 'R-AP50', 'R-CT3', 'R-CT8', 'R-CT9', 'R-RE17', 'R-RE18', 'R-RE25', 'R-CT7', 'R-CT16', 'R-AP21', 'R-AP48'),
    settings: SETTINGS, seed,
    requests: [
      login('ghu_alpha', { machine: M.m1, now: T(1) }),
      login('ghu_beta', { machine: M.m2, now: T(2) }),
      login('ghu_gamma', { now: T(3) }),
      login('ghu_delta', { machine: M.m1, now: T(4) }),
    ],
    responses: [ok201(4242, 'someone', T(1)), ok201(4242, 'renamed', T(2)), ok201(77, 'other', T(3)), ok201(99, 'ninety', T(4))],
    d1: [1, 1, 1, 1], github: [GH, GH, GH, GH],
    files: {
      ...userFile(1, 4242, 'someone', 200, 'ghu_alpha'), ...userFile(2, 4242, 'renamed', 200, 'ghu_beta'), ...userFile(3, 77, 'other', 200, 'ghu_gamma'), ...userFile(4, 99, 'ninety', 200, 'ghu_delta'),
    },
    db: tsv([
      [Q_ACCOUNTS, [[77, 'other', T(3), T(3), T(3)], [99, 'ninety', T(4), T(4), T(4)], [4242, 'renamed', T(1), T(1), T(2)]]],
      [Q_LINKS, [[cid(M.m1), 99, T(4)], [cid(M.m2), 4242, T(2)]].sort((a, b) => (a[0] < b[0] ? -1 : 1)).map((r) => [r[0].toString(), r[1], r[2]])],
      [Q_CONTRIB, contribRows(after)],
      [Q_TOTALS, [['4242', 9, 3, 1, 1, 7, 1767224000050, 1767224000500]]],
      [Q_HINTS, hints],
    ]),
  });
}

// =====================================================================================================================================================================
// B. account/ct8-login-refusals: every refusal of POST /v1/tokens, with the D1 calls and the GitHub reads. Nothing is written by a refusal.
{
  const big = ' '.repeat(262145);
  writeCase({
    name: 'ct8-login-refusals', rules: RULES('R-AP37', 'R-AP46', 'R-AP48', 'R-AP51', 'R-AP23', 'R-CT1', 'R-CT8', 'R-CT16', 'R-AP21', 'R-AP41'),
    settings: SETTINGS,
    requests: [
      { method: 'POST', path: '/v1/tokens', headers: { 'content-type': 'text/plain' }, body: '{"github_token":"ghu_x"}', now: D },
      { method: 'POST', path: '/v1/tokens', headers: { ...JSON_CT }, body: big, now: D },
      login('ghu_x', { machine: 'NOT-AN-ID' }),
      post('this is not json', { machine: 'NOT-AN-ID' }),
      { method: 'POST', path: '/v1/tokens', headers: {}, now: D },
      post('{}'),
      post({ github_token: 'ghu x' }),
      login('ghu_bad'),
      login('ghu_down'),
      login('ghu_odd'),
      login('ghu_good'),
    ],
    responses: [
      prob(415, '/errors/unsupported-media-type'),
      prob(413, '/errors/too-large', 'the body of the login request is larger than its limit of 262144', { field: 'body', limit: 262144 }),
      prob(400, '/errors/bad-request', 'the header Talon-Contributor must be 32 characters, each one of 0 to 9 and a to f'),
      prob(400, '/errors/bad-request', 'the header Talon-Contributor must be 32 characters, each one of 0 to 9 and a to f'),
      prob(400, '/errors/bad-request'),
      prob(400, '/errors/bad-request', 'the login request body is not valid: github_token is missing'),
      prob(400, '/errors/bad-request', 'the login request body is not valid: github_token has a byte that is not allowed in a token'),
      unauth('GitHub refused the token'),
      prob(502, '/errors/upstream', 'the GitHub user read failed with status 500'),
      prob(502, '/errors/upstream', 'the GitHub user read gave an answer that is not a user'),
      ok201(77, 'other', D),
    ],
    d1: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1], github: [GH, GH, GH, GH],
    files: { ...userFile(1, undefined, undefined, 401, 'ghu_bad'), ...userFile(2, undefined, undefined, 500, 'ghu_down'), ...(() => { const f = {}; f[`${USER_FILE}.3`] = '{"login":"x"}\n'; f[`${USER_FILE}.3.meta.json`] = JSON.stringify({ require: { authorization: 'Bearer ghu_odd' } }) + '\n'; return f; })(), ...userFile(4, 77, 'other', 200, 'ghu_good') },
    db: tsv([[Q_ACCOUNTS, [[77, 'other', D, D, D]]], [Q_LINKS, []], [Q_CONTRIB, []], [Q_TOTALS, []]]),
  });
}

// =====================================================================================================================================================================
// C. account/ct9-token-check: GET /v1/contributors/me with each kind of bad token, and the edges of the good ones. A bad signature or bad claims is 0 D1 calls.
{
  const NOW = D + 1_000_000; // 1767226600 s
  const NOWS = NOW / 1000;
  const LEEWAY = 60_000; // R-CT9, Q301: the leeway of exp and iat is 60 s, as R-TP3 row 3
  const AFTER = D + 500; // tokens_after of 4242
  const good = 1767225600.5;
  const specs = {
    good: spec(4242, good), old: spec(4242, 1767225600.499), exp_edge: spec(4242, good, { exp: (NOW - LEEWAY) / 1000 }), exp_ok: spec(4242, good, { exp: (NOW - LEEWAY + 1) / 1000 }), future: spec(4242, (NOW + LEEWAY + 1) / 1000), iat_now: spec(4242, NOWS), iat_edge: spec(4242, (NOW + LEEWAY) / 1000),
    rs256: spec(4242, good, { top: { alg: 'RS256', kid: 'key-1' } }), none: spec(4242, good, { top: { alg: 'none', kid: 'key-1' } }), kid2: spec(4242, good, { top: { kid: 'key-2' } }),
    tamper_sig: spec(4242, good, { top: { tamper: 'signature' } }), tamper_payload: spec(4242, good, { top: { tamper: 'payload' } }), other_key: spec(4242, good, { top: { key: 't2' } }),
    iss: spec(4242, good, { claims: { iss: 'https://other.example' } }), aud: spec(4242, good, { claims: { aud: 'https://other.example' } }),
    sub_abc: spec('abc', good), sub_0: spec('0', good), sub_neg: spec('-5', good), sub_plus: spec('+7', good), sub_frac: spec('12.5', good), sub_empty: spec('', good), sub_77: spec(77, good), garbage: { raw: 'garbage' },
  };
  const seed = [...seedBase(), contributorSql(4242, 'someone', AFTER, D - 5000, D - 5000), linkSql(cid(M.m1), 4242, D - 5000)];
  const sig = [];
  const tr = (token, response, calls, o = {}) => sig.push({ req: get(me, { token, now: NOW, ...o }), res: response, calls });
  const zeros = { status: 200, headers: { ...JSON_ANS, etag: null }, json: { account: { id: 4242, login: 'someone' }, machines: 1, counted: 0, first: 0, agreed: 0, disagreed: 0, unconfirmed: 0, first_time: null, last_time: null } };
  sig.push({ req: get(me, { now: NOW }), res: unauth('the request has no Authorization header: this route needs a registry token'), calls: 0 });
  sig.push({ req: get(me, { now: NOW, headers: { authorization: 'Basic abc' } }), res: unauth('the Authorization header must be "Bearer <token>"'), calls: 0 });
  tr('garbage', unauth('the token is not a valid JWT'), 0);
  tr('rs256', unauth('the token alg is "RS256", expected "EdDSA"'), 0);
  tr('none', unauth('the token alg is "none", expected "EdDSA"'), 0);
  tr('kid2', unauth('the token kid "key-2" is not the key of this registry'), 0);
  tr('tamper_sig', unauth('the token signature is not valid'), 0);
  tr('tamper_payload', unauth('the token signature is not valid'), 0);
  tr('other_key', unauth('the token signature is not valid'), 0);
  tr('iss', unauth('token claim iss is "https://other.example", expected "https://registry.example"'), 0);
  tr('aud', unauth('token claim aud is "https://other.example", expected "https://registry.example"'), 0);
  tr('exp_edge', unauth(`token claim exp is ${NOWS - 60}: the token expired (now is ${NOWS}, leeway 60 s)`), 0); // exp = clock - 60 s
  tr('future', unauth(`token claim iat is ${NOWS + 60}: the token is issued in the future (now is ${NOWS}, leeway 60 s)`), 0); // iat = clock + 60.001 s
  for (const [k, v] of [['sub_abc', 'abc'], ['sub_0', '0'], ['sub_neg', '-5'], ['sub_plus', '+7'], ['sub_frac', '12.5'], ['sub_empty', '']]) tr(k, unauth(`token claim sub is "${v}", expected a GitHub user id`), 0);
  tr('sub_77', unauth('the account of the token has no data in this registry: log in again'), 1);
  tr('old', unauth('the token was issued before the last revoke of the tokens of its account: log in again'), 1);
  tr('good', zeros, 1);
  tr('exp_ok', zeros, 1);
  tr('iat_now', zeros, 1);
  tr('iat_edge', zeros, 1); // iat = clock + 60 s: good
  sig.push({ req: get(me, { token: 'good', now: NOW, headers: { 'talon-contributor': M.m2 } }), res: zeros, calls: 1 });
  writeCase({
    name: 'ct9-token-check', rules: RULES('R-AP35', 'R-AP41', 'R-AP48', 'R-CT9', 'R-CT16', 'R-RE17', 'R-AP21', 'R-AP50'),
    settings: SETTINGS, seed, tokenSpecs: specs,
    requests: sig.map((s) => s.req), responses: sig.map((s) => s.res), d1: sig.map((s) => s.calls), github: [],
  });
}

// =====================================================================================================================================================================
// D. account/ct9-tokens-after: the revoke by DELETE /v1/tokens, the same-ms login, tokens_after that no login changes, and a deleted account that is made again.
{
  const t0 = D + 10_000, t1 = D + 15_000, t2 = D + 35_000, t3 = D + 36_000, t4 = D + 40_000, t5 = D + 41_000;
  const s = (ms) => ms / 1000;
  const specs = {
    A: spec(4242, s(t0)), B: spec(4242, s(t1 + 7)), G: spec(4242, s(t1 + 3)), H: spec(4242, s(t1 - 1)), D: spec(4242, s(t2 + 500)), E: spec(4242, s(t2 - 1)), F: spec(4242, s(t5)),
  };
  const zero = (login_ = 'someone') => ({ status: 200, headers: { ...JSON_ANS, etag: null }, json: { account: { id: 4242, login: login_ }, machines: 0, counted: 0, first: 0, agreed: 0, disagreed: 0, unconfirmed: 0, first_time: null, last_time: null } });
  const revoked = unauth('the token was issued before the last revoke of the tokens of its account: log in again');
  const notGood = unauth('the token is revoked or its account has no data in this registry: log in again');
  const rq = [];
  const add = (req, res, calls) => rq.push({ req, res, calls });
  add(login('ghu_one', { now: t0 }), ok201(4242, 'someone', t0), 1); // 1. new row: tokens_after t0
  add(get(me, { token: 'A', now: t0 + 1000 }), zero(), 1); // 2. iat t0 = tokens_after t0: good
  add(del('/v1/tokens', { token: 'A', now: t1 }), no204, 1); // 3. tokens_after t1
  add(get(me, { token: 'A', now: t1 }), revoked, 1); // 4.
  add(del('/v1/tokens', { token: 'A', now: t1 + 1 }), notGood, 1); // 5. a revoked token cannot revoke
  add(login('ghu_two', { now: t1 + 7 }), ok201(4242, 'someone', t1 + 7), 1); // 6. a login does not change tokens_after (t1)
  add(get(me, { token: 'B', now: t1 + 8 }), zero(), 1); // 7.
  add(get(me, { token: 'G', now: t1 + 8 }), zero(), 1); // 8. iat t1 + 3 ms: after t1 and before the login: good (the login did not set tokens_after)
  add(get(me, { token: 'H', now: t1 + 8 }), revoked, 1); // 9. iat t1 - 1 ms: revoked
  add(get(me, { token: 'A', now: t1 + 8 }), revoked, 1); // 10.
  add(del('/v1/tokens', { token: 'B', now: t2 }), no204, 1); // 11. tokens_after t2
  add(get(me, { token: 'B', now: t2 + 1 }), revoked, 1); // 12.
  add(login('ghu_three', { now: t3 }), ok201(4242, 'someone', t3), 1); // 13.
  add(get(me, { token: 'D', now: t3 + 1 }), zero(), 1); // 14. iat t2 + 500 ms: good
  add(get(me, { token: 'E', now: t3 + 1 }), revoked, 1); // 15. iat t2 - 1 ms: revoked
  add(del('/v1/tokens', { now: t3 + 2 }), unauth('the request has no Authorization header: this route needs a registry token'), 0); // 16.
  add(del(me, { token: 'D', now: t4 }), no204, 1); // 17. the account form: the row is gone
  add(get(me, { token: 'D', now: t4 + 1 }), unauth('the account of the token has no data in this registry: log in again'), 1); // 18.
  add(login('ghu_four', { now: t5 }), ok201(4242, 'someone', t5), 1); // 19. a new row: tokens_after t5
  add(get(me, { token: 'D', now: t5 + 1 }), revoked, 1); // 20. a token from before the delete does not live again
  add(get(me, { token: 'F', now: t5 + 1 }), zero(), 1); // 21.
  writeCase({
    name: 'ct9-tokens-after', rules: RULES('R-AP35', 'R-AP36', 'R-AP37', 'R-AP38', 'R-AP41', 'R-CT7', 'R-CT8', 'R-CT9', 'R-CT16', 'R-RE17'),
    settings: SETTINGS, tokenSpecs: specs,
    requests: rq.map((x) => x.req), responses: rq.map((x) => x.res), d1: rq.map((x) => x.calls), github: [GH, GH, GH, GH],
    files: { ...userFile(1, 4242, 'someone', 200, 'ghu_one'), ...userFile(2, 4242, 'someone', 200, 'ghu_two'), ...userFile(3, 4242, 'someone', 200, 'ghu_three'), ...userFile(4, 4242, 'someone', 200, 'ghu_four') },
    db: tsv([[Q_ACCOUNTS, [[4242, 'someone', t5, t5, t5]]], [Q_LINKS, []]]),
  });
}

// =====================================================================================================================================================================
// E. account/ct10-tracker: the totals of GET /v1/contributors/me, in one D1 call, from a seeded state. The model computes them from the rows.
{
  const B = 1767225000000;
  const A = 4242n, O = 77n, C5 = 5000n;
  const rowsA = [
    [pairs.a, 'pass', 1000], [pairs.b, 'fail', 1100], [pairs.c, 'pass', 1200], [pairs.p, 'crash', 1300], [pairs.x, 'pass', 1400], [pairs.a2, 'pass', 1500], [pairs.b2, 'fail', 1600],
  ].map(([p, r, t]) => ({ p, r, t: B + t, who: A }));
  const rowsO = [[pairs.b, 'pass', 1050, O], [pairs.p, 'fail', 1300, O], [pairs.x, 'pass', 1400, C5]].map(([p, r, t, who]) => ({ p, r, t: B + t, who }));
  const compat = [
    [pairs.a, 0, 'pass', 2000], [pairs.a, 1, 'fail', 5000], // a bot row and an author row on one pair: counted once
    [pairs.b, 0, 'pass', 2000], [pairs.c, 1, 'pass', 1100], [pairs.p, 0, 'hang', 2000], [pairs.b2, 0, 'fail', 1600],
  ].map(([p, s, r, t]) => ({ p, s, r, t: B + t }));
  const totals = { counted: 10, first: 4, agreed: 2, disagreed: 1, unconfirmed: 7, first_time: 1767224000500, last_time: B + 2500 }; // last_time is above the largest time of the rows of 4242 (B + 1600)
  // the model of R-CT10
  const all = [...rowsA, ...rowsO];
  const trackerOf = (who) => {
    const mine = all.filter((c) => c.who === who);
    let first = 0, agreed = 0, disagreed = 0, unconfirmed = 0;
    for (const c of mine) {
      const k = pk(c.p);
      const earlierCompat = compat.some((x) => pk(x.p) === k && x.t < c.t);
      const earlierOther = all.some((o) => pk(o.p) === k && o.who !== who && (o.t < c.t || (o.t === c.t && o.who < who)));
      if (!earlierCompat && !earlierOther) first++;
      const bot = compat.filter((x) => pk(x.p) === k && x.s === 0);
      if (bot.length === 0) unconfirmed++; else if (bot.some((x) => R[x.r] === R[c.r])) agreed++; else disagreed++;
    }
    return { mine, first, agreed, disagreed, unconfirmed };
  };
  const totals77 = { counted: 2, first: 0, agreed: 0, disagreed: 0, unconfirmed: 2, first_time: 1767224000800, last_time: B + 500 }; // the totals of 77 are older than its rows: the rows give the larger last_time (Q302)
  const want = (who, tot) => {
    const a = trackerOf(who);
    return { counted: a.mine.length + tot.counted, first: a.first + tot.first, agreed: a.agreed + tot.agreed, disagreed: a.disagreed + tot.disagreed, unconfirmed: a.unconfirmed + tot.unconfirmed,
      first_time: Math.min(...a.mine.map((c) => c.t), tot.first_time), last_time: Math.max(...a.mine.map((c) => c.t), tot.last_time) };
  };
  const wantA = want(A, totals), want77 = want(O, totals77);
  console.log('tracker of 4242', JSON.stringify(wantA), 'of 77', JSON.stringify(want77));
  const seed = [
    ...seedBase(),
    ...[...rowsA, ...rowsO].map((c) => contribSql(c.who, c.p, c.r, c.t)),
    ...compat.map((x) => compatSql(x.p, x.s, x.r, x.t)),
    totalsSql(A, [totals.counted, totals.first, totals.agreed, totals.disagreed, totals.unconfirmed, totals.first_time, totals.last_time]),
    totalsSql(88, [3, 1, 1, 1, 1, 1767224000400, 1767224000900]),
    totalsSql(77, [totals77.counted, totals77.first, totals77.agreed, totals77.disagreed, totals77.unconfirmed, totals77.first_time, totals77.last_time]),
    contributorSql(4242, 'someone', 0, B, B), contributorSql(88, 'totals-only', 0, B, B), contributorSql(99, 'empty', 0, B, B), contributorSql(77, 'other', 0, B, B),
    linkSql(cid(M.m1), 4242, B), linkSql(cid(M.m2), 4242, B), linkSql(cid(M.m3), 99, B), linkSql(cid(M.m4), 77, B),
  ];
  const ans = (id, login_, w) => ({ status: 200, headers: { ...JSON_ANS, etag: null }, json: { account: { id, login: login_ }, ...w } });
  writeCase({
    name: 'ct10-tracker', rules: RULES('R-AP35', 'R-AP41', 'R-AP73', 'R-CT5', 'R-CT6', 'R-CT10', 'R-CT15', 'R-CT16', 'R-RE16', 'R-RE17', 'R-RE18', 'R-RE25', 'R-RC1', 'R-RC3', 'R-RC4'),
    settings: SETTINGS,
    tokenSpecs: { A: spec(4242, 1767225600), P: spec(88, 1767225600), Q: spec(99, 1767225600), R: spec(77, 1767225600) },
    seed,
    requests: [get(me, { token: 'A' }), get(me, { token: 'P' }), get(me, { token: 'Q' }), get(me, { token: 'R' })],
    responses: [
      ans(4242, 'someone', { machines: 2, ...wantA }),
      ans(88, 'totals-only', { machines: 0, counted: 3, first: 1, agreed: 1, disagreed: 1, unconfirmed: 1, first_time: 1767224000400, last_time: 1767224000900 }),
      ans(99, 'empty', { machines: 1, counted: 0, first: 0, agreed: 0, disagreed: 0, unconfirmed: 0, first_time: null, last_time: null }),
      ans(77, 'other', { machines: 1, ...want77 }),
    ],
    d1: [1, 1, 1, 1], github: [],
  });
}

// =====================================================================================================================================================================
// F. account/ct7-delete: DELETE /v1/contributors/me, the machine form and the account form. compat_hints never changes.
{
  const B = 1767225000000;
  const m1 = cid(M.m1), m2 = cid(M.m2), m3 = cid(M.m3), m4 = cid(M.m4);
  const rows = [
    rowOf(m1, pairs.a, 'pass', B + 1), rowOf(m1, pairs.b, 'fail', B + 2), // m1: no account
    rowOf(m2, pairs.c, 'pass', B + 3), // m2: linked to 4242, with an own row
    rowOf(4242, pairs.a, 'pass', B + 4), rowOf(4242, pairs.p, 'crash', B + 5), rowOf(4242, pairs.x, 'pass', B + 6),
    rowOf(77, pairs.a, 'fail', B + 7), rowOf(77, pairs.b, 'pass', B + 8),
  ];
  const pairOf = { PA: pairs.a, PB: pairs.b, PC: pairs.c, PP: pairs.p, PX: pairs.x };
  void pairOf;
  const seed = [
    ...seedBase(),
    ...[
      [m1, pairs.a, 'pass', B + 1], [m1, pairs.b, 'fail', B + 2], [m2, pairs.c, 'pass', B + 3],
      [4242, pairs.a, 'pass', B + 4], [4242, pairs.p, 'crash', B + 5], [4242, pairs.x, 'pass', B + 6], [77, pairs.a, 'fail', B + 7], [77, pairs.b, 'pass', B + 8],
    ].map(([w, p, r, t]) => contribSql(w, p, r, t)),
    totalsSql(m1, [2, 1, 0, 0, 2, B, B + 10]), totalsSql(m2, [1, 0, 0, 0, 1, B, B + 11]), totalsSql(4242, [4, 1, 1, 0, 3, B, B + 12]), totalsSql(77, [2, 0, 0, 0, 2, B, B + 13]),
    contributorSql(4242, 'someone', 0, B, B), contributorSql(77, 'other', D + 1000, B, B),
    linkSql(m2, 4242, B), linkSql(m3, 4242, B), linkSql(m4, 77, B), linkSql(m1, 4242, B).replace(m1.toString(), '-1'), // a link of another machine (-1) to the account 4242
  ];
  void rows;
  const NOW = D + 10_000;
  const state = (o) => ({
    contrib: [], totals: [], accounts: [], links: [], ...o,
  });
  void state;
  // final state after all 11 requests: nothing of m1, m2, 4242 and 77 stays; only the link of m4 to 77 was removed with the account 77; -1 link removed with 4242
  const remainingLinks = [];
  writeCase({
    name: 'ct7-delete', rules: RULES('R-AP36', 'R-AP41', 'R-AP48', 'R-CT1', 'R-CT3', 'R-CT6', 'R-CT7', 'R-CT9', 'R-CT16', 'R-RE12', 'R-RE16', 'R-RE17', 'R-RE18', 'R-RE25', 'R-AP21'),
    settings: SETTINGS, seed,
    tokenSpecs: { T4242: spec(4242, 1767225601), T77old: spec(77, 1767225600), T77new: spec(77, 1767225602), T5000: spec(5000, 1767225601) },
    requests: [
      del(me, { machine: M.m1, now: NOW }),
      del(me, { machine: M.m1, now: NOW }),
      del(me, { machine: M.m2, now: NOW }),
      del(me, { now: NOW }),
      del(me, { machine: 'abc', now: NOW }),
      { method: 'DELETE', path: me, headers: { authorization: 'Bearer garbage', 'talon-contributor': M.m4 }, now: NOW },
      del(me, { token: 'T4242', now: NOW }),
      del(me, { token: 'T4242', now: NOW }),
      del(me, { token: 'T77old', now: NOW }),
      get(me, { token: 'T77new', now: NOW }),
      del(me, { token: 'T77new', now: NOW }),
      del(me, { token: 'T5000', now: NOW }),
    ],
    responses: [
      no204, no204, no204,
      prob(400, '/errors/bad-request', 'the request needs the header Authorization (an account) or the header Talon-Contributor (one machine)'),
      prob(400, '/errors/bad-request', 'the header Talon-Contributor must be 32 characters, each one of 0 to 9 and a to f'),
      unauth('the token is not a valid JWT'),
      no204, no204,
      unauth('the token is revoked or its account has no data in this registry: log in again'),
      { status: 200, json: { account: { id: 77, login: 'other' }, machines: 1, counted: 4 } }, // the revoked token deleted nothing
      no204, no204,
    ],
    d1: [1, 1, 1, 0, 0, 0, 1, 1, 1, 1, 1, 1], github: [],
    db: tsv([
      [Q_CONTRIB, []], [Q_TOTALS, []], [Q_ACCOUNTS, []], [Q_LINKS, remainingLinks],
      [Q_HINTS, hintRows(rows)],
    ]),
  });
}

// =====================================================================================================================================================================
// G. account/ct11-login-limit: RL_LOGIN, 3 a minute (the runner file). POST /v1/tokens and DELETE /v1/contributors/me share the budget; a refusal before the limit costs nothing.
{
  const a1 = { 'cf-connecting-ip': '1.2.3.4' };
  const rl = (extra = {}) => ({ headers: a1, ...extra });
  const B = 1767225000000;
  void B;
  const lim = prob(429, '/errors/rate-limited', 'too many login requests from this address: try again in a minute');
  const lim60 = { ...lim, headers: { 'retry-after': '60' } };
  const rq = [];
  const add = (req, res, calls) => rq.push({ req, res, calls });
  add({ window_s: 60, need_ms: 8000 }, null, null);
  const withIp = (req, ip) => ({ ...req, headers: { ...req.headers, 'cf-connecting-ip': ip } });
  add(withIp(post('{}'), '1.2.3.4'), prob(400, '/errors/bad-request', 'the login request body is not valid: github_token is missing'), 0); // 1 refused before the limit
  add(withIp(del(me, {}), '1.2.3.4'), prob(400, '/errors/bad-request'), 0); // 2
  add(withIp({ method: 'DELETE', path: me, headers: { authorization: 'Bearer garbage' }, now: D }, '1.2.3.4'), unauth('the token is not a valid JWT'), 0); // 3
  add(withIp(del(me, { machine: 'abc' }), '1.2.3.4'), prob(400, '/errors/bad-request', 'the header Talon-Contributor must be 32 characters, each one of 0 to 9 and a to f'), 0); // 3b the machine form with a bad id costs nothing (Q308)
  add(withIp(login('ghu_a'), '1.2.3.4'), unauth('GitHub refused the token'), 0); // 4 counts (1)
  add(withIp(del(me, { machine: M.m1 }), '1.2.3.4'), no204, 1); // 5 counts (2)
  add(withIp(login('ghu_b'), '1.2.3.4'), unauth('GitHub refused the token'), 0); // 6 counts (3)
  add(withIp(login('ghu_c'), '1.2.3.4'), { ...lim60 }, 0); // 7 over the limit: no GitHub read
  add(withIp(del(me, { machine: M.m1 }), '1.2.3.4'), { ...lim60 }, 0); // 8 shared budget
  add(withIp(del(me, { token: 'good' }), '1.2.3.4'), { ...lim60 }, 0); // 9 the token is checked, then the limit
  add(withIp({ method: 'DELETE', path: me, headers: { authorization: 'Bearer garbage' }, now: D }, '1.2.3.4'), unauth('the token is not a valid JWT'), 0); // 10 a bad token is refused before the limit
  add(withIp(get(me, { token: 'good' }), '1.2.3.4'), { status: 200 }, 1); // 11 the tracker has no limit
  add(withIp(del('/v1/tokens', { token: 'good' }), '1.2.3.4'), { status: 204 }, 1); // 12 DELETE /v1/tokens has no limit
  add(withIp(login('ghu_d'), '5.6.7.8'), ok201(77, 'other', D), 1); // 13 another address
  add(withIp(login('ghu_e'), '::ffff:1.2.3.4'), { ...lim60 }, 0); // 14 a mapped address is the IPv4 address
  add(withIp(login('ghu_f'), '2001:db8::1'), unauth('GitHub refused the token'), 0); // 15 IPv6 /64 A (1)
  add(withIp(login('ghu_g'), '2001:DB8:0:0:ffff::2'), unauth('GitHub refused the token'), 0); // 16 the same /64 (2)
  add(withIp(login('ghu_h'), '2001:db8:0:0:1:2:3:4'), unauth('GitHub refused the token'), 0); // 17 (3)
  add(withIp(login('ghu_i'), '2001:db8:0:0::9'), { ...lim60 }, 0); // 18 over
  add(withIp(login('ghu_j'), '2001:db8:0:1::1'), unauth('GitHub refused the token'), 0); // 19 another /64
  const reqs = rq.filter((x) => x.res !== null);
  const wins = rq.filter((x) => x.res === null).map((x) => x.req);
  // requests.jsonl: the window line first, then the requests; the user answers are in order: 4 (401), 6 (401), 13 (200), 15..17 (401), 19 (401)
  const gh = [];
  const order = [4, 6, 13, 15, 16, 17, 19];
  void order;
  const files = {};
  const answers = [401, 401, 200, 401, 401, 401, 401];
  answers.forEach((st, i) => Object.assign(files, userFile(i + 1, st === 200 ? 77 : undefined, st === 200 ? 'other' : undefined, st)));
  for (let i = 0; i < answers.length; i++) gh.push(GH);
  const goodSpec = spec(4242, 1767225600);
  writeCase({
    name: 'ct11-login-limit', rules: RULES('R-CT11', 'R-CT16', 'R-AP25', 'R-AP37', 'R-AP36', 'R-AP38', 'R-AP35', 'R-AP68', 'R-WH14'),
    settings: SETTINGS, ratelimits: { RL_LOGIN: { limit: 3, period: 60 } },
    seed: [...seedBase(), contributorSql(4242, 'someone', 0, D, D)],
    tokenSpecs: { good: goodSpec },
    requests: [...wins, ...reqs.map((x) => x.req)],
    responses: reqs.map((x) => x.res),
    d1: reqs.map((x) => x.calls), github: gh, files,
  });
}

// =====================================================================================================================================================================
// H. account/ap45-write-routes: MIN_TLN_WRITE covers the three write routes (Design Q182), MIN_TLN covers the tracker. The client check comes before the media type and the token.
{
  const ua = (v) => ({ 'user-agent': v });
  const tooOld = (min) => prob(400, '/errors/unsupported-client', undefined, { minimum: min });
  const rq = [
    [{ method: 'POST', path: '/v1/tokens', headers: { ...ua('tln/0.4.1'), 'content-type': 'text/plain' }, body: '{}', now: D }, tooOld('0.5.0')],
    [{ method: 'DELETE', path: '/v1/tokens', headers: { ...ua('tln/0.4.1'), authorization: 'Bearer garbage' }, now: D }, tooOld('0.5.0')],
    [{ method: 'DELETE', path: me, headers: { ...ua('tln/0.4.1'), authorization: 'Bearer garbage' }, now: D }, tooOld('0.5.0')],
    [{ method: 'DELETE', path: me, headers: { ...ua('tln/0.4.1'), 'talon-contributor': M.m1 }, now: D }, tooOld('0.5.0')],
    [{ method: 'GET', path: me, headers: ua('tln/0.4.1'), now: D }, unauth('the request has no Authorization header: this route needs a registry token')],
    [{ method: 'GET', path: me, headers: ua('tln/0.2.9'), now: D }, tooOld('0.3.0')],
    [{ method: 'POST', path: '/v1/tokens', headers: { ...JSON_CT, ...ua('tln/0.5.0') }, body: '{}', now: D }, prob(400, '/errors/bad-request', 'the login request body is not valid: github_token is missing')],
    [{ method: 'POST', path: '/v1/tokens', headers: { ...JSON_CT, ...ua('curl/8.5.0') }, body: '{}', now: D }, prob(400, '/errors/bad-request', 'the login request body is not valid: github_token is missing')],
    [{ method: 'PUT', path: '/v1/tokens', headers: ua('tln/0.4.1'), now: D }, { status: 405, headers: { allow: 'DELETE, POST' }, problem: { type: '/errors/method-not-allowed' } }],
    [{ method: 'DELETE', path: '/v1/contributors', headers: ua('tln/0.4.1'), now: D }, prob(404, '/errors/not-found')],
  ];
  writeCase({
    name: 'ap45-write-routes', rules: RULES('R-AP45', 'R-AP48', 'R-CT16', 'R-AP35', 'R-AP36', 'R-AP37', 'R-AP38', 'R-AP21'),
    settings: { ...SETTINGS, MIN_TLN: '0.3.0', MIN_TLN_WRITE: '0.5.0' },
    requests: rq.map((x) => x[0]), responses: rq.map((x) => x[1]), d1: rq.map(() => 0), github: [],
  });
}
console.log('done');
