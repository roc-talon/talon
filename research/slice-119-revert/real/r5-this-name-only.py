import sys; sys.path.insert(0, __import__("os").path.dirname(__file__)); from _mut import mutate
mutate(sys.argv[1], "lib/Reconcile.roc", "WHERE r.repo IN (SELECT repo FROM repos WHERE repository_id = (${same_id}))", "WHERE r.repo = repo_checks.repo")
