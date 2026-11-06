import sys
d = sys.argv[1]
f = d + '/PublishRoutes.roc'
s = open(f).read()
old = 'stmts = [provenance].concat(identity.stmts).concat(extra(now))'
new = 'stmts = [provenance].concat(extra(now))'
assert s.count(old) == 1, (s.count(old), old)
open(f, 'w').write(s.replace(old, new))
