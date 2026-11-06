import sys; sys.path.insert(0, __import__("os").path.dirname(__file__)); from _mut import mutate
# a rename to a new name F writes no repo_checks row for F
mutate(sys.argv[1], "ReconcileCron.roc", "WHERE NOT EXISTS (SELECT 1 FROM repo_checks WHERE repo = ?1)", "WHERE 0")
