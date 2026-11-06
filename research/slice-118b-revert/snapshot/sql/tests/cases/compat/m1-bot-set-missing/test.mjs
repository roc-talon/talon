// R-MX11, R-MX8, R-MX9, R-RE8, R-MX16, R-IK2: the statement `missing` against the triggers and against an independent reference, on random states (slice 115a).
// Cases: 120 on sqlite and 8 on local D1 by default (the w1 budget of TW26), SLOW=1 gives 600 and 60, COMPAT_CASES=<n> sets the count.
import { compatSql, hexOf, makeRng, randomState, insertState, clearState, refMembers, hexOfArtifact } from '../../../compat.mjs';

const casesOf = (backend) => Number(process.env.COMPAT_CASES ?? (process.env.SLOW === '1' ? (backend === 'd1' ? 60 : 600) : backend === 'd1' ? 8 : 120));

export default async function (b) {
  const fails = [];
  const missingSql = compatSql.missing();
  const rnd = makeRng(115);
  let nonEmpty = 0, empty = 0;
  const n = casesOf(b.name);
  for (let c = 0; c < n; c++) {
    await clearState(b);
    const st = randomState(rnd);
    await insertState(b, st);
    // The nightly under test: one with toolchains rows, or (1 in 5) one with none. The bound: any log index up to the log size.
    const nightly = rnd(5) === 0 ? 9999 : st.nights[rnd(st.nights.length)].id;
    const bound = rnd(3) === 0 ? st.log_size : rnd(st.log_size + 1);
    // The bot rows: a random subset of the artifacts, and a random subset as author rows (they must not count).
    const bot = st.artifacts.filter(() => rnd(3) !== 0).map((a) => a.id);
    const author = st.artifacts.filter(() => rnd(3) === 0).map((a) => a.id);
    const rows = [
      ...bot.map((id) => `(${id}, ${nightly}, 0, 0, ${rnd(2)}, NULL, 1790000000000, NULL)`),
      ...author.map((id) => `(${id}, ${nightly}, 0, 1, ${rnd(2)}, NULL, 1790000000000, 1)`),
    ];
    if (rows.length > 0) await b.batch([{ sql: `INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index) VALUES ${rows.join(', ')} ON CONFLICT DO NOTHING`, params: [] }]);
    const hasBot = new Set(bot);
    const want = [...refMembers(st, nightly, bound)].filter((id) => !hasBot.has(id)).map((id) => hexOfArtifact(st, id)).sort();
    const label = `case ${c} nightly ${nightly} bound ${bound}/${st.log_size}`;
    const got = (await b.all(missingSql, [String(nightly), 0, bound])).map((r) => hexOf(r.hash));
    if (JSON.stringify(got) !== JSON.stringify(want)) fails.push(`${label}: missing differs\n      expected ${JSON.stringify(want)}\n      got      ${JSON.stringify(got)}`);
    // The bound NULL is the log size now.
    const atSize = (await b.all(missingSql, [String(nightly), 0, st.log_size])).map((r) => hexOf(r.hash));
    const viaNull = (await b.all(missingSql, [String(nightly), 0, null])).map((r) => hexOf(r.hash));
    if (JSON.stringify(atSize) !== JSON.stringify(viaNull)) fails.push(`${label}: the bound NULL is not the log size: ${JSON.stringify(viaNull)} against ${JSON.stringify(atSize)}`);
    // The trigger: the sweep insert (the upsert of R-MX8) raises sweep-incomplete if and only if the statement finds a missing member.
    let err = null;
    try {
      await b.run('INSERT INTO sweeps (nightly, target, upto_log_index, time) VALUES (?1, 0, ?2, 1790000000000) ON CONFLICT (nightly, target) DO UPDATE SET upto_log_index = excluded.upto_log_index, time = excluded.time WHERE excluded.upto_log_index > sweeps.upto_log_index', [String(nightly), bound]);
    } catch (e) { err = String(e.message ?? e); }
    if (got.length > 0) {
      nonEmpty++;
      if (err === null || !err.includes('sweep-incomplete')) fails.push(`${label}: ${got.length} members have no bot row, but the sweep gave ${err === null ? 'no error' : err.slice(0, 120)}`);
    } else {
      empty++;
      if (err !== null) fails.push(`${label}: no member is missing, but the sweep failed: ${err.slice(0, 120)}`);
    }
  }
  // The generator must make both kinds of case, else the test checks nothing.
  if (nonEmpty < n / 10 || empty < n / 10) fails.push(`the random states are not mixed: ${nonEmpty} with a missing member, ${empty} complete`);
  return fails;
}
