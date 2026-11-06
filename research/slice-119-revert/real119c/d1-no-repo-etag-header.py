import sys; sys.path.insert(0, __import__("os").path.dirname(__file__)); from _mut import mutate
# the visibility read never sends If-None-Match
mutate(sys.argv[1], 'ReconcileCron.roc', 'request = if (c.repo_etag.is_empty()) ask else ask.with_header("if-none-match", c.repo_etag)', 'request = ask')
