import sys; sys.path.insert(0, __import__("os").path.dirname(__file__)); from _mut import mutate
# a duplicate id of two pages is not merged
mutate(sys.argv[1], 'ReconcileCron.roc', 'list: Reconcile.merge_pages($pages)', 'list: $pages.join_map(|p| p)')
