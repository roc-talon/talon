import sys; sys.path.insert(0, __import__("os").path.dirname(__file__)); from _mut import mutate
# repo_etag is stored also for a renamed row
mutate(sys.argv[1], "ReconcileCron.roc", "row_name: c.name ?? \"\", full_name,", "row_name: full_name.with_ascii_lowercased(), full_name,")
