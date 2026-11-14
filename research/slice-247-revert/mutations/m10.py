# Mutation m10 of slice 247 (revert check): worker/lib/Move.roc: the text below is replaced. Usage: m10.py <copy root>
import sys
root = sys.argv[1]
p = f'{root}/worker/lib/Move.roc'
s = open(p).read()
old = '\t\tOidc.claim_is(Forbidden, "event_name", claims.event_name, "workflow_dispatch")\n'
new = '\t\tOk({})\n'
assert old in s, 'anchor not found: ' + old[:50]
open(p, 'w').write(s.replace(old, new, 1))
