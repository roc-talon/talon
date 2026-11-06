# Mutation m12-bad-digest-counts of the slice 109 reference
import sys, os
f = os.path.join(sys.argv[1], 'lib/Toolchains.roc')
s = open(f).read()
old = ' and valid_digest(a.digest) != Err(Bad)'
new = ''
assert old in s, "mutation text not found"
open(f, "w").write(s.replace(old, new, 1))
