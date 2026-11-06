import sys; sys.path.insert(0, __import__("os").path.dirname(__file__)); from _mut import mutate
# a name F of another repository id gets the rename (row 1 without the F check)
mutate(sys.argv[1], "ReconcileCron.roc", "AND state <> 2 AND NOT EXISTS (SELECT 1 FROM repos WHERE repo = ?1)\", (fid, now, id))", "AND state <> 2\", (fid, now, id))")
