import sys
d = sys.argv[1]
f = d + '/PublishRoutes.roc'
s = open(f).read()
old = 'first = session.batch!([Sql.stmt(IngestRoutes.label_sql_of(0),'
new = 'first = session.batch!([Sql.stmt(IngestRoutes.label_sql_of(3),'
assert s.count(old) == 1, (s.count(old), old)
open(f, 'w').write(s.replace(old, new))
