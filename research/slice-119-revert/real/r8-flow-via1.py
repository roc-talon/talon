import sys; sys.path.insert(0, __import__("os").path.dirname(__file__)); from _mut import mutate
mutate(sys.argv[1], "IndexQueue.roc", "flow = { repo: found.repo, identity, now, via, claims", "flow = { repo: found.repo, identity, now, via: 1, claims")
