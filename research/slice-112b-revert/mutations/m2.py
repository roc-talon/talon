# the day count takes time > day_start (a row at 00:00:00.000 does not count)
import sys
p = sys.argv[1] + '/IngestRoutes.roc'
s = open(p).read()
old = 'AND p.time >= ?3'
new = 'AND p.time > ?3'
assert s.count(old) == 1, old
open(p, 'w').write(s.replace(old, new))
