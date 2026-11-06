// Makes the W2 cases of slice 116 (the user hint path of POST /v1/compat) in worker/tests/cases/hints/. Run: node gen_116.mjs
// No Roc code and no id from the Worker: node crypto only. The expected answers and rows of the case ct4-hint-batch come from the independent model `Sim` below (a JS oracle of R-CT4, R-CT14).
import { createHmac } from 'node:crypto';
import { N, H, G, dataset, writeCase, tsv, b58, rep, nameId, hex, nightlyId, JSON_CT } from './lib.mjs';

const KEY = 'test-contributor-key';
const SETTINGS = { CONTRIBUTOR_KEY: KEY };
const D = 1767225600000; // 2026-01-01T00:00:00Z, day 20454 (the default clock of the runner)
const DAY = 86400000;
const T = (i) => D + i * 1000;
const M = { m1: '0123456789abcdef0123456789abcdef', m2: 'fedcba9876543210fedcba9876543210', m3: '00000000000000000000000000000000', m4: 'ffffffffffffffffffffffffffffffff' };
const cid = (m) => BigInt.asIntN(64, createHmac('sha256', KEY).update(m, 'utf8').digest().readBigUInt64BE(0) | (1n << 63n));
const ACCOUNT = 4242n;
const code = { any: 0, x64mac: 1, x64glibc: 8, wasm32: 34 };
const TV = { '0.4.1': 17180000255n, '1.2.3': 281483566907391n, '0.5.0-rc.1': 21474844191n, '0.3.0': 12884967423n };
const TAGS = ['v0.4.1', 'v0.5.0-rc.1', 'v1.2.3', 'v0.3.0'];
const tagsBody = JSON.stringify(TAGS.map((name) => ({ name, zipball_url: `https://example.invalid/${name}`, commit: { sha: 'abc' } }))) + '\n';
const TAGS_FILE = 'github/api.github.com/repos/roc-talon/talon/tags%3Fper_page=100';
const TAGS_LOG = 'GET https://api.github.com/repos/roc-talon/talon/tags?per_page=100';

// Extra nightlies and rows. n0: published 2024-01-05, older than a year at the default clock (R-CT14 old-nightly). nx: a valid tag with no toolchains row.
const n0 = { tag: 'nightly-2024-01-05-ddddddd', published_at: Date.UTC(2024, 0, 5) };
n0.id = nightlyId(n0.tag);
const nx = { tag: 'nightly-2026-10-28-eeeeeee' };
nx.id = nightlyId(nx.tag);
const unknownHash = { b58: b58(rep(0x77)), id: nameId(1, rep(0x77)) };
const hashOf = { PA: H.PA, PB: H.PB, PC: H.PC, PP: H.PP, PX: H.PX };

function seed(extra = []) {
  const s = dataset();
  s.push(`INSERT INTO log (idx, grp, version, hash, time) VALUES (9, 'roc-lang/nightlies:linux_x86_64', '${n0.tag}', 'sha256:${n0.tag.replace(/\D/g, '').padEnd(64, 'e').slice(0, 64)}', 1790000000000);`);
  s.push(`INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, published_at, log_index) VALUES (${n0.id}, 'linux_x86_64', '${n0.tag}', 'roc_nightly-linux_x86_64.tar.gz', '${n0.tag.replace(/\D/g, '').padEnd(64, 'e').slice(0, 64)}', ${n0.published_at}, 9);`);
  // a bot row on (PB, n2, any), an author row on (PC, n1, any)
  s.push(`INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index) VALUES (${H.PB.id}, ${N.n2.id}, 0, 0, 0, NULL, 1767225000000, NULL);`);
  s.push(`INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index) VALUES (${H.PC.id}, ${N.n1.id}, 0, 1, 0, NULL, 1767225000000, 5);`);
  s.push(...extra);
  return s;
}
const LINK_SEED = [
  `INSERT INTO contributors (contributor, login, tokens_after, first_time, last_time) VALUES (${ACCOUNT}, 'octo', 0, 1767225000000, 1767225000000);`,
  `INSERT INTO links (machine, contributor, time) VALUES (${cid(M.m2)}, ${ACCOUNT}, 1767225000000);`,
];

// A hint row. `h` a key of H (or 'PU' for the unknown hash), `n` a key of N or 'n0' or 'nx', `t` the target name, `r` the result.
const nightlyOf = (n) => (n === 'n0' ? n0 : n === 'nx' ? nx : N[n]);
const hrow = (h, n, t, r) => ({ hash: h === 'PU' ? unknownHash.b58 : H[h].b58, nightly: nightlyOf(n).tag, target: t, result: r });
const hbody = (version, rows, extra = {}) => ({ talon_version: version, rows, ...extra });
const hreq = (machine, body, o = {}) => ({
  method: 'POST', path: '/v1/compat', headers: { ...JSON_CT, 'talon-contributor': machine, ...(o.headers ?? {}) },
  body: typeof body === 'string' ? body : JSON.stringify(body), ...(o.token === undefined ? {} : { token: o.token }), now: o.now ?? D,
});
const ans = (status, written, first, skipped) => ({ status, headers: { 'content-type': 'application/json', 'cache-control': 'no-store' }, body: `{"written":${written},"first":${first},"skipped":${JSON.stringify(skipped)}}` });
const bad = (status, type, more = {}) => ({ status, problem: { type, ...more } });

// ---- the oracle (R-CT4, R-CT14, R-RE12, R-RE13 row 3, R-RE16, R-RE24) ----
class Sim {
  constructor() {
    this.compat = new Set([`${H.PB.id}|${N.n2.id}|0|0`, `${H.PC.id}|${N.n1.id}|0|1`]); // key|source
    this.hints = new Map(); // pair -> { v: Map(version -> [pass, fail, crash, first, last]) }
    this.contrib = new Map(); // contributor|pair -> row
    this.days = new Map();
    this.links = new Map([[cid(M.m2).toString(), ACCOUNT]]);
    this.known = new Set(Object.values(hashOf).map((h) => h.id.toString()));
    this.nightlies = new Map([[N.n1.id, N.n1.published_at], [N.n2.id, N.n2.published_at], [N.n3.id, N.n3.published_at], [n0.id, n0.published_at]]);
  }
  reason(r, now) {
    const artifact = r.hash === unknownHash.b58 ? unknownHash.id : Object.values(hashOf).find((h) => h.b58 === r.hash).id;
    const nightly = Object.values({ ...N, n0, nx }).find((n) => n.tag === r.nightly).id;
    const target = code[r.target];
    if (!this.known.has(artifact.toString())) return { why: 'unknown-hash' };
    if (!this.nightlies.has(nightly)) return { why: 'unknown-nightly' };
    if (target === undefined) return { why: 'unknown-target' };
    if (this.compat.has(`${artifact}|${nightly}|${target}|0`)) return { why: 'bot-row' };
    if (this.nightlies.get(nightly) < now - 31536000000) return { why: 'old-nightly' };
    return { artifact, nightly, target };
  }
  // Returns { written, first, skipped }. quota: the limit of the day (default 200000): a row over it undoes the request (returns null).
  post(machine, version, rows, now, quota = 200000) {
    const cont = this.links.get(cid(machine).toString()) ?? cid(machine);
    const tv = TV[version] ?? 0n; // the tag list has the key for these versions only
    const sent = rows.map((r, i) => ({ i, ...this.reason(r, now), result: { pass: 0, fail: 1, crash: 3 }[r.result] }));
    const skipped = sent.filter((x) => x.why).map((x) => ({ row: x.i, reason: x.why }));
    const live = sent.filter((x) => !x.why);
    const pairs = new Set();
    for (const x of live) {
      const k = `${x.artifact}|${x.nightly}|${x.target}`;
      if (!this.compat.has(`${k}|0`) && !this.compat.has(`${k}|1`) && !this.hints.has(k)) pairs.add(k);
    }
    const snapshot = { hints: structuredClone([...this.hints]), contrib: new Map(this.contrib), days: new Map(this.days) };
    let written = 0;
    for (const x of live) {
      const pk = `${x.artifact}|${x.nightly}|${x.target}`;
      const ck = `${cont}|${pk}`;
      if (this.contrib.has(ck)) continue;
      this.contrib.set(ck, { cont, artifact: x.artifact, nightly: x.nightly, target: x.target, result: x.result, tv, time: now });
      const h = this.hints.get(pk) ?? { v: new Map() };
      const c = h.v.get(tv) ?? [0, 0, 0, now, now];
      c[x.result === 0 ? 0 : x.result === 1 ? 1 : 2] += 1;
      c[4] = Math.max(c[4], now);
      h.v.set(tv, c);
      this.hints.set(pk, h);
      const day = Math.floor(now / DAY);
      this.days.set(day, (this.days.get(day) ?? 0) + 1);
      written++;
      if (this.days.get(day) > quota) { // RAISE(ABORT, 'hint-quota'): the whole batch is undone
        this.hints = new Map(snapshot.hints);
        this.contrib = snapshot.contrib;
        this.days = snapshot.days;
        return null;
      }
    }
    return { written, first: pairs.size, skipped };
  }
  contribRows() {
    const nameOf = (id) => Object.values(hashOf).find((h) => h.id === id);
    return [...this.contrib.values()]
      .map((c) => ({ ...c, byte: nameOf(c.artifact).byte }))
      .sort((a, b) => a.byte - b.byte || (a.cont < b.cont ? -1 : a.cont > b.cont ? 1 : 0) || a.nightly - b.nightly || a.target - b.target)
      .map((c) => [hex([c.byte]).toUpperCase(), c.cont, c.nightly, c.target, c.result, c.tv, c.time]);
  }
  hintRows() {
    const out = [];
    for (const [pk, h] of this.hints) {
      const [a, n, t] = pk.split('|');
      const byte = Object.values(hashOf).find((x) => x.id.toString() === a).byte;
      for (const [tv, c] of h.v) out.push({ byte, n: Number(n), t: Number(t), tv, row: [hex([byte]).toUpperCase(), Number(n), Number(t), tv, c[0], c[1], c[2], c[3], c[4]] });
    }
    return out.sort((x, y) => x.byte - y.byte || x.n - y.n || x.t - y.t || (x.tv < y.tv ? -1 : x.tv > y.tv ? 1 : 0)).map((x) => x.row);
  }
  dayRows() { return [...this.days].sort((a, b) => a[0] - b[0]).map(([d, c]) => [d, c]); }
}

const CONTRIB_Q = 'SELECT hex(substr(n.value, 1, 1)) AS h, CAST(c.contributor AS TEXT) AS contributor, c.nightly, c.target, c.result, CAST(c.talon_version AS TEXT) AS talon_version, c.time FROM contributions c JOIN names n ON n.id = c.artifact ORDER BY n.value, c.contributor, c.nightly, c.target';
const HINTS_Q = 'SELECT hex(substr(n.value, 1, 1)) AS h, x.nightly, x.target, CAST(x.talon_version AS TEXT) AS talon_version, x.pass_count, x.fail_count, x.crash_count, x.first_time, x.last_time FROM compat_hints x JOIN names n ON n.id = x.artifact ORDER BY n.value, x.nightly, x.target, x.talon_version';
const DAYS_Q = 'SELECT day, counted FROM hint_days ORDER BY day';
const COMPAT_COUNT_Q = 'SELECT source, count(*) FROM compat GROUP BY source ORDER BY source';
const dbOf = (sim) => tsv([[CONTRIB_Q, sim.contribRows()], [HINTS_Q, sim.hintRows()], [DAYS_Q, sim.dayRows()], [COMPAT_COUNT_Q, [[0, 1], [1, 1]]]]);
const files = (extra = {}) => ({ [TAGS_FILE]: tagsBody, ...extra });

// ---- A: ct4-hint-batch ----
{
  const sim = new Sim();
  const requests = [];
  const responses = [];
  const d1 = [];
  const step = (machine, version, rows, i, o = {}) => {
    const now = T(i);
    const r = sim.post(machine, version, rows, now);
    requests.push(hreq(machine, hbody(version, rows), { now, ...o }));
    responses.push(ans(r.written > 0 ? 201 : 200, r.written, r.first, r.skipped));
    d1.push(rows.length === 0 ? 0 : 2);
  };
  const big = [
    hrow('PA', 'n1', 'any', 'pass'), // 0 written, first
    hrow('PP', 'n1', 'x64glibc', 'fail'), // 1 written, first (a smoke build of a platform)
    hrow('PX', 'n1', 'wasm32', 'crash'), // 2 written, first (a tool app build)
    hrow('PU', 'n1', 'any', 'pass'), // 3 unknown-hash
    hrow('PA', 'nx', 'any', 'pass'), // 4 unknown-nightly
    hrow('PX', 'n1', 'nonesuch', 'pass'), // 5 unknown-target
    hrow('PB', 'n2', 'any', 'pass'), // 6 bot-row
    hrow('PA', 'n0', 'any', 'pass'), // 7 old-nightly
    hrow('PC', 'n1', 'any', 'pass'), // 8 written, not first (an author row exists)
    hrow('PA', 'n1', 'any', 'fail'), // 9 same pair as row 0: the key conflicts, not written, not skipped
    hrow('PU', 'n1', 'x64glibc', 'pass'), // 10 unknown-hash (a real target of an unknown hash is no 400)
    hrow('PU', 'nx', 'any', 'pass'), // 11 unknown-hash before unknown-nightly
    hrow('PX', 'nx', 'nonesuch', 'pass'), // 12 unknown-nightly before unknown-target
  ];
  step(M.m1, '0.4.1', big, 1);
  step(M.m1, '0.4.1', big, 2); // again: written 0, first 0, the same skipped
  step(M.m2, '0.4.1', [hrow('PA', 'n1', 'any', 'pass'), hrow('PB', 'n1', 'any', 'pass')], 3); // the machine of an account: the pair of PA has a hint, PB n1 is first
  step(M.m1, '0.5.0-rc.1', [hrow('PA', 'n1', 'any', 'pass')], 4); // the same contributor, the same pair: 200, nothing counted for the other version
  step(M.m3, '0.5.0-rc.1', [hrow('PA', 'n1', 'any', 'crash')], 5); // another version of the same pair is another compat_hints row
  step(M.m3, 'banana', [hrow('PB', 'n1', 'any', 'fail')], 6); // not a release of Talon: the key 0
  step(M.m3, '0.4.1', [], 7); // no row: no D1 call
  // a token wins over the contributor header (Design Q146): a garbage token is 401, nothing written
  requests.push(hreq(M.m1, hbody('0.4.1', [{ ...hrow('PA', 'n3', 'any', 'pass'), error_digest: null }]), { token: 'garbage', now: T(8) })); // a body that the bot path accepts, so the token check is the first fault
  responses.push(bad(401, '/errors/unauthenticated'));
  d1.push(0);
  writeCase({
    name: 'ct4-hint-batch',
    rules: ['R-AP10', 'R-AP41', 'R-AP48', 'R-AP70', 'R-CT1', 'R-CT2', 'R-CT3', 'R-CT4', 'R-CT12', 'R-CT14', 'R-MX5', 'R-MX6', 'R-RE12', 'R-RE13', 'R-RE16', 'R-RE24', 'R-IK2', 'R-IK5', 'R-IK7'],
    seed: seed(LINK_SEED), settings: SETTINGS, tokenSpecs: { garbage: { raw: 'not-a-jwt' } },
    requests, responses, d1, db: dbOf(sim), github: [TAGS_LOG], files: files(),
  });
}

// ---- B: ct2-bad-requests ----
{
  const good = hrow('PA', 'n1', 'any', 'pass');
  const body = (rows, extra) => hbody('0.4.1', rows, extra);
  const reqs = [];
  const add = (label, machine, b, calls, status, type, o = {}) => reqs.push({ label, machine, b, calls, status, type, o });
  add('id upper case', 'FEDCBA9876543210FEDCBA9876543210', body([good]), 0, 400, '/errors/bad-request');
  add('id 31', M.m1.slice(1), body([good]), 0, 400, '/errors/bad-request');
  add('id 33', `${M.m1}0`, body([good]), 0, 400, '/errors/bad-request');
  add('id not hex', 'zzzz456789abcdef0123456789abcdef', body([good]), 0, 400, '/errors/bad-request');
  add('id empty', '', body([good]), 0, 400, '/errors/bad-request');
  add('garbage body', M.m1, 'not json', 0, 400, '/errors/bad-request');
  add('body over 256 KB, bad id', 'xyz', '{"p":"' + 'x'.repeat(262145) + '"}', 0, 413, '/errors/too-large', { json: { field: 'body', limit: 262144 } });
  add('body over 256 KB as text/plain: 415 before 413', M.m1, 'x'.repeat(262145), 0, 415, '/errors/unsupported-media-type', { headers: { 'content-type': 'text/plain' } });
  add('bad id and a body that is not JSON: the id first', 'xyz', 'not json', 0, 400, '/errors/bad-request');
  add('501 rows, bad id', 'xyz', body(Array(501).fill(good)), 0, 400, '/errors/bad-request');
  add('501 rows', M.m1, body(Array(501).fill(good)), 0, 413, '/errors/too-large', { json: { field: 'rows', limit: 500 } });
  add('501 bad rows', M.m1, body(Array(501).fill({ ...good, hash: 'abc' })), 0, 413, '/errors/too-large', { json: { field: 'rows', limit: 500 } });
  add('error_digest text', M.m1, body([{ ...good, error_digest: 'boom' }]), 0, 400, '/errors/bad-request');
  add('error_digest null', M.m1, body([{ ...good, error_digest: null }]), 0, 400, '/errors/bad-request');
  add('source in a row', M.m1, body([{ ...good, source: 'bot' }]), 0, 400, '/errors/bad-request');
  add('source in the body', M.m1, body([good], { source: 'bot' }), 0, 400, '/errors/bad-request');
  add('sweep in the body', M.m1, body([good], { sweep: { nightly: N.n1.tag, target: 'any', upto_log_index: 3 } }), 0, 400, '/errors/bad-request');
  add('hang', M.m1, body([{ ...good, result: 'hang' }]), 0, 400, '/errors/bad-request');
  add('unknown result', M.m1, body([{ ...good, result: 'maybe' }]), 0, 400, '/errors/bad-request');
  add('bad hash', M.m1, body([{ ...good, hash: 'abc' }]), 0, 400, '/errors/bad-request');
  add('bad nightly', M.m1, body([{ ...good, nightly: 'nightly-2026-10-21' }]), 0, 400, '/errors/bad-request');
  add('no talon_version', M.m1, { rows: [good] }, 0, 400, '/errors/bad-request');
  add('talon_version null', M.m1, { talon_version: null, rows: [good] }, 0, 400, '/errors/bad-request');
  add('no rows', M.m1, { talon_version: '0.4.1' }, 0, 400, '/errors/bad-request');
  add('good rows and one hang', M.m1, body([good, hrow('PB', 'n1', 'any', 'fail'), hrow('PC', 'n1', 'any', 'pass'), { ...good, result: 'hang' }]), 0, 400, '/errors/bad-request');
  add('package with a real target', M.m1, body([hrow('PA', 'n1', 'x64glibc', 'pass')]), 1, 400, '/errors/bad-request');
  add('package with a name that has no code', M.m1, body([hrow('PA', 'n1', 'nonesuch', 'pass')]), 1, 400, '/errors/bad-request');
  add('platform with a target it does not build', M.m1, body([hrow('PP', 'n1', 'x64mac', 'pass')]), 1, 400, '/errors/bad-request');
  add('good rows and one package target', M.m1, body([good, hrow('PX', 'n1', 'wasm32', 'crash'), hrow('PA', 'n1', 'wasm32', 'pass')]), 1, 400, '/errors/bad-request');
  // a last good request: the rules pass, so the 400 above are not a broken setup
  add('good', M.m1, body([good]), 2, 201, null);
  const rq = [], rs = [], d1 = [];
  reqs.forEach((r, i) => {
    rq.push(hreq(r.machine, r.b, { now: T(i + 1), headers: r.o.headers }));
    if (r.label === 'good') rs.push(ans(201, 1, 1, []));
    else rs.push({ status: r.status, ...(r.o.json ? { json: r.o.json } : {}), problem: { type: r.type } });
    d1.push(r.calls);
  });
  const sim = new Sim();
  sim.post(M.m1, '0.4.1', [good], T(reqs.length), 200000);
  writeCase({
    name: 'ct2-bad-requests',
    rules: ['R-AP10', 'R-AP46', 'R-AP48', 'R-AP51', 'R-AP70', 'R-CT1', 'R-CT2', 'R-MX5', 'R-MX6', 'R-IK2', 'R-IK4', 'R-IK7'],
    seed: seed(), settings: SETTINGS, requests: rq, responses: rs, d1, db: dbOf(sim), github: [TAGS_LOG], files: files(),
  });
}

// ---- C: ct12-talon-version ----
{
  const sim = new Sim();
  const rq = [], rs = [], d1 = [];
  const step = (machine, version, rows, i) => {
    const r = sim.post(machine, version, rows, T(i));
    rq.push(hreq(machine, hbody(version, rows), { now: T(i) }));
    rs.push(ans(r.written > 0 ? 201 : 200, r.written, r.first, r.skipped));
    d1.push(2);
  };
  step(M.m1, '0.4.1', [hrow('PA', 'n1', 'any', 'pass')], 1);
  step(M.m1, '1.2.3', [hrow('PA', 'n2', 'any', 'pass')], 2);
  step(M.m1, '0.5.0-rc.1', [hrow('PA', 'n3', 'any', 'fail')], 3);
  step(M.m1, '0.4.2', [hrow('PB', 'n1', 'any', 'pass')], 4);
  step(M.m3, 'v0.4.1', [hrow('PB', 'n1', 'any', 'pass')], 5);
  step(M.m4, '', [hrow('PB', 'n1', 'any', 'crash')], 6);
  step(M.m1, 'banana', [hrow('PB', 'n2', 'any', 'pass')], 7);
  step(M.m1, '0.3.0', [hrow('PB', 'n3', 'any', 'pass')], 8); // a tag in the list, a release of Talon
  writeCase({
    name: 'ct12-talon-version',
    rules: ['R-CT12', 'R-RE12', 'R-RE13', 'R-IK5', 'R-AP41', 'R-AP70'],
    seed: seed(), settings: SETTINGS, requests: rq, responses: rs, d1, db: dbOf(sim), github: [TAGS_LOG], files: files(),
  });
}

// ---- D: ct12-tags-fail (R-CT12, Design Q178) ----
{
  const sim = new Sim();
  const rq = [], rs = [], d1 = [];
  // request 1: the tag list is not readable (status 500): the request still works and stores the key 0. Request 2: the list is read again (nothing was kept), now it is good.
  const r1 = sim.post(M.m1, 'banana', [hrow('PA', 'n1', 'any', 'pass')], T(1)); // the oracle gets a text with no key: 0
  rq.push(hreq(M.m1, hbody('0.4.1', [hrow('PA', 'n1', 'any', 'pass')]), { now: T(1) }));
  rs.push(ans(201, r1.written, r1.first, r1.skipped));
  const r2 = sim.post(M.m1, '0.4.1', [hrow('PA', 'n2', 'any', 'pass')], T(2));
  rq.push(hreq(M.m1, hbody('0.4.1', [hrow('PA', 'n2', 'any', 'pass')]), { now: T(2) }));
  rs.push(ans(201, r2.written, r2.first, r2.skipped));
  const r3 = sim.post(M.m1, '0.4.1', [hrow('PA', 'n3', 'any', 'pass')], T(3));
  rq.push(hreq(M.m1, hbody('0.4.1', [hrow('PA', 'n3', 'any', 'pass')]), { now: T(3) }));
  rs.push(ans(201, r3.written, r3.first, r3.skipped));
  d1.push(2, 2, 2);
  const db = dbOf(sim);
  writeCase({
    name: 'ct12-tags-fail',
    rules: ['R-CT12', 'R-RE12', 'R-AP70'],
    seed: seed(), settings: SETTINGS, requests: rq, responses: rs, d1, db,
    github: [TAGS_LOG, TAGS_LOG],
    files: { [TAGS_FILE]: 'upstream failed\n', [`${TAGS_FILE}.meta.json`]: JSON.stringify({ status: 500 }) + '\n', [`${TAGS_FILE}.2`]: tagsBody, [`${TAGS_FILE}.2.meta.json`]: JSON.stringify({ status: 200 }) + '\n' },
  });
}

// ---- E: ct13-hint-quota ----
{
  const day1 = Math.floor(D / DAY);
  const sim = new Sim();
  sim.days.set(day1, 199999);
  const rq = [], rs = [], d1 = [];
  const post = (machine, rows, now, expectQuota, retry) => {
    const r = sim.post(machine, '0.4.1', rows, now);
    rq.push(hreq(machine, hbody('0.4.1', rows), { now }));
    if (r === null) rs.push({ status: 429, headers: { 'retry-after': String(retry) }, problem: { type: '/errors/rate-limited' } });
    else rs.push(ans(r.written > 0 ? 201 : 200, r.written, r.first, r.skipped));
    d1.push(2);
  };
  const noon = D + 43200000;
  post(M.m1, [hrow('PA', 'n1', 'any', 'pass'), hrow('PB', 'n1', 'any', 'pass')], noon, true, 43200); // the second row is over the limit: the whole request is undone
  post(M.m1, [hrow('PA', 'n1', 'any', 'pass')], noon + 1000, false); // the last row of the day
  post(M.m1, [hrow('PB', 'n1', 'any', 'pass')], D + 86399500, true, 1); // over the limit: 429, Retry-After 1 s
  post(M.m1, [hrow('PA', 'n1', 'any', 'pass'), hrow('PU', 'n1', 'any', 'pass')], noon + 2000, false); // a conflict row and a skipped row count nothing: 200 at the limit
  post(M.m1, [hrow('PB', 'n1', 'any', 'pass')], D + DAY, false); // the next day: a new counter, 201
  const day = (n) => `INSERT INTO hint_days (day, counted) VALUES (${n}, 199999);`;
  writeCase({
    name: 'ct13-hint-quota',
    rules: ['R-CT13', 'R-CT4', 'R-AP25', 'R-AP41', 'R-AP70', 'R-RE24', 'R-MX9'],
    seed: seed([day(day1)]), settings: SETTINGS, requests: rq, responses: rs, d1, db: dbOf(sim), github: [TAGS_LOG], files: files(),
  });
}

// ---- F: ap45-client-version (slice 116b) ----
{
  const ua = (v) => ({ 'user-agent': v });
  const empty = hbody('0.4.1', []);
  const rq = [], rs = [], d1 = [];
  const add = (request, response, calls) => { rq.push(request); rs.push(response); d1.push(calls); };
  const unsupported = (min) => ({ status: 400, problem: { type: '/errors/unsupported-client', minimum: min } });
  const hint = (agent, body = empty, headers = {}) => hreq(M.m1, body, { headers: { ...ua(agent), ...headers }, now: T(rq.length + 1) });
  add(hint('tln/0.4.1'), unsupported('0.5.0'), 0); // MIN_TLN_WRITE
  add(hint('tln/0.4.1 (linux)'), unsupported('0.5.0'), 0); // the first product is read (Design Q184)
  add(hint('tln/0.5.0 (linux)'), ans(200, 0, 0, []), 0);
  add(hint('tln/0.5.0'), ans(200, 0, 0, []), 0); // equal is good
  add(hint('tln/0.10.0'), ans(200, 0, 0, []), 0); // numbers, not text
  add(hint('curl/8.4.0'), ans(200, 0, 0, []), 0); // not a tln agent
  add(hreq(M.m1, empty, { now: T(5) }), ans(200, 0, 0, []), 0); // no User-Agent
  add({ method: 'GET', path: '/v1/toolchains', headers: ua('tln/0.4.1'), now: T(6) }, { status: 200 }, 1); // a read: MIN_TLN is 0.3.0
  add({ method: 'GET', path: '/v1/toolchains', headers: ua('tln/0.2.9'), now: T(7) }, unsupported('0.3.0'), 0); // MIN_TLN covers every route
  add(hint('tln/0.4.1', 'plain text', { 'content-type': 'text/plain' }), unsupported('0.5.0'), 0); // row 3 before the media type (row 5)
  add(hint('tln/0.4.1', '{"p":"' + 'x'.repeat(262145) + '"}'), unsupported('0.5.0'), 0); // row 3 before the size (row 4)
  add({ method: 'GET', path: '/v1/compat', headers: ua('tln/0.2.0'), now: T(10) }, { status: 405, problem: { type: '/errors/method-not-allowed' } }, 0); // rows 1 and 2 come first
  add({ method: 'GET', path: '/v1/nothing', headers: ua('tln/0.2.0'), now: T(11) }, { status: 404, problem: { type: '/errors/not-found' } }, 0);
  add(hint('tln/0.4.1', empty, { authorization: 'Bearer not-a-jwt' }), unsupported('0.5.0'), 0); // the bot path is checked for a tln agent too, before the token
  writeCase({
    name: 'ap45-client-version',
    rules: ['R-AP45', 'R-AP48', 'R-AP70', 'R-AP21', 'R-WH14'],
    seed: seed(), settings: { ...SETTINGS, MIN_TLN: '0.3.0', MIN_TLN_WRITE: '0.5.0' },
    requests: rq, responses: rs, d1,
  });
}

// ---- G: ct11-rate-limit (slice 116b) ----
{
  const ip = (a) => ({ 'cf-connecting-ip': a });
  const empty = hbody('0.4.1', []);
  const rq = [{ window_s: 60, need_ms: 25000 }], rs = [], d1 = []; // Miniflare counts in windows aligned to the wall clock: start when 25 s are left in the window
  const go = (machine, address, body = empty) => {
    rq.push(hreq(machine, body, { headers: address === null ? {} : ip(address), now: T(rq.length + 1) }));
  };
  const okEmpty = ans(200, 0, 0, []);
  const limited = { status: 429, headers: { 'retry-after': '60' }, problem: { type: '/errors/rate-limited' } };
  const add = (address, response, machine = M.m1, body = empty, calls = 0) => { go(machine, address, body); rs.push(response); d1.push(calls); };
  for (let i = 0; i < 3; i++) add('203.0.113.7', okEmpty); // the budget of one IPv4 address is 3 in this case (the real one is 30 a minute)
  add('203.0.113.7', limited);
  add('203.0.113.8', okEmpty); // another address has its own budget
  add('::ffff:203.0.113.7', limited); // an IPv4-mapped address is the IPv4 address
  for (let i = 0; i < 3; i++) add(`2001:db8:0:1::${i + 1}`, okEmpty); // 3 addresses of one /64 share one budget
  add('2001:db8:0:1:ffff:ffff:ffff:ffff', limited);
  add('2001:DB8:0:1::9', limited); // the same /64 in capitals
  add('2001:db8:0:2::1', okEmpty); // another /64
  // a request that fails the id check or the body does not use the budget of its address (R-AP70 rows 5 to 9, Design Q186)
  for (let i = 0; i < 4; i++) add('198.51.100.1', { status: 400, problem: { type: '/errors/bad-request' } }, 'xyz');
  add('198.51.100.1', { status: 400, problem: { type: '/errors/bad-request' } }, M.m1, 'not json');
  for (let i = 0; i < 3; i++) add('198.51.100.1', okEmpty);
  add('198.51.100.1', limited);
  // a request that gets to the limit counts, whatever its answer (Design Q186): 2 empty bodies, then a 400 of the read batch (a package with a real target), then 429
  add('198.51.100.2', okEmpty);
  add('198.51.100.2', okEmpty);
  add('198.51.100.2', { status: 400, problem: { type: '/errors/bad-request' } }, M.m1, hbody('0.4.1', [hrow('PA', 'n1', 'x64glibc', 'pass')]), 1);
  add('198.51.100.2', limited);
  for (let i = 0; i < 3; i++) add(null, okEmpty); // no address (Design Q185): one shared key
  add(null, limited);
  writeCase({
    name: 'ct11-rate-limit',
    rules: ['R-CT11', 'R-AP25', 'R-AP68', 'R-AP70', 'R-MX6', 'R-WH14'],
    seed: seed(), settings: SETTINGS, ratelimits: { RL_HINTS: { limit: 3, period: 60 } }, requests: rq, responses: rs, d1,
  });
}
// ---- H: ct14-old-nightly-edge (Design Q174, R-CT14, R-CT15) ----
{
  const now = T(1);
  const E = 31536000000;
  const mk = (tag, rows) => ({ tag, id: nightlyId(tag), rows }); // rows: [[target text, published_at], ...]
  const nA = mk('nightly-2025-03-01-a1a1a1a', [['linux_x86_64', now - E]]); // exactly at the edge: kept
  const nB = mk('nightly-2025-03-02-b2b2b2b', [['linux_x86_64', now - E - 1]]); // one ms older: old-nightly
  const nC = mk('nightly-2025-03-03-c3c3c3c', [['linux_x86_64', now - E - 1], ['macos_arm64', now - 1000]]); // two rows: the smaller decides: old-nightly
  const nE = mk('nightly-2025-03-04-e4e4e4e', [['linux_x86_64', now - 1000], ['macos_arm64', now - E]]); // two rows: the smaller is the edge: kept
  const extra = [];
  let idx = 20;
  for (const n of [nA, nB, nC, nE]) {
    for (const [target, at] of n.rows) {
      const sha = (n.tag.replace(/\D/g, '') + target.length).padEnd(64, 'f').slice(0, 64);
      extra.push(`INSERT INTO log (idx, grp, version, hash, time) VALUES (${idx}, 'roc-lang/nightlies:${target}', '${n.tag}', 'sha256:${sha}', 1790000000000);`);
      extra.push(`INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, published_at, log_index) VALUES (${n.id}, '${target}', '${n.tag}', 'roc_nightly-${target}.tar.gz', '${sha}', ${at}, ${idx});`);
      idx++;
    }
  }
  const r = (n) => ({ hash: H.PA.b58, nightly: n.tag, target: 'any', result: 'pass' });
  const rows = [r(nA), r(nB), r(nC), r(nE)];
  const row0 = (n) => [hex([H.PA.byte]).toUpperCase(), -6890997442180345381n, n.id, 0, 0, 17180000255n, now];
  const sorted = [nA, nE].sort((x, y) => x.id - y.id);
  writeCase({
    name: 'ct14-old-nightly-edge',
    rules: ['R-CT14', 'R-CT15', 'R-CT4', 'R-AP10', 'R-AP70', 'R-RE4'],
    seed: seed(extra), settings: SETTINGS,
    requests: [hreq(M.m1, hbody('0.4.1', rows), { now })],
    responses: [ans(201, 2, 2, [{ row: 1, reason: 'old-nightly' }, { row: 2, reason: 'old-nightly' }])],
    d1: [2],
    db: tsv([[CONTRIB_Q, sorted.map(row0)]]),
    github: [TAGS_LOG], files: files(),
  });
}
console.log('cases written');
