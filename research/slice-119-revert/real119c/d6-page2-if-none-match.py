import sys; sys.path.insert(0, __import__("os").path.dirname(__file__)); from _mut import mutate
# every page sends If-None-Match
mutate(sys.argv[1], 'ReconcileCron.roc', 'next = page!(Request.get(Reconcile.page_url(full_name, $n)), $reserve)?', 'next = page!(if (c.etag.is_empty()) Request.get(Reconcile.page_url(full_name, $n)) else Request.get(Reconcile.page_url(full_name, $n)).with_header("if-none-match", c.etag), $reserve)?')
