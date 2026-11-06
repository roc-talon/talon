# Mutation m7-repo-case of the slice 108 reference: repository compared with case
import sys, os
f = os.path.join(sys.argv[1], "lib/Oidc.roc")
s = open(f).read()
old = '!repo.caseless_ascii_equals(asset.owner_repo)'
new = 'repo != asset.owner_repo'
assert old in s, "mutation text not found"
open(f, "w").write(s.replace(old, new, 1))
