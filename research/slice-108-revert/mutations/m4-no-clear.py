# Mutation m4-no-clear of the slice 108 reference: the read again does not clear the Memo
import sys, os
f = os.path.join(sys.argv[1], "Auth.roc")
s = open(f).read()
old = 'jwks.clear!()\n'
new = '\n'
assert old in s, "mutation text not found"
open(f, "w").write(s.replace(old, new, 1))
