import sys
d = sys.argv[1]
f = d + '/IngestRoutes.roc'
s = open(f).read()
old = '''UPDATE repos SET state = 2, successor = ?1, state_at = ?2 WHERE repository_id = ?3 AND repo <> ?1 AND state <> 2 AND NOT EXISTS'''
new = '''UPDATE repos SET state_at = ?2 WHERE repository_id = ?3 AND repo <> ?1 AND state <> 2 AND ?1 <> ?1 AND NOT EXISTS'''
assert s.count(old) == 1, (s.count(old), old)
open(f, 'w').write(s.replace(old, new))
