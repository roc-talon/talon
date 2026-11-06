# Mutation m6-aud-slash of the slice 108 reference: aud with a trailing / is accepted
import sys, os
f = os.path.join(sys.argv[1], "lib/Oidc.roc")
s = open(f).read()
old = 'same("aud", claims.aud, ctx.audience'
new = 'same("aud", claims.aud.map_ok(|a| a.drop_suffix("/")), ctx.audience'
assert old in s, "mutation text not found"
open(f, "w").write(s.replace(old, new, 1))
