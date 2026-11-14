# m13 (247b): the sub-select of the move routes takes the last event of ANY action 1, 3 or 6 (a move event hides the transfer).
import sys, runpy
runpy.run_path(__file__.replace("m13.py", "ref247b.py"), run_name="__main__")
root = sys.argv[1]
p = f"{root}/worker/MoveRoutes.roc"; s = open(p).read()
assert "e.action IN (1, 3)" in s
open(p, "w").write(s.replace("e.action IN (1, 3)", "e.action IN (1, 3, 6, 7, 8)").replace("(Ok(1), Ok(t))", "(Ok(1), Ok(t))"))
