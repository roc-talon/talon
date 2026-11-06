import sys
f = sys.argv[1] + '/IngestRoutes.roc'
s = open(f).read()
old = '''[mark, event_marked, back, event_back]'''
new = '''[back, event_back, mark, event_marked]'''
assert s.count(old) == 1, (s.count(old), old)
open(f, 'w').write(s.replace(old, new))
