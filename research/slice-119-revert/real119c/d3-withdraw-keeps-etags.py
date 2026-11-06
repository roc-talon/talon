import sys; sys.path.insert(0, __import__("os").path.dirname(__file__)); from _mut import mutate
# the withdraw keeps etag and repo_etag (Q376)
mutate(sys.argv[1], 'IndexQueue.roc', '[event, state, releases, etags]', '[event, state, releases]')
