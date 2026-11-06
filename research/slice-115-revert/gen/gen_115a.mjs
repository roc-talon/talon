// Makes the W2 cases of slice 115a (POST /v1/compat, the bot path) in worker/tests/cases/compat/. Run: node gen_115a.mjs
import { N, H, G, LOG_SIZE, dataset, row, sweepOf, post, req, ok, prob, writeCase, tsv, COMPAT_Q, SWEEPS_Q, TRANS_Q, crow, incompleteDetail, JWKS_LOG, b58, rep, nameId, hex, storedVersion } from './lib.mjs';

const T = (i) => 1767225600000 + i * 1000;
const U = 'é';

// ---- A: ap10-bot-rows-and-sweep ----
{
  const r1 = [row('PA', 'n1', 'any', 'pass'), row('PC', 'n1', 'any', 'pass'), row('PB', 'n1', 'any', 'fail', `boom"${U}`), row('PP', 'n1', 'any', 'pass'), row('PC', 'n2', 'any', 'pass', '')];
  const first = { extra: 1, rows: r1.map((r, i) => (i === 0 ? { ...r, note: [1] } : r)) };
  writeCase({
    name: 'ap10-bot-rows-and-sweep',
    rules: ['R-AP10', 'R-AP66', 'R-AP41', 'R-AP44', 'R-AP48', 'R-AP51', 'R-AP58', 'R-IK2', 'R-IK7', 'R-MX4', 'R-MX5', 'R-MX8', 'R-MX11', 'R-MX12', 'R-RE3', 'R-RE6', 'R-RE7', 'R-RE8', 'R-RE13', 'R-RE23', 'R-RE26', 'R-TP7'],
    seed: dataset(),
    requests: [
      req(first, { token: 'bot', now: T(1) }),
      req(post([...r1, row('PA', 'n1', 'any', 'fail', 'x')]), { token: 'bot', now: T(2) }),
      req(post([], sweepOf('n1', LOG_SIZE)), { token: 'bot', now: T(3) }),
      req(post([row('PB', 'n2', 'any', 'pass'), row('PP', 'n2', 'any', 'pass')], sweepOf('n2', LOG_SIZE)), { token: 'bot', now: T(4) }),
      req(post([], sweepOf('n1', 7)), { token: 'bot', now: T(5) }),
      { sql: ['UPDATE releases SET yanked = 1 WHERE log_index = 5'] },
      req(post([row('PB', 'n3', 'any', 'pass')], sweepOf('n2', LOG_SIZE)), { token: 'bot', now: T(6) }),
    ],
    responses: [ok(201, 5), ok(200, 0), ok(200, 0), ok(201, 2), ok(200, 0), ok(201, 1)],
    d1: [2, 2, 1, 2, 1, 2],
    github: [JWKS_LOG],
    db: tsv([
      [COMPAT_Q, [
        crow('PA', 'n1', 0, 0, 0, null, T(1)),
        crow('PB', 'n1', 0, 0, 1, `boom"${U}`, T(1)),
        crow('PB', 'n2', 0, 0, 0, null, T(4)),
        crow('PB', 'n3', 0, 0, 0, null, T(6)),
        crow('PP', 'n1', 0, 0, 0, null, T(1)),
        crow('PP', 'n2', 0, 0, 0, null, T(4)),
        crow('PC', 'n1', 0, 0, 0, null, T(1)),
        crow('PC', 'n2', 0, 0, 0, '', T(1)),
      ]],
      [SWEEPS_Q, [[N.n1.id, 0, 8, T(3)], [N.n2.id, 0, 8, T(4)]]],
      [TRANS_Q, [[N.n2.id, 0, N.n1.id, 3, 1]]],
    ]),
  });
}

// ---- B: mx9-sweep-errors ----
{
  const author = `INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index) VALUES (${H.PB.id}, ${N.n1.id}, 0, 1, 0, NULL, 1790000000000, 6);`;
  const missing12 = [H.PB.b58, H.PP.b58, H.PC.b58]; // by the state of the database after the rollback: the row of PC in the request is not written (R-AP66 check 10, Design Q145)
  writeCase({
    name: 'mx9-sweep-errors',
    rules: ['R-AP10', 'R-AP66', 'R-AP21', 'R-AP41', 'R-MX4', 'R-MX8', 'R-MX9', 'R-MX11', 'R-RE8', 'R-IK2', 'R-AP46'],
    seed: [...dataset(), author],
    requests: [
      req(post([row('PC', 'n1', 'any', 'pass')], sweepOf('n1', LOG_SIZE)), { token: 'bot', now: T(1) }),
      req(post([row('PC', 'n1', 'any', 'pass'), row('PB', 'n1', 'any', 'pass'), row('PP', 'n1', 'any', 'pass')], sweepOf('n1', LOG_SIZE)), { token: 'bot', now: T(2) }),
      req(post([row('PA', 'n2', 'any', 'pass')], sweepOf('n2', LOG_SIZE + 1)), { token: 'bot', now: T(3) }),
      req(post([row('PC', 'n2', 'any', 'pass')], sweepOf('n2', LOG_SIZE)), { token: 'bot', now: T(4) }),
    ],
    responses: [
      prob(422, '/errors/sweep-incomplete', { detail: incompleteDetail(N.n1.tag, LOG_SIZE, missing12) }),
      ok(201, 3),
      prob(400, '/errors/bad-request', { detail: 'the sweep upto_log_index is larger than the log size' }),
      prob(422, '/errors/sweep-incomplete', { detail: incompleteDetail(N.n2.tag, LOG_SIZE, missing12) }),
    ],
    d1: [3, 2, 2, 3],
    github: [JWKS_LOG],
    db: tsv([
      [COMPAT_Q, [
        crow('PB', 'n1', 0, 0, 0, null, T(2)),
        crow('PB', 'n1', 0, 1, 0, null, 1790000000000, 6),
        crow('PP', 'n1', 0, 0, 0, null, T(2)),
        crow('PC', 'n1', 0, 0, 0, null, T(2)),
      ]],
      [SWEEPS_Q, [[N.n1.id, 0, 8, T(2)]]],
    ]),
  });
}

// ---- C: mx9-missing-100 ----
{
  const K = 130;
  const seed = [];
  const hs = Array.from({ length: K }, (_, i) => ({ k: i + 1, bytes: rep(i + 1), b58: b58(rep(i + 1)), id: nameId(1, rep(i + 1)), g: `github.com/o/p${i + 1}/releases/download/{v}/` }));
  for (const h of hs) {
    seed.push(`INSERT INTO names (id, kind, value) VALUES (${h.id}, 1, X'${hex(h.bytes)}');`);
    seed.push(`INSERT INTO names (id, kind, value) VALUES (${nameId(2, Buffer.from(h.g))}, 2, '${h.g}');`);
    seed.push(`INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (${h.id}, 1, '[]', NULL, NULL, 1);`);
  }
  const n1 = N.n1;
  seed.push(`INSERT INTO log (idx, grp, version, hash, time) VALUES (1, 'roc-lang/nightlies:linux_x86_64', '${n1.tag}', 'sha256:${'a'.repeat(64)}', 1790000000000);`);
  seed.push(`INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, published_at, log_index) VALUES (${n1.id}, 'linux_x86_64', '${n1.tag}', 'a', '${'a'.repeat(64)}', ${n1.published_at}, 1);`);
  hs.forEach((h, i) => {
    seed.push(`INSERT INTO log (idx, grp, version, hash, time) VALUES (${i + 2}, '${h.g}', '1.0.0', '${h.b58}', 1790000000000);`);
    seed.push(`INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (${i + 2}, ${nameId(2, Buffer.from(h.g))}, ${storedVersion(1, 0, 0)}, '', ${h.id}, NULL, 'u', '1.0.0', NULL, ${Date.UTC(2026, 9, 25)}, 0, NULL, NULL);`);
  });
  const bound = K + 1;
  const sweep = { nightly: n1.tag, target: 'any', upto_log_index: bound };
  const names = hs.map((h) => h.b58); // the byte order of the hash is the order of k
  const botRows = (from, to) => ({ sql: [`INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index) SELECT value, ${n1.id}, 0, 0, 0, NULL, 1767225600000, NULL FROM json_each('[${hs.filter((h) => h.k >= from && h.k <= to).map((h) => h.id).join(',')}]')`] });
  writeCase({
    name: 'mx9-missing-100',
    rules: ['R-AP10', 'R-AP66', 'R-AP41', 'R-AP46', 'R-MX8', 'R-MX9', 'R-MX11', 'R-AP21'],
    seed,
    requests: [
      req({ rows: [], sweep }, { token: 'bot', now: T(1) }),
      botRows(1, 29),
      req({ rows: [], sweep }, { token: 'bot', now: T(2) }),
      botRows(30, 30),
      req({ rows: [], sweep }, { token: 'bot', now: T(3) }),
      botRows(31, K),
      req({ rows: [], sweep }, { token: 'bot', now: T(4) }),
    ],
    responses: [
      prob(422, '/errors/sweep-incomplete', { detail: incompleteDetail(n1.tag, bound, names) }),
      prob(422, '/errors/sweep-incomplete', { detail: incompleteDetail(n1.tag, bound, names.slice(29)) }),
      prob(422, '/errors/sweep-incomplete', { detail: incompleteDetail(n1.tag, bound, names.slice(30)) }),
      ok(200, 0),
    ],
    d1: [2, 2, 2, 1],
    github: [JWKS_LOG],
    db: tsv([
      ['SELECT count(*) FROM compat', [[K]]],
      [SWEEPS_Q, [[n1.id, 0, bound, T(4)]]],
    ]),
  });
}

// ---- D: ap46-500-rows ----
{
  const hs = ['PA', 'PB', 'PC', 'PP'], ns = ['n1', 'n2', 'n3'];
  const rows = Array.from({ length: 500 }, (_, i) => {
    const c = i % 12;
    return row(hs[Math.floor(c / 3)], ns[c % 3], 'any', i < 12 ? 'pass' : 'fail', i < 12 ? undefined : `d${i}`);
  });
  const expected = [];
  for (const h of ['PA', 'PB', 'PP', 'PC']) for (const n of ns) expected.push(crow(h, n, 0, 0, 0, null, T(1)));
  writeCase({
    name: 'ap46-500-rows',
    rules: ['R-AP10', 'R-AP66', 'R-AP46', 'R-AP41', 'R-RE13', 'R-IK2'],
    seed: dataset(),
    requests: [req(post(rows), { token: 'bot', now: T(1) })],
    responses: [ok(201, 12)],
    d1: [2],
    github: [JWKS_LOG],
    db: tsv([[COMPAT_Q, expected]]),
  });
}

// ---- E: ap10-bad-requests ----
{
  const good = row('PA', 'n1', 'any', 'pass');
  const goodBody = post([good]);
  const bad = (b, extra = {}) => req(b, { token: 'garbage', ...extra });
  const rows501 = Array.from({ length: 501 }, () => good);
  const base = JSON.stringify(post([row('PA', 'n1', 'any', 'fail', '')]));
  const pad = 262145 - Buffer.byteLength(base);
  const over = JSON.stringify(post([row('PA', 'n1', 'any', 'fail', 'x'.repeat(pad))]));
  if (Buffer.byteLength(over) !== 262145) throw new Error('over is ' + Buffer.byteLength(over));
  const badReq = prob(400, '/errors/bad-request');
  const lines = [
    bad('not json'),
    bad({}),
    bad({ rows: [], source: 'bot' }),
    bad(post([{ ...good, source: 'bot' }])),
    bad(post([{ nightly: good.nightly, target: 'any', result: 'pass', error_digest: null }])),
    bad(post([{ ...good, result: 'maybe' }])),
    bad(post([{ ...good, nightly: 'nightly-2026-02-30-aaaaaaa' }])),
    bad(post([{ ...good, hash: 'abc' }])),
    bad(post([], { nightly: N.n1.tag, target: 'x64glibc', upto_log_index: 1 })),
    bad('{"rows":[],"sweep":{"nightly":"' + N.n1.tag + '","target":"any","upto_log_index":18446744073709551615}}'),
    bad(post([], { nightly: N.n1.tag, target: 'any', upto_log_index: -1 })),
    bad(post(rows501)),
    bad(over),
    bad(post([...rows501.slice(0, 500).map(() => ({ ...good, hash: 'abc' })), good, good])),
    bad(''),
    { method: 'POST', path: '/v1/compat', headers: { 'content-type': 'text/plain' }, body: 'rows', token: 'garbage' },
    { method: 'GET', path: '/v1/compat', token: 'garbage' },
    // R-AP66 check 1 before 2 (Design Q144): a body of 262,145 bytes that is not JSON is 415, as POST /v1/closure.
    { method: 'POST', path: '/v1/compat', headers: { 'content-type': 'text/plain' }, body: 'x'.repeat(262145), token: 'garbage' },
    // R-AP66 check 3 before 5: no Authorization and no Talon-Contributor with 501 rows is 400 (R-CT1), not 413.
    req(post(rows501)),
  ];
  const tooLargeRows = prob(413, '/errors/too-large', { field: 'rows', limit: 500 });
  writeCase({
    name: 'ap10-bad-requests',
    rules: ['R-AP10', 'R-AP21', 'R-AP23', 'R-AP41', 'R-AP46', 'R-AP48', 'R-AP51', 'R-MX4', 'R-MX5', 'R-IK4', 'R-IK7', 'R-AP66', 'R-CT1'],
    seed: dataset(),
    requests: lines,
    responses: [
      badReq, badReq, badReq, badReq, badReq, badReq, badReq, badReq, badReq, badReq, badReq,
      tooLargeRows,
      prob(413, '/errors/too-large', { field: 'body', limit: 262144 }),
      tooLargeRows,
      badReq,
      prob(415, '/errors/unsupported-media-type'),
      { status: 405, headers: { allow: 'POST' }, problem: { type: '/errors/method-not-allowed' } },
      prob(415, '/errors/unsupported-media-type'),
      badReq,
    ],
    d1: lines.map(() => 0),
    github: [],
    db: tsv([['SELECT count(*) FROM compat', [[0]]], [SWEEPS_Q, []]]),
  });
}

// ---- F: ap10-auth ----
{
  const body = post([row('PA', 'n1', 'any', 'pass')]);
  writeCase({
    name: 'ap10-auth',
    rules: ['R-AP10', 'R-AP66', 'R-AP21', 'R-AP26', 'R-AP48', 'R-CT1', 'R-MX5', 'R-TP3', 'R-TP7', 'R-MX15'],
    seed: dataset(),
    requests: [
      req(body, { token: 'bot', now: T(1) }),
      req(body, { token: 'pub', now: T(2) }),
      req(body, { token: 'bad', now: T(3) }),
      req(body, { now: T(4) }),
      req(body, { token: 'garbage', now: T(5) }),
      req(body, { token: 'bot', now: T(6), headers: { 'talon-contributor': '0123456789abcdef0123456789abcdef' } }),
      req(post([row('PB', 'n1', 'any', 'pass')], undefined, { source: 'author' }), { token: 'bot', now: T(7) }),
    ],
    responses: [
      ok(201, 1),
      prob(403, '/errors/forbidden'),
      prob(401, '/errors/unauthenticated'),
      prob(400, '/errors/bad-request'),
      prob(401, '/errors/unauthenticated'),
      ok(200, 0),
      prob(400, '/errors/bad-request'),
    ],
    d1: [2, 0, 0, 0, 0, 2, 0],
    github: [JWKS_LOG],
    db: tsv([[COMPAT_Q, [crow('PA', 'n1', 0, 0, 0, null, T(1))]]]),
  });
}

// ---- G: ap10-404-and-targets ----
{
  const seed = [...dataset(), `INSERT INTO targets (target, name) VALUES (36, 'zzz');`, `INSERT INTO artifact_targets (artifact, target) VALUES (${H.PP.id}, 36);`];
  const r = (b, i) => req(b, { token: 'bot', now: T(i) });
  writeCase({
    name: 'ap10-404-and-targets',
    rules: ['R-AP10', 'R-AP21', 'R-AP41', 'R-AP48', 'R-AP56', 'R-MX10', 'R-IK7', 'R-RE20', 'R-RE21', 'R-RE13', 'R-AP66'],
    seed,
    requests: [
      r(post([row('PA', 'n1', 'any', 'pass'), row('PY', 'n1', 'any', 'pass')]), 1),
      r(post([row('PY', 'n1', 'x64glibc', 'pass')]), 2),
      r(post([row('PA', 'n1', 'any', 'pass'), row('PA', 'n1', 'x64glibc', 'pass')]), 3),
      r(post([row('PX', 'n1', 'x64glibc', 'pass')]), 4),
      r(post([row('PP', 'n1', 'x64mac', 'pass')]), 5),
      r(post([row('PP', 'n1', 'nosuch', 'pass')]), 6),
      r(post([row('PP', 'n1', 'x64glibc', 'pass'), row('PP', 'n1', 'wasm32', 'crash', 'link')]), 7),
      r(post([row('PP', 'n1', 'zzz', 'fail', 'e'), row('PP', 'n1', 'any', 'pass')]), 8),
      // R-AP66 checks 6 and 8 (Design Q142): the static checks of all rows come before the facts. A row 2 with a hash that is no hash is 400 also when row 1 is a 404.
      r(post([row('PY', 'n1', 'any', 'pass'), { ...row('PA', 'n1', 'any', 'pass'), hash: 'abc' }]), 9),
      // Row 1 is a 404, row 2 has a target 400 (a package with a real target): the 404 of row 1.
      r(post([row('PY', 'n1', 'any', 'pass'), row('PA', 'n1', 'x64glibc', 'pass')]), 10),
      // Row 1 is a target 400, row 2 is a 404: the 400 of row 1.
      r(post([row('PA', 'n1', 'x64glibc', 'pass'), row('PY', 'n1', 'any', 'pass')]), 11),
    ],
    responses: [
      prob(404, '/errors/not-found', { detail: `no artifact ${H.PY.b58}` }),
      prob(404, '/errors/not-found', { detail: `no artifact ${H.PY.b58}` }),
      prob(400, '/errors/bad-request'),
      prob(400, '/errors/bad-request'),
      prob(400, '/errors/bad-request'),
      prob(400, '/errors/bad-request'),
      ok(201, 2),
      ok(201, 2),
      prob(400, '/errors/bad-request'),
      prob(404, '/errors/not-found', { detail: `no artifact ${H.PY.b58}` }),
      prob(400, '/errors/bad-request'),
    ],
    d1: [1, 1, 1, 1, 1, 1, 2, 2, 0, 1, 1],
    github: [JWKS_LOG],
    db: tsv([[COMPAT_Q, [
      crow('PP', 'n1', 0, 0, 0, null, T(8)),
      crow('PP', 'n1', 8, 0, 0, null, T(7)),
      crow('PP', 'n1', 34, 0, 3, 'link', T(7)),
      crow('PP', 'n1', 36, 0, 1, 'e', T(8)),
    ]]]),
  });
}
console.log('115a cases written');
