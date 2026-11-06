import sys; sys.path.insert(0, __import__("os").path.dirname(__file__)); from _mut import mutate
mutate(sys.argv[1], "lib/Reconcile.roc", "\"UPDATE repo_checks SET next_check_at = ?1 + 900000 WHERE", "\"UPDATE repo_checks SET next_check_at = next_check_at + 0 * ?1 + 0 * 900000 WHERE")
