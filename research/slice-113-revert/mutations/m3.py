import sys
d = sys.argv[1]
f = d + '/lib/Identity.roc'
s = open(f).read()
old = '''back = if (recreated) { state: Active, successor: Err(None) } else'''
new = '''back = if (recreated) { state: row.state, successor: row.successor } else'''
assert s.count(old) == 1, (s.count(old), old)
open(f, 'w').write(s.replace(old, new))
