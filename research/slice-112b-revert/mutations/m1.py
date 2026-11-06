# the owner range is a prefix (hi <owner>~, as a LIKE): acme2/x counts
import sys
p = sys.argv[1] + '/lib/IngestLimits.roc'
s = open(p).read()
old = 'hi: "${owner}0"'
new = 'hi: "${owner}~"'
assert s.count(old) == 1, old
open(p, 'w').write(s.replace(old, new))
