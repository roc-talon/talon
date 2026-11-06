import sys
f = sys.argv[1] + '/lib/Identity.roc'
s = open(f).read()
old = 'state_at: if (moved_state) input.now else row.state_at, time: row.time }'
new = 'state_at: if (moved_state) input.now else row.state_at, time: input.now }'
assert s.count(old) == 1
open(f, 'w').write(s.replace(old, new))
