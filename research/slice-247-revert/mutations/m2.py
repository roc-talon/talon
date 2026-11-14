# Mutation m2 of slice 247 (revert check): worker/MoveRoutes.roc: the text below is replaced. Usage: m2.py <copy root>
import sys
root = sys.argv[1]
p = f'{root}/worker/MoveRoutes.roc'
s = open(p).read()
old = 'ORDER BY r.version DESC, r.log_index DESC LIMIT 1",\n\t\t"SELECT r.state'
new = 'ORDER BY r.log_index DESC LIMIT 1",\n\t\t"SELECT r.state'
assert old in s, 'anchor not found: ' + old[:50]
open(p, 'w').write(s.replace(old, new, 1))
