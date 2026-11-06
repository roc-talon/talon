# the count refuses exactly 100,000,000 bytes
import sys
d = sys.argv[1]
p = d + '/lib/ArchiveRead.roc'
s = open(p).read()
old = '\t\tif total > max_packed_bytes {'
new = '\t\tif total >= max_packed_bytes {'
assert s.count(old) == 1, old
open(p, 'w').write(s.replace(old, new))
