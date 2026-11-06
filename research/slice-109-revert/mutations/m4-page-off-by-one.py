# Mutation m4-page-off-by-one of the slice 109 reference
import sys, os
f = os.path.join(sys.argv[1], 'lib/Toolchains.roc')
s = open(f).read()
old = 'if (rows.len() > page_limit)'
new = 'if (rows.len() >= page_limit)'
assert old in s, "mutation text not found"
open(f, "w").write(s.replace(old, new, 1))
