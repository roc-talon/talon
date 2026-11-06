import sys
d = sys.argv[1]
f = d + '/lib/Publish.roc'
s = open(f).read()
old = "'$.error_digest'), ?2, r.log_index FROM"
new = "'$.error_digest'), ?2, NULL FROM"
assert s.count(old) == 1, (s.count(old), old)
open(f, 'w').write(s.replace(old, new))
