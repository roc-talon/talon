import sys
f = sys.argv[1] + '/IngestRoutes.roc'
s = open(f).read()
old = '''WHERE repo = ?1 AND state = 2 AND repository_id = ?3", (u, now, rid))'''
new = '''WHERE repo = ?1 AND state = 2 AND repository_id = ?3 AND ?3 < 0", (u, now, rid))'''
assert s.count(old) == 1, (s.count(old), old)
open(f, 'w').write(s.replace(old, new))
