import sys
d = sys.argv[1]
f = d + '/lib/Identity.roc'
s = open(f).read()
old = '''found = !recreated and row.state == Missing'''
new = '''found = Bool.False'''
assert s.count(old) == 1, (s.count(old), old)
open(f, 'w').write(s.replace(old, new))
