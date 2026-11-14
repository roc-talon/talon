# m14 (247b): the decoder maps an unknown action to recreate (no BadJson).
import sys, runpy
runpy.run_path(__file__.replace("m14.py", "ref247b.py"), run_name="__main__")
root = sys.argv[1]
p = f"{root}/packages/records/Closure.roc"; s = open(p).read()
a = 'other => Err(bad("owner_changed.action", other))'
assert a in s
open(p, "w").write(s.replace(a, 'other => Ok({ action: Recreate, at: w.at })'))
