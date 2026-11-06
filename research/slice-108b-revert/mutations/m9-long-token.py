# Mutation m9-long-token of the slice 108b reference: max_token_bytes raised to 100000
import sys, os
f = os.path.join(sys.argv[1], "lib/Oidc.roc")
s = open(f).read()
old = 'Jwt.decode(text, Jwt.Options.{ algs })'
new = 'Jwt.decode(text, Jwt.Options.{ algs, max_token_bytes: 100000 })'
assert old in s, "mutation text not found"
open(f, "w").write(s.replace(old, new, 1))
