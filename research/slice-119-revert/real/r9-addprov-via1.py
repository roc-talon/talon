import sys; sys.path.insert(0, __import__("os").path.dirname(__file__)); from _mut import mutate
mutate(sys.argv[1], "IndexQueue.roc", "SELECT ?1, ?3, NULL, ?2 WHERE NOT EXISTS", "SELECT ?1, 1, NULL, ?2 WHERE NOT EXISTS")
