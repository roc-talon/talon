import sys
f = sys.argv[1] + '/IngestRoutes.roc'
s = open(f).read()
old = '''Err(None) if !same =>'''
new = '''Err(None) if !same and change.row.repository_id == 0 =>'''
assert s.count(old) == 1, (s.count(old), old)
open(f, 'w').write(s.replace(old, new))
