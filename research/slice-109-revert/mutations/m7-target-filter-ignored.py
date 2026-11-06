# Mutation m7-target-filter-ignored of the slice 109 reference
import sys, os
f = os.path.join(sys.argv[1], 'ToolchainRoutes.roc')
s = open(f).read()
old = 'Ok(t) => D1.all!(db, sql, (q.after, t))'
new = 'Ok(_) => D1.all!(db, sql, [q.after])'
assert old in s, "mutation text not found"
open(f, "w").write(s.replace(old, new, 1))
