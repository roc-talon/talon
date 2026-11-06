# the duplicate check compares the exact path text, not the key of row 17
import sys
d = sys.argv[1]
p = d + '/lib/ArchiveRead.roc'
s = open(p).read()
old = '\tk = ArchiveRead.path_key(e.path)\n'
new = '\tk = e.path\n'
assert s.count(old) == 1, old
open(p, 'w').write(s.replace(old, new))
