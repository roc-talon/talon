// The SQL of the closure query (Registry R-AP16 to R-AP18, slice 110) for the W1 cases of sql/tests/cases/closure/.
// The Worker embeds the same files (worker/sql/closure/*.sql). The statement `<name>` is the text of `prefix.sql`, a newline, and the text of `<name>.sql`.
// All statements take the same 4 parameters: ?1 the groups (JSON text), ?2 the hashes (JSON text), ?3 the nightly id of `compilers.from` or NULL,
// ?4 the nightly id of `compilers.to` or NULL. The columns of each statement are in docs/slices/110-closure.md section 4.
// Env: CLOSURE_SQL_DIR (another dir of the same files, for the private reference and its mutations).
import { readFileSync, existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..');

// The statements of the one batch, in this order (R-AP18: one D1 call).
export const STATEMENTS = ['artifacts', 'deps', 'targets', 'releases', 'unknown', 'epochs', 'runs', 'nearest', 'hints', 'checked', 'repos', 'log_size'];

export function closureDir() { return process.env.CLOSURE_SQL_DIR ?? join(root, 'worker', 'sql', 'closure'); }

// { name: statement text } for each of STATEMENTS. Throws when a file is missing.
export function closureSql() {
  const dir = closureDir();
  const read = (name) => {
    const p = join(dir, `${name}.sql`);
    if (!existsSync(p)) throw new Error(`the closure SQL is missing: ${p}`);
    return readFileSync(p, 'utf8');
  };
  const prefix = read('prefix');
  return Object.fromEntries(STATEMENTS.map((s) => [s, `${prefix}\n${read(s)}`]));
}

// The parameters. groups: [{form, lo, hi}] as JSON text (the caller writes 64-bit values as JSON numbers in the text). hashes: JSON text.
export function params(groupsJson, hashesJson, from, to) { return [groupsJson, hashesJson, from ?? null, to ?? null]; }

// A BLOB cell (a hash: names.value) as upper-case hex, so that node:sqlite (Uint8Array) and local D1 (an array of bytes) give one text.
const cell = (v) => {
  if (v instanceof ArrayBuffer) v = new Uint8Array(v);
  if (v instanceof Uint8Array || Array.isArray(v)) return [...v].map((x) => x.toString(16).toUpperCase().padStart(2, '0')).join('');
  return v;
};

// Run all statements in one batch. Gives { name: rows } with plain objects. A BLOB cell is hex (above).
export async function runBatch(b, p) {
  const sql = closureSql();
  const out = await b.batchAll(STATEMENTS.map((s) => ({ sql: sql[s], params: p })));
  return Object.fromEntries(STATEMENTS.map((s, i) => [s, out[i].map((r) => Object.fromEntries(Object.entries(r).map(([k, v]) => [k, cell(v)])))]));
}

// Compare 2 lists of rows as JSON, in order. Gives the failure texts.
export function sameRows(what, want, got) {
  const a = JSON.stringify(want), g = JSON.stringify(got);
  return a === g ? [] : [`${what}: rows differ\n      expected: ${a}\n      got:      ${g}`];
}
