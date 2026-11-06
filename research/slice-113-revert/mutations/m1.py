import sys
d = sys.argv[1]
f = d + '/lib/Identity.roc'
s = open(f).read()
old = '''if !same_repo and !same_owner {'''
new = '''if !same_repo or !same_owner {'''
assert s.count(old) == 1, (s.count(old), old)
open(f, 'w').write(s.replace(old, new))
