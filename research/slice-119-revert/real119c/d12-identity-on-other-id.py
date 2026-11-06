import sys; sys.path.insert(0, __import__("os").path.dirname(__file__)); from _mut import mutate
# row 1 and 3 mark without the check of the row of F
mutate(sys.argv[1], 'ReconcileCron.roc', 'AND state <> 2 AND (NOT EXISTS (SELECT 1 FROM repos WHERE repo = ?1) OR EXISTS (SELECT 1 FROM repos WHERE repo = ?1 AND state = 2 AND repository_id = ?3))"', 'AND state <> 2"')
