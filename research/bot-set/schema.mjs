// Prototype schema of the bounded bot set (Registry 6, R-MX11), the sweep guard (R-MX4, R-MX8) and the transitions
// table (R-RE23). Only the columns that these rules use. Integer codes: kind 0 package, 1 platform, 2 app; source 0 bot,
// 1 author; result 0 pass, 1 fail, 2 crash, 3 hang. `version` is the stored order key of R-IK5 (key XOR 2^63).
// The member condition is one SQL text, used by the guard triggers and by the work route (R-AP39), so they cannot differ.

export const WINDOW_DAYS = 548; // 18 months, first guess
const MUTATE = process.env.MUTATE ?? "";
const W = WINDOW_DAYS * 86400;

const live = (a, L) => `${a}.log_index <= ${L} AND ${a}.yanked = 0 AND ${a}.withdrawn = 0`;
// Same series (Design 4.1, R-ID1): same major, and for major 0 also the same minor. Major 0 is stored >> 48 = -32768.
const sameSeries = (a, b) => `(${a}.version >> 48) = (${b}.version >> 48)
  AND ((${b}.version >> 48) <> -32768 OR ((${a}.version >> 32) & 65535) = ((${b}.version >> 32) & 65535))`;

// r is a member of the bot set at bound L for nightly N.
export function memberSql(L, N) {
  if (MUTATE === "allhash") return `r.log_index <= ${L}`; // the old rule: every hash up to the bound
  const newestOfForm = `NOT EXISTS (SELECT 1 FROM releases r3 WHERE r3.form = r.form AND ${live("r3", L)} AND r3.version > r.version)`;
  const newestOfSeries = MUTATE === "noseries" ? newestOfForm
    : `NOT EXISTS (SELECT 1 FROM releases r2 WHERE r2.form = r.form AND ${live("r2", L)} AND r2.version > r.version AND ${sameSeries("r2", "r")})`;
  const inWindow = MUTATE === "nowindow" ? "1"
    : `r.published_at >= (SELECT published_at FROM toolchains WHERE nightly = ${N}) - ${W}`;
  return `${live("r", L)}
    AND (SELECT kind FROM artifacts a WHERE a.artifact = r.artifact) IN (0, 1)
    AND ${newestOfSeries}
    AND (${inWindow} OR ${newestOfForm})`;
}

const noBotRow = (N, T) => `NOT EXISTS (SELECT 1 FROM compat c
  WHERE c.artifact = r.artifact AND c.nightly = ${N} AND c.target = ${T} AND c.source = 0)`;

// The work route (R-AP39): the members with no bot row, at the log size now.
export const missingSql = `SELECT DISTINCT r.artifact AS artifact FROM releases r
  WHERE ${memberSql("(SELECT MAX(log_index) FROM releases)", "?1")} AND ${noBotRow("?1", "?2")} ORDER BY 1`;
export const membersSql = `SELECT DISTINCT r.artifact AS artifact FROM releases r
  WHERE ${memberSql("?2", "?1")} ORDER BY 1`;

const guard = `SELECT RAISE(ABORT, 'sweep-incomplete') WHERE EXISTS (SELECT 1 FROM releases r
    WHERE ${memberSql("NEW.upto_log_index", "NEW.nightly")} AND ${noBotRow("NEW.nightly", "NEW.target")});`;

// The nightly before n in the order of R-NS1 (published_at, then the id).
const before = (n) => `(SELECT t.nightly FROM toolchains t, toolchains me WHERE me.nightly = ${n}
  AND (t.published_at < me.published_at OR (t.published_at = me.published_at AND t.nightly < me.nightly))
  ORDER BY t.published_at DESC, t.nightly DESC LIMIT 1)`;
const after = (n) => `(SELECT t.nightly FROM toolchains t, toolchains me WHERE me.nightly = ${n}
  AND (t.published_at > me.published_at OR (t.published_at = me.published_at AND t.nightly > me.nightly))
  ORDER BY t.published_at, t.nightly LIMIT 1)`;
// Code results only (R-EP1): a fault is not part of a boundary (R-EP5).
const code = MUTATE === "faults" ? "(0, 1, 2, 3)" : "(0, 1)";
const pairs = (p, n, T, extra) => `(SELECT COUNT(*) FROM compat a JOIN compat b
  ON b.artifact = a.artifact AND b.nightly = ${n} AND b.target = a.target AND b.source = 0 AND b.result IN ${code}
  WHERE a.nightly = ${p} AND a.target = ${T} AND a.source = 0 AND a.result IN ${code} ${extra})`;
// One transitions row for (p, n) when both are swept. The row has the key of the later nightly.
const transition = (p, n) => `INSERT OR REPLACE INTO transitions (nightly, target, previous, compared, changed)
  SELECT ${n}, NEW.target, ${p}, ${pairs(p, n, "NEW.target", "")}, ${pairs(p, n, "NEW.target", "AND a.result <> b.result")}
  WHERE ${p} IS NOT NULL AND ${n} IS NOT NULL
    AND EXISTS (SELECT 1 FROM sweeps s WHERE s.nightly = ${p} AND s.target = NEW.target)
    AND EXISTS (SELECT 1 FROM sweeps s WHERE s.nightly = ${n} AND s.target = NEW.target);`;
const transitions = `${transition(before("NEW.nightly"), "NEW.nightly")}
  ${transition("NEW.nightly", after("NEW.nightly"))}`;

export const schema = [
  `CREATE TABLE artifacts (artifact INTEGER PRIMARY KEY, kind INTEGER NOT NULL CHECK (kind IN (0, 1, 2))) STRICT`,
  `CREATE TABLE releases (log_index INTEGER PRIMARY KEY, form INTEGER NOT NULL, version INTEGER NOT NULL,
    artifact INTEGER NOT NULL, published_at INTEGER NOT NULL, yanked INTEGER NOT NULL, withdrawn INTEGER NOT NULL,
    UNIQUE (form, version)) STRICT`,
  `CREATE TABLE toolchains (nightly INTEGER PRIMARY KEY, published_at INTEGER NOT NULL) STRICT`,
  `CREATE TABLE compat (artifact INTEGER NOT NULL, nightly INTEGER NOT NULL, target INTEGER NOT NULL,
    source INTEGER NOT NULL, result INTEGER NOT NULL, PRIMARY KEY (artifact, nightly, target, source)) STRICT, WITHOUT ROWID`,
  `CREATE INDEX compat_nightly ON compat (nightly, target, source, artifact)`,
  `CREATE TABLE sweeps (nightly INTEGER NOT NULL, target INTEGER NOT NULL, upto_log_index INTEGER NOT NULL,
    PRIMARY KEY (nightly, target)) STRICT, WITHOUT ROWID`,
  `CREATE TABLE transitions (nightly INTEGER NOT NULL, target INTEGER NOT NULL, previous INTEGER NOT NULL,
    compared INTEGER NOT NULL, changed INTEGER NOT NULL, PRIMARY KEY (nightly, target)) STRICT, WITHOUT ROWID`,
  `CREATE TRIGGER sweeps_guard_insert BEFORE INSERT ON sweeps BEGIN ${guard} END`,
  `CREATE TRIGGER sweeps_guard_update BEFORE UPDATE ON sweeps BEGIN
    SELECT RAISE(ABORT, 'sweep-smaller') WHERE NEW.upto_log_index < OLD.upto_log_index;
    ${guard} END`,
  `CREATE TRIGGER sweeps_transitions_insert AFTER INSERT ON sweeps BEGIN ${transitions} END`,
  `CREATE TRIGGER sweeps_transitions_update AFTER UPDATE ON sweeps BEGIN ${transitions} END`,
];
