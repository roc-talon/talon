# Mutation m3-reread-always of the slice 108 reference: an unknown kid always reads again (no 60 s rule)
import sys, os
f = os.path.join(sys.argv[1], "lib/Oidc.roc")
s = open(f).read()
old = 'if age > reread_after_ms Reload'
new = 'if age >= 0 Reload'
assert old in s, "mutation text not found"
open(f, "w").write(s.replace(old, new, 1))
