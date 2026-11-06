# Mutation m13-status-always-201 of the slice 109 reference
import sys, os
f = os.path.join(sys.argv[1], 'lib/Toolchains.roc')
s = open(f).read()
old = 'if (changes.any(|c| c > 0)) 201 else 200'
new = '201'
assert old in s, "mutation text not found"
open(f, "w").write(s.replace(old, new, 1))
