// Writes the expected files of the cases schema/s1-tables and schema/s2-targets, and the column table of the slice file.
//   node research/slice-102-revert/gen-shape.mjs [--md]
// The SPEC below is the contract of slice 102 (Registry 5, 5.1, and the proposals of the slice file section 5).
// It is written from the design and the prototypes, not from the reference schema: the reference and the SPEC are two
// separate texts, and a case that passes on the reference shows that they agree.
// Column code: `name:T` with T in I (INTEGER), T (TEXT), A (ANY). A `?` after T means NULL is allowed. `*n` marks the n-th key column.
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const TYPE = { I: 'INTEGER', T: 'TEXT', A: 'ANY' };

// [table, without rowid (1/0), columns]
const SPEC = [
  ['names', 0, 'id:I*1 kind:I value:A'],
  ['targets', 0, 'target:I*1 name:T'],
  ['artifacts', 0, 'artifact:I*1 kind:I exposes:T platform:I? roc_pin:T? size:I'],
  ['releases', 0, 'log_index:I*1 form:I version:I version_text:T artifact:I repo:I? url:T tag:T? roc_version:T? published_at:I yanked:I withdrawn:T? withdrawn_at:I?'],
  ['compat', 1, 'artifact:I*1 nightly:I*2 target:I*3 source:I*4 result:I error_digest:T? time:I log_index:I?'],
  ['toolchains', 1, 'nightly:I*1 target:T*2 tag:T asset_name:T sha256:T published_at:I log_index:I'],
  ['log', 0, 'idx:I*1 grp:T version:T hash:T time:I'],
  ['sweeps', 1, 'nightly:I*1 target:I*2 upto_log_index:I time:I'],
  ['transitions', 1, 'nightly:I*1 target:I*2 previous:I compared:I changed:I'],
  ['provenance', 0, 'release:I*1 via:I*2 claims:T? time:I'],
  ['repos', 0, 'repo:I*1 repository_id:I repository_owner_id:I state:I successor:I? state_at:I time:I'],
  ['repo_events', 0, 'repo:I*1 seq:I*2 action:I repository_id_before:I? repository_id_after:I? owner_id_before:I? owner_id_after:I? successor:I? claims:T? time:I'],
  ['repo_checks', 0, 'repo:I*1 etag:T? checked_at:I? next_check_at:I fail_count:I app_installed:I'],
  ['compat_hints', 1, 'artifact:I*1 nightly:I*2 target:I*3 talon_version:I*4 pass_count:I fail_count:I crash_count:I first_time:I last_time:I'],
  ['contributions', 1, 'contributor:I*1 artifact:I*2 nightly:I*3 target:I*4 result:I talon_version:I time:I'],
  ['contributors', 0, 'contributor:I*1 login:T tokens_after:I first_time:I last_time:I'],
  ['links', 0, 'machine:I*1 contributor:I time:I'],
  ['deps', 1, 'artifact:I*1 alias:T*2 dep:I form:I? version:I? version_text:T? url:T'],
  ['artifact_targets', 1, 'artifact:I*1 target:I*2'],
  ['hint_days', 0, 'day:I*1 counted:I'],
  ['contributor_totals', 0, 'contributor:I*1 counted:I first:I agreed:I disagreed:I unconfirmed:I first_time:I last_time:I'],
];
// [table, index name or null (null: the origin is not `c`), unique, origin, columns]
const INDEXES = [
  ['names', null, 1, 'u', 'kind,value'],
  ['targets', null, 1, 'u', 'name'],
  ['releases', null, 1, 'u', 'form,version,version_text'],
  ['releases', 'releases_artifact', 0, 'c', 'artifact,log_index'],
  ['compat', null, 1, 'pk', 'artifact,nightly,target,source'],
  ['compat', 'compat_artifact_target', 0, 'c', 'artifact,target,nightly'],
  ['compat', 'compat_nightly', 0, 'c', 'nightly,target,source,artifact'],
  ['toolchains', null, 1, 'pk', 'nightly,target'],
  ['sweeps', null, 1, 'pk', 'nightly,target'],
  ['transitions', null, 1, 'pk', 'nightly,target'],
  ['provenance', null, 1, 'pk', 'release,via'],
  ['repo_events', null, 1, 'pk', 'repo,seq'],
  ['compat_hints', null, 1, 'pk', 'artifact,nightly,target,talon_version'],
  ['contributions', null, 1, 'pk', 'contributor,artifact,nightly,target'],
  ['contributions', 'contributions_pair', 0, 'c', 'artifact,nightly,target,time'],
  ['contributions', 'contributions_nightly', 0, 'c', 'nightly'],
  ['deps', null, 1, 'pk', 'artifact,alias'],
  ['artifact_targets', null, 1, 'pk', 'artifact,target'],
];

const cols = (spec) => spec.split(' ').map((c) => {
  const m = /^(\w+):([ITA])(\?)?(?:\*(\d))?$/.exec(c);
  return { name: m[1], type: TYPE[m[2]], null: !!m[3], pk: m[4] ? Number(m[4]) : 0 };
});
const cmp = (a, b) => (a < b ? -1 : a > b ? 1 : 0);
const filt = `t.schema = 'main' AND t.type = 'table' AND t.name NOT GLOB 'sqlite_*' AND t.name NOT GLOB '_cf_*'`;

const lines = [];
lines.push(`@ SELECT t.name, t.ncol, t.wr, t.strict FROM pragma_table_list t WHERE ${filt} ORDER BY t.name`);
for (const [n, wr, c] of [...SPEC].sort((a, b) => cmp(a[0], b[0]))) lines.push(`${n}\t${cols(c).length}\t${wr}\t1`);
lines.push(`@ SELECT t.name, c.name, c.type, CASE WHEN c.pk > 0 THEN NULL ELSE c."notnull" END, c.pk, c.hidden FROM pragma_table_list t, pragma_table_xinfo(t.name) c WHERE ${filt} ORDER BY t.name, c.name`);
for (const [n, , c] of [...SPEC].sort((a, b) => cmp(a[0], b[0]))) {
  for (const x of cols(c).sort((a, b) => cmp(a.name, b.name))) lines.push([n, x.name, x.type, x.pk ? '\\N' : x.null ? 0 : 1, x.pk, 0].join('\t'));
}
lines.push(`@ SELECT t.name, CASE WHEN i.origin = 'c' THEN i.name END, i."unique", i.origin, (SELECT group_concat(x.name, ',') FROM (SELECT name FROM pragma_index_info(i.name) ORDER BY seqno) x) FROM pragma_table_list t, pragma_index_list(t.name) i WHERE ${filt} ORDER BY 1, 4, 5`);
for (const [t, n, u, o, c] of [...INDEXES].sort((a, b) => cmp(a[0], b[0]) || cmp(a[3], b[3]) || cmp(a[4], b[4]))) lines.push([t, n ?? '\\N', u, o, c].join('\t'));
lines.push(`@ SELECT count(*) FROM pragma_table_list t, pragma_foreign_key_list(t.name) f WHERE ${filt}`);
lines.push('0');

if (process.argv.includes('--md')) {
  const out = ['| Table | Rows | Column | Type | Null | Key |', '| --- | --- | --- | --- | --- | --- |'];
  for (const [n, wr, c] of SPEC) {
    cols(c).forEach((x, i) => out.push(`| ${i ? '' : '`' + n + '`'} | ${i ? '' : wr ? 'WITHOUT ROWID' : 'rowid'} | \`${x.name}\` | ${x.type} | ${x.pk ? 'no' : x.null ? 'yes' : 'no'} | ${x.pk ? (c.split(' ').filter((y) => y.includes('*')).length > 1 ? `key ${x.pk}` : 'key') : ''} |`));
  }
  console.log(out.join('\n'));
  process.exit(0);
}
writeFileSync(join(root, 'sql/tests/cases/schema/s1-tables/expect.tsv'), lines.join('\n') + '\n');

// s2: the targets rows. The names come from cli/lib/BuildTarget.roc (the list of R-IK7 codes 1 to 35).
const src = readFileSync(join(root, 'cli/lib/BuildTarget.roc'), 'utf8');
const names = [...src.slice(src.indexOf('names = ['), src.indexOf(']', src.indexOf('names = ['))).matchAll(/"([a-z0-9]+)"/g)].map((m) => m[1]);
if (names.length !== 35) throw new Error(`expected 35 target names, got ${names.length}`);
const t = ['@ SELECT target, name FROM targets ORDER BY target', '0\tany', ...names.map((n, i) => `${i + 1}\t${n}`),
  '36\triscv64',
  '@ SELECT count(*), count(DISTINCT name), min(target), max(target) FROM targets', '37\t37\t0\t36'];
writeFileSync(join(root, 'sql/tests/cases/schema/s2-targets/expect.tsv'), t.join('\n') + '\n');
