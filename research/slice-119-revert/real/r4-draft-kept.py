import sys; sys.path.insert(0, __import__("os").path.dirname(__file__)); from _mut import mutate
mutate(sys.argv[1], "lib/Reconcile.roc", "Ok(item) if item.release.draft => Withdrawn(\"deleted\")\n", "")
