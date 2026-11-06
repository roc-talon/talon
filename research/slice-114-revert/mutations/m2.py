import sys
d = sys.argv[1]
f = d + '/lib/Publish.roc'
s = open(f).read()
old = 'Ok({ repository_id, owner_id })'
new = 'Ok({ repository_id: owner_id, owner_id: repository_id })'
assert s.count(old) == 1, (s.count(old), old)
open(f, 'w').write(s.replace(old, new))
