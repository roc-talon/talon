import sys
d = sys.argv[1]
f = d + '/IngestRoutes.roc'
s = open(f).read()
old = 'identity_stmts({ u: repo_id, same, old, change, now, claims })'
new = 'identity_stmts({ u: repo_id, same, old, change, now, claims: Err(None) })'
assert s.count(old) == 1, (s.count(old), old)
open(f, 'w').write(s.replace(old, new))
