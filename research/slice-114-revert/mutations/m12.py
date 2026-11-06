import sys
d = sys.argv[1]
f = d + '/lib/Publish.roc'
s = open(f).read()
old = '\t\tfacts = facts_wire.map_try(fact_of)?\n'
new = '\t\t_u = Ingest.parse_url(wire.url).map_err(|p| Bad(p))?\n' + old
assert s.count(old) == 1
if 'import lib.Ingest' not in s and 'import Ingest' not in s:
    s = s.replace('import ', 'import lib.Ingest\nimport ', 1)
open(f, 'w').write(s.replace(old, new))
