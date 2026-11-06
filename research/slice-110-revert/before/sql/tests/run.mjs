// The W1 runner (docs/registry/PLAN.md B): the SQL of the registry (sql/) on plain SQLite (node:sqlite) and on local D1 (Miniflare).
//   node sql/tests/run.mjs [filter ...]       run the cases whose name has a filter text; the self-test cases run too
// Env: MINIFLARE (the dir of the miniflare package, default: the one of the global wrangler of this node), JOBS (not used: the cases run in one process).
// A case is a dir `sql/tests/cases/<area>/<id>-<name>/` (the dir `sql/tests/selftest/<name>/` has cases that must fail):
//   setup.sql    optional. Statements that run after the migrations (`sql/0001_init.sql`, ... when they exist).
//   steps.sql    optional. Statements that run in order. The comment lines right before a statement are notes:
//                  -- params: [1, "a", null]       the values of the `?` of the statement (a 64-bit integer goes as text)
//                  -- expect-error: some text      the statement must fail, and the message must have this text
//                  -- batch: 3                     this statement and the next 2 are one batch (D1 `batch`, or BEGIN ... COMMIT on SQLite):
//                                                  all or nothing. `expect-error` of the first statement is the error of the batch.
//   expect.tsv   optional. Blocks: a line `@ SELECT ...` and then the rows that it must give, with the cells tab separated, NULL as \N,
//                in the order of the query. The queries run after the last step.
//   migrations   optional. One name prefix in each line, for example `0001`. Only the migration files whose name starts with a listed prefix run.
//                Default: all. A case of the tables (slice 102) lists `0001`, so the triggers of `0002_triggers.sql` do not change its data.
//   backends     optional. The backends of the case, one in each line (sqlite, d1). Default: both.
//   expect-fail  self-test cases only. One text in each line. The case must fail on each backend, and the failure must have each text.
// The output is one line for each case and backend: `PASS <backend> <case>` or `FAIL <backend> <case>` and the reasons. Exit 1 on a failure.
import { createRequire } from 'node:module';
import { readFileSync, readdirSync, existsSync, mkdtempSync, rmSync } from 'node:fs';
import { DatabaseSync } from 'node:sqlite';
import { basename, dirname, join } from 'node:path';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';
import { splitSql, migrationFiles, parseExpected, tsvOf } from './split.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const sqlDir = dirname(here);
const filters = process.argv.slice(2);
const runDir = mkdtempSync(join(tmpdir(), 'talon-w1-'));
process.env.TMPDIR = runDir;
process.on('exit', () => rmSync(runDir, { recursive: true, force: true }));

const read = (p) => (existsSync(p) ? readFileSync(p, 'utf8') : '');
const subdirs = (d) => (existsSync(d) ? readdirSync(d, { withFileTypes: true }).filter((e) => e.isDirectory()).map((e) => e.name).sort() : []);

// The cases: [{ name, dir, mustFail }].
const cases = [];
for (const area of subdirs(join(here, 'cases'))) for (const id of subdirs(join(here, 'cases', area, ''))) cases.push({ name: `${area}/${id}`, dir: join(here, 'cases', area, id), mustFail: false });
for (const id of subdirs(join(here, 'selftest'))) cases.push({ name: `selftest/${id}`, dir: join(here, 'selftest', id), mustFail: true });
const chosen = cases.filter((c) => filters.length === 0 || filters.some((f) => c.name.includes(f)));

const migrations = migrationFiles(sqlDir).map((f) => ({ name: basename(f), text: readFileSync(f, 'utf8') }));

// A backend gives `run(sql, params)` (the rows or nothing) and `rows(sql)` (arrays), and `close()`.
function sqliteBackend() {
  const db = new DatabaseSync(':memory:');
  return {
    name: 'sqlite',
    async run(sql, params) { db.prepare(sql).run(...params); },
    async batch(list) {
      db.exec('BEGIN');
      try { for (const s of list) db.prepare(s.sql).run(...s.params); db.exec('COMMIT'); } catch (e) { db.exec('ROLLBACK'); throw e; }
    },
    async rows(sql) { const st = db.prepare(sql); st.setReturnArrays(true); return st.all(); },
    async close() { db.close(); },
  };
}
const mfDir = process.env.MINIFLARE ?? join(dirname(dirname(process.execPath)), 'lib/node_modules/wrangler/node_modules/miniflare');
let Miniflare, convertV4MiniflareOptions;
try {
  ({ Miniflare, convertV4MiniflareOptions } = createRequire(import.meta.url)(mfDir));
} catch (e) {
  console.log(`FAIL w1: Miniflare is not at ${mfDir} (install wrangler 4 globally, or set MINIFLARE): ${e.message.split('\n')[0]}`);
  process.exit(1);
}
const d1Cases = chosen.filter((c) => (read(join(c.dir, 'backends')).trim() || 'sqlite\nd1').split('\n').includes('d1'));
const dbIds = Object.fromEntries(d1Cases.map((c, i) => [`C${i}`, `00000000-0000-4000-8000-${String(i).padStart(12, '0')}`]));
let mf = null;
if (d1Cases.length) {
  mf = new Miniflare(convertV4MiniflareOptions({
    modules: [{ type: 'ESModule', path: join(here, 'w1.js'), contents: 'export default { fetch() { return new Response("w1"); } }' }],
    modulesRoot: here,
    compatibilityDate: '2026-10-01',
    d1Databases: dbIds,
    d1Persist: join(runDir, 'd1'),
  }));
}
async function d1Backend(c) {
  const db = await mf.getD1Database(`C${d1Cases.indexOf(c)}`);
  return {
    name: 'd1',
    async run(sql, params) { await db.prepare(sql).bind(...params).run(); },
    async batch(list) { await db.batch(list.map((s) => db.prepare(s.sql).bind(...s.params))); },
    async rows(sql) { return (await db.prepare(sql).raw()); },
    async close() {},
  };
}

// Run one case on one backend. Gives the list of failure texts.
async function runCase(c, b) {
  const fails = [];
  try {
    const only = read(join(c.dir, 'migrations')).split('\n').map((l) => l.trim()).filter(Boolean);
    for (const m of migrations) if (only.length === 0 || only.some((p) => m.name.startsWith(p))) for (const s of splitSql(m.text)) await b.run(s.sql, []);
    for (const s of splitSql(read(join(c.dir, 'setup.sql')))) await b.run(s.sql, []);
    const steps = splitSql(read(join(c.dir, 'steps.sql')));
    for (let i = 0; i < steps.length; i++) {
      const s = steps[i];
      const paramsOf = (t) => JSON.parse((t.notes.find((n) => n.startsWith('params:')) ?? 'params: []').slice(7));
      const want = s.notes.find((n) => n.startsWith('expect-error:'))?.slice(13).trim();
      const size = Number(s.notes.find((n) => n.startsWith('batch:'))?.slice(6) ?? 0);
      let err = null;
      try {
        if (size > 0) {
          const group = steps.slice(i, i + size);
          if (group.length < size) throw new Error(`batch of ${size} statements, but only ${group.length} are left`);
          i += size - 1;
          await b.batch(group.map((t) => ({ sql: t.sql, params: paramsOf(t) })));
        } else await b.run(s.sql, paramsOf(s));
      } catch (e) { err = String(e.message ?? e); }
      if (want === undefined && err !== null) fails.push(`step "${s.sql.slice(0, 60)}": failed: ${err.slice(0, 200)}`);
      else if (want !== undefined && err === null) fails.push(`step "${s.sql.slice(0, 60)}": expected an error with "${want}", got none`);
      else if (want !== undefined && !err.includes(want)) fails.push(`step "${s.sql.slice(0, 60)}": expected an error with "${want}", got: ${err.slice(0, 200)}`);
    }
    for (const blk of parseExpected(read(join(c.dir, 'expect.tsv')))) {
      const got = tsvOf(await b.rows(blk.sql));
      if (got.join('\n') !== blk.rows.join('\n')) fails.push(`rows differ for "${blk.sql}":\n      expected: ${JSON.stringify(blk.rows)}\n      got:      ${JSON.stringify(got)}`);
    }
  } catch (e) {
    fails.push(`setup failed: ${String(e.message ?? e).slice(0, 300)}`);
  }
  return fails;
}

let failed = 0, passed = 0;
try {
  for (const c of chosen) {
    const names = (read(join(c.dir, 'backends')).trim() || 'sqlite\nd1').split('\n');
    for (const name of names) {
      const b = name === 'd1' ? await d1Backend(c) : sqliteBackend();
      const t0 = performance.now();
      const fails = await runCase(c, b);
      await b.close();
      let ok = fails.length === 0, why = fails;
      if (c.mustFail) {
        const want = read(join(c.dir, 'expect-fail')).split('\n').filter(Boolean);
        const text = fails.join('\n');
        const missing = want.filter((w) => !text.includes(w));
        ok = fails.length > 0 && missing.length === 0;
        why = fails.length === 0 ? ['the case passed, but it must fail'] : missing.map((w) => `the failure has no text "${w}"; it is:\n${text}`);
      }
      console.log(`${ok ? 'PASS' : 'FAIL'} ${name} ${c.name} (${(performance.now() - t0).toFixed(0)} ms)`);
      if (ok) passed++; else { failed++; for (const w of why) console.log(`    ${w}`); }
    }
  }
} finally {
  if (mf) await mf.dispose();
}
console.log(`w1: ${passed} passed, ${failed} failed`);
process.exit(failed ? 1 : 0);
