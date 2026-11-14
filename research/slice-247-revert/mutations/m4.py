# Mutation m4 of slice 247 (revert check): worker/lib/Move.roc: the text below is replaced. Usage: m4.py <copy root>
import sys
root = sys.argv[1]
p = f'{root}/worker/lib/Move.roc'
s = open(p).read()
old = 'if is_succ and owner == Ok(old.owner_id.to_str()) {'
new = 'if is_succ {'
assert old in s, 'anchor not found: ' + old[:50]
open(p, 'w').write(s.replace(old, new, 1))
