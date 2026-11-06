import sys; sys.path.insert(0, __import__('os').path.dirname(__file__)); from _mut import mutate
mutate(sys.argv[1], "lib/Reconcile.roc", "WHERE r.repo IN (SELECT o.repo FROM repos o WHERE o.repository_id = (SELECT p.repository_id FROM repos p WHERE p.repo = repo_checks.repo))) AS rows", "WHERE r.repo = repo_checks.repo) AS rows")
