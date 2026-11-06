import sys
d = sys.argv[1]
f = d + '/PublishRoutes.roc'
s = open(f).read()
old = 'via: 0, claims: claims_text'
new = 'via: 3, claims: claims_text'
assert s.count(old) == 1, (s.count(old), old)
open(f, 'w').write(s.replace(old, new))
