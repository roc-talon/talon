# Mutation m1-alg-list of the slice 108b reference: the alg allowlist also has RS384
import sys, os
f = os.path.join(sys.argv[1], "lib/Oidc.roc")
s = open(f).read()
old = 'algs = [RS256]'
new = 'algs = [RS256, RS384]'
assert old in s, "mutation text not found"
open(f, "w").write(s.replace(old, new, 1))
