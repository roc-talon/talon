SELECT x.hx AS hash, tt.name AS target, x.source, x.result, x.error_digest, a.tag AS "from", b.tag AS "to"
FROM (SELECT hx, target, source, result, error_digest, MIN(ord) AS lo, MAX(ord) AS hi FROM (SELECT r.*,
  ord - ROW_NUMBER() OVER (PARTITION BY hx, target, source, result, error_digest ORDER BY ord) AS grp FROM r) g
GROUP BY hx, target, source, result, error_digest, grp) x JOIN d a ON a.ord = x.lo JOIN d b ON b.ord = x.hi JOIN targets tt ON tt.target = x.target
ORDER BY x.hx, tt.name, x.source, x.lo
