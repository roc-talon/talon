import sys; sys.path.insert(0, __import__("os").path.dirname(__file__)); from _mut import mutate
# the list etag is stored for more than one page
mutate(sys.argv[1], "ReconcileCron.roc", "etag = if ($n > 1) Err(None) else $etag", "etag = $etag")
