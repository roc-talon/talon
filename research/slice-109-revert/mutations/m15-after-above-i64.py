# Mutation m15-after-above-i64 of the slice 109 reference
import sys, os
f = os.path.join(sys.argv[1], 'lib/Toolchains.roc')
s = open(f).read()
old = 'Ok(n) if n <= 9223372036854775807 => Ok(n)'
new = 'Ok(n) => Ok(n)'
assert old in s, "mutation text not found"
open(f, "w").write(s.replace(old, new, 1))
