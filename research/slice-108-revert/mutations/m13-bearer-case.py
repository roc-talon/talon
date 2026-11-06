# Mutation m13-bearer-case of the slice 108 reference: the scheme Bearer is compared with case
import sys, os
f = os.path.join(sys.argv[1], "lib/Oidc.roc")
s = open(f).read()
old = 'before.caseless_ascii_equals("Bearer")'
new = 'before == "Bearer"'
assert old in s, "mutation text not found"
open(f, "w").write(s.replace(old, new, 1))
