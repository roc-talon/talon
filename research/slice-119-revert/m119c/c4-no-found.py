import sys; sys.path.insert(0, __import__("os").path.dirname(__file__)); from _mut import mutate
# a missing row stays missing on a public read
mutate(sys.argv[1], "ReconcileCron.roc", "repository_id = ?2 AND state = 1\", (fid, id, now)", "repository_id = ?2 AND state = 99\", (fid, id, now)")
