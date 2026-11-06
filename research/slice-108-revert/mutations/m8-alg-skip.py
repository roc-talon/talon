# Mutation m8-alg-skip of the slice 108 reference: any alg is accepted
import sys, os
f = os.path.join(sys.argv[1], "lib/Oidc.roc")
s = open(f).read()
old = 'Ok(alg) if alg != "RS256"'
new = 'Ok(alg) if alg == "XX"'
assert old in s, "mutation text not found"
open(f, "w").write(s.replace(old, new, 1))
