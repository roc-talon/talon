# Mutation m3 of slice 247 (revert check): worker/MoveRoutes.roc: the text below is replaced. Usage: m3.py <copy root>
import sys
root = sys.argv[1]
p = f'{root}/worker/MoveRoutes.roc'
s = open(p).read()
old = ' AND r.yanked = 0 AND r.withdrawn IS NULL'
new = ''
assert old in s, 'anchor not found: ' + old[:50]
open(p, 'w').write(s.replace(old, new, 1))
