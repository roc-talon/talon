# the leaf statement in the aggregate form (R-SG8)
import sys
p = sys.argv[1] + '/IngestRoutes.roc'
s = open(p).read()
old = 'SELECT (SELECT COALESCE(MAX(idx), 0) + 1 FROM log), ?1, ?2, ?3, ?4 WHERE NOT EXISTS'
new = 'SELECT COALESCE(MAX(idx), 0) + 1, ?1, ?2, ?3, ?4 FROM log WHERE NOT EXISTS'
assert s.count(old) == 1, old
open(p, 'w').write(s.replace(old, new))
