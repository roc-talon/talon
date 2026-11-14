# Mutation m7 of slice 247 (revert check): worker/lib/Move.roc: the text below is replaced. Usage: m7.py <copy root>
import sys
root = sys.argv[1]
p = f'{root}/worker/lib/Move.roc'
s = open(p).read()
old = 'if is_old or repository.caseless_ascii_equals(successor) Ok({})'
new = 'if is_old Ok({})'
assert old in s, 'anchor not found: ' + old[:50]
open(p, 'w').write(s.replace(old, new, 1))
