-- Reference (slice 110, private). The common CTEs of the closure batch. ?1 groups, ?2 hashes, ?3 from, ?4 to.
WITH RECURSIVE
c(artifact) AS (
  SELECT r.artifact FROM releases r, json_each(?1) g
    WHERE r.form = (g.value ->> '$.form') AND r.version BETWEEN (g.value ->> '$.lo') AND (g.value ->> '$.hi')
  UNION SELECT a.artifact FROM artifacts a, json_each(?2) j WHERE a.artifact = j.value
  UNION SELECT dp.dep FROM deps dp JOIN c ON dp.artifact = c.artifact),
h AS (SELECT c.artifact, n.value AS hx FROM c JOIN artifacts a ON a.artifact = c.artifact JOIN names n ON n.id = c.artifact),
nt AS (SELECT nightly, MIN(published_at) AS t, MIN(tag) AS tag FROM toolchains GROUP BY nightly),
d AS MATERIALIZED (SELECT nightly, tag, ROW_NUMBER() OVER (ORDER BY nightly >> 28, t, nightly) AS ord,
    LAG(nightly) OVER (ORDER BY nightly >> 28, t, nightly) AS prev FROM nt),
tg AS (SELECT DISTINCT target FROM compat WHERE artifact IN (SELECT artifact FROM h)),
ep AS MATERIALIZED (SELECT t.target, d.nightly, d.ord, SUM(CASE WHEN EXISTS (SELECT 1 FROM transitions x
    WHERE x.nightly = d.nightly AND x.target = t.target AND x.previous = d.prev AND x.changed = 0) THEN 0 ELSE 1 END)
    OVER (PARTITION BY t.target ORDER BY d.ord) AS epoch FROM d, tg t),
w AS (SELECT COALESCE((SELECT ord FROM d WHERE nightly = ?3), 1) AS lo,
    COALESCE((SELECT ord FROM d WHERE nightly = ?4), (SELECT MAX(ord) FROM d)) AS hi),
e AS (SELECT ep.target, MIN(ep.ord) AS lo, MAX(ep.ord) AS hi
    FROM ep JOIN (SELECT target, MIN(epoch) AS e0, MAX(epoch) AS e1 FROM ep, w WHERE ord BETWEEN w.lo AND w.hi GROUP BY target) z
    ON z.target = ep.target WHERE ep.epoch BETWEEN z.e0 AND z.e1 GROUP BY ep.target),
r AS (SELECT h.hx, cp.target, cp.source, cp.result, cp.error_digest, d.ord FROM compat cp JOIN h ON h.artifact = cp.artifact
    JOIN d ON d.nightly = cp.nightly JOIN e ON e.target = cp.target WHERE d.ord BETWEEN e.lo AND e.hi)
