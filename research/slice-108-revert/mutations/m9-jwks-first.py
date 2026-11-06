# Mutation m9-jwks-first of the slice 108 reference: the JWKS is read before the token is parsed
import sys, os
f = os.path.join(sys.argv[1], "Auth.roc")
s = open(f).read()
old = 'jwt = Oidc.parse(token)?\n\t\tkey = key!(jwt.kid)?'
new = '_ = jwks.get!(load!)?\n\t\tjwt = Oidc.parse(token)?\n\t\tkey = key!(jwt.kid)?'
assert old in s, "mutation text not found"
open(f, "w").write(s.replace(old, new, 1))
