# Mutation m10-binding-and of the slice 108 reference: row 5 needs both ids
import sys, os
f = os.path.join(sys.argv[1], "lib/Oidc.roc")
s = open(f).read()
old = ') or (claims.repository_owner_id'
new = ') and (claims.repository_owner_id'
assert old in s, "mutation text not found"
open(f, "w").write(s.replace(old, new, 1))
