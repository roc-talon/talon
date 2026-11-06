# Mutation m5-after-inclusive of the slice 109 reference
import sys, os
f = os.path.join(sys.argv[1], 'ToolchainRoutes.roc')
s = open(f).read()
old = 'WHERE log_index > ? ORDER BY log_index LIMIT 1001'
new = 'WHERE log_index >= ? ORDER BY log_index LIMIT 1001'
assert old in s, "mutation text not found"
open(f, "w").write(s.replace(old, new, 1))
