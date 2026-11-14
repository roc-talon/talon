# Mutation m8 of slice 247 (revert check): worker/MoveRoutes.roc: the text below is replaced. Usage: m8.py <copy root>
import sys
root = sys.argv[1]
p = f'{root}/worker/MoveRoutes.roc'
s = open(p).read()
old = 'Token(c) => Ok(Publish.claims_json(c))'
new = 'Token(_) => Ok("{}")'
assert old in s, 'anchor not found: ' + old[:50]
open(p, 'w').write(s.replace(old, new, 1))
