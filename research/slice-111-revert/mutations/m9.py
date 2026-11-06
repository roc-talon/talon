# Content-Length is not checked before the read
import sys
d = sys.argv[1]
p = d + '/Archive.roc'
s = open(p).read()
old = 'ArchiveRead.check_length(res.header("content-length")).map_err(|r| Refused(r))?'
new = '_cl = res.header("content-length")'
assert s.count(old) == 1, old
open(p, 'w').write(s.replace(old, new))
