-- R-AP4: the runs of one artifact on all compilers (R-AP17 `runs`, R-MX16 order). ?1 the artifact id.
WITH d0 AS (SELECT nightly, MIN(tag) AS tag, MIN(published_at) AS t FROM toolchains GROUP BY nightly),
d AS MATERIALIZED (SELECT nightly, tag, ROW_NUMBER() OVER (ORDER BY nightly >> 28, t, nightly) AS ord FROM d0),
r AS (SELECT c.artifact, c.target, c.source, c.result, c.error_digest, d.ord FROM compat c JOIN d ON d.nightly = c.nightly WHERE c.artifact = ?1)
SELECT hn.value AS hash, tn.name AS target, x.source AS source, x.result AS result, x.error_digest AS error_digest, a.tag AS "from", b.tag AS "to"
FROM (SELECT artifact, target, source, result, error_digest, MIN(ord) AS lo, MAX(ord) AS hi
    FROM (SELECT r.*, ord - ROW_NUMBER() OVER (PARTITION BY artifact, target, source, result, error_digest ORDER BY ord) AS grp FROM r) g
    GROUP BY artifact, target, source, result, error_digest, grp) x
JOIN d a ON a.ord = x.lo JOIN d b ON b.ord = x.hi JOIN names hn ON hn.id = x.artifact JOIN targets tn ON tn.target = x.target
ORDER BY hn.value, tn.name, x.source, x.lo
