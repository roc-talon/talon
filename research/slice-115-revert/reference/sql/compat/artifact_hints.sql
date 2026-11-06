-- R-AP4: the hints of one artifact on all compilers, added up over the Talon versions. ?1 the artifact id.
WITH d0 AS (SELECT nightly, MIN(tag) AS tag, MIN(published_at) AS t FROM toolchains GROUP BY nightly),
d AS MATERIALIZED (SELECT nightly, tag, ROW_NUMBER() OVER (ORDER BY nightly >> 28, t, nightly) AS ord FROM d0)
SELECT hn.value AS hash, d.tag AS nightly, tn.name AS target, SUM(x.pass_count) AS pass_count, SUM(x.fail_count) AS fail_count, SUM(x.crash_count) AS crash_count
FROM compat_hints x JOIN d ON d.nightly = x.nightly JOIN names hn ON hn.id = x.artifact JOIN targets tn ON tn.target = x.target
WHERE x.artifact = ?1
GROUP BY x.nightly, x.target ORDER BY d.ord, tn.name
