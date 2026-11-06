// Shared by the W1 runner (sql/tests/run.mjs) and the W2 runner (worker/tests/run.mjs).
//   splitSql(text)      the statements of an SQL text, in order, with the comment lines that stand before each one
//   migrationFiles(dir) the migration files of sql/: `0001_init.sql`, ... in name order
//   tsvOf(rows)         rows (arrays) as text lines, for the expected files (NULL is \N, tab and newline are escaped)
// D1 `exec` splits a text at each newline, and a trigger has `;` inside, so the runners run one statement at a time (`prepare(sql).run()`).
// A `;` ends a statement only outside quotes, outside comments and outside BEGIN ... END and CASE ... END.
import { readdirSync } from 'node:fs';
import { join } from 'node:path';

export function splitSql(text) {
  const out = [];
  let cur = '';
  let notes = [];
  let depth = 0;
  let i = 0;
  const n = text.length;
  const flush = () => {
    const sql = cur.trim();
    if (sql) out.push({ sql, notes });
    cur = '';
    notes = [];
  };
  while (i < n) {
    const c = text[i];
    if (c === "'" || c === '"' || c === '`') {
      const j = text.indexOf(c, i + 1);
      const end = j < 0 ? n : j + 1;
      cur += text.slice(i, end);
      i = end;
    } else if (c === '-' && text[i + 1] === '-') {
      const j = text.indexOf('\n', i);
      const end = j < 0 ? n : j;
      const line = text.slice(i + 2, end).trim();
      // A comment line before a statement (nothing of the statement read yet) is a note of the runner: `-- params: [..]`, `-- expect-error: text`.
      if (cur.trim() === '') notes.push(line);
      else cur += text.slice(i, end);
      i = end;
    } else if (c === '/' && text[i + 1] === '*') {
      const j = text.indexOf('*/', i + 2);
      const end = j < 0 ? n : j + 2;
      i = end;
    } else if (c === ';' && depth === 0) {
      flush();
      i++;
    } else if (/[A-Za-z_]/.test(c)) {
      let j = i;
      while (j < n && /[A-Za-z0-9_]/.test(text[j])) j++;
      const word = text.slice(i, j).toUpperCase();
      if (word === 'BEGIN' || word === 'CASE') depth++;
      else if (word === 'END' && depth > 0) depth--;
      cur += text.slice(i, j);
      i = j;
    } else {
      cur += c;
      i++;
    }
  }
  flush();
  return out;
}

export function migrationFiles(dir) {
  try {
    return readdirSync(dir).filter((f) => /^\d{4}_.*\.sql$/.test(f)).sort().map((f) => join(dir, f));
  } catch {
    return [];
  }
}

const cell = (v) => (v === null || v === undefined ? '\\N' : String(v).replace(/\\/g, '\\\\').replace(/\t/g, '\\t').replace(/\n/g, '\\n'));
export const tsvOf = (rows) => rows.map((r) => r.map(cell).join('\t'));

// The blocks of an expected file: a line `@ <sql>` and then the rows (tab separated) up to the next `@` line.
export function parseExpected(text) {
  const blocks = [];
  for (const line of text.split('\n')) {
    if (line.startsWith('@ ')) blocks.push({ sql: line.slice(2).trim(), rows: [] });
    else if (blocks.length && line !== '') blocks[blocks.length - 1].rows.push(line);
  }
  return blocks;
}
