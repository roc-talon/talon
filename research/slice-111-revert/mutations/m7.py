# the header read ends when main.roc is collected: the members after it are not checked
import sys
d = sys.argv[1]
p = d + '/lib/ArchiveRead.roc'
s = open(p).read()
old = '\treading = |state| state.refused.is_err()'
new = '\treading = |state| state.refused.is_err() and state.header.is_err()'
assert s.count(old) == 1, old
open(p, 'w').write(s.replace(old, new))
