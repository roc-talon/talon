SELECT h.hx AS hash, d.tag AS nightly, tt.name AS target, SUM(x.pass_count) AS pass_count, SUM(x.fail_count) AS fail_count,
  SUM(x.crash_count) AS crash_count
FROM compat_hints x JOIN h ON h.artifact = x.artifact JOIN d ON d.nightly = x.nightly JOIN targets tt ON tt.target = x.target, w
WHERE d.ord BETWEEN w.lo AND w.hi GROUP BY h.hx, d.ord, tt.name ORDER BY h.hx, d.ord, tt.name
