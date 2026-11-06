# the dep hash is not checked as base58 of 32 bytes (row 14)
import sys
d = sys.argv[1]
p = d + '/lib/ArchiveRead.roc'
s = open(p).read()
old = '\t\tOk(b) if b.len() == 32 => Ok(dep)\n'
new = '\t\t_ if Bool.True => Ok(dep)\n'
assert s.count(old) == 1, old
open(p, 'w').write(s.replace(old, new))
