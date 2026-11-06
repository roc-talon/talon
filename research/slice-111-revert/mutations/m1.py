# the hash of the stream is not compared with the hash of the URL
import sys
d = sys.argv[1]
p = d + '/lib/ArchiveRead.roc'
s = open(p).read()
old = '\t\tif actual != hash {'
new = '\t\tif Bool.False {'
assert s.count(old) == 1, old
open(p, 'w').write(s.replace(old, new))
