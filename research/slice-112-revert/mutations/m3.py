# the provenance via is webhook (1), not ingest (3)
import sys
p = sys.argv[1] + '/IngestRoutes.roc'
s = open(p).read()
old = 'SELECT r.log_index, 3, NULL, ?4 FROM releases r'
new = 'SELECT r.log_index, 1, NULL, ?4 FROM releases r'
assert s.count(old) == 1, old
open(p, 'w').write(s.replace(old, new))
