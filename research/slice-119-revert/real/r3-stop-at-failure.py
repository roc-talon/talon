import sys; sys.path.insert(0, __import__("os").path.dirname(__file__)); from _mut import mutate
mutate(sys.argv[1], "ReconcileCron.roc", "Log.warn!(\"reconcile row failed\", { job: \"reconcile\", repository_id, fail_count: n, error })\n\t\t\t\treserve", "Log.warn!(\"reconcile row failed\", { job: \"reconcile\", repository_id, fail_count: n, error })\n\t\t\t\tOk(0)")
