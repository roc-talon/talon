-- R-AP40: the pairs with hints and no bot row. ?1 the most pairs. The pair needs a tag (a nightly with a toolchains row).
SELECT n.value AS hash, d.tag AS nightly, t.name AS target, SUM(h.pass_count) AS pass_count, SUM(h.fail_count) AS fail_count, SUM(h.crash_count) AS crash_count
FROM compat_hints h
JOIN artifacts a ON a.artifact = h.artifact
JOIN names n ON n.id = h.artifact
JOIN targets t ON t.target = h.target
JOIN (SELECT nightly, MIN(tag) AS tag FROM toolchains GROUP BY nightly) d ON d.nightly = h.nightly
WHERE (h.target = 0 OR a.kind = 2)
  AND NOT EXISTS (SELECT 1 FROM compat c WHERE c.artifact = h.artifact AND c.nightly = h.nightly AND c.target = h.target AND c.source = 0)
GROUP BY h.artifact, h.nightly, h.target
ORDER BY SUM(h.pass_count + h.fail_count + h.crash_count) DESC, n.value, h.nightly, h.target
LIMIT ?1
