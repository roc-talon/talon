import sys
f = sys.argv[1] + '/IngestRoutes.roc'
s = open(f).read()
old = '''next_check_at = MIN(next_check_at, ?2)'''
new = '''next_check_at = MAX(next_check_at, ?2)'''
assert s.count(old) == 1, (s.count(old), old)
open(f, 'w').write(s.replace(old, new))
