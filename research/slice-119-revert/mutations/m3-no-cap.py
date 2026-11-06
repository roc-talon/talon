import sys; sys.path.insert(0, __import__('os').path.dirname(__file__)); from _mut import mutate
mutate(sys.argv[1], "lib/Reconcile.roc", "while $i < fail_count and $d < interval {", "while $i < fail_count {")
mutate(sys.argv[1], "lib/Reconcile.roc", "now + (if ($d < interval) $d else interval)", "now + $d")
