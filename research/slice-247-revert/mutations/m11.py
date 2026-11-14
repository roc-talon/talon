# Mutation m11 of slice 247 (revert check): worker/MoveRoutes.roc: the text below is replaced. Usage: m11.py <copy root>
import sys
root = sys.argv[1]
p = f'{root}/worker/MoveRoutes.roc'
s = open(p).read()
old = 'state = 2, successor = ?2'
new = 'state = 0, successor = ?2'
assert old in s, 'anchor not found: ' + old[:50]
open(p, 'w').write(s.replace(old, new, 1))
