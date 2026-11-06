# the names insert has no conflict target (R-IK3)
import sys
p = sys.argv[1] + '/IngestRoutes.roc'
s = open(p).read()
old = 'ON CONFLICT (kind, value) DO NOTHING'
new = 'ON CONFLICT DO NOTHING'
assert s.count(old) == 1, old
open(p, 'w').write(s.replace(old, new))
