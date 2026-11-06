import sys
d = sys.argv[1]
f = d + '/lib/Publish.roc'
s = open(f).read()
old = 'if facts_wire.len() > fact_limit {'
new = 'if facts_wire.len() >= fact_limit {'
assert s.count(old) == 1, (s.count(old), old)
open(f, 'w').write(s.replace(old, new))
