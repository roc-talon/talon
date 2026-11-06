# an existing ingest row is ignored (each same-hash ingest reads GitHub again)
import sys
p = sys.argv[1] + '/lib/Ingest.roc'
s = open(p).read()
old = '\t\t\t} else if row.has_ingest {'
new = '\t\t\t} else if Bool.False {'
assert s.count(old) == 1, old
open(p, 'w').write(s.replace(old, new))
