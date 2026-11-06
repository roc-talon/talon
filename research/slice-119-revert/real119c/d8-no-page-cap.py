import sys; sys.path.insert(0, __import__("os").path.dirname(__file__)); from _mut import mutate
# more than 10 pages is not a failure
mutate(sys.argv[1], 'ReconcileCron.roc', 'if $n >= Reconcile.max_pages {', 'if $n >= 1000 {')
