# Mutation m11-leading-zero-ok of the slice 109 reference
import sys, os
f = os.path.join(sys.argv[1], 'lib/Toolchains.roc')
s = open(f).read()
old = ' and (bytes.len() == 1 or bytes.first() != Ok(48))'
new = ''
assert old in s, "mutation text not found"
open(f, "w").write(s.replace(old, new, 1))
