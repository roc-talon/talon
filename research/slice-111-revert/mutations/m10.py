# target names for each kind, not only a platform
import sys
d = sys.argv[1]
p = d + '/lib/ArchiveRead.roc'
s = open(p).read()
old = '\t\tif kind != Platform {'
new = '\t\tif Bool.False {'
assert s.count(old) == 1, old
open(p, 'w').write(s.replace(old, new))
