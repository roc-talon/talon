# Mutation m3-ambiguous-first of the slice 109 reference
import sys, os
f = os.path.join(sys.argv[1], 'lib/Toolchains.roc')
s = open(f).read()
old = '\t\t[one] => match valid_digest(one.digest) {'
new = '\t\t[one, ..] => match valid_digest(one.digest) {'
assert old in s, "mutation text not found"
open(f, "w").write(s.replace(old, new, 1))
