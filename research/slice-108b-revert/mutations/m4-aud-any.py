# Mutation m4-aud-any of the slice 108b reference: aud is not checked (Any)
import sys, os
f = os.path.join(sys.argv[1], "lib/Oidc.roc")
s = open(f).read()
old = 'aud: OneOf([ctx.audience])'
new = 'aud: Any'
assert old in s, "mutation text not found"
open(f, "w").write(s.replace(old, new, 1))
