import sys; sys.path.insert(0, __import__("os").path.dirname(__file__)); from _mut import mutate
# the clear has no guard on the claim value
mutate(sys.argv[1], 'ReconcileCron.roc', 'WHERE log_index = ?1 AND withdrawn = ?2", (change.log_index, Sql.or_null(seen)))', 'WHERE log_index = ?1 AND (?2 IS NULL OR 1)", (change.log_index, Sql.or_null(seen)))')
