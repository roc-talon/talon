# query_value keeps /
import sys
p = sys.argv[1] + '/lib/IngestLimits.roc'
s = open(p).read()
old = 'or b == 95 or b == 126'
new = 'or b == 95 or b == 126 or b == 47'
assert s.count(old) == 1, old
open(p, 'w').write(s.replace(old, new))
