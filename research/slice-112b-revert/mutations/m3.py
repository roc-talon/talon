# the owner check also for a known name
import sys
p = sys.argv[1] + '/lib/IngestLimits.roc'
s = open(p).read()
old = 'if !i.has_repo and i.count >= owner_limit'
new = 'if i.count >= owner_limit'
assert s.count(old) == 1, old
open(p, 'w').write(s.replace(old, new))
