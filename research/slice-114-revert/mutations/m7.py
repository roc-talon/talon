import sys
d = sys.argv[1]
f = d + '/lib/Publish.roc'
s = open(f).read()
old = 'row.has_ingest and !have.facts and !have.events'
new = 'row.has_ingest and !have.events'
assert s.count(old) == 1, (s.count(old), old)
open(f, 'w').write(s.replace(old, new))
