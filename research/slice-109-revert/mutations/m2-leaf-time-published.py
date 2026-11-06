# Mutation m2-leaf-time-published of the slice 109 reference
import sys, os
f = os.path.join(sys.argv[1], 'ToolchainRoutes.roc')
s = open(f).read()
old = 'now_ms: now, picked'
new = 'now_ms: (if (now > 0) release.published_at else now), picked'
assert old in s, "mutation text not found"
open(f, "w").write(s.replace(old, new, 1))
