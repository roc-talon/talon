// R-AP39, R-MX11, R-MX8, R-MX16: the statements `members` and `missing` with the bound NULL (the log size now) against the independent reference (slice 115b).
// Cases: 120 on sqlite and 8 on local D1 by default, SLOW=1 gives 600 and 60, COMPAT_CASES=<n> sets the count.
import { compatSql, hexOf, makeRng, randomState, insertState, clearState, refMembers, hexOfArtifact } from '../../../compat.mjs';

const casesOf = (backend) => Number(process.env.COMPAT_CASES ?? (process.env.SLOW === '1' ? (backend === 'd1' ? 60 : 600) : backend === 'd1' ? 8 : 120));

export default async function (b) {
  const fails = [];
  const membersSql = compatSql.members();
  const missingSql = compatSql.missing();
  const rnd = makeRng(1150);
  for (let c = 0; c < casesOf(b.name); c++) {
    await clearState(b);
    const st = randomState(rnd);
    await insertState(b, st);
    const nightly = rnd(5) === 0 ? 9999 : st.nights[rnd(st.nights.length)].id;
    const bot = st.artifacts.filter(() => rnd(2) === 0).map((a) => a.id);
    if (bot.length > 0) await b.batch([{ sql: `INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index) VALUES ${bot.map((id) => `(${id}, ${nightly}, 0, 0, 0, NULL, 1790000000000, NULL)`).join(', ')}`, params: [] }]);
    const members = refMembers(st, nightly, st.log_size);
    const want = [...members].filter((id) => !bot.includes(id)).map((id) => hexOfArtifact(st, id)).sort();
    const label = `case ${c} nightly ${nightly}`;
    const count = await b.all(membersSql, [String(nightly), 0, null]);
    if (count.length !== 1 || Number(count[0].members) !== members.size) fails.push(`${label}: members expected ${members.size}, got ${JSON.stringify(count)}`);
    const got = (await b.all(missingSql, [String(nightly), 0, null])).map((r) => hexOf(r.hash));
    if (JSON.stringify(got) !== JSON.stringify(want)) fails.push(`${label}: missing differs\n      expected ${JSON.stringify(want)}\n      got      ${JSON.stringify(got)}`);
  }
  return fails;
}
