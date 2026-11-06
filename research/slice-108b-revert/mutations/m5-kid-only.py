# Mutation m5-kid-only of the slice 108b reference: the key by kid only, not Jwk.select (a wrong kty with the right kid is used)
import sys, os
f = os.path.join(sys.argv[1], "lib/Oidc.roc")
s = open(f).read()
old = 'match Jwk.select(Jwk.parse_set(keys.jwks) ?? [], header) {'
new = 'match (Jwk.parse_set(keys.jwks) ?? []).find_first(|k| k.kid == header.kid) {'
assert old in s, "mutation text not found"
open(f, "w").write(s.replace(old, new, 1))
