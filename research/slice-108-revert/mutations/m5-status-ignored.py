# Mutation m5-status-ignored of the slice 108 reference: a JWKS answer that is not 200 is read as a JWKS
import sys, os
f = os.path.join(sys.argv[1], "Auth.roc")
s = open(f).read()
old = 'if res.status() != 200 {'
new = 'if res.status() == 999 {'
assert old in s, "mutation text not found"
open(f, "w").write(s.replace(old, new, 1))
