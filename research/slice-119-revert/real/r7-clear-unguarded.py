import sys; sys.path.insert(0, __import__("os").path.dirname(__file__)); from _mut import mutate
mutate(sys.argv[1], "ReconcileCron.roc", "WHERE log_index = ?1 AND withdrawn IS NOT NULL AND withdrawn <> 'repo-missing'\"", "WHERE log_index = ?1\"")
