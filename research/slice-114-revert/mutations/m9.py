import sys
d = sys.argv[1]
f = d + '/PublishRoutes.roc'
s = open(f).read()
old = 'IngestRoutes.dropping(IngestRoutes.index!(session, target, repo_id, old, ctx), req, target, 201)'
new = 'IngestRoutes.index!(session, target, repo_id, old, ctx)'
assert s.count(old) == 1, (s.count(old), old)
open(f, 'w').write(s.replace(old, new))
