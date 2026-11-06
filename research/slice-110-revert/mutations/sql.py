# SQL mutations of the private reference (slice 110). Usage: python3 sql.py <name> <src dir> <out dir>
import sys, shutil, os
name, src, out = sys.argv[1:4]
shutil.rmtree(out, ignore_errors=True); shutil.copytree(src, out)
M = {
  'noexpand': ('prefix.sql', 'SELECT ep.target, MIN(ep.ord) AS lo, MAX(ep.ord) AS hi\n    FROM ep JOIN', 'SELECT ep.target, MIN((SELECT lo FROM w)) AS lo, MAX((SELECT hi FROM w)) AS hi\n    FROM ep JOIN'),
  'nogap': ('runs.sql', 'ord - ROW_NUMBER()', 'DENSE_RANK() OVER (PARTITION BY hx, target, source ORDER BY ord) - ROW_NUMBER()'),
  'nomerge': ('nearest.sql', 'AND NOT (cp.source = 1 AND EXISTS', 'AND NOT (cp.source = 7 AND EXISTS'),
  'fault': ('nearest.sql', 'WHERE result IN (0, 1)) k', 'WHERE result IN (0, 1, 2, 3)) k'),
  'order-id': ('prefix.sql', 'OVER (ORDER BY nightly >> 28, t, nightly) AS ord', 'OVER (ORDER BY nightly) AS ord'),
  'order-t': ('prefix.sql', 'OVER (ORDER BY nightly >> 28, t, nightly) AS ord', 'OVER (ORDER BY t, nightly) AS ord'),
  'edge-lo': ('prefix.sql', 'FROM ep, w WHERE ord BETWEEN w.lo AND w.hi', 'FROM ep, w WHERE ord > w.lo AND ord <= w.hi'),
  'no-previous': ('prefix.sql', ' AND x.previous = d.prev AND x.changed = 0', ' AND x.changed = 0'),
  'any-changed': ('prefix.sql', 'AND x.changed = 0) THEN 0', 'AND x.compared >= 0) THEN 0'),
  'union-all-dup': ('releases.sql', 'FROM h JOIN releases', 'FROM (SELECT * FROM h UNION ALL SELECT * FROM h) h JOIN releases'),
}
f, a, b = M[name]
p = os.path.join(out, f); s = open(p).read()
assert a in s, (name, a)
open(p, 'w').write(s.replace(a, b, 1))
