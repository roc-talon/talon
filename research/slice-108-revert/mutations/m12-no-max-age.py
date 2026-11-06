# Mutation m12-no-max-age of the slice 108 reference: the 1 h max age is not checked
import sys, os
f = os.path.join(sys.argv[1], "lib/Oidc.roc")
s = open(f).read()
old = 'if age > max_age_ms {'
new = 'if age > max_age_ms * 1000 {'
assert old in s, "mutation text not found"
open(f, "w").write(s.replace(old, new, 1))
