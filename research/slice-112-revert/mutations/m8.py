# next_check_at is the clock, with no interval (R-PU26)
import sys
p = sys.argv[1] + '/lib/Ingest.roc'
s = open(p).read()
old = 'next_check_at: input.now_ms + Reads.interval_ms(Bool.False)'
new = 'next_check_at: input.now_ms'
assert s.count(old) == 1, old
open(p, 'w').write(s.replace(old, new))
