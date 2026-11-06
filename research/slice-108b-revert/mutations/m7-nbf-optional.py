# Mutation m7-nbf-optional of the slice 108b reference: nbf is not required
import sys, os
f = os.path.join(sys.argv[1], "lib/Oidc.roc")
s = open(f).read()
old = 'require: [Iss, Aud, Exp, Nbf]'
new = 'require: [Iss, Aud, Exp]'
assert old in s, "mutation text not found"
open(f, "w").write(s.replace(old, new, 1))
