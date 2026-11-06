# Mutation m8-kid-optional of the slice 108b reference: a token with no kid is accepted
import sys, os
f = os.path.join(sys.argv[1], "lib/Oidc.roc")
s = open(f).read()
old = 'kid = token.header.kid ? |Missing| Problem.new(Unauthenticated, "the token kid is missing")'
new = 'kid = token.header.kid ?? ""'
assert old in s, "mutation text not found"
open(f, "w").write(s.replace(old, new, 1))
