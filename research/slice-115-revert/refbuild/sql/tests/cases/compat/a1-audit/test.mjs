// R-AP40, R-MX13, R-RE8, R-MX16, R-AP67 (Design Q151): the statement `audit` on a small state (slice 115b).
import { compatSql, hexOf } from '../../../compat.mjs';

export default async function (b) {
  const fails = [];
  const sql = compatSql.audit();
  const show = (rows) => rows.map((r) => `${hexOf(r.hash).slice(0, 2)} ${r.nightly} ${r.target} ${r.pass_count}/${r.fail_count}/${r.crash_count}`);
  // 11 on t1 / any: 3+2 pass, 1 fail (total 6). 12 on t1 / x64glibc: 2 pass, 2 fail, 1 crash (total 5). 14 on t1 / any: 1/1/1 (total 3) and 12 on t1 / any: 0/3/0 (total 3):
  // equal totals, so the hash bytes decide (00 before 02). Out: (11, t2, any) has a bot row; (13, t1, x64glibc) is a tool build; (11, nightly 3) has no tag.
  const all = [
    '01 t1 any 5/1/0',
    '02 t1 x64glibc 2/2/1',
    '00 t1 any 1/1/1',
    '02 t1 any 0/3/0',
  ];
  const got = show(await b.all(sql, [100]));
  if (JSON.stringify(got) !== JSON.stringify(all)) fails.push(`audit 100 differs\n      expected ${JSON.stringify(all)}\n      got      ${JSON.stringify(got)}`);
  const two = show(await b.all(sql, [2]));
  if (JSON.stringify(two) !== JSON.stringify(all.slice(0, 2))) fails.push(`audit 2 differs: ${JSON.stringify(two)}`);
  const none = await b.all(sql, [0]);
  if (none.length !== 0) fails.push(`audit 0 gives ${none.length} rows`);
  // A bot row removes a pair: (12, t1, any) gets one.
  await b.run('INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index) VALUES (12, 1, 0, 0, 0, NULL, 1790000000000, NULL)', []);
  const after = show(await b.all(sql, [100]));
  if (JSON.stringify(after) !== JSON.stringify(all.slice(0, 3))) fails.push(`audit after a bot row differs: ${JSON.stringify(after)}`);
  return fails;
}
