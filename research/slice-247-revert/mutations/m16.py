# m16 (247b, Q247-9): the check of the old ids always passes (a stranger token of the old name is not refused).
import sys, runpy
runpy.run_path(__file__.replace("m16.py", "ref247b.py"), run_name="__main__")
root = sys.argv[1]
p = f"{root}/worker/MoveRoutes.roc"; s = open(p).read()
import re
m = re.search(r"\n\told_ids! = \|claims, old\| \{", s)
assert m, "old_ids! not found"
open(p, "w").write(s[:m.end()] + "\n\t\tif Bool.True { return Ok(Go) }" + s[m.end():])
