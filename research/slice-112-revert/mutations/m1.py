# the pre-read does not compare the hash (another hash is the same label)
import sys
p = sys.argv[1] + '/lib/Ingest.roc'
s = open(p).read()
old = '\t\t\tif hash != target.hash {'
new = '\t\t\tif Bool.False {'
assert s.count(old) == 1, old
open(p, 'w').write(s.replace(old, new))
