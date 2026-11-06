# type 7 (contiguous) is read as a file (roc-tar gives File)
import sys
d = sys.argv[1]
p = d + '/lib/ArchiveRead.roc'
s = open(p).read()
old = "type7 = e.kind == File and window.get(e.offset + 156 - window_start) == Ok('7')"
new = "type7 = Bool.False and window.get(e.offset + 156 - window_start) == Ok('7')"
assert s.count(old) == 1, old
open(p, 'w').write(s.replace(old, new))
