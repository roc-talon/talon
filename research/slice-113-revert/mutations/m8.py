import sys
d = sys.argv[1]
f = d + '/IngestRoutes.roc'
s = open(f).read()
old = '''SELECT ?1, (SELECT COALESCE(MAX(seq), 0) + 1 FROM repo_events WHERE repo = ?1), ?2, ?3, ?4, ?5, ?6, ?7, NULL, ?8 WHERE changes() > 0'''
new = '''SELECT ?1, 1, ?2, ?3, ?4, ?5, ?6, ?7, NULL, ?8 WHERE changes() > 0'''
assert s.count(old) == 1, (s.count(old), old)
open(f, 'w').write(s.replace(old, new))
