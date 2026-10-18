// The closure facts as runs in a window of compilers (Registry R-AP16, R-AP17). Text keys here; the registry uses
// integer ids (Registry 5.1). The order of compilers is R-NS1: by `published_at`, then by tag.
export const schema = [
  `CREATE TABLE toolchains (nightly TEXT PRIMARY KEY, published_at INTEGER NOT NULL) STRICT`,
  `CREATE TABLE compat (hash TEXT NOT NULL, nightly TEXT NOT NULL, target TEXT NOT NULL, source TEXT NOT NULL,
    result TEXT NOT NULL, digest TEXT, PRIMARY KEY (hash, nightly, target, source)) STRICT`,
  `CREATE INDEX compat_hash_target ON compat (hash, target, nightly)`,
  `CREATE TABLE transitions (nightly TEXT NOT NULL, target TEXT NOT NULL, previous TEXT NOT NULL,
    compared INTEGER NOT NULL, changed INTEGER NOT NULL, PRIMARY KEY (nightly, target)) STRICT`,
  `CREATE TABLE compat_hints (hash TEXT NOT NULL, nightly TEXT NOT NULL, target TEXT NOT NULL, talon_version TEXT NOT NULL,
    pass_count INTEGER NOT NULL, fail_count INTEGER NOT NULL, crash_count INTEGER NOT NULL,
    PRIMARY KEY (hash, nightly, target, talon_version)) STRICT`,
];

// Parameters: ?1 the hashes (JSON list), ?2 the first compiler of the window, ?3 the last (null: the end of the domain).
// MUTATE=noexpand: the epochs are not added to the window. MUTATE=nogap: a run goes over a compiler with no row.
// MUTATE=nomerge: the nearest fact ignores the precedence of the sources. MUTATE=fault: the nearest fact can be a fault.
const M = process.env.MUTATE ?? "";
const prefix = `
WITH d AS MATERIALIZED (SELECT nightly, ROW_NUMBER() OVER (ORDER BY published_at, nightly) AS ord,
    LAG(nightly) OVER (ORDER BY published_at, nightly) AS prev FROM toolchains),
h AS (SELECT value AS hash FROM json_each(?1)),
tg AS (SELECT DISTINCT target FROM compat WHERE hash IN (SELECT hash FROM h)),
-- An epoch starts at each compiler whose transition is not covered, or is a boundary of the registry (R-EP3 case a).
ep AS MATERIALIZED (SELECT t.target, d.nightly, d.ord, SUM(CASE WHEN EXISTS (SELECT 1 FROM transitions x
    WHERE x.nightly = d.nightly AND x.target = t.target AND x.previous = d.prev AND x.changed = 0) THEN 0 ELSE 1 END)
    OVER (PARTITION BY t.target ORDER BY d.ord) AS epoch FROM d, tg t),
w AS (SELECT COALESCE((SELECT ord FROM d WHERE nightly = ?2), 1) AS lo,
    COALESCE((SELECT ord FROM d WHERE nightly = ?3), (SELECT MAX(ord) FROM d)) AS hi),
-- E: the window, made larger to the ends of each epoch that it touches.
-- An epoch number only grows with the order, so the epochs that the window touches are one range of numbers.
e AS (SELECT ep.target, ${M === "noexpand" ? "MIN(w.lo) AS lo, MAX(w.hi) AS hi" : "MIN(ep.ord) AS lo, MAX(ep.ord) AS hi"}
    FROM ep JOIN (SELECT target, MIN(epoch) AS e0, MAX(epoch) AS e1 FROM ep, w WHERE ord BETWEEN w.lo AND w.hi GROUP BY target) z
    ON z.target = ep.target, w WHERE ep.epoch BETWEEN z.e0 AND z.e1 GROUP BY ep.target),
r AS (SELECT c.hash, c.target, c.source, c.result, c.digest, d.ord FROM compat c JOIN d ON d.nightly = c.nightly
    JOIN e ON e.target = c.target WHERE c.hash IN (SELECT hash FROM h) AND d.ord BETWEEN e.lo AND e.hi)`;

// An epoch of one release is not listed: each release that no listed epoch holds is an epoch of its own.
export const epochsSql = `${prefix}
SELECT x.target, a.nightly AS "from", b.nightly AS "to" FROM (SELECT ep.target, MIN(ep.ord) AS lo, MAX(ep.ord) AS hi
  FROM ep JOIN e ON e.target = ep.target WHERE ep.ord BETWEEN e.lo AND e.hi GROUP BY ep.target, ep.epoch HAVING COUNT(*) > 1) x
JOIN d a ON a.ord = x.lo JOIN d b ON b.ord = x.hi`;

// Runs: the rows of one (hash, target, source) with one result on adjacent compilers (gaps and islands).
export const runsSql = `${prefix}
SELECT x.hash, x.target, x.source, x.result, x.digest, a.nightly AS "from", b.nightly AS "to"
FROM (SELECT hash, target, source, result, digest, MIN(ord) AS lo, MAX(ord) AS hi FROM (SELECT r.*, ${M === "nogap" ? "DENSE_RANK() OVER (PARTITION BY hash, target, source ORDER BY ord)" : "ord"}
  - ROW_NUMBER() OVER (PARTITION BY hash, target, source, result, digest ORDER BY ord) AS grp FROM r) g
GROUP BY hash, target, source, result, digest, grp) x JOIN d a ON a.ord = x.lo JOIN d b ON b.ord = x.hi`;

// The nearest real code result of each (hash, target) before E and after E (R-EP6 case b). A `bot` row wins over an
// `author` row of the same pair (Resolution 3, R-EF3), so the source of a pair is chosen before the result is tested.
export const nearestSql = `${prefix},
m AS (SELECT c.hash, c.target, c.source, c.result, c.digest, d.ord, CASE WHEN d.ord < e.lo THEN 'before' ELSE 'after' END AS side
  FROM compat c JOIN d ON d.nightly = c.nightly JOIN e ON e.target = c.target
  WHERE c.hash IN (SELECT hash FROM h) AND (d.ord < e.lo OR d.ord > e.hi)
  ${M === "nomerge" ? "" : `AND NOT (c.source = 'author' AND EXISTS (SELECT 1 FROM compat b WHERE b.hash = c.hash
    AND b.nightly = c.nightly AND b.target = c.target AND b.source = 'bot'))`}),
k AS (SELECT m.*, ROW_NUMBER() OVER (PARTITION BY hash, target, side ORDER BY CASE side WHEN 'before' THEN -ord ELSE ord END) AS n
  FROM m ${M === "fault" ? "" : "WHERE result IN ('pass', 'fail')"})
SELECT hash, target, source, result, digest, side, (SELECT nightly FROM d WHERE ord = k.ord) AS nightly FROM k WHERE n = 1`;

// The user hints in the window only, added up over the Talon versions. They are search order only (Resolution 3).
export const hintsSql = `${prefix}
SELECT x.hash, x.nightly, x.target, SUM(pass_count) AS pass_count, SUM(fail_count) AS fail_count, SUM(crash_count) AS crash_count
FROM compat_hints x JOIN d ON d.nightly = x.nightly, w WHERE x.hash IN (SELECT hash FROM h) AND d.ord BETWEEN w.lo AND w.hi
GROUP BY x.hash, x.nightly, x.target`;

// The old answer, for the size compare: each row of each hash.
export const allRowsSql = `SELECT hash, nightly, target, source, result, digest FROM compat WHERE hash IN (SELECT value FROM json_each(?1))`;
