# m15 (247b, Q247-13): the move does not drop the R-AP1 key of the old name.
import sys, runpy
runpy.run_path(__file__.replace("m15.py", "ref247b.py"), run_name="__main__")
root = sys.argv[1]
p = f"{root}/worker/MoveRoutes.roc"; s = open(p).read()
a = "match Cache.default.delete!(key) {"
assert a in s
open(p, "w").write(s.replace(a, "match Ok({}) {").replace("Err(e) => Log.warn!(\"cache drop failed\", { key, error: Str.inspect(e) })", "Err(_) => {}"))
