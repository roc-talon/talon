import sys
d = sys.argv[1]
f = d + '/PublishRoutes.roc'
s = open(f).read()
old = '\t\tidentity = match IngestRoutes.identity!(target, repo_id, github_repo, old, now, claims_text)? {'
new = '\t\tconflict = match Publish.after_read(target, rows, { facts: Bool.False, events: Bool.False }) {\n\t\t\tOk(Conflict(_)) => Bool.True\n\t\t\t_ => Bool.False\n\t\t}\n\t\tidentity = match (if conflict Ok(Go({ stmts: [], events: Bool.False })) else IngestRoutes.identity!(target, repo_id, github_repo, old, now, claims_text))? {'
assert s.count(old) == 1, (s.count(old), old)
open(f, 'w').write(s.replace(old, new))
