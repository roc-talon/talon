SELECT k.hx AS hash, tt.name AS target, k.source, k.result, k.error_digest, (SELECT tag FROM d WHERE ord = k.ord) AS nightly, k.side
FROM (SELECT m.*, ROW_NUMBER() OVER (PARTITION BY hx, target, side ORDER BY CASE side WHEN 'before' THEN -ord ELSE ord END) AS n
  FROM (SELECT h.hx, cp.target, cp.source, cp.result, cp.error_digest, d.ord, CASE WHEN d.ord < e.lo THEN 'before' ELSE 'after' END AS side
    FROM compat cp JOIN h ON h.artifact = cp.artifact JOIN d ON d.nightly = cp.nightly JOIN e ON e.target = cp.target
    WHERE (d.ord < e.lo OR d.ord > e.hi)
      AND NOT (cp.source = 1 AND EXISTS (SELECT 1 FROM compat b WHERE b.artifact = cp.artifact AND b.nightly = cp.nightly
        AND b.target = cp.target AND b.source = 0))) m
  WHERE result IN (0, 1)) k JOIN targets tt ON tt.target = k.target
WHERE k.n = 1 ORDER BY k.hx, tt.name, k.side = 'after'
