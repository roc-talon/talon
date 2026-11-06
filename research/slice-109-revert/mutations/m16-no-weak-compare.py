# Mutation m16-no-weak-compare of the slice 109 reference
import sys, os
f = os.path.join(sys.argv[1], 'ToolchainRoutes.roc')
s = open(f).read()
old = '(if (t.starts_with("W/")) t.drop_prefix("W/") else t) == etag'
new = 't == etag'
assert old in s, "mutation text not found"
open(f, "w").write(s.replace(old, new, 1))
