import sys; sys.path.insert(0, __import__("os").path.dirname(__file__)); from _mut import mutate
# a missing row stays missing on a public read
mutate(sys.argv[1], 'ReconcileCron.roc', 'WHERE repo = ?1 AND state = 1 AND repository_id = ?3', 'WHERE repo = ?1 AND state = 99 AND repository_id = ?3')
