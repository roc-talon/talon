# Mutation m2-leeway-0 of the slice 108b reference: Jwt.check gets no leeway
import sys, os
f = os.path.join(sys.argv[1], "lib/Oidc.roc")
s = open(f).read()
old = 'iss: OneOf([issuer]), leeway_s,'
new = 'iss: OneOf([issuer]), leeway_s: 0,'
assert old in s, "mutation text not found"
open(f, "w").write(s.replace(old, new, 1))
