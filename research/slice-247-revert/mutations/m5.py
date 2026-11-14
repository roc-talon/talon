# Mutation m5 of slice 247 (revert check): worker/MoveRoutes.roc: the text below is replaced. Usage: m5.py <copy root>
import sys
root = sys.argv[1]
p = f'{root}/worker/MoveRoutes.roc'
s = open(p).read()
old = 'state = 2, successor = ?2, state_at = ?3, offer = NULL WHERE'
new = 'state = 2, successor = ?2, state_at = ?3 WHERE'
assert old in s, 'anchor not found: ' + old[:50]
open(p, 'w').write(s.replace(old, new, 1))
