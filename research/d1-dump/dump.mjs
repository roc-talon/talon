#!/usr/bin/env node
// Dump the data of a Talon registry D1 database to a SQL file (INSERT statements only).
// Usage, from worker/: node ../research/d1-dump/dump.mjs [--local|--remote] [--persist-to DIR] [--page N] [--snapshot-rows N] <binding> <out.sql>
// SQLite makes the text with quote(), so a 64-bit INTEGER is exact. wrangler JSON would write it as a float.
// The tool only runs SELECT statements. It never writes to the database.
import { spawnSync } from 'node:child_process'
import { writeFileSync } from 'node:fs'

// The order is the order of the inserts. See README.md for the reason of each place.
// mode: 'plain' is INSERT. 'replace' is INSERT OR REPLACE (a trigger already wrote the row, the dump value wins).
const TABLES = [
  ['names', 'plain'],
  ['artifacts', 'plain'],
  ['log', 'plain'], // before releases and toolchains (leaf triggers)
  ['repos', 'plain'],
  ['repo_events', 'plain'],
  ['repo_checks', 'plain'],
  ['contributors', 'plain'],
  ['links', 'plain'],
  ['deps', 'plain'],
  ['artifact_targets', 'plain'],
  ['releases', 'plain'], // needs log and names (releases_leaf_check)
  ['provenance', 'plain'],
  ['toolchains', 'plain'], // needs log (toolchains_leaf_check)
  ['compat', 'plain'], // before sweeps (sweeps_guard_*)
  ['contributions', 'plain'], // its trigger writes compat_hints and hint_days
  ['compat_hints', 'replace'],
  ['hint_days', 'replace'],
  ['contributor_totals', 'plain'],
  ['sweeps', 'plain'], // its trigger writes transitions
  ['transitions', 'replace'],
]
// The migrations make targets. wrangler makes the others.
const SKIP = new Set(['targets', 'd1_migrations', 'sqlite_sequence'])
const skipped = (name) => SKIP.has(name) || name.startsWith('_cf_') || name.startsWith('sqlite_')

const args = process.argv.slice(2)
let mode = '--local'
let persist = null
let page = 500
let snapshotRows = 5000
const pos = []
for (let i = 0; i < args.length; i++) {
  const a = args[i]
  if (a === '--local' || a === '--remote') mode = a
  else if (a === '--persist-to') persist = args[++i]
  else if (a === '--page') page = Number(args[++i])
  else if (a === '--snapshot-rows') snapshotRows = Number(args[++i])
  else pos.push(a)
}
if (pos.length !== 2 || !(page > 0)) {
  console.error('usage: node dump.mjs [--local|--remote] [--persist-to DIR] [--page N] [--snapshot-rows N] <binding> <out.sql>')
  process.exit(2)
}
const [binding, out] = pos

function queryAll(sql, tries = 4) {
  if (!/^\s*SELECT\b/i.test(sql)) throw new Error('read only: ' + sql.slice(0, 40))
  const flags = ['wrangler', 'd1', 'execute', binding, mode]
  if (persist) flags.push('--persist-to', persist)
  flags.push('--json', '--command', sql)
  const r = spawnSync('npx', flags, { encoding: 'utf8', maxBuffer: 1 << 30 })
  const text = r.stdout || ''
  const start = text.indexOf('[')
  let j
  try { j = JSON.parse(text.slice(start)) } catch { j = null }
  if (r.status !== 0 || !Array.isArray(j)) {
    const msg = (j && j.error && (j.error.text + ' ' + (j.error.notes || []).map((n) => n.text).join(' '))) || r.stderr || text
    // a read is safe to repeat: D1 gives a transient internal error now and then
    if (tries > 1) {
      console.error('wrangler call failed, trying again: ' + String(msg).replace(/\s+/g, ' ').slice(0, 160))
      spawnSync('sleep', ['3'])
      return queryAll(sql, tries - 1)
    }
    throw new Error('wrangler failed: ' + String(msg).slice(0, 500))
  }
  return j.map((x) => x.results)
}
const query = (sql) => queryAll(sql)[0]

const qi = (n) => '"' + n.replaceAll('"', '""') + '"'

// 1 tables and columns (D1 allows pragma_table_info only with a text literal, so one call for each table)
const tables = query(`SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name`).map((r) => r.name)
const cols = new Map()
for (const t of tables) {
  if (!TABLES.some(([n]) => n === t)) continue
  cols.set(t, query(`SELECT name AS c, pk, cid FROM pragma_table_info('${t.replaceAll("'", "''")}') ORDER BY cid`))
}
const known = new Set(TABLES.map((t) => t[0]))
for (const t of tables) {
  if (!known.has(t) && !skipped(t)) {
    console.error(`table ${t} is not in the dump order and not skipped: add it to TABLES in dump.mjs`)
    process.exit(1)
  }
}
for (const [t] of TABLES) {
  if (!cols.has(t)) {
    console.error(`table ${t} is missing in the database`)
    process.exit(1)
  }
}

const countsOf = () =>
  // one SELECT, because D1 limits the terms of a compound SELECT
  query('SELECT ' + TABLES.map(([t]) => `(SELECT count(*) FROM ${qi(t)}) AS ${qi(t)}`).join(', '))[0]

// 2 rows. Two modes:
//  snapshot: one wrangler call with one SELECT for each table. D1 runs the statements of one call as a batch in one
//            transaction, so the rows are one consistent state of a live database. Used when the tables are small
//            (at most snapshotRows rows in all).
//  paged:    LIMIT/OFFSET on the primary key, a few calls for each table. It returns null when a count changed during the
//            read (a live database: the caller tries again).
const insertExpr = (t, how) => {
  const cs = cols.get(t)
  const head = `${how === 'replace' ? 'INSERT OR REPLACE' : 'INSERT'} INTO ${qi(t)} (${cs.map((c) => qi(c.c)).join(', ')}) VALUES (`
  return `'${head.replaceAll("'", "''")}' || ` + cs.map((c) => `quote(${qi(c.c)})`).join(` || ', ' || `) + ` || ');'`
}
const orderOf = (t) => {
  const pk = cols.get(t).filter((c) => c.pk > 0).sort((a, b) => a.pk - b.pk)
  if (pk.length === 0) throw new Error(`table ${t} has no primary key`)
  return pk.map((c) => qi(c.c)).join(', ')
}
const HEADER = [
  '-- Talon registry data dump (research/d1-dump/dump.mjs). INSERT statements only, one for each row.',
  '-- Skipped: targets, d1_migrations, sqlite_sequence, _cf_* (the migrations make them).',
]

function snapshot() {
  const sets = queryAll(
    TABLES.map(([t, how]) => `SELECT ${insertExpr(t, how)} AS line FROM ${qi(t)} ORDER BY ${orderOf(t)}`).join('; '),
  )
  if (sets.length !== TABLES.length) throw new Error(`snapshot: ${sets.length} result sets for ${TABLES.length} tables`)
  const lines = [...HEADER]
  const counts = {}
  TABLES.forEach(([t], i) => {
    counts[t] = sets[i].length
    lines.push(`-- table ${t}: ${sets[i].length} rows`)
    for (const r of sets[i]) lines.push(r.line)
    console.error(`${t}: ${sets[i].length} rows`)
  })
  return { lines, counts }
}

function paged() {
  const before = countsOf()
  const lines = [...HEADER]
  for (const [t, how] of TABLES) {
    const expr = insertExpr(t, how)
    const order = orderOf(t)
    lines.push(`-- table ${t}: ${before[t]} rows`)
    let got = 0
    let size = page
    while (got < before[t]) {
      let rows
      try {
        rows = query(`SELECT ${expr} AS line FROM ${qi(t)} ORDER BY ${order} LIMIT ${size} OFFSET ${got}`)
      } catch (e) {
        if (size > 1) { size = Math.max(1, size >> 1); continue }
        throw e
      }
      if (rows.length === 0) break
      for (const r of rows) lines.push(r.line)
      got += rows.length
    }
    if (got !== before[t]) return null
    console.error(`${t}: ${got} rows`)
  }
  const after = countsOf()
  if (TABLES.some(([t]) => after[t] !== before[t])) return null
  return { lines, counts: before }
}

let result = null
const total = Object.values(countsOf()).reduce((a, b) => a + b, 0)
if (total <= snapshotRows) {
  console.error(`snapshot mode (${total} rows)`)
  result = snapshot()
} else {
  console.error(`paged mode (${total} rows): the database must not change during the read`)
  for (let n = 1; n <= 6 && !result; n++) {
    result = paged()
    if (!result) console.error(`a row count changed during the read (attempt ${n}), trying again`)
  }
}
if (!result) {
  console.error('the database changes too fast: no stable read in 6 attempts')
  process.exit(1)
}
writeFileSync(out, result.lines.join('\n') + '\n')
console.error(`wrote ${out}`)
