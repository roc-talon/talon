# a drop also on the Answer path (a 200 with no write)
import sys
p = sys.argv[1] + '/IngestRoutes.roc'
s = open(p).read()
old = 'Answer(release) => answer!(session, 200, release)'
new = 'Answer(release) => answer!(session, 200, release).map_ok(drop)'
assert s.count(old) == 1, old
open(p, 'w').write(s.replace(old, new))
