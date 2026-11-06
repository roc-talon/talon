import sys; sys.path.insert(0, __import__("os").path.dirname(__file__)); from _mut import mutate
# a new F gets no repo_checks row
mutate(sys.argv[1], 'ReconcileCron.roc', 'WHERE NOT EXISTS (SELECT 1 FROM repo_checks WHERE repo = ?1) AND EXISTS', 'WHERE 0 AND EXISTS')
