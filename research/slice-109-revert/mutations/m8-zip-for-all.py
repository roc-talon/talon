# Mutation m8-zip-for-all of the slice 109 reference
import sys, os
f = os.path.join(sys.argv[1], 'lib/Toolchains.roc')
s = open(f).read()
old = 'if (target.starts_with("windows_")) ".zip" else ".tar.gz"'
new = 'if (target.starts_with("windows_x")) ".zip" else ".tar.gz"'
assert old in s, "mutation text not found"
open(f, "w").write(s.replace(old, new, 1))
