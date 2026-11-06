import sys
f = sys.argv[1] + '/IngestRoutes.roc'
s = open(f).read()
old = '''WHERE repo = ?1 AND repository_id = ?7 AND repository_owner_id = ?8"'''
new = '''WHERE repo = ?1 AND ?7 = ?7 AND ?8 = ?8"'''
assert s.count(old) == 1, (s.count(old), old)
open(f, 'w').write(s.replace(old, new))
