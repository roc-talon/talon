import sys
f = sys.argv[1] + '/IngestRoutes.roc'
s = open(f).read()
old = '''WHERE repo = ?1 AND changes() > 0", (a.repo, now))] else []'''
new = '''WHERE repo = ?1 AND changes() > 0", (a.repo, now)), Sql.stmt("UPDATE releases SET withdrawn = NULL, withdrawn_at = NULL WHERE repo = ?1 AND withdrawn = 'repo-missing'", [a.repo])] else []'''
assert s.count(old) == 1, (s.count(old), old)
open(f, 'w').write(s.replace(old, new))
