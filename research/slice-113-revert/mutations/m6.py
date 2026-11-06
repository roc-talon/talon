import sys
d = sys.argv[1]
f = d + '/IngestRoutes.roc'
s = open(f).read()
old = '''CASE WHEN EXISTS (SELECT 1 FROM repo_events o WHERE o.action = 2 AND o.successor = ?1 AND o.time = ?2) THEN 2 ELSE 0 END'''
new = '''0'''
assert s.count(old) == 1, (s.count(old), old)
open(f, 'w').write(s.replace(old, new))
