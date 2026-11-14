# Mutation m6 of slice 247 (revert check): worker/lib/Move.roc: the text below is replaced. Usage: m6.py <copy root>
import sys
root = sys.argv[1]
p = f'{root}/worker/lib/Move.roc'
s = open(p).read()
old = 'Ok(successor) => if successor == name Same else Replace'
new = 'Ok(_) => Replace'
assert old in s, 'anchor not found: ' + old[:50]
open(p, 'w').write(s.replace(old, new, 1))
