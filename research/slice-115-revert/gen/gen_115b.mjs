// Makes the W2 cases of slice 115b (GET /v1/sweeps/{tag}, GET /v1/compat_hints, GET /v1/artifacts/{hash}/compat) in worker/tests/cases/compat/. Run: node gen_115b.mjs
import { N, H, G, LOG_SIZE, dataset, writeCase, tsv, etagOf, nightlyId } from './lib.mjs';

const T = (i) => 1767225600000 + i * 1000;
const get = (path, o = {}) => ({ method: 'GET', path, ...(o.headers ? { headers: o.headers } : {}), now: o.now ?? T(0) });
const json = (body, extra = {}) => ({ status: 200, headers: { 'content-type': 'application/json', ...extra }, body });
const NO_STORE = { 'cache-control': 'no-store', etag: null };
const botRow = (h, n, t, res, d, time = T(0)) => `INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index) VALUES (${H[h].id}, ${N[n].id}, ${t}, 0, ${res}, ${d === undefined ? 'NULL' : `'${d}'`}, ${time}, NULL);`;
const authorRow = (h, n, t, res) => `INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index) VALUES (${H[h].id}, ${N[n].id}, ${t}, 1, ${res}, NULL, ${T(0)}, 6);`;
const prob = (status, type, more = {}) => ({ status, problem: { type, ...more } });

// ---- H: ap39-sweeps ----
{
  const missingAll = [H.PB.b58, H.PP.b58, H.PC.b58]; // hash bytes 22, 33, 66
  const body = (o) => JSON.stringify({ log_size: o.log_size ?? LOG_SIZE, members: o.members ?? 3, missing: o.missing, sweep: o.sweep ?? null });
  const sweepJson = (n, upto, time) => ({ nightly: N[n].tag, target: 'any', time, upto_log_index: upto });
  const path = (n) => `/v1/sweeps/${N[n].tag}`;
  writeCase({
    name: 'ap39-sweeps',
    tokens: false,
    rules: ['R-AP39', 'R-AP67', 'R-AP41', 'R-AP21', 'R-AP48', 'R-MX1', 'R-MX4', 'R-MX8', 'R-MX11', 'R-MX16', 'R-RE7', 'R-RE8', 'R-IK2', 'R-IK4'],
    seed: dataset(),
    requests: [
      get(path('n1')),
      { sql: [botRow('PC', 'n1', 0, 0), botRow('PB', 'n1', 0, 1, 'x'), authorRow('PP', 'n1', 0, 0)] },
      get(path('n1')),
      { sql: [botRow('PP', 'n1', 0, 0), `INSERT INTO sweeps (nightly, target, upto_log_index, time) VALUES (${N.n1.id}, 0, 8, ${T(9)});`] },
      get(path('n1')),
      get(path('n3')),
      get('/v1/sweeps/nightly-2026-10-01-1234567'),
      get('/v1/sweeps/latest'),
      get(`${path('n1')}?target=x64glibc`),
      get(`${path('n1')}?target=any`),
      { sql: ['UPDATE releases SET yanked = 1 WHERE log_index = 5'] },
      get(path('n1')),
    ],
    responses: [
      json(body({ missing: missingAll }), NO_STORE),
      json(body({ missing: [H.PP.b58] }), NO_STORE),
      json(body({ missing: [], sweep: sweepJson('n1', 8, T(9)) }), NO_STORE),
      json(body({ missing: missingAll }), NO_STORE),
      prob(404, '/errors/not-found', { detail: 'no toolchain for the tag nightly-2026-10-01-1234567' }),
      prob(404, '/errors/not-found', { detail: 'no toolchain for the tag latest' }),
      prob(400, '/errors/bad-request', { detail: 'the query parameter target must be any, got x64glibc' }),
      json(body({ missing: [], sweep: sweepJson('n1', 8, T(9)) }), NO_STORE),
      json(body({ missing: [H.PA.b58], sweep: sweepJson('n1', 8, T(9)) }), NO_STORE),
    ],
    d1: [1, 1, 1, 1, 0, 0, 1, 1].slice(0, 0).concat([1, 1, 1, 1, 1, 0, 0, 1, 1]),
    db: undefined,
  });
}

// ---- I: ap40-audit ----
{
  const phantom = nightlyId('nightly-2026-11-01-ddddddd');
  const hint = (h, nid, t, tv, p, f, c) => `INSERT INTO compat_hints (artifact, nightly, target, talon_version, pass_count, fail_count, crash_count, first_time, last_time) VALUES (${H[h].id}, ${nid}, ${t}, ${tv}, ${p}, ${f}, ${c}, ${T(0)}, ${T(0)});`;
  const seed = [
    ...dataset(),
    hint('PA', N.n1.id, 0, 1, 3, 1, 0), hint('PA', N.n1.id, 0, 2, 2, 0, 0), hint('PA', N.n2.id, 0, 1, 1, 0, 0),
    hint('PP', N.n1.id, 8, 2, 2, 2, 1), hint('PP', N.n1.id, 0, 3, 0, 3, 0), hint('PX', N.n1.id, 8, 1, 9, 9, 9),
    hint('PA', phantom, 0, 1, 9, 0, 0), hint('PC', N.n1.id, 0, 1, 1, 1, 1),
    botRow('PA', 'n2', 0, 0), authorRow('PP', 'n1', 0, 1),
  ];
  const pair = (h, n, t, p, f, c) => ({ crash_count: c, fail_count: f, hash: H[h].b58, nightly: N[n].tag, pass_count: p, target: t });
  const all = [pair('PA', 'n1', 'any', 5, 1, 0), pair('PP', 'n1', 'x64glibc', 2, 2, 1), pair('PP', 'n1', 'any', 0, 3, 0), pair('PC', 'n1', 'any', 1, 1, 1)];
  const body = (pairs) => JSON.stringify({ pairs });
  const b100 = body(all), tag100 = etagOf(b100);
  const b2 = body(all.slice(0, 2));
  const CC = { 'cache-control': 'max-age=300' };
  writeCase({
    name: 'ap40-audit',
    tokens: false,
    rules: ['R-AP40', 'R-AP67', 'R-AP41', 'R-AP43', 'R-AP24', 'R-AP54', 'R-AP55', 'R-AP56', 'R-AP46', 'R-AP21', 'R-MX13', 'R-MX16', 'R-RE8', 'R-RE12', 'R-IK7'],
    seed,
    requests: [
      get('/v1/compat_hints?audit=100'),
      get('/v1/compat_hints?audit=100'),
      get('/v1/compat_hints?audit=100', { headers: { 'if-none-match': tag100 } }),
      get('/v1/compat_hints?audit=100', { headers: { 'cache-control': 'no-cache' } }),
      get('/v1/compat_hints?audit=2'),
      get('/v1/compat_hints?audit=0'),
      get('/v1/compat_hints'),
      get('/v1/compat_hints?audit=abc'),
      get('/v1/compat_hints?audit=007'),
      get('/v1/compat_hints?audit=5000'),
      // R-AP67 (Design Q149): a count above 1000 is 1000, also a number past 2^63 - 1. The answer has the same bytes and ETag as audit=1000 and audit=100 here (4 pairs).
      get('/v1/compat_hints?audit=1000'),
      get('/v1/compat_hints?audit=99999999999999999999999999'),
    ],
    responses: [
      { status: 200, headers: { 'content-type': 'application/json', ...CC, etag: tag100 }, body: b100 },
      { status: 200, headers: { 'content-type': 'application/json', ...CC, etag: tag100 }, body: b100 },
      { status: 304, headers: { ...CC, etag: tag100 }, body: '' },
      { status: 200, headers: { 'content-type': 'application/json', ...CC, etag: tag100 }, body: b100 },
      { status: 200, headers: { 'content-type': 'application/json', ...CC, etag: etagOf(b2) }, body: b2 },
      { status: 200, headers: { 'content-type': 'application/json', ...CC }, body: body([]) },
      prob(400, '/errors/bad-request'),
      prob(400, '/errors/bad-request'),
      prob(400, '/errors/bad-request'),
      { status: 200, headers: { 'content-type': 'application/json', ...CC, etag: tag100 }, body: b100 },
      { status: 200, headers: { 'content-type': 'application/json', ...CC, etag: tag100 }, body: b100 },
      { status: 200, headers: { 'content-type': 'application/json', ...CC, etag: tag100 }, body: b100 },
    ],
    d1: [1, 0, 0, 1, 1, 1, 0, 0, 0, 1, '-', '-'],
  });
}

// ---- J: ap4-artifact-compat ----
{
  const phantom = nightlyId('nightly-2026-11-01-ddddddd');
  const phantomRow = `INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index) VALUES (${H.PA.id}, ${phantom}, 0, 0, 1, 'ghost', ${T(0)}, NULL);`;
  const hint = (h, nid, t, tv, p, f, c) => `INSERT INTO compat_hints (artifact, nightly, target, talon_version, pass_count, fail_count, crash_count, first_time, last_time) VALUES (${H[h].id}, ${nid}, ${t}, ${tv}, ${p}, ${f}, ${c}, ${T(0)}, ${T(0)});`;
  const seed = [
    ...dataset(),
    botRow('PA', 'n1', 0, 0), botRow('PA', 'n2', 0, 0), botRow('PA', 'n3', 0, 1, 'e1'), authorRow('PA', 'n1', 0, 0), phantomRow,
    botRow('PP', 'n1', 0, 0), botRow('PP', 'n1', 8, 0), botRow('PP', 'n2', 8, 0),
    hint('PA', N.n3.id, 0, 1, 2, 1, 0), hint('PA', N.n3.id, 0, 2, 1, 0, 0), hint('PA', N.n2.id, 0, 1, 0, 0, 1), hint('PA', phantom, 0, 1, 7, 0, 0),
  ];
  const run = (h, t, source, result, d, from, to) => ({ error_digest: d, from: N[from].tag, hash: H[h].b58, result, source, target: t, to: N[to].tag });
  const hintJson = (h, n, t, p, f, c) => ({ crash_count: c, fail_count: f, hash: H[h].b58, nightly: N[n].tag, pass_count: p, target: t });
  const bodyOf = (hints, runs) => JSON.stringify({ hints, runs });
  const pa = bodyOf(
    [hintJson('PA', 'n2', 'any', 0, 0, 1), hintJson('PA', 'n3', 'any', 3, 1, 0)],
    [run('PA', 'any', 'bot', 'pass', null, 'n1', 'n2'), run('PA', 'any', 'bot', 'fail', 'e1', 'n3', 'n3'), run('PA', 'any', 'author', 'pass', null, 'n1', 'n1')],
  );
  const pp = bodyOf([], [run('PP', 'any', 'bot', 'pass', null, 'n1', 'n1'), run('PP', 'x64glibc', 'bot', 'pass', null, 'n1', 'n2')]);
  const empty = bodyOf([], []);
  const pa2 = bodyOf(
    [hintJson('PA', 'n2', 'any', 0, 0, 1), hintJson('PA', 'n3', 'any', 3, 1, 0)],
    [run('PA', 'any', 'bot', 'pass', null, 'n1', 'n3'), run('PA', 'any', 'author', 'pass', null, 'n1', 'n1')],
  );
  const CC = { 'cache-control': 'max-age=300' };
  const ok = (body) => ({ status: 200, headers: { 'content-type': 'application/json', ...CC, etag: etagOf(body) }, body });
  const pathOf = (h) => `/v1/artifacts/${H[h].b58}/compat`;
  writeCase({
    name: 'ap4-artifact-compat',
    tokens: false,
    rules: ['R-AP4', 'R-AP67', 'R-AP41', 'R-AP43', 'R-AP24', 'R-AP54', 'R-AP55', 'R-AP56', 'R-AP17', 'R-AP58', 'R-RE3', 'R-RE12', 'R-RE13', 'R-MX16', 'R-IK7', 'R-AP21'],
    seed,
    requests: [
      get(pathOf('PA')),
      get(pathOf('PA')),
      get(pathOf('PA'), { headers: { 'if-none-match': `W/${etagOf(pa)}` } }),
      get(pathOf('PP')),
      get(pathOf('PY')),
      get(pathOf('PY')),
      get('/v1/artifacts/abc/compat'),
      get(pathOf('PX')),
      { sql: [`UPDATE compat SET result = 0, error_digest = NULL WHERE artifact = ${H.PA.id} AND nightly = ${N.n3.id} AND source = 0`] },
      get(pathOf('PA'), { headers: { 'cache-control': 'no-cache' } }),
      get(pathOf('PA')),
    ],
    responses: [
      ok(pa),
      ok(pa),
      { status: 304, headers: { ...CC, etag: etagOf(pa) }, body: '' },
      ok(pp),
      prob(404, '/errors/not-found', { detail: `no artifact ${H.PY.b58}` }),
      prob(404, '/errors/not-found', { detail: `no artifact ${H.PY.b58}` }),
      prob(404, '/errors/not-found', { detail: 'no artifact abc' }),
      ok(empty),
      ok(pa2),
      ok(pa2),
    ],
    d1: [1, 0, 0, 1, 1, 1, 0, 1, 1, 0],
  });
}
console.log('115b cases written');
