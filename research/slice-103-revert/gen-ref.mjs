// Writes the private reference migration reference/0002_triggers.sql (slice 103), from the prototypes of
// research/d1-sweep/, research/bot-set/ and research/d1-contrib/, ported to the schema of sql/0001_init.sql.
// MUTATE=<name> makes one hand mutation (mutate.sh runs each). Test agent only (TW18).
import { writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const M = process.env.MUTATE ?? '';
const out = process.argv[2] ?? join(dirname(fileURLToPath(import.meta.url)), 'reference/0002_triggers.sql');
const W = 548 * 86400000; // 18 months, first guess (the prototype: 548 days), in ms
const CAP = M === 'cap-ge' ? 'counted >= 200000' : 'counted > 200000';
const DAYMS = M === 'day-seconds' ? 86400 : 86400000;

// ---- releases (Q27, R-SG2) ----
const labelWhere = M === 'label-no-text' ? '' : ' AND version_text = NEW.version_text';
const labelConflict = M === 'no-label-trigger' ? '' : `CREATE TRIGGER releases_label_conflict BEFORE INSERT ON releases
BEGIN
  SELECT RAISE(ABORT, 'label-conflict') WHERE EXISTS (
    SELECT 1 FROM releases WHERE form = NEW.form AND version = NEW.version${labelWhere} AND artifact <> NEW.artifact);
END;
`;
// R-SG8: the Worker writes the leaf. An AFTER INSERT trigger only checks it. A BEFORE trigger would stop a publish that is sent again.
const leafTime = M === 'leaf-check-before' ? 'BEFORE' : 'AFTER';
const leaf = `CREATE TRIGGER releases_leaf_check ${leafTime} INSERT ON releases
BEGIN
  SELECT RAISE(ABORT, 'leaf-missing') WHERE ${M === 'no-leaf-check' ? '0 AND ' : ''}NOT EXISTS (SELECT 1 FROM log
    WHERE idx = NEW.log_index AND grp = (SELECT value FROM names WHERE id = NEW.form AND kind = 2));
END;

CREATE TRIGGER toolchains_leaf_check ${leafTime} INSERT ON toolchains
BEGIN
  SELECT RAISE(ABORT, 'leaf-missing') WHERE NOT EXISTS (SELECT 1 FROM log
    WHERE idx = NEW.log_index AND grp = 'roc-lang/nightlies:' || NEW.target AND version = NEW.tag AND hash = 'sha256:' || NEW.sha256);
END;
`;

// ---- the bot set (R-MX11) ----
const live = (a, L) => `${a}.log_index <= ${L} AND ${a}.yanked = 0 AND ${a}.withdrawn ${M === 'withdrawn-eq0' ? '= 0' : 'IS NULL'}`;
const sameSeries = (a, b) => `(${a}.version >> 48) = (${b}.version >> 48)
      AND ((${b}.version >> 48) <> -32768 OR ((${a}.version >> 32) & 65535) = ((${b}.version >> 32) & 65535))`;
const memberSql = (L, N) => {
  if (M === 'allhash') return `r.log_index <= ${L}`;
  const newestOfForm = `NOT EXISTS (SELECT 1 FROM releases r3 WHERE r3.form = r.form AND ${live('r3', L)} AND r3.version > r.version)`;
  const newestOfSeries = M === 'noseries' ? newestOfForm
    : `NOT EXISTS (SELECT 1 FROM releases r2 WHERE r2.form = r.form AND ${live('r2', L)} AND r2.version > r.version AND ${sameSeries('r2', 'r')})`;
  const inWindow = M === 'nowindow' ? '1'
    : M === 'window-now' ? `r.published_at >= 1790000000000 - ${W}`
    : `r.published_at ${M === 'window-gt' ? '>' : '>='} (SELECT MIN(published_at) FROM toolchains WHERE nightly = ${N}) - ${W}${M === 'window-edge-1' ? ' - 1' : ''}`;
  const kinds = M === 'apps-count' ? '(0, 1, 2)' : '(1, 2)';
  return `${live('r', L)}
      AND (SELECT kind FROM artifacts a WHERE a.artifact = r.artifact) IN ${kinds}
      AND ${newestOfSeries}
      AND (${inWindow} OR ${M === 'no-newest-of-form' ? '0' : newestOfForm})`;
};
const botRow = M === 'author-counts' ? 'c.source IN (0, 1)' : 'c.source = 0';
const noBotRow = (N, T) => `NOT EXISTS (SELECT 1 FROM compat c
      WHERE c.artifact = r.artifact AND c.nightly = ${N} AND c.target = ${T} AND ${botRow})`;
const incomplete = `SELECT RAISE(ABORT, 'sweep-incomplete') WHERE EXISTS (SELECT 1 FROM releases r
    WHERE ${memberSql('NEW.upto_log_index', 'NEW.nightly')}
      AND ${noBotRow('NEW.nightly', 'NEW.target')});`;
const bound = `SELECT RAISE(ABORT, 'sweep-bound') WHERE NEW.upto_log_index > (SELECT COALESCE(MAX(idx), 0) FROM log);`;
// Q83: nothing is checked when the row has a bound at least the new bound.
const skip = M === 'no-skip' ? '' : ` AND NOT EXISTS (SELECT 1 FROM sweeps s0 WHERE s0.nightly = NEW.nightly AND s0.target = NEW.target AND s0.upto_log_index >= NEW.upto_log_index)`;
const guardInsert = `CREATE TRIGGER sweeps_guard_insert BEFORE INSERT ON sweeps
BEGIN
  ${M === 'no-bound' ? '' : bound.replace(';', skip + ';')}
  ${incomplete.replace(/\);$/, ')' + skip + ';')}
END;
`;
const guardUpdate = `CREATE TRIGGER sweeps_guard_update BEFORE UPDATE ON sweeps
BEGIN
  ${M === 'no-smaller' ? '' : "SELECT RAISE(ABORT, 'sweep-smaller') WHERE NEW.upto_log_index < OLD.upto_log_index;"}
  ${bound}
  ${M === 'no-update-guard' ? '' : incomplete}
END;
`;

// ---- transitions (R-MX12, R-RE23) ----
const nights = '(SELECT nightly, MIN(published_at) AS pa FROM toolchains GROUP BY nightly)';
// R-MX16: the order of nightlies is the date (nightly >> 28), then t, then the id.
const dateOf = (x) => (M === 'order-t-id' ? `(${x} * 0)` : `(${x} >> 28)`);
const before = (n) => `(SELECT t.nightly FROM ${nights} t, (SELECT MIN(published_at) AS pa FROM toolchains WHERE nightly = ${n}) me
      WHERE me.pa IS NOT NULL AND (${dateOf('t.nightly')} < ${dateOf(n)} OR (${dateOf('t.nightly')} = ${dateOf(n)} AND (t.pa < me.pa OR (t.pa = me.pa AND t.nightly < ${n}))))
      ORDER BY ${dateOf('t.nightly')} DESC, t.pa DESC, t.nightly DESC LIMIT 1)`;
const after = (n) => `(SELECT t.nightly FROM ${nights} t, (SELECT MIN(published_at) AS pa FROM toolchains WHERE nightly = ${n}) me
      WHERE me.pa IS NOT NULL AND (${dateOf('t.nightly')} > ${dateOf(n)} OR (${dateOf('t.nightly')} = ${dateOf(n)} AND (t.pa > me.pa OR (t.pa = me.pa AND t.nightly > ${n}))))
      ORDER BY ${dateOf('t.nightly')}, t.pa, t.nightly LIMIT 1)`;
const beforeId = (n) => (M === 'order-by-id' ? `(SELECT MAX(nightly) FROM ${nights} WHERE nightly < ${n})` : before(n));
const afterId = (n) => (M === 'order-by-id' ? `(SELECT MIN(nightly) FROM ${nights} WHERE nightly > ${n})` : after(n));
const code = M === 'faults' ? '(0, 1, 2, 3)' : M === 'crash-is-2' ? '(0, 1, 3)' : '(0, 1)';
const pairs = (p, n, extra) => `(SELECT COUNT(*) FROM compat a JOIN compat b
      ON b.artifact = a.artifact AND b.nightly = ${n} AND b.target = a.target AND b.source = 0 AND b.result IN ${code}
      WHERE a.nightly = ${p} AND a.target = NEW.target AND a.source = 0 AND a.result IN ${code} ${extra})`;
const transition = (p, n) => `INSERT ${M === 'or-replace' ? 'OR REPLACE ' : ''}INTO transitions (nightly, target, previous, compared, changed)
    SELECT ${n}, NEW.target, ${p}, ${pairs(p, n, '')}, ${pairs(p, n, 'AND a.result <> b.result')}
    WHERE ${p} IS NOT NULL AND ${n} IS NOT NULL
      AND EXISTS (SELECT 1 FROM sweeps s WHERE s.nightly = ${p} AND s.target = NEW.target)
      AND EXISTS (SELECT 1 FROM sweeps s WHERE s.nightly = ${n} AND s.target = NEW.target)
    ${M === 'or-replace' ? ';' : 'ON CONFLICT (nightly, target) DO UPDATE SET previous = excluded.previous, compared = excluded.compared, changed = excluded.changed;'}`;
const transitions = `${transition(beforeId('NEW.nightly'), 'NEW.nightly')}
  ${M === 'no-next' ? '' : transition('NEW.nightly', afterId('NEW.nightly'))}`;
const transIns = `CREATE TRIGGER sweeps_transitions_insert AFTER INSERT ON sweeps
BEGIN
  ${transitions}
END;
`;
const transUpd = `CREATE TRIGGER sweeps_transitions_update AFTER UPDATE ON sweeps
BEGIN
  ${transitions}
END;
`;

// ---- user hints (R-CT13, R-RE12) ----
const hints = `CREATE TRIGGER contributions_count AFTER INSERT ON contributions
BEGIN
  INSERT INTO compat_hints (artifact, nightly, target, talon_version, pass_count, fail_count, crash_count, first_time, last_time)
  VALUES (NEW.artifact, NEW.nightly, NEW.target, NEW.talon_version,
    NEW.result = 0, NEW.result = 1, NEW.result = ${M === 'crash-is-2' ? '2' : '3'}, NEW.time, NEW.time)
  ON CONFLICT (artifact, nightly, target, talon_version) DO UPDATE SET
    pass_count = pass_count + excluded.pass_count, fail_count = fail_count + excluded.fail_count,
    crash_count = crash_count + excluded.crash_count,
    ${M === 'first-min' ? 'first_time = MIN(first_time, excluded.first_time), ' : ''}last_time = ${M === 'last-new' ? 'excluded.last_time' : 'MAX(last_time, excluded.last_time)'};
  INSERT INTO hint_days (day, counted) VALUES (NEW.time / ${DAYMS}, 1)
  ON CONFLICT (day) DO UPDATE SET counted = counted + 1;
  ${M === 'no-quota' ? '' : `SELECT RAISE(ABORT, 'hint-quota') WHERE (SELECT counted FROM hint_days WHERE day = NEW.time / ${DAYMS}) ${CAP.replace('counted ', '')};`}
END;
`;

const text = `-- Slice 103, PRIVATE REFERENCE (test agent). Not the code. The code agent does not read it (TW18).
${labelConflict}
${leaf}
${guardInsert}
${guardUpdate}
${transIns}
${transUpd}
${hints}`;
writeFileSync(out, text);
