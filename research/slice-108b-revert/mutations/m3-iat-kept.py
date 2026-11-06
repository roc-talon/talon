# Mutation m3-iat-kept of the slice 108b reference: the iat of the token goes to Jwt.check
import sys, os
f = os.path.join(sys.argv[1], "lib/Oidc.roc")
s = open(f).read()
old = 'Jwt.check({ ..claims, iat: Err(Missing) }, rules)'
new = 'Jwt.check(claims, rules)'
assert old in s, "mutation text not found"
open(f, "w").write(s.replace(old, new, 1))
