# m12 (247b): the sub-select takes the FIRST event of action 1 or 3 (ORDER BY seq ASC) in the read routes and the closure.
import sys, runpy
runpy.run_path(__file__.replace("m12.py", "ref247b.py"), run_name="__main__")
root = sys.argv[1]
for f in ("worker/ReadRoutes.roc", "worker/sql/closure/repos.sql"):
    p = f"{root}/{f}"; s = open(p).read()
    assert "ORDER BY e.seq DESC" in s
    open(p, "w").write(s.replace("ORDER BY e.seq DESC", "ORDER BY e.seq ASC"))
