# Mutation m1-always-read-github of the slice 109 reference
import sys, os
f = os.path.join(sys.argv[1], 'ToolchainRoutes.roc')
s = open(f).read()
old = 'match Toolchains.after_rows(tag, known) {'
new = 'match Toolchains.after_rows(tag, known.take_first(0)) {'
assert old in s, "mutation text not found"
open(f, "w").write(s.replace(old, new, 1))
