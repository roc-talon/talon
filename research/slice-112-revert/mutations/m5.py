# no dedup of the names of the plan
import sys
p = sys.argv[1] + '/lib/Ingest.roc'
s = open(p).read()
old = 'if (acc.any(|m| m.kind == n.kind and m.value == n.value)) acc else acc.append(n)'
new = 'acc.append(n)'
assert s.count(old) == 1, old
open(p, 'w').write(s.replace(old, new))
