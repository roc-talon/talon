import sys; sys.path.insert(0, __import__("os").path.dirname(__file__)); from _mut import mutate
# every page sends If-None-Match
mutate(sys.argv[1], "ReconcileCron.roc", "if ($n == 1 and !c.etag.is_empty())", "if (!c.etag.is_empty())")
